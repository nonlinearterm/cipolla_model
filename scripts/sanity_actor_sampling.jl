#!/usr/bin/env julia

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using CipollaModel
using Random
using Statistics: mean, cor

function usage()
    println("Usage: julia --project scripts/sanity_actor_sampling.jl /path/to/config.yaml [bins=10] [steps_override]")
end

function bin_summary(L::Vector{Float64}, counts::Vector{Int}; bins::Int=10)
    N = length(L)
    order = sortperm(L)
    out = Vector{Tuple{Int,Int,Float64,Float64}}()
    # (bin_id, n, mean_L, mean_count)
    for b in 1:bins
        lo = floor(Int, (b-1)*N/bins) + 1
        hi = floor(Int, b*N/bins)
        lo > hi && continue
        idx = order[lo:hi]
        push!(out, (b, length(idx), mean(L[idx]), mean(Float64.(counts[idx]))))
    end
    return out
end

function main()
    if length(ARGS) < 1
        usage()
        return 1
    end

    cfg_path = abspath(ARGS[1])
    bins = (length(ARGS) >= 2) ? parse(Int, ARGS[2]) : 10
    steps_override = (length(ARGS) >= 3) ? parse(Int, ARGS[3]) : nothing

    cfg = load_config(cfg_path)
    params = params_from_config(cfg)

    rng = MersenneTwister(params.random_seed)

    # Sample population leverage once (same as simulation init)
    types = CipollaModel.sample_types(rng, params.p_types, params.N)
    L = CipollaModel.sample_leverages(rng, params.leverage, types)

    T = isnothing(steps_override) ? params.T_steps : steps_override
    counts = zeros(Int, params.N)

    if params.leverage.enabled && params.leverage.gamma > 0
        w = L .^ params.leverage.gamma
        tab = CipollaModel.AliasTable(w)
        @inbounds for t in 1:T
            i = CipollaModel.sample(rng, tab)
            counts[i] += 1
        end
    else
        @inbounds for t in 1:T
            i = rand(rng, 1:params.N)
            counts[i] += 1
        end
    end

    # Correlations (cheap sanity)
    c = Float64.(counts)
    Llog = log.(L)
    println("N=$(params.N)  steps=$(T)")
    println("leverage.enabled=$(params.leverage.enabled)  alpha=$(params.leverage.alpha)  gamma=$(params.leverage.gamma)  mode=$(params.leverage.mode)")
    println("corr(count, L)      = ", cor(c, L))
    println("corr(count, log L)  = ", cor(c, Llog))
    if params.leverage.enabled && params.leverage.gamma > 0
        w = L .^ params.leverage.gamma
        println("corr(count, L^gamma)= ", cor(c, w))
    end

    println("\nBinned by leverage (ascending):")
    println("bin,n,mean_L,mean_actor_count")
    for (b, n, mL, mc) in bin_summary(L, counts; bins=bins)
        println("$(b),$(n),$(mL),$(mc)")
    end

    return 0
end

exit(main())


