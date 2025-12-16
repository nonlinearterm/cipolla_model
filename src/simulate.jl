using Random
using Distributions: Exponential, Normal

struct SimulationResult
    u::Vector{Float64}
    W_series::Vector{Float64}
end

"""
Run the Minimal ABM (v1/v2).

Each step samples an ordered pair i→j (i≠j), draws:
- a ~ Exponential(A)
- ϵ_i, ϵ_j ~ Normal(0, σ^2)

Then updates:
Δu_i = s_self(type_i)*a + ϵ_i
Δu_j = s_other(type_i)*a + ϵ_j

If leverage is enabled, both deltas are multiplied by (L_actor^alpha).
"""
function simulate(params::ModelParams; rng::AbstractRNG=MersenneTwister(params.random_seed))
    N = params.N
    T = params.T_steps

    types = sample_types(rng, params.p_types, N)
    leverages = sample_leverages(rng, params.leverage, types)
    u = fill(params.u0, N)

    W_series = Vector{Float64}(undef, T + 1)
    W = sum(u)
    W_series[1] = W

    dist_a = Exponential(params.A)
    dist_eps = Normal(0.0, params.sigma)

    @inbounds for t in 1:T
        i = rand(rng, 1:N)
        j = rand(rng, 1:(N - 1))
        j = (j >= i) ? (j + 1) : j  # map to {1..N}\{i}

        a = rand(rng, dist_a)
        eps_i = rand(rng, dist_eps)
        eps_j = rand(rng, dist_eps)

        ti = types[i]
        du_i = sign_self(ti) * a + eps_i
        du_j = sign_other(ti) * a + eps_j

        if params.leverage.enabled
            f = leverages[i]^params.leverage.alpha
            du_i *= f
            du_j *= f
        end

        u[i] += du_i
        u[j] += du_j
        W += du_i + du_j
        W_series[t + 1] = W
    end

    return SimulationResult(u, W_series)
end



