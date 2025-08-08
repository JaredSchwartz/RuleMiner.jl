#= core_utils.jl
Core utilities for the RuleMiner.jl package
Licensed under the MIT license. See https://github.com/JaredSchwartz/RuleMiner.jl/blob/main/LICENSE
=#

# Utility function for checking min_support - Relative
function clean_support(min_support::Float64, n_transactions::Int)::Int64
    (0.0 < min_support <= 1.0) || throw(DomainError(min_support, "min_support value must satisfy: 0.0 < min_support <= 1.0"))
    return ceil(Int, min_support * n_transactions)
end

# Utility function for checking min_support - Absolute
function clean_support(min_support::Int, n_transactions::Int)::Int64
    (1 <= min_support <= n_transactions) || throw(DomainError(min_support, "min_support value must satisfy: 1 <= min_support <= $n_transactions (total transactions)"))
    return min_support
end
