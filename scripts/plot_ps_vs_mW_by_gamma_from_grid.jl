#!/usr/bin/env julia

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using DelimitedFiles
using Plots

function usage()
    println("Usage: julia --project scripts/plot_ps_vs_mW_by_gamma_from_grid.jl /path/to/grid_summary.csv [output_png]")
end

function main()
    if length(ARGS) < 1
        usage()
        return 1
    end
    in_csv = abspath(ARGS[1])
    out_png = (length(ARGS) >= 2) ? abspath(ARGS[2]) : joinpath(dirname(in_csv), "ps_vs_mW_by_gamma.png")

    data = readdlm(in_csv, ',', Any)
    header = String.(vec(data[1, :]))
    col = Dict{String,Int}([(h,i) for (i,h) in enumerate(header)])
    for k in ("p_S","gamma","collapse_prob","m_W_mean")
        haskey(col, k) || error("Missing column $k in $in_csv")
    end

    pS = Float64.([data[r, col["p_S"]] for r in 2:size(data,1)])
    gam = Float64.([data[r, col["gamma"]] for r in 2:size(data,1)])
    cp  = Float64.([data[r, col["collapse_prob"]] for r in 2:size(data,1)])
    mW  = Float64.([data[r, col["m_W_mean"]] for r in 2:size(data,1)])

    gammas = sort(unique(gam))
    # keep only gammas that have any collapse probability > 0
    interesting = Float64[]
    for g in gammas
        idx = findall(==(g), gam)
        maximum(cp[idx]) > 0 && push!(interesting, g)
    end

    if isempty(interesting)
        println("No gamma has collapse_prob > 0 in this grid; plotting all gammas instead.")
        interesting = gammas
    end

    p = plot(; xlabel="p_S", ylabel="m_W_mean", title="p_S vs m_W_mean (curves for gammas with collapse_prob>0)")
    hline!(p, [0.0]; linestyle=:dash, color=:black, linewidth=1)

    for g in interesting
        idx = findall(==(g), gam)
        ord = sortperm(pS[idx])
        xs = pS[idx][ord]
        ys = mW[idx][ord]
        cs = cp[idx][ord]

        plot!(p, xs, ys; label="gamma=$(g)", linewidth=2)

        # mark points with collapse probability > 0
        hit = findall(>(0.0), cs)
        if !isempty(hit)
            scatter!(p, xs[hit], ys[hit]; label=false, marker=:xcross, ms=6, color=:red)
        end
    end

    savefig(p, out_png)
    println("Saved: ", out_png)
    return 0
end

exit(main())


