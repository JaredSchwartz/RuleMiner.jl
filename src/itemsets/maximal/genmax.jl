# genmax.jl
# GenMax maximal itemset mining in Julia
#=
Copyright (c) 2024 Jared Schwartz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
=#

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
txns = Txns("transactions.txt", ' ')

# Find maximal frequent itemsets with 5% minimum support
result = genmax(txns, 0.05)

# Find maximal frequent itemsets with minimum 5,000 transactions
result = genmax(txns, 5_000)
```

# References
Gouda, Karam, and Mohammed J. Zaki. “GenMax: An Efficient Algorithm for Mining Maximal Frequent Itemsets.” Data Mining and Knowledge Discovery 11, no. 3 (November 1, 2005): 223–42. https://doi.org/10.1007/s10618-005-0002-x.
"""
function genmax(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
    
    # Handle min_support as a float value
    min_support = min_support isa Float64 ? ceil(Int, min_support * txns.n_transactions) : min_support

    # Get pruned matrix and sorted items
    matrix, sorted_items = RuleMiner.prune_matrix(txns.matrix, min_support)
    
    # Initialize results dictionary and threading lock
    results = Dict{Vector{Int}, Int}()
    candidates = Dict{Vector{Int}, Int}()
    thread_lock = ReentrantLock()

    function genmax!(itemset::Vector{Int}, start_idx::Int, rows::BitVector)
        local_maximal = true
        
        for i in start_idx:size(matrix, 2)
            # Calculate new support with additional item
            new_rows = rows .& matrix[:, i]
            new_support = count(new_rows)
            
            # Skip if the new itemset is not frequent
            new_support < min_support && continue
            
            local_maximal = false
            new_itemset = push!(copy(itemset), i)
            genmax!(new_itemset, i + 1, new_rows)
        end
        
        # If itemset is empty or not locally maximal, return
        (isempty(itemset) || !local_maximal) && return
        
        # Map positions back to original item indices
        orig_itemset = sorted_items[itemset]
        support = count(rows)
        
        lock(thread_lock) do
            candidates[orig_itemset] = support
        end
    end

    # Start the depth-first search in parallel
    @sync begin
        for i in 1:length(sorted_items)
            Threads.@spawn begin
                initial_rows = matrix[:, i]
                initial_support = count(initial_rows)
                
                # Only process if it meets minimum support
                if initial_support >= min_support
                    genmax!([i], i + 1, initial_rows)
                end
            end
        end
    end

    # Filter candidates to get maximal itemsets
    for (itemset, support) in candidates
        is_maximal = true
        itemset_set = Set(itemset)
        
        for (other_itemset, other_support) in candidates
            itemset === other_itemset && continue
            
            if issubset(itemset_set, Set(other_itemset))
                is_maximal = false
                break
            end
        end
        
        # Add to results if maximal
        if is_maximal
            results[itemset] = support
        end
    end

    return RuleMiner.make_itemset_df(results, txns)
end