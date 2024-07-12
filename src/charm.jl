# charm.jl
# CHARM closed itemset mining in Julia
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

export charm

function charm(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
    n_transactions, n_items = size(txns.matrix)

    if min_support isa Float64
        min_support = ceil(Int, min_support * n_transactions)
    end
    
    tidsets = [BitSet(txns.matrix.rowval[nzrange(txns.matrix, col)]) for col in 1:n_items]
    supports = [length(tidset) for tidset in tidsets]
    item_order = sort(findall(s -> s >= min_support, supports), by=i -> supports[i])
    
    closed_itemsets = Vector{Tuple{Vector{Int}, Int}}()
    itemsets_lock = ReentrantLock()
    
    function charm!(closed_itemsets::Vector{Tuple{Vector{Int}, Int}}, prefix::Vector{Int}, eq_class::Vector{Int})
        for (i, item) in enumerate(eq_class)
            new_itemset = vcat(prefix, item)
            new_tidset = intersect_tidsets(new_itemset)
            support = length(new_tidset)
            
            if support < min_support
                continue
            end
            
            new_eq_class = Int[]
            for j in (i+1):length(eq_class)
                other_item = eq_class[j]
                other_tidset = intersect(new_tidset, tidsets[other_item])
                other_support = length(other_tidset)
                
                if other_support >= min_support
                    if support == other_support
                        push!(new_itemset, other_item)
                    else
                        push!(new_eq_class, other_item)
                    end
                end
            end
            
            lock(itemsets_lock) do
                is_closed = true
                for (existing_itemset, existing_support) in closed_itemsets
                    if support == existing_support
                        if issubset(Set(new_itemset), Set(existing_itemset))
                            is_closed = false
                            break
                        elseif issubset(Set(existing_itemset), Set(new_itemset))
                            filter!(x -> x[1] != existing_itemset, closed_itemsets)
                        end
                    end
                end
                if is_closed
                    push!(closed_itemsets, (new_itemset, support))
                end
            end
            
            if !isempty(new_eq_class)
                charm!(closed_itemsets, new_itemset, new_eq_class)
            end
        end
    end
    
    function intersect_tidsets(itemset::Vector{Int})::BitSet
        if length(itemset) == 1
            return tidsets[itemset[1]]
        else
            result = copy(tidsets[itemset[1]])
            for item in itemset[2:end]
                intersect!(result, tidsets[item])
            end
            return result
        end
    end
    
    # Add single-item frequent itemsets
    for item in item_order
        push!(closed_itemsets, ([item], supports[item]))
    end
    
    # Parallel processing of top-level equivalence classes
    @threads for i in eachindex(item_order)
        item = item_order[i]
        charm!(closed_itemsets, [item], item_order[i+1:end])
    end
    
    result_df = DataFrame(
        Itemset = [getnames(itemset, txns) for (itemset, _) in closed_itemsets],
        Support = [support / n_transactions for (_, support) in closed_itemsets],
        N = [support for (_, support) in closed_itemsets],
        Length = [length(itemset) for (itemset, _) in closed_itemsets]
    )
    
    sort!(result_df, :N, rev=true)
    return result_df
end