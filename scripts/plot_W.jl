#!/usr/bin/env julia

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using DelimitedFiles
using Plots

function usage()
    println("Usage: julia --project scripts/plot_W.jl /path/to/results_W.csv [output_png]")
end

function main()
    if length(ARGS) < 1
        usage()
        return 1
    end

    in_csv = abspath(ARGS[1])
    out_png = (length(ARGS) >= 2) ? abspath(ARGS[2]) : joinpath(dirname(in_csv), "W_timeseries.png")

    W = vec(readdlm(in_csv, ',', Float64))
    t = 0:(length(W) - 1)

    p = plot(
        t, W;
        xlabel = "t",
        ylabel = "W(t)",
        title = "Total resource W(t)",
        legend = false,
        linewidth = 2,
    )

    savefig(p, out_png)
    println("Saved: ", out_png)
    return 0
end

exit(main())



