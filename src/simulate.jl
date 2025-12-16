using Random
using Distributions: Exponential, Normal

struct SimulationResult
    u::Vector{Float64}
    W_series::Vector{Float64}
    collapse_step::Int      # 0 means no early collapse; otherwise first step where active<2
    active_final::Int
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

    # v4: absorbing state via bankruptcy_threshold (if finite)
    use_bankruptcy = isfinite(params.bankruptcy_threshold)
    active = trues(N)
    active_idx = collect(1:N)
    active_count = N
    active_pos = collect(1:N)  # active_pos[i] = position of i in active_idx, undefined if inactive

    # v3: actor sampling ∝ L^gamma among ACTIVE agents (rebuild alias when active set changes)
    function rebuild_actor_tab()
        if !(params.leverage.enabled && params.leverage.gamma > 0) || active_count == 0
            return nothing
        end
        w = Vector{Float64}(undef, active_count)
        @inbounds for p in 1:active_count
            w[p] = leverages[active_idx[p]]^params.leverage.gamma
        end
        return AliasTable(w)
    end
    actor_tab = rebuild_actor_tab()

    function deactivate!(k::Int)
        if !active[k]
            return false
        end
        active[k] = false
        # remove from active_idx by swap-remove in O(1)
        pos = active_pos[k]
        last = active_idx[end]
        active_idx[pos] = last
        active_pos[last] = pos
        pop!(active_idx)
        active_pos[k] = 0
        active_count -= 1
        return true
    end

    collapse_step = 0

    @inbounds for t in 1:T
        if use_bankruptcy && active_count < 2
            collapse_step = t
            # fill remaining series with last W
            for tt in t:T
                W_series[tt + 1] = W
            end
            break
        end

        # sample actor i
        if use_bankruptcy
            if actor_tab === nothing
                i = active_idx[rand(rng, 1:active_count)]
            else
                i = active_idx[sample(rng, actor_tab)]
            end
        else
            i = actor_tab === nothing ? rand(rng, 1:N) : sample(rng, actor_tab)
        end

        # sample target j uniformly among active, excluding i
        if use_bankruptcy
            # pick position in active_idx excluding actor's position
            apos = active_pos[i]
            jp = rand(rng, 1:(active_count - 1))
            jp = (jp >= apos) ? (jp + 1) : jp
            j = active_idx[jp]
        else
            j = rand(rng, 1:(N - 1))
            j = (j >= i) ? (j + 1) : j  # map to {1..N}\{i}
        end

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

        if use_bankruptcy
            changed = false
            if u[i] < params.bankruptcy_threshold
                changed |= deactivate!(i)
            end
            if u[j] < params.bankruptcy_threshold
                changed |= deactivate!(j)
            end
            if changed
                actor_tab = rebuild_actor_tab()
            end
        end
    end

    return SimulationResult(u, W_series, collapse_step, use_bankruptcy ? active_count : N)
end



