using Random

"""
Alias table for O(1) discrete sampling from fixed weights.
"""
struct AliasTable
    prob::Vector{Float64}
    alias::Vector{Int}
end

function AliasTable(weights::Vector{Float64})
    n = length(weights)
    n > 0 || error("AliasTable: weights must be non-empty")

    w = Vector{Float64}(undef, n)
    s = 0.0
    @inbounds for i in 1:n
        wi = Float64(weights[i])
        wi < 0 && error("AliasTable: weights must be >= 0")
        w[i] = wi
        s += wi
    end
    s > 0 || error("AliasTable: sum(weights) must be > 0")

    scaled = w .* (n / s)
    prob = Vector{Float64}(undef, n)
    alias = collect(1:n)

    small = Int[]
    large = Int[]
    @inbounds for i in 1:n
        if scaled[i] < 1.0
            push!(small, i)
        else
            push!(large, i)
        end
    end

    while !isempty(small) && !isempty(large)
        l = pop!(small)
        g = pop!(large)
        prob[l] = scaled[l]
        alias[l] = g
        scaled[g] = (scaled[g] + scaled[l]) - 1.0
        if scaled[g] < 1.0
            push!(small, g)
        else
            push!(large, g)
        end
    end

    @inbounds for i in large
        prob[i] = 1.0
        alias[i] = i
    end
    @inbounds for i in small
        prob[i] = 1.0
        alias[i] = i
    end

    return AliasTable(prob, alias)
end

@inline function sample(rng::AbstractRNG, tab::AliasTable)::Int
    n = length(tab.prob)
    i = rand(rng, 1:n)
    return (rand(rng) < tab.prob[i]) ? i : tab.alias[i]
end


