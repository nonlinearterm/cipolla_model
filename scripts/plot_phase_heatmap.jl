#!/usr/bin/env julia

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using DelimitedFiles
using Plots

function usage()
    println("Usage: julia --project scripts/plot_phase_heatmap.jl /path/to/grid_summary.csv [output_png]")
end

function main()
    if length(ARGS) < 1
        usage()
        return 1
    end
    in_csv = abspath(ARGS[1])
    out_png = (length(ARGS) >= 2) ? abspath(ARGS[2]) : joinpath(dirname(in_csv), "phase_collapse.png")

    data = readdlm(in_csv, ',', Any)
    header = String.(vec(data[1, :]))
    col = Dict{String,Int}([(h,i) for (i,h) in enumerate(header)])

    for k in ("p_S","gamma","collapse_prob")
        haskey(col, k) || error("grid_summary.csv must contain column: $k")
    end

    pS = Float64.([data[r, col["p_S"]] for r in 2:size(data,1)])
    gamma = Float64.([data[r, col["gamma"]] for r in 2:size(data,1)])
    prob = Float64.([data[r, col["collapse_prob"]] for r in 2:size(data,1)])

    xs = sort(unique(pS))
    ys = sort(unique(gamma))
    Z = fill(NaN, length(ys), length(xs))
    for k in eachindex(prob)
        xi = findfirst(==(pS[k]), xs)
        yi = findfirst(==(gamma[k]), ys)
        Z[yi, xi] = prob[k]
    end

    p = heatmap(xs, ys, Z;
        xlabel="p_S",
        ylabel="gamma",
        title="Collapse probability heatmap",
        colorbar_title="P(collapse)",
        clims=(0.0, 1.0),
    )
    savefig(p, out_png)
    println("Saved: ", out_png)
    return 0
end

exit(main())


