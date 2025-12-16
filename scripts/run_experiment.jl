#!/usr/bin/env julia

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using CipollaModel
using JSON3
using DelimitedFiles

function usage()
    println("Usage: julia --project scripts/run_experiment.jl /path/to/config.yaml [output_dir]")
end

function ensure_dir(path::AbstractString)
    isdir(path) || mkpath(path)
end

function git_commit_or_unknown(repo_dir::AbstractString)
    try
        cmd = `git -C $repo_dir rev-parse HEAD`
        s = read(pipeline(cmd; stderr=devnull), String)
        return chomp(s)
    catch
        return "UNKNOWN"
    end
end

function write_json(path::AbstractString, obj)
    open(path, "w") do io
        JSON3.write(io, obj; indent=2)
        write(io, "\n")
    end
end

function scan_values(scan)::Vector{Any}
    if haskey(scan, "values")
        return scan["values"]
    elseif haskey(scan, "linspace")
        ls = scan["linspace"]
        start = Float64(ls["start"])
        stop = Float64(ls["stop"])
        num = Int(ls["num"])
        num >= 2 || error("scan.linspace.num must be >= 2, got $num")
        return collect(range(start, stop; length=num))
    elseif haskey(scan, "logspace")
        ls = scan["logspace"]
        start = Float64(ls["start"])
        stop = Float64(ls["stop"])
        num = Int(ls["num"])
        num >= 2 || error("scan.logspace.num must be >= 2, got $num")
        start > 0 || error("scan.logspace.start must be > 0, got $start")
        stop > 0 || error("scan.logspace.stop must be > 0, got $stop")
        r = (stop / start)^(1.0 / (num - 1))
        vals = Vector{Float64}(undef, num)
        vals[1] = start
        for k in 2:num
            vals[k] = vals[k - 1] * r
        end
        return vals
    else
        error("scan must contain one of: values, linspace, logspace")
    end
end

function scan_replicates(scan)::Int
    return Int(get(scan, "replicates", 1))
end

function metric_keys()
    return (
        "m_W",
        "final_W",
        "final_mean_u",
        "min_u",
        "var_u",
        "gini_shifted",
        "phi_u_lt_threshold",
    )
end

function mean_std(xs::Vector{Float64})
    n = length(xs)
    n == 0 && return (NaN, NaN)
    μ = sum(xs) / n
    if n == 1
        return (μ, 0.0)
    end
    s2 = 0.0
    @inbounds for x in xs
        d = x - μ
        s2 += d * d
    end
    return (μ, sqrt(s2 / (n - 1)))
end

function run_single(cfg, out_dir::AbstractString; tag=nothing)
    params = params_from_config(cfg)
    res = simulate(params)
    metrics = measure_summary(res; u_threshold=params.u_threshold)

    # Save time series (ignored by git by default)
    wcsv = isnothing(tag) ? "results_W.csv" : "results_W_$(tag).csv"
    writedlm(joinpath(out_dir, wcsv), res.W_series, ',')

    meta = Dict(
        "model" => get(cfg, "model", "minimal_abm_v1"),
        "model_version" => get(cfg, "model_version", "minimal-v1"),
        "git_commit" => get(cfg, "git_commit", git_commit_or_unknown(joinpath(@__DIR__, ".."))),
        "random_seed" => params.random_seed,
        "p_types" => Dict("I"=>params.p_types[I], "B"=>params.p_types[B], "H"=>params.p_types[H], "S"=>params.p_types[S]),
        "A" => params.A,
        "sigma" => params.sigma,
        "u0" => params.u0,
    )

    if isfinite(params.bankruptcy_threshold)
        meta["bankruptcy_threshold"] = params.bankruptcy_threshold
    end

    if params.leverage.enabled
        meta["leverage"] = Dict(
            "enabled" => true,
            "alpha" => params.leverage.alpha,
            "gamma" => params.leverage.gamma,
            "dist" => String(params.leverage.dist),
            "lmin" => params.leverage.lmin,
            "mu" => params.leverage.mu,
            "sigma" => params.leverage.sigma,
            "mode" => String(params.leverage.mode),
            "type_bias" => Dict("I"=>get(params.leverage.type_bias, I, 1.0),
                                "B"=>get(params.leverage.type_bias, B, 1.0),
                                "H"=>get(params.leverage.type_bias, H, 1.0),
                                "S"=>get(params.leverage.type_bias, S, 1.0)),
        )
    end

    return Dict(
        "status" => "OK",
        "timestamp" => utc_timestamp(),
        "meta" => meta,
        "metrics" => metrics,
    )
end

function run_scan(cfg, out_dir::AbstractString)
    scan = cfg["scan"]
    name = scan["name"]
    values = scan_values(scan)
    R = scan_replicates(scan)
    R >= 1 || error("scan.replicates must be >= 1, got $R")

    seed0 = Int(get(cfg, "random_seed", 12345))

    rows = Vector{Vector{Any}}()
    # summary table: mean/std for each metric
    header = Any[name]
    for k in metric_keys()
        push!(header, "$(k)_mean")
        push!(header, "$(k)_std")
    end
    push!(header, "replicates")
    push!(header, "seed_base")
    push!(rows, header)

    # long table: one row per (param, seed)
    long_rows = Vector{Vector{Any}}()
    push!(long_rows, Any[name, "seed", metric_keys()...])

    scan_results = Vector{Any}()
    if name == "p_S"
        base = cfg["p_types_base"]
        base_I = Float64(base["I"])
        base_B = Float64(base["B"])
        base_H = Float64(base["H"])
        base_sum = base_I + base_B + base_H
        base_sum > 0 || error("p_types_base must have positive sum")
        base_I /= base_sum
        base_B /= base_sum
        base_H /= base_sum

        for (k, pS_raw) in enumerate(values)
            pS = Float64(pS_raw)
            (0.0 <= pS < 1.0) || error("scan p_S must be in [0,1), got $pS")
            rest = 1.0 - pS

            ms = Dict{String, Vector{Float64}}()
            for kk in metric_keys()
                ms[kk] = Float64[]
            end

            for r in 1:R
                cfg_k = copy(cfg)
                cfg_k["p_types"] = Dict("I"=>rest*base_I, "B"=>rest*base_B, "H"=>rest*base_H, "S"=>pS)
                seed = seed0 + (k - 1) * R + (r - 1)
                cfg_k["random_seed"] = seed

                tag = "pS_$(replace(string(pS), "." => "_"))_seed_$(seed)"
                out = run_single(cfg_k, out_dir; tag=tag)
                m = out["metrics"]

                push!(scan_results, Dict("p_S" => pS, "seed" => seed, "metrics" => m))

                # long row
                long_row = Any[pS, seed]
                for kk in metric_keys()
                    v = Float64(m[kk])
                    push!(ms[kk], v)
                    push!(long_row, v)
                end
                push!(long_rows, long_row)
            end

            # summary row
            row = Any[pS]
            for kk in metric_keys()
                μ, σ = mean_std(ms[kk])
                push!(row, μ); push!(row, σ)
            end
            push!(row, R)
            push!(row, seed0 + (k - 1) * R)
            push!(rows, row)
        end
    elseif name == "N"
        Ns = unique(sort(Int.(round.(Float64.(values)))))
        for (k, N) in enumerate(Ns)
            N > 1 || error("scan N must be > 1, got $N")

            ms = Dict{String, Vector{Float64}}()
            for kk in metric_keys()
                ms[kk] = Float64[]
            end

            for r in 1:R
                cfg_k = copy(cfg)
                cfg_k["N"] = N
                seed = seed0 + (k - 1) * R + (r - 1)
                cfg_k["random_seed"] = seed

                tag = "N_$(N)_seed_$(seed)"
                out = run_single(cfg_k, out_dir; tag=tag)
                m = out["metrics"]

                push!(scan_results, Dict("N" => N, "seed" => seed, "metrics" => m))

                long_row = Any[N, seed]
                for kk in metric_keys()
                    v = Float64(m[kk])
                    push!(ms[kk], v)
                    push!(long_row, v)
                end
                push!(long_rows, long_row)
            end

            row = Any[N]
            for kk in metric_keys()
                μ, σ = mean_std(ms[kk])
                push!(row, μ); push!(row, σ)
            end
            push!(row, R)
            push!(row, seed0 + (k - 1) * R)
            push!(rows, row)
        end
    else
        error("Unsupported scan.name: $(repr(name)). Supported: p_S, N")
    end

    writedlm(joinpath(out_dir, "results_scan.csv"), rows, ',')
    writedlm(joinpath(out_dir, "results_scan_long.csv"), long_rows, ',')

    meta = Dict(
        "model" => get(cfg, "model", "minimal_abm_v1"),
        "model_version" => get(cfg, "model_version", "minimal-v1"),
        "git_commit" => get(cfg, "git_commit", git_commit_or_unknown(joinpath(@__DIR__, ".."))),
        "scan" => Dict("name"=>name, "values"=>values, "replicates"=>R),
        "A" => cfg["A"],
        "sigma" => get(cfg, "sigma", get(cfg, "σ", 0.0)),
        "u0" => get(cfg, "u0", 0.0),
    )

    return Dict(
        "status" => "OK",
        "timestamp" => utc_timestamp(),
        "meta" => meta,
        "scan_results" => scan_results,
    )
end

function main()
    if length(ARGS) < 1
        usage()
        return 1
    end

    config_path = abspath(ARGS[1])
    out_dir = (length(ARGS) >= 2) ? abspath(ARGS[2]) : dirname(config_path)
    ensure_dir(out_dir)

    cfg = load_config(config_path)
    out = haskey(cfg, "scan") ? run_scan(cfg, out_dir) : run_single(cfg, out_dir)

    write_json(joinpath(out_dir, "summary.json"), out)
    return 0
end

exit(main())


