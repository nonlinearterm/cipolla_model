using Random

struct LeverageSpec
    enabled::Bool
    alpha::Float64
    gamma::Float64                  # actor sampling weight exponent: P(actor=i) ∝ L_i^gamma
    dist::Symbol
    lmin::Float64
    mu::Float64
    sigma::Float64
    type_bias::Dict{AgentType,Float64}  # multiplicative factor per type (>=0); only used when mode = :type_biased
    mode::Symbol                        # :independent or :type_biased
end

struct ModelParams
    N::Int
    T_steps::Int
    A::Float64
    sigma::Float64
    p_types::Dict{AgentType,Float64}
    random_seed::Int
    u0::Float64
    u_threshold::Float64
    leverage::LeverageSpec
end

function ModelParams(;
    N::Integer,
    T_steps::Integer,
    A::Real,
    sigma::Real,
    p_types,
    random_seed::Integer=12345,
    u0::Real=0.0,
    u_threshold::Real=-Inf,
    leverage = nothing,
)
    N <= 1 && error("N must be > 1, got $N")
    T_steps <= 0 && error("T_steps must be > 0, got $T_steps")
    A <= 0 && error("A must be > 0, got $A")
    sigma < 0 && error("sigma must be >= 0, got $sigma")

    pt = Dict{AgentType,Float64}()
    for (k, v) in p_types
        pt[parse_agent_type(k)] = Float64(v)
    end
    for t in (I, B, H, S)
        haskey(pt, t) || error("p_types missing key $(t). Provide I,B,H,S.")
        pt[t] < 0 && error("p_types[$(t)] must be >= 0, got $(pt[t])")
    end
    s = sum(values(pt))
    isfinite(s) || error("p_types sum must be finite, got $s")
    abs(s - 1.0) > 1e-9 && error("p_types must sum to 1.0, got $s")

    lev = leverage === nothing ? LeverageSpec(false, 1.0, 0.0, :lognormal, 1.0, 0.0, 0.0, Dict{AgentType,Float64}(), :independent) : leverage
    lev.lmin < 1.0 && error("leverage.lmin must be >= 1.0, got $(lev.lmin)")
    lev.alpha < 0 && error("leverage.alpha must be >= 0, got $(lev.alpha)")
    lev.gamma < 0 && error("leverage.gamma must be >= 0, got $(lev.gamma)")
    (lev.mode == :independent || lev.mode == :type_biased) || error("leverage.mode must be :independent or :type_biased")
    (lev.dist == :lognormal) || error("leverage.dist must be :lognormal (v2)")

    return ModelParams(
        Int(N),
        Int(T_steps),
        Float64(A),
        Float64(sigma),
        pt,
        Int(random_seed),
        Float64(u0),
        Float64(u_threshold),
        lev,
    )
end

"""
Sample `N` types from Multinomial(p_types) using the provided RNG.
"""
function sample_types(rng::AbstractRNG, p_types::Dict{AgentType,Float64}, N::Int)
    # deterministic order for cumulative probs
    ts = (I, B, H, S)
    ps = (p_types[I], p_types[B], p_types[H], p_types[S])
    c1 = ps[1]
    c2 = c1 + ps[2]
    c3 = c2 + ps[3]
    # c4 = 1.0

    out = Vector{AgentType}(undef, N)
    @inbounds for n in 1:N
        r = rand(rng)
        out[n] = (r < c1) ? I : (r < c2) ? B : (r < c3) ? H : S
    end
    return out
end

function default_type_bias()
    # neutral multipliers
    return Dict{AgentType,Float64}(I=>1.0, B=>1.0, H=>1.0, S=>1.0)
end

"""
Sample leverage L_i >= lmin. v2 supports LogNormal(mu, sigma) shifted by lmin:
L = lmin * exp(N(mu, sigma)).
If leverage.mode == :type_biased, multiply by per-type factor type_bias[T_i].
"""
function sample_leverages(rng::AbstractRNG, lev::LeverageSpec, types::Vector{AgentType})
    N = length(types)
    out = Vector{Float64}(undef, N)
    if !lev.enabled
        fill!(out, 1.0)
        return out
    end
    # exp(N(mu, sigma))
    @inbounds for i in 1:N
        z = randn(rng) * lev.sigma + lev.mu
        Li = lev.lmin * exp(z)
        if lev.mode == :type_biased
            m = get(lev.type_bias, types[i], 1.0)
            Li *= m
        end
        # enforce >=1
        out[i] = max(1.0, Li)
    end
    return out
end



