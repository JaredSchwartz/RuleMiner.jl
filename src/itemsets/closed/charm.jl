#= charm.jl
CHARM closed itemset mining in Julia
Licensed under the MIT license. See https://github.com/JaredSchwartz/RuleMiner.jl/blob/main/LICENSE
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
    min_support = clean_support(min_support, n_transactions)

    # Get pruned matrix and sorted items
    matrix, sorted_items = RuleMiner.prune_matrix(txns.matrix, min_support)
    
    # Initialize results dictionary and threading lock
    Results = Dict{Vector{Int}, Int}()
    ThreadLock = ReentrantLock()
    
    function charm!(closed_itemsets::Dict{Vector{Int}, Int}, prefix::Vector{Int}, eq_class::Vector{Int}, rows::BitVector)
        for (i, pos) in enumerate(eq_class)
            # Create new itemset by adding current item to prefix
            new_itemset = vcat(prefix, pos)
            new_rows = rows .& matrix[:, pos]
            support = count(new_rows)
            
            # Skip infrequent itemsets
            support < min_support && continue
            
            # Initialize new equivalence class
            new_eq_class = Int[]
            
            # Process remaining items in current equivalence class
            for j in (i+1):length(eq_class)
                other_pos = eq_class[j]
                
                # Calculate intersection with the other item
                other_rows = new_rows .& matrix[:, other_pos]
                other_support = count(other_rows)
                
                # Skip infrequent items
                other_support < min_support && continue
                
                if support == other_support
                    # If supports are equal, add item to current itemset
                    push!(new_itemset, other_pos)
                else
                    # Otherwise, add to new equivalence class
                    push!(new_eq_class, other_pos)
                end
            end
            
            # Map positions back to original item indices
            orig_itemset = sorted_items[new_itemset]
            
            # Update closed itemsets list with thread safety
            lock(ThreadLock) do
                update_closed_itemsets!(closed_itemsets, orig_itemset, support)
            end
            
            # Recursively process new equivalence class if non-empty
            !isempty(new_eq_class) && charm!(closed_itemsets, new_itemset, new_eq_class, new_rows)
        end
    end
    
    # Helper function to update closed itemsets
    function update_closed_itemsets!(closed_itemsets::Dict{Vector{Int}, Int}, new_itemset::Vector{Int}, support::Int)
        new_set = Set(new_itemset)
        
        # Check against existing closed itemsets
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
    
    # Process single items and add to results
    for (pos, item) in enumerate(sorted_items)
        Results[[item]] = count(matrix[:, pos])
    end
    
    # Parallel processing of top-level equivalence classes
    @sync begin
        for (i, pos) in enumerate(1:length(sorted_items))
            Threads.@spawn begin
                # Get initial rows for this item
                initial_rows = matrix[:, pos]
                
                # Only process if it meets minimum support
                if count(initial_rows) >= min_support
                    charm!(Results, [pos], collect((i+1):length(sorted_items)), initial_rows)
                end
            end
        end
    end
    
    return RuleMiner.make_itemset_df(Results, txns)
end