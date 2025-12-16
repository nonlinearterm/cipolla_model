#!/usr/bin/env julia

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using CipollaModel
using JSON3
using DelimitedFiles
using Statistics: mean

function usage()
    println("Usage: julia --project scripts/run_grid_scan_N_pS.jl /path/to/config.yaml [output_dir]")
end

function ensure_dir(path::AbstractString)
    isdir(path) || mkpath(path)
end

function scan_values(spec)::Vector{Any}
    if haskey(spec, "values")
        return spec["values"]
    elseif haskey(spec, "linspace")
        ls = spec["linspace"]
        start = Float64(ls["start"])
        stop = Float64(ls["stop"])
        num = Int(ls["num"])
        return collect(range(start, stop; length=num))
    elseif haskey(spec, "logspace")
        ls = spec["logspace"]
        start = Float64(ls["start"])
        stop = Float64(ls["stop"])
        num = Int(ls["num"])
        r = (stop / start)^(1.0 / (num - 1))
        vals = Vector{Float64}(undef, num)
        vals[1] = start
        for k in 2:num
            vals[k] = vals[k - 1] * r
        end
        return vals
    else
        error("grid dimension must contain values/linspace/logspace")
    end
end

function write_json(path::AbstractString, obj)
    open(path, "w") do io
        JSON3.write(io, obj; indent=2)
        write(io, "\n")
    end
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

    Ns_raw = scan_values(grid["N"])
    Ns = unique(sort(Int.(round.(Float64.(Ns_raw)))))
    pS_vals = Float64.(scan_values(grid["p_S"]))
    R = Int(get(grid, "replicates", 3))
    seed0 = Int(get(cfg, "random_seed", 12345))

    base = cfg["p_types_base"]
    base_I = Float64(base["I"])
    base_B = Float64(base["B"])
    base_H = Float64(base["H"])
    base_sum = base_I + base_B + base_H
    base_I /= base_sum; base_B /= base_sum; base_H /= base_sum

    long_rows = Vector{Vector{Any}}()
    push!(long_rows, Any["N","p_S","seed","collapsed","collapse_step","m_W","final_mean_u","final_W","active_final"])

    sum_rows = Vector{Vector{Any}}()
    push!(sum_rows, Any["N","p_S","replicates","collapse_prob","collapse_step_mean","m_W_mean","final_mean_u_mean"])

    cells = Vector{Any}()
    for (iN, N) in enumerate(Ns)
        N > 1 || error("N must be > 1")
        for (ip, pS) in enumerate(pS_vals)
            (0.0 <= pS < 1.0) || error("p_S must be in [0,1), got $pS")
            rest = 1.0 - pS

            collapsed_flags = Int[]
            collapse_steps = Float64[]
            mWs = Float64[]
            mus = Float64[]

            for r in 1:R
                cfg_k = copy(cfg)
                cfg_k["N"] = N
                cfg_k["p_types"] = Dict("I"=>rest*base_I, "B"=>rest*base_B, "H"=>rest*base_H, "S"=>pS)
                seed = seed0 + ((iN-1)*length(pS_vals) + (ip-1))*R + (r-1)
                cfg_k["random_seed"] = seed

                params = params_from_config(cfg_k)
                res = simulate(params)
                m = measure_summary(res; u_threshold=params.u_threshold)

                collapsed = m["collapsed"] ? 1 : 0
                push!(collapsed_flags, collapsed)
                push!(collapse_steps, Float64(m["collapse_step"]))
                push!(mWs, Float64(m["m_W"]))
                push!(mus, Float64(m["final_mean_u"]))
                push!(long_rows, Any[N, pS, seed, collapsed, m["collapse_step"], m["m_W"], m["final_mean_u"], m["final_W"], m["active_final"]])
            end

            collapse_prob = mean(Float64.(collapsed_flags))
            cs_mean = mean(collapse_steps)
            mW_mean = mean(mWs)
            mu_mean = mean(mus)

            push!(sum_rows, Any[N, pS, R, collapse_prob, cs_mean, mW_mean, mu_mean])
            push!(cells, Dict("N"=>N, "p_S"=>pS, "replicates"=>R, "collapse_prob"=>collapse_prob, "collapse_step_mean"=>cs_mean, "m_W_mean"=>mW_mean, "final_mean_u_mean"=>mu_mean))
        end
    end

    writedlm(joinpath(out_dir, "grid_long.csv"), long_rows, ',')
    writedlm(joinpath(out_dir, "grid_summary.csv"), sum_rows, ',')
    write_json(joinpath(out_dir, "summary.json"), Dict("status"=>"OK", "meta"=>Dict("model"=>get(cfg,"model","v4_absorbing"),"model_version"=>get(cfg,"model_version","leverage-v4"),"grid"=>grid), "cells"=>cells))
    return 0
end

exit(main())


