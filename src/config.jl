using YAML

"""
Load a YAML config file into a Dict.
"""
function load_config(path::AbstractString)
    return YAML.load_file(path)
end

@inline function _get_any(cfg, keys::Tuple, default=nothing)
    for k in keys
        haskey(cfg, k) && return cfg[k]
    end
    return default
end

"""
Convert a config Dict (single-run) into ModelParams.

Required keys:
- N, T_steps, A, sigma (or σ), p_types
Optional:
- random_seed (or seed), u0, u_threshold
"""
function params_from_config(cfg)::ModelParams
    N = _get_any(cfg, ("N",), nothing)
    T_steps = _get_any(cfg, ("T_steps", "T", "steps"), nothing)
    A = _get_any(cfg, ("A",), nothing)
    sigma = _get_any(cfg, ("sigma", "σ"), 0.0)
    p_types = _get_any(cfg, ("p_types",), nothing)

    N === nothing && error("Config missing required key: N")
    T_steps === nothing && error("Config missing required key: T_steps")
    A === nothing && error("Config missing required key: A")
    p_types === nothing && error("Config missing required key: p_types")

    random_seed = _get_any(cfg, ("random_seed", "seed"), 12345)
    u0 = _get_any(cfg, ("u0",), 0.0)
    u_threshold = _get_any(cfg, ("u_threshold",), -Inf)

    # v2 leverage (optional; defaults keep v1 behavior)
    lev_cfg = get(cfg, "leverage", nothing)
    leverage = nothing
    if lev_cfg !== nothing
        enabled = Bool(get(lev_cfg, "enabled", true))
        alpha = Float64(get(lev_cfg, "alpha", 1.0))
        dist = Symbol(get(lev_cfg, "dist", "lognormal"))
        lmin = Float64(get(lev_cfg, "lmin", 1.0))
        mu = Float64(get(lev_cfg, "mu", 0.0))
        sigmaL = Float64(get(lev_cfg, "sigma", 0.0))
        mode = Symbol(get(lev_cfg, "mode", "independent"))

        tb = default_type_bias()
        if haskey(lev_cfg, "type_bias")
            raw = lev_cfg["type_bias"]
            for (k, v) in raw
                tb[parse_agent_type(k)] = Float64(v)
            end
        end
        leverage = LeverageSpec(enabled, alpha, dist, lmin, mu, sigmaL, tb, mode)
    end

    return ModelParams(
        N = N,
        T_steps = T_steps,
        A = A,
        sigma = sigma,
        p_types = p_types,
        random_seed = random_seed,
        u0 = u0,
        u_threshold = u_threshold,
        leverage = leverage,
    )
end



