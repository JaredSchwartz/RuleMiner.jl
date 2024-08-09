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

Identify closed frequent itemsets in a transactional dataset with the LCM algorithm.

# Arguments
- `txns::Transactions`: A `Transactions` object containing the dataset to mine.
- `min_support::Union{Int,Float64}`: The minimum support threshold. If an `Int`, it represents 
  the absolute support. If a `Float64`, it represents relative support.

# Returns
- `DataFrame`: A DataFrame containing the maximal frequent itemsets, with columns:
  - `Itemset`: The items in the maximal frequent itemset.
  - `Support`: The relative support of the itemset as a proportion of total transactions.
  - `N`: The absolute support count of the itemset.
  - `Length`: The number of items in the itemset.

# Description
LCM is an algorithm that uses a depth-first search pattern with closed-ness checking to return only closed itemsets.
It utilizes two key pruning techniques to avoid redundant mining: prefix-preserving closure extension (PPCE) and progressive database reduction (PDR).

- PPCE ensures that each branch will never overlap in the itemsets they explore by enforcing the order of the itemsets. This reduces redunant search space.
- PDR works with PPCE to remove data from a branch's dataset once it is determined to be not nescessary.

# Example
```julia
txns = load_transactions("transactions.txt", ' ')

# Find closed frequent itemsets with 5% minimum support
result = LCM(txns, 0.05)

# Find closed frequent itemsets with minimum 5,000 transactions
result = LCM(txns, 5_000)
```
# References
Uno, Takeaki, Tatsuya Asai, Yuzo Uchida, and Hiroki Arimura. “An Efficient Algorithm for Enumerating Closed Patterns in Transaction Databases.” 
In Discovery Science, edited by Einoshin Suzuki and Setsuo Arikawa, 16–31. Berlin, Heidelberg: Springer, 2004. https://doi.org/10.1007/978-3-540-30214-8_2.
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
        Itemset = [RuleMiner.getnames(itemset, txns) for itemset in keys(Results)],
        Support = [support / n_transactions for support in values(Results)],
        N = collect(values(Results)),
        Length = [length(itemset) for itemset in keys(Results)]
    )

    # Sort results by support in descending order
    sort!(result, :N, rev=true)

    return result
end
