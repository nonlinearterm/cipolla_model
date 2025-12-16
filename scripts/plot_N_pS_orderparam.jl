#!/usr/bin/env julia

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using DelimitedFiles
using Plots

function usage()
    println("Usage: julia --project scripts/plot_N_pS_orderparam.jl /path/to/grid_summary.csv [output_png]")
end

function main()
    if length(ARGS) < 1
        usage()
        return 1
    end
    in_csv = abspath(ARGS[1])
    out_png = (length(ARGS) >= 2) ? abspath(ARGS[2]) : joinpath(dirname(in_csv), "ps_vs_mW_by_N.png")

    data = readdlm(in_csv, ',', Any)
    header = String.(vec(data[1, :]))
    col = Dict{String,Int}([(h,i) for (i,h) in enumerate(header)])
    for k in ("N","p_S","collapse_prob","m_W_mean")
        haskey(col, k) || error("Missing column $k in $in_csv")
    end

    N = Int.(round.(Float64.([data[r, col["N"]] for r in 2:size(data,1)])))
    pS = Float64.([data[r, col["p_S"]] for r in 2:size(data,1)])
    cp = Float64.([data[r, col["collapse_prob"]] for r in 2:size(data,1)])
    mW = Float64.([data[r, col["m_W_mean"]] for r in 2:size(data,1)])

    Ns = sort(unique(N))
    p = plot(; xlabel="p_S", ylabel="m_W_mean", title="p_S vs m_W_mean by N (red markers: collapse_prob>0)")
    hline!(p, [0.0]; linestyle=:dash, color=:black, linewidth=1)

    for n in Ns
        idx = findall(==(n), N)
        ord = sortperm(pS[idx])
        xs = pS[idx][ord]
        ys = mW[idx][ord]
        cs = cp[idx][ord]
        plot!(p, xs, ys; label="N=$(n)", linewidth=2)
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


