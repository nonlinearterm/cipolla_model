#!/usr/bin/env julia

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using DelimitedFiles
using Plots

function usage()
    println("Usage: julia --project scripts/plot_collapse_prob.jl /path/to/grid_summary.csv [output_png]")
end

"""
Wilson score interval for Binomial proportion.
Returns (center, half_width).
"""
function wilson(p̂::Float64, n::Int; z::Float64=1.96)
    n <= 0 && return (NaN, NaN)
    p̂ = min(1.0, max(0.0, p̂))
    z2 = z^2
    denom = 1.0 + z2/n
    center = (p̂ + z2/(2n)) / denom
    hw = (z/denom) * sqrt(p̂*(1-p̂)/n + z2/(4n^2))
    return (center, hw)
end

function main()
    if length(ARGS) < 1
        usage()
        return 1
    end
    in_csv = abspath(ARGS[1])
    out_png = (length(ARGS) >= 2) ? abspath(ARGS[2]) : joinpath(dirname(in_csv), "collapse_prob_vs_pS.png")

    data = readdlm(in_csv, ',', Any)
    header = String.(vec(data[1, :]))
    col = Dict{String,Int}([(h,i) for (i,h) in enumerate(header)])
    for k in ("p_S","replicates","collapse_prob")
        haskey(col, k) || error("Missing column $k in $in_csv")
    end

    pS = Float64.([data[r, col["p_S"]] for r in 2:size(data,1)])
    nrep = Int.(round.(Float64.([data[r, col["replicates"]] for r in 2:size(data,1)])))
    p̂ = Float64.([data[r, col["collapse_prob"]] for r in 2:size(data,1)])

    ord = sortperm(pS)
    xs = pS[ord]
    ps = p̂[ord]
    ns = nrep[ord]

    centers = similar(ps)
    errs = similar(ps)
    for i in eachindex(ps)
        c, hw = wilson(ps[i], ns[i])
        centers[i] = c
        errs[i] = hw
    end

    p = plot(xs, centers;
        marker=:circle, linewidth=2,
        xlabel="p_S", ylabel="P(collapse before T)",
        title="Collapse probability vs p_S (Wilson 95% CI)",
        legend=false,
        ylim=(0.0, 1.0),
    )
    scatter!(p, xs, centers; yerror=errs, ms=4, alpha=0.9)
    xlims!(p, (minimum(xs), maximum(xs)))

    savefig(p, out_png)
    println("Saved: ", out_png)
    return 0
end

exit(main())


