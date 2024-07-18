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
function carpenter(txns::Transactions, min_support::Union{Int,Float64})
    n_transactions, n_items = size(txns.matrix)
    
    if min_support isa Float64
        min_support = ceil(Int, min_support * n_transactions)
    end
    
    function carpenter!(closed_itemsets::Dict{Vector{Int}, Int}, X::Vector{Int}, R::Vector{Int},Lock::ReentrantLock)
       
        # Pruning 3: Early return if itemset is already present in the output
        if haskey(closed_itemsets,X)
            return
        end
        
        # Find transactions with the itemset and calculate support
        rows = BitVector(vec(all(txns.matrix[:, X], dims=2)))
        support_X = sum(rows)
        
        # Pruning 1: Early return if the itemset is not frequent
        if support_X < min_support
            return
        end
    
        # Pruning 2: Find items that can be added without changing support
        mask = vec(sum(txns.matrix[rows, R], dims=1)) .== support_X
        Y = R[mask]

        # Add X to itemsets if it's closed (Y is empty)
        if isempty(Y) 
            lock(Lock) do
            closed_itemsets[X] = support_X
            end
        # If Y is not empty, add the itemset's closure (X ∪ Y)
        else 
            lock(Lock) do
            closed_itemsets[sort(vcat(X, Y))] = support_X
            end
        end
        
        # Recursive enumeration
        for i in setdiff(R, Y)
            carpenter!(closed_itemsets, sort(vcat(X, i)), setdiff(R, [i]),Lock)
        end
    end

    allitems = collect(1:n_items)
    frequent_items = findall(vec(sum(txns.matrix, dims=1)) .>= min_support)

    DictLock = ReentrantLock()
    itemsets = Dict{Vector{Int}, Int}()

    @threads for item in frequent_items
        carpenter!(itemsets, [item], setdiff(allitems, [item]), DictLock)
    end
    
    df = DataFrame(
        Itemset = [getnames(pattern, txns) for pattern in keys(itemsets)],
        Support = [count / n_transactions for count in values(itemsets)],
        N = collect(values(itemsets)),
        Length = [length(pattern) for pattern in keys(itemsets)]
    )
    
    sort!(df, :N, rev=true)
    
    return df
end