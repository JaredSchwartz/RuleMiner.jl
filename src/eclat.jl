# eclat.jl
# ECLAT frequent itemset mining in Julia
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

export eclat

"""
    eclat(txns::Transactions, min_support::Union{Int,Float64})::DataFrame


Identify frequent itemsets in a transactional dataset `txns` with a minimum support: `min_support`.

When an Int value is supplied to min_support, eclat will use absolute support (count) of transactions as minimum support.
When a Float value is supplied, it will use relative support (percentage).
"""
function eclat(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
    n_transactions = size(txns.matrix, 1)
    
    # Handle min_support as a float value
    if min_support isa Float64
        min_support = ceil(Int, min_support * n_transactions)
    end

    # Calculate initial supports and sort the columns
    item_index = collect(1:size(txns.matrix, 2))
    item_supports = Dict(zip(item_index, vec(sum(txns.matrix, dims=1))))
    
    frequent_items = [item for item in item_index if item_supports[item] >= min_support]
    sorted_items = sort(frequent_items, by= x -> item_supports[x])

    # Initialize results dictionary and threading lock
    Results = Dict{Vector{Int}, Int}()
    ThreadLock = ReentrantLock()

    # Add single-item frequent itemsets to results
    for item in sorted_items
        Results[[item]] = item_supports[item]
    end

    # Define recursive eclat function and run it on the data
    function eclat!(lineage::Vector{Int}, items::Vector{Int}, trans::SparseMatrixCSC{Bool, Int}, min_support::Int)
        for (i, item) in enumerate(items)
            new_lineage = vcat(lineage, item)
            support = sum(all(trans[:, new_lineage], dims=2))
    
            if support >= min_support
                lock(ThreadLock) do
                    Results[new_lineage] = support
                end
                new_items = items[i+1:end]
                if !isempty(new_items)
                    eclat!(new_lineage, new_items, trans, min_support)
                end
            end
        end
    end

    @sync begin
        for (i, item) in enumerate(sorted_items)
            Threads.@spawn eclat!([item], sorted_items[i+1:end], txns.matrix, min_support)
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