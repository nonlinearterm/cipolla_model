#!/usr/bin/env julia

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using CipollaModel
using JSON3
using DelimitedFiles
using Statistics: mean

function usage()
    println("Usage: julia --project scripts/run_grid_scan.jl /path/to/config.yaml [output_dir]")
end

function ensure_dir(path::AbstractString)
    isdir(path) || mkpath(path)
end

function scan_values(scan)::Vector{Any}
    if haskey(scan, "values")
        return scan["values"]
    elseif haskey(scan, "linspace")
        ls = scan["linspace"]
        start = Float64(ls["start"])
        stop = Float64(ls["stop"])
        num = Int(ls["num"])
        return collect(range(start, stop; length=num))
    else
        error("scan must contain values or linspace")
    end
end

function write_json(path::AbstractString, obj)
    open(path, "w") do io
        JSON3.write(io, obj; indent=2)
        write(io, "\n")
    end
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

function main()
    if length(ARGS) < 1
        usage()
        return 1
    end
    config_path = abspath(ARGS[1])
    out_dir = (length(ARGS) >= 2) ? abspath(ARGS[2]) : dirname(config_path)
    ensure_dir(out_dir)

    cfg = load_config(config_path)
    grid = cfg["grid"]

    pS_vals = scan_values(grid["p_S"])
    gamma_vals = scan_values(grid["gamma"])
    R = Int(get(grid, "replicates", 3))
    seed0 = Int(get(cfg, "random_seed", 12345))

    # write long table
    long_rows = Vector{Vector{Any}}()
    push!(long_rows, Any["p_S","gamma","seed","collapsed","collapse_step","m_W","final_mean_u","final_W","active_final"])

    # write summary per cell
    sum_rows = Vector{Vector{Any}}()
    push!(sum_rows, Any["p_S","gamma","replicates","collapse_prob","collapse_step_mean","m_W_mean","final_mean_u_mean"])

    cells = Vector{Any}()

    for (ip, pS_raw) in enumerate(pS_vals)
        pS = Float64(pS_raw)
        (0.0 <= pS < 1.0) || error("p_S must be in [0,1), got $pS")
        rest = 1.0 - pS

        base = cfg["p_types_base"]
        base_I = Float64(base["I"])
        base_B = Float64(base["B"])
        base_H = Float64(base["H"])
        base_sum = base_I + base_B + base_H
        base_I /= base_sum; base_B /= base_sum; base_H /= base_sum

        for (ig, g_raw) in enumerate(gamma_vals)
            g = Float64(g_raw)
            g >= 0 || error("gamma must be >= 0, got $g")

            collapsed_flags = Int[]
            collapse_steps = Float64[]
            mWs = Float64[]
            mus = Float64[]

            for r in 1:R
                cfg_k = copy(cfg)
                cfg_k["p_types"] = Dict("I"=>rest*base_I, "B"=>rest*base_B, "H"=>rest*base_H, "S"=>pS)
                # override gamma
                lev = copy(cfg_k["leverage"])
                lev["gamma"] = g
                cfg_k["leverage"] = lev

                seed = seed0 + ((ip-1)*length(gamma_vals) + (ig-1))*R + (r-1)
                cfg_k["random_seed"] = seed

                params = params_from_config(cfg_k)
                res = simulate(params)
                m = measure_summary(res; u_threshold=params.u_threshold)

                collapsed = m["collapsed"] ? 1 : 0
                push!(collapsed_flags, collapsed)
                push!(collapse_steps, Float64(m["collapse_step"]))
                push!(mWs, Float64(m["m_W"]))
                push!(mus, Float64(m["final_mean_u"]))

                push!(long_rows, Any[pS, g, seed, collapsed, m["collapse_step"], m["m_W"], m["final_mean_u"], m["final_W"], m["active_final"]])
            end

            collapse_prob = mean(Float64.(collapsed_flags))
            cs_mean = mean(collapse_steps)
            mW_mean, _ = mean_std(mWs)
            mu_mean, _ = mean_std(mus)

            push!(sum_rows, Any[pS, g, R, collapse_prob, cs_mean, mW_mean, mu_mean])
            push!(cells, Dict("p_S"=>pS, "gamma"=>g, "replicates"=>R, "collapse_prob"=>collapse_prob, "collapse_step_mean"=>cs_mean, "m_W_mean"=>mW_mean, "final_mean_u_mean"=>mu_mean))
        end
    end

    writedlm(joinpath(out_dir, "grid_long.csv"), long_rows, ',')
    writedlm(joinpath(out_dir, "grid_summary.csv"), sum_rows, ',')

    out = Dict(
        "status" => "OK",
        "meta" => Dict(
            "model" => get(cfg, "model", "v4_absorbing"),
            "model_version" => get(cfg, "model_version", "leverage-v4"),
            "grid" => Dict("p_S"=>grid["p_S"], "gamma"=>grid["gamma"], "replicates"=>R),
            "bankruptcy_threshold" => get(cfg, "bankruptcy_threshold", get(cfg, "bankrupt_threshold", nothing)),
        ),
        "cells" => cells,
    )
    write_json(joinpath(out_dir, "summary.json"), out)

    return 0
end

exit(main())


