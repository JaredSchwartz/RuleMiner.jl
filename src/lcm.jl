# lcm.jl
# LCM closed itemset mining in Julia
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
    n_transactions, n_items = size(txns.matrix)
    
    # Handle min_support as a float value
    min_support = min_support isa Float64 ? ceil(Int, min_support * n_transactions) : min_support

    # Create tidsets (transaction ID sets) for each item
    tidsets = [BitSet(findall(txns.matrix[:,col])) for col in 1:n_items]
    supports = vec(sum(txns.matrix, dims=1))

    # Sort items by support in descending order, keeping only frequent items
    sorted_items = sort(findall(s -> s >= min_support, supports), by=i -> supports[i], rev=true)

    # Dictionary to store closed itemsets and their supports
    Results = Dict{Vector{Int}, Int}()

    ThreadLock = ReentrantLock()

    function lcm!(closed_itemsets::Dict{Vector{Int}, Int}, current::Vector{Int}, tidset::BitSet, dict_lock::ReentrantLock)
        closure = findall(i -> length(intersect(tidset, tidsets[i])) == length(tidset), 1:n_items)
        support = length(tidset)
        
        lock(dict_lock) do
            # If we've seen this closure with equal or higher support, skip it
            (haskey(closed_itemsets, closure) && closed_itemsets[closure] >= support) && return

            # Add Closure to Dict
            if !isempty(closure)
                closed_itemsets[closure] = support
            end
        end
        
        # Try extending the itemset with each frequent item
        for item in sorted_items

            # Skip if the item is already in the closure
            item ∈ closure && continue

            # Skip if the item comes before the last item in the current itemset
            item <= (isempty(current) ? 0 : current[end]) && continue
            
            # Compute the new tidset for the extended itemset
            new_tidset = intersect(tidset, tidsets[item])

            # Skip if the new tidset doesn't meet minimum support
            length(new_tidset) < min_support && continue
            
            # Recurse with new tidset and itemset
            lcm!(closed_itemsets, vcat(current, item), new_tidset, dict_lock)
        end
    end

    # Start the LCM process with size-1 itemsets
    @sync begin
        for item in sorted_items
            Threads.@spawn lcm!(Results, [item], tidsets[item], ThreadLock)
        end
    end

    # Convert results to a DataFrame
    result = DataFrame(
        Itemset = [getnames(itemset, txns) for itemset in keys(Results)],
        Support = [support / n_transactions for support in values(Results)],
        N = collect(values(Results)),
        Length = [length(itemset) for itemset in keys(Results)]
    )

    # Sort results by support in descending order
    sort!(result, :N, rev=true)

    return result
end
