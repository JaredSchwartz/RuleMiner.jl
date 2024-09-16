# charm.jl
# CHARM closed itemset mining in Julia
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
    charm(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

Identify closed frequent itemsets in a transactional dataset with the CHARM algorithm.

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
CHARM is an algorithm that builds on the ECLAT algorithm but adds additional closed-ness checking to return only closed itemsets.
It uses a depth-first approach, exploring the search space and checking found itemsets against previously discovered itemsets to determine closedness.

# Example
```julia
txns = Txns("transactions.txt", ' ')

# Find closed frequent itemsets with 5% minimum support
result = charm(txns, 0.05)

# Find closed frequent itemsets with minimum 5,000 transactions
result = charm(txns, 5_000)
```
# References
Zaki, Mohammed, and Ching-Jui Hsiao. “CHARM: An Efficient Algorithm for Closed Itemset Mining.” In Proceedings of the 2002 SIAM International Conference on Data Mining (SDM), 457–73. Proceedings. Society for Industrial and Applied Mathematics, 2002. https://doi.org/10.1137/1.9781611972726.27.
"""
function charm(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
    n_transactions, n_items = size(txns.matrix)

    # Handle min_support as a float value
    min_support = min_support isa Float64 ? ceil(Int, min_support * n_transactions) : min_support
    
    # Create tidsets (transaction ID sets) for each item
    tidsets = [BitSet(findall(txns.matrix[:,col])) for col in 1:n_items]
    supports = vec(sum(txns.matrix,dims=1))

    # Sort items by support in ascending order, keeping only frequent items
    item_order = sort(findall(s -> s >= min_support, supports), by=i -> supports[i])
    
    # Initialize results dictionary and threading lock
    Results = Dict{Vector{Int}, Int}()
    ThreadLock = ReentrantLock()
    
    function charm!(closed_itemsets::Dict{Vector{Int}, Int}, prefix::Vector{Int}, eq_class::Vector{Int})
        for (i, item) in enumerate(eq_class)
            
            # Create new itemset by adding current item to prefix
            new_itemset = vcat(prefix, item)
            new_tidset = intersect(tidsets[new_itemset]...)
            support = length(new_tidset)
            
            # Skip infrequent itemsets
            support < min_support && continue
            
            new_eq_class = Int[]
            for j in (i+1):length(eq_class)

                # Generate itemset, tidset, and support for new items in the next eq class
                other_item = eq_class[j]
                other_tidset = intersect(new_tidset, tidsets[other_item])
                other_support = length(other_tidset)
                
                # Skip infrequent items
                other_support < min_support && continue

                if support == other_support
                    # If supports are equal, add item to current itemset
                    push!(new_itemset, other_item)
                else
                    # Otherwise, add to new equivalence class for further processing
                    push!(new_eq_class, other_item)
                end
            end
            
            # Update closed itemsets list, ensuring thread safety
            lock(ThreadLock) do
                update_closed_itemsets!(closed_itemsets, new_itemset, support)
            end
            
            # Recursively process new equivalence class if non-empty
            !isempty(new_eq_class) && charm!(closed_itemsets, new_itemset, new_eq_class)
        end
    end

    # Helper function to update closed itemsets
    function update_closed_itemsets!(closed_itemsets, new_itemset, support)
        new_set = Set(new_itemset)
        for (existing_itemset, existing_support) in closed_itemsets
            
            # Only compare itemsets with equal support
            support != existing_support && continue

            existing_set = Set(existing_itemset)
            
            # If new itemset is a subset of an existing one, it's not closed
            issubset(new_set, existing_set) && return
            
            # If an existing itemset is a subset of the new one, remove it
            if issubset(existing_set, new_set)
                delete!(closed_itemsets, existing_itemset)
            end
        end
        
        # If we reach here, the new itemset is closed, so add it
        closed_itemsets[new_itemset] = support
    end
    
    # Add single-item frequent itemsets
    for item in item_order
        Results[[item]] = supports[item]
    end
    
    # Parallel processing of top-level equivalence classes
    @sync begin
        for (i, item) in enumerate(item_order)
            Threads.@spawn charm!(Results, [item], item_order[i+1:end])
        end
    end
    
    # Create the result DataFrame
    result_df = DataFrame(
        Itemset = [RuleMiner.getnames(itemset, txns) for itemset in keys(Results)],
        Support = [support / n_transactions for support in values(Results)],
        N = collect(values(Results)),
        Length = [length(itemset) for itemset in keys(Results)]
    )
    
    # Sort results by support in descending order
    sort!(result_df, :N, rev=true)
    return result_df
end