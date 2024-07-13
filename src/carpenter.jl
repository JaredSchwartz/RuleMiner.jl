# carpenter.jl
# Carpenter algorithm for mining closed itemsets in Julia
#
# Copyright (c) 2024 Jared Schwartz
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

export carpenter

"""
    carpenter(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

Identify closed frequent itemsets in a transactional dataset `txns` with a minimum support: `min_support`.

When an Int value is supplied to min_support, carpenter will use absolute support (count) of transactions as minimum support.

When a Float value is supplied, it will use relative support (percentage).
"""
function carpenter(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
    n_transactions = size(txns.matrix, 1)
    n_items = size(txns.matrix, 2)
    
    if min_support isa Float64
        min_support = ceil(Int, min_support * n_transactions)
    end
    
    function carpenter!(closed_itemsets::Dict{Vector{Int}, Int}, X::Vector{Int}, R::Vector{Int})
        
        # Pruning 3: Check if this itemset has been discovered before
        if haskey(closed_itemsets, X)
            return
        end
    
       # Calculate support for current itemset
       support_X = sum(all(txns.matrix[:,X], dims=2))
            
       # Pruning 1: Remove infrequent itemsets
       if support_X < min_support
           return
       end
       
       # Check if X is closed (additional pruning step not in the paper)
       for item in setdiff(1:n_items, X)
           if sum(all(txns.matrix[:,vcat(X, item)], dims=2)) == support_X
               return
           end
       end
    
       # Pruning 2: Find items that can be added without changing support
       Y = Int[]
       for item in R
           if sum(all(txns.matrix[:,vcat(X, item)], dims=2)) == support_X
               push!(Y, item)
           end
       end


       # Add to itemsets
       closed_itemsets[X] = support_X
       
       # Recursive enumeration
       for i in setdiff(R, Y)
           if i > maximum(X)
            carpenter!(closed_itemsets,vcat(X, i), filter(j -> j > i, R))
           end
       end
    end

    itemsets = Dict{Vector{Int}, Int}()

    supports = vec(sum(txns.matrix, dims=1))
    items = findall(x -> x >= min_support, supports)

    # Start mining with individual items
    for item in items
        carpenter!(itemsets, [item], collect(item+1:n_items))
    end
    
    df = DataFrame(
        Itemset = [getnames(pattern,txns) for pattern in keys(itemsets)],
        Support = [count / n_transactions for count in values(itemsets)],
        N = collect(values(itemsets)),
        Length = [length(pattern) for pattern in keys(itemsets)]
    )
    
    sort!(df, :N, rev=true)
    
    return df
end


