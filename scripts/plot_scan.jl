#!/usr/bin/env julia

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using DelimitedFiles
using Plots

function usage()
    println("Usage: julia --project scripts/plot_scan.jl /path/to/results_scan.csv [output_png]")
end

function asfloat(x)
    x isa Float64 && return x
    x isa Integer && return Float64(x)
    x isa AbstractFloat && return Float64(x)
    x isa AbstractString && return parse(Float64, x)
    return Float64(x)
end

function infer_label(path::AbstractString)
    lp = lowercase(path)
    occursin("levind", lp) && return "levInd"
    occursin("levs", lp) && return "levS"
    return nothing
end

function main()
    if length(ARGS) < 1
        usage()
        return 1
    end

    in_csv = abspath(ARGS[1])
    out_png = (length(ARGS) >= 2) ? abspath(ARGS[2]) : joinpath(dirname(in_csv), "scan_plot.png")
    label = infer_label(in_csv)

    data = readdlm(in_csv, ',', Any)
    size(data, 1) >= 2 || error("CSV must have header + at least one data row: $in_csv")

    header = String.(vec(data[1, :]))
    param_name = header[1]
    col = Dict{String,Int}()
    for (i, h) in enumerate(header)
        col[h] = i
    end

    x = [asfloat(data[r, 1]) for r in 2:size(data, 1)]

    # New summary format: m_W_mean/m_W_std, final_mean_u_mean/final_mean_u_std
    has_summary = haskey(col, "m_W_mean") && haskey(col, "m_W_std")

    if has_summary
        mW = [asfloat(data[r, col["m_W_mean"]]) for r in 2:size(data, 1)]
        mW_std = [asfloat(data[r, col["m_W_std"]]) for r in 2:size(data, 1)]
        mean_u = [asfloat(data[r, col["final_mean_u_mean"]]) for r in 2:size(data, 1)]
        mean_u_std = [asfloat(data[r, col["final_mean_u_std"]]) for r in 2:size(data, 1)]
    else
        # Old format fallback: [param, m_W, final_W, final_mean_u, ...]
        mW = [asfloat(data[r, 2]) for r in 2:size(data, 1)]
        mW_std = nothing
        mean_u = [asfloat(data[r, 4]) for r in 2:size(data, 1)]
        mean_u_std = nothing
    end

    title_suffix = isnothing(label) ? "" : " ($(label))"

    p1 = plot(
        x, mW;
        marker = :circle,
        linewidth = 2,
        xlabel = param_name,
        ylabel = "m_W",
        title = "Order parameter: m_W vs $param_name$title_suffix",
        legend = false,
    )
    hline!(p1, [0.0]; linestyle=:dash, linewidth=1, color=:black)

    if mW_std !== nothing
        scatter!(p1, x, mW; yerror=mW_std, marker=:circle, ms=4, alpha=0.9)
    end

    p2 = plot(
        x, mean_u;
        marker = :circle,
        linewidth = 2,
        xlabel = param_name,
        ylabel = "final_mean_u",
        title = "Aux: final_mean_u vs $param_name$title_suffix",
        legend = false,
    )
    hline!(p2, [0.0]; linestyle=:dash, linewidth=1, color=:black)

    if mean_u_std !== nothing
        scatter!(p2, x, mean_u; yerror=mean_u_std, marker=:circle, ms=4, alpha=0.9)
    end

    # Optional: overlay per-seed curves if results_scan_long.csv exists next to the summary csv
    long_csv = joinpath(dirname(in_csv), "results_scan_long.csv")
    if isfile(long_csv)
        long = readdlm(long_csv, ',', Any)
        if size(long, 1) >= 2
            long_header = String.(vec(long[1, :]))
            lc = Dict{String,Int}()
            for (i, h) in enumerate(long_header)
                lc[h] = i
            end
            if haskey(lc, "seed") && haskey(lc, "m_W") && haskey(lc, "final_mean_u")
                xs = [asfloat(long[r, 1]) for r in 2:size(long, 1)]
                seeds = [Int(asfloat(long[r, lc["seed"]])) for r in 2:size(long, 1)]
                mWs = [asfloat(long[r, lc["m_W"]]) for r in 2:size(long, 1)]
                mus = [asfloat(long[r, lc["final_mean_u"]]) for r in 2:size(long, 1)]

                uniq = unique(seeds)
                for s in uniq
                    idx = findall(==(s), seeds)
                    # sort by x for line plotting
                    ord = sortperm(xs[idx])
                    xk = xs[idx][ord]
                    plot!(p1, xk, mWs[idx][ord]; color=:gray, alpha=0.25, linewidth=1)
                    plot!(p2, xk, mus[idx][ord]; color=:gray, alpha=0.25, linewidth=1)
                end
            end
        end
    end

    if !isnothing(label)
        annotate!(p1, (0.02, 0.96), text("label: $(label)", 10, :left, :black))
        annotate!(p2, (0.02, 0.96), text("label: $(label)", 10, :left, :black))
    end

    p = plot(p1, p2; layout=(2,1), size=(900,700))
    savefig(p, out_png)
    println("Saved: ", out_png)
    return 0
end

exit(main())



