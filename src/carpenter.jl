# carpenter.jl
# Carpenter closed itemset mining in Julia
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
    
    # Create tidsets (transaction ID sets) for each item
    tidsets = [BitSet(findall(txns.matrix[:,col])) for col in 1:n_items]
    supports = vec(sum(txns.matrix, dims=1))

    # Create vectors of all items and all frequent items for mining
    allitems = collect(1:n_items)
    frequent_items = findall(supports .>= min_support)

    # Initialize results dictionary and threading lock
    Results = Dict{Vector{Int}, Int}()
    ThreadLock = ReentrantLock()
    
    function carpenter!(closed_itemsets::Dict{Vector{Int}, Int}, X::Vector{Int}, R::Vector{Int}, Lock::ReentrantLock)
        # Pruning 3: Early return if itemset is already present in the output
        if haskey(closed_itemsets, X)
            return
        end
        
        # Find transactions with the itemset and calculate support
        tidset_X = length(X) == 1 ? tidsets[X[1]] : intersect(tidsets[X]...)
        support_X = length(tidset_X)
        
        # Pruning 1: Early return if the itemset is not frequent
        if support_X < min_support
            return
        end
    
        # Pruning 2: Find items that can be added without changing support
        Y = filter(i -> length(intersect(tidset_X, tidsets[i])) == support_X, R)

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
            carpenter!(closed_itemsets, sort(vcat(X, i)), setdiff(R, [i]), Lock)
        end
    end

    # Parallel Processing of initial itemsets
    @sync begin
        for item in frequent_items
            Threads.@spawn carpenter!(Results, [item], setdiff(allitems, [item]), ThreadLock)
        end
    end
    
    # Create the result DataFrame
    result_df = DataFrame(
        Itemset = [getnames(itemset, txns) for itemset in keys(Results)],
        Support = [support / n_transactions for support in values(Results)],
        N = collect(values(Results)),
        Length = [length(itemset) for itemset in keys(Results)]
    )
    
    # Sort results by support in descending order
    sort!(result_df, :N, rev=true)
    return result_df
end