# genmax.jl
# GenMax maximal itemset mining in Julia
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

export genmax

"""
    genmax(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

Identify maximal frequent itemsets in a transactional dataset with the GenMax algorithm.

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
The GenMax algorithm finds maximal frequent itemsets, which are frequent itemsets that are not 
proper subsets of any other frequent itemset. It uses a depth-first search strategy with 
pruning techniques like progressive focusing to discover these itemsets.

The algorithm proceeds in two main phases:
1. Candidate Generation: Uses a depth-first search to generate candidate maximal frequent itemsets.
2. Maximality Checking: Ensures that only truly maximal itemsets are retained in the final output.

# Example
```julia
txns = load_transactions("transactions.txt", ' ')

# Find maximal frequent itemsets with 5% minimum support
result = genmax(txns, 0.05)

# Find maximal frequent itemsets with minimum 5,000 transactions
result = genmax(txns, 5_000)
```

# References
Gouda, Karam, and Mohammed J. Zaki. “GenMax: An Efficient Algorithm for Mining Maximal Frequent Itemsets.” Data Mining and Knowledge Discovery 11, no. 3 (November 1, 2005): 223–42. https://doi.org/10.1007/s10618-005-0002-x.
"""
function genmax(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
    n_transactions, n_items = size(txns.matrix)
    
    # Handle min_support as a float value
    min_support = min_support isa Float64 ? ceil(Int, min_support * n_transactions) : min_support

    # Calculate initial supports for each item
    item_supports = Dict(i => sum(txns.matrix[:, i]) for i in 1:n_items)
    
    # Sort items by support in descending order and filter for frequent items
    sorted_items = sort(collect(keys(item_supports)), by=i -> item_supports[i], rev=true)
    frequent_items = filter(i -> item_supports[i] >= min_support, sorted_items)

    # Create BitSets for each frequent item's transactions
    item_bitsets = [BitSet(findall(txns.matrix[:, i])) for i in frequent_items]

    # Initialize the Maximal Frequent Itemsets (MFI) list and threading lock
    Results = Vector{Vector{Int}}()
    ThreadLock = ReentrantLock()

    # Depth-First Search to find maximal frequent itemsets
    function genmax!(itemset::Vector{Int}, start_idx::Int, tidset::BitSet)
        local_maximal = true
        
        for i in start_idx:length(frequent_items)
            item = frequent_items[i]
            new_tidset = intersect(tidset, item_bitsets[i])
            
            # Skip if the new itemset is not frequent
            length(new_tidset) < min_support && continue
            
            local_maximal = false
            new_itemset = push!(copy(itemset), item)
            genmax!(new_itemset, i + 1, new_tidset)
        end
        
        # If itemset is empty or not locally maximal, return
        (isempty(itemset) || !local_maximal) && return
        
        lock(ThreadLock) do
            push!(Results, itemset)
        end
    end

    # Start the depth-first search in parallel
    @sync begin
        for (i, item) in enumerate(frequent_items)
            Threads.@spawn genmax!([item], i + 1, item_bitsets[i])
        end
    end

    # Filter candidates to get final maximal sets
    sort!(Results, by=length, rev=true)
    maximal = trues(length(Results))
    
    for i in 1:length(Results)
        #Skip if the item has already been marked as non-maximal
        !maximal[i] && continue
        
        for j in 1:length(Results)
            # Skip if item is being compared to its self or if [j] has been marked as non-maximal
            (i == j || !maximal[j]) && continue
            
            # Check if Results[j] is a subset of Results[i] and mark it not maximal if it is
            Results[j] ⊊ Results[i] && (maximal[j] = false)
        end
    end

    result = Results[maximal]

    # Create output DataFrame
    df = DataFrame(
        Itemset = [RuleMiner.getnames(itemset, txns) for itemset in result],
        Support = [length(intersect([item_bitsets[findfirst(==(item), frequent_items)] for item in itemset]...)) / n_transactions for itemset in result],
        N = [length(intersect([item_bitsets[findfirst(==(item), frequent_items)] for item in itemset]...)) for itemset in result],
        Length = [length(itemset) for itemset in result]
    )

    # Sort by length (descending) and then by support (descending)
    sort!(df, [:Length, :Support], rev=true)
    return df
end