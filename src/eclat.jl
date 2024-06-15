# eclat.jl
# ECLAT set mining in Julia
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

struct Itemset
    items::Vector{Int}
    support::Int
end

"""
    eclat(txns::Transactions, min_support::Union{Int,Float64})::DataFrame


Identify frequent itemsets in a transactional dataset `txns` with a minimum support: `min_support`.

When an Int value is supplied to min_support, eclat will use absolute support (count) of transactions as minimum support.

When a Float value is supplied, it will use relative support (percentage).
"""
function eclat(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

    n_transactions = size(txns.matrix,1)
    
    # Handle min_support as a float value
    if min_support isa Float64
        min_support = trunc(Int, min_support * n_transactions)
    end

    # Calculate initial supports and sort the columns
    item_index = collect(1:size(txns.matrix, 2))
    item_supports = Dict(zip(item_index, vec(sum(txns.matrix, dims=1))))
    
    frequent_items = [item for item in item_index if item_supports[item] >= min_support]
    sorted_items = sort(frequent_items, by= x -> item_supports[x])

    # Define recrusive eclat function and run it on the data
    function eclat!(lineage::Vector{Int}, items::Vector{Int}, trans::SparseMatrixCSC{Bool, Int}, min_support::Int, result::Vector{Itemset})
        for i in 1:length(items)
            item = items[i]
            new_lineage = vcat(lineage, item)
            support = length(findall(all(trans[:, new_lineage] .== 1, dims=2)))
    
            if support >= min_support
                set = Itemset(new_lineage,support)
                push!(result,set)
                new_items = items[i+1:end]
                if !isempty(new_items)
                    eclat!(new_lineage, new_items, trans, min_support, result)
                end
            end
        end
    end

    result = Vector{Itemset}()
    eclat!(Int[], sorted_items, txns.matrix, min_support, result)
    
    result = DataFrame(
        Itemset = [getnames(x.items,txns) for x in result],
        Support = [x.support/n_transactions for x in result],
        N = [x.support for x in result]
    )
    return result
end