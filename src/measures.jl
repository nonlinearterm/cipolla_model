using Statistics: mean, var
using Dates

@inline function drift_rate(W_series::AbstractVector{<:Real})
    # m_W = mean(diff(W_series))
    n = length(W_series)
    n <= 1 && return 0.0
    return (Float64(W_series[end]) - Float64(W_series[1])) / (n - 1)
end

"""
Gini coefficient computed on a shifted-to-nonnegative copy of u (since u can be negative).
Returns NaN if all values are (numerically) zero after shifting.
"""
function gini_shifted(u::AbstractVector{<:Real})
    n = length(u)
    n == 0 && return NaN
    xmin = minimum(u)
    x = similar(u, Float64)
    @inbounds for i in eachindex(u)
        x[i] = Float64(u[i] - xmin) + 1e-12
    end
    s = sum(x)
    s <= 0 && return NaN
    sort!(x)
    # G = (2*Σ i*x_i)/(n*Σ x_i) - (n+1)/n
    num = 0.0
    @inbounds for i in 1:n
        num += i * x[i]
    end
    return (2.0 * num) / (n * s) - (n + 1.0) / n
end

function measure_summary(res::SimulationResult; u_threshold::Real=-Inf)
    u = res.u
    W_series = res.W_series
    N = length(u)

    mW = drift_rate(W_series)
    mean_u = mean(u)
    min_u = minimum(u)
    var_u = var(u)
    gini = gini_shifted(u)

    thr = Float64(u_threshold)
    phi = isfinite(thr) ? (count(<(thr), u) / N) : 0.0

    return Dict(
        "m_W" => mW,
        "final_W" => Float64(W_series[end]),
        "final_mean_u" => Float64(mean_u),
        "min_u" => Float64(min_u),
        "var_u" => Float64(var_u),
        "gini_shifted" => Float64(gini),
        "phi_u_lt_threshold" => Float64(phi),
        "u_threshold" => thr,
        "T_steps" => length(W_series) - 1,
        "N" => N,
    )
end

function utc_timestamp()
    return Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
end



