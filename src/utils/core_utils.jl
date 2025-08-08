function clean_support(support::Union{Int,Float64}, n_transactions::Int)::Int64
    output = support isa Float64 ? ceil(Int, support * n_transactions) : support
    output <= 0 && throw((DomainError(support,"min_support must be greater than 0")))
    return output
end
