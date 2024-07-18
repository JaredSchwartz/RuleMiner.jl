# lcm.jl
# LCM algorithm for mining closed itemsets in Julia
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

export LCM

"""
    LCM(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

Identify frequent closed itemsets in a transactional dataset `txns` with a minimum support: `min_support`.

When an Int value is supplied to min_support, lcm will use absolute support (count) of transactions as minimum support.
When a Float value is supplied, it will use relative support (percentage).
"""
function LCM(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
    n_transactions = size(txns.matrix, 1)
    
    # Convert relative support to absolute support if necessary
    if min_support isa Float64
        min_support = ceil(Int, min_support * n_transactions)
    end

    # Calculate support for each item and find frequent items
    item_supports = vec(sum(txns.matrix, dims=1))
    frequent_items = findall(item_supports .>= min_support)
    
    # Sort frequent items in descending order of support
    sorted_items = sort(frequent_items, by=i -> item_supports[i], rev=true)

   
    dict_lock = ReentrantLock()

    function lcm!(closed_itemsets::Dict{Vector{Int}, Int},current::Vector{Int}, tidset::BitVector)

        # Compute the closure of the current itemset using the tidset
        closure = findall(vec(all(txns.matrix[tidset,:], dims=1)))
        support = sum(tidset)
        
        lock(dict_lock) do
            # If we've seen this closure with equal or higher support, skip it
            if haskey(closed_itemsets, closure) && closed_itemsets[closure] >= support
                return
            end

            # Add Closure to Dict
            closed_itemsets[closure] = support
        end

        # Try extending the itemset with each frequent item
        for item in sorted_items

            # Skip if the item is already in the closure
            item ∈ closure && continue

            # Skip if the item comes before the last item in the current itemset
            item <= (isempty(current) ? 0 : current[end]) && continue
            
            # Compute the new tidset for the extended itemset
            new_tidset = tidset .& txns.matrix[:, item]

            # Skip if the new tidset doesn't meet minimum support
            sum(new_tidset) < min_support && continue
            
            # Recursively process the extended itemset
            lcm!(closed_itemsets,vcat(current, item), new_tidset)
        end
    end

    # Dictionary to store closed itemsets and their supports
    results = Dict{Vector{Int}, Int}()

    # Start the LCM process with top-level equivalence class
    @sync begin
        for item in sorted_items
            @spawn begin
                tidset = BitVector(txns.matrix[:, item])
                lcm!(results,[item], tidset)
            end
        end
    end

    # Convert results to a DataFrame
    result = DataFrame(
        Itemset = [getnames(itemset, txns) for itemset in keys(results)],
        Support = [support / n_transactions for support in values(results)],
        N = collect(values(results)),
        Length = [length(itemset) for itemset in keys(results)]
    )

    # Sort results by support in descending order
    sort!(result, :N, rev=true)

    return result
end
