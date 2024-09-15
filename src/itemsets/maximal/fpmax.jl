# fpmax.jl
# Algorithm for mining maximal itemsets from FP Trees
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
    fpmax(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

Identify maximal frequent itemsets in a transactional dataset with the FPMax algorithm.

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
The FPMax algorithm is an extension of FP-Growth with 
additional pruning techniques to focus on mining maximal itemsets. The algorithm operates in three main phases:

1. FP-tree Construction: Builds a compact representation of the dataset, organizing items 
   by their frequency to allow efficient mining.

2. Recursive Tree Traversal: 
   - Processes itemsets from least frequent to most frequent.
   - For each item, creates a conditional FP-tree and recursively mines it.
   - Uses a depth-first search strategy, exploring longer itemsets before shorter ones.
   - Employs pruning techniques to avoid generating non-maximal itemsets.
   - Adds an itemset to the candidate set when no frequent superset exists.

3. Maximality Checking: After the recursive traversal, filters the candidate set to ensure 
   only truly maximal itemsets are included in the final output.

FPMax is particularly efficient for datasets with long transactions or sparse frequent itemsets, 
as it can significantly reduce the number of generated itemsets compared to algorithms that 
find all frequent itemsets.

# Example
```julia
txns = load_transactions("transactions.txt", ' ')

# Find maximal frequent itemsets with 5% minimum support
result = fpmax(txns, 0.05)

# Find maximal frequent itemsets with minimum 5,000 transactions
result = fpmax(txns, 5_000)
```
# References
Grahne, Gösta, and Jianfei Zhu. “Fast Algorithms for Frequent Itemset Mining Using FP-Trees.” IEEE Transactions on Knowledge and Data Engineering 17, no. 10 (October 2005): 1347–62. https://doi.org/10.1109/TKDE.2005.166.
"""
function fpmax(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
    n_transactions = size(txns.matrix, 1)
    
    # Handle min_support as a float value
    min_support = min_support isa Float64 ? ceil(Int, min_support * n_transactions) : min_support

    tree = FPTree(txns, min_support)
    
    # Initialize results set
    candidate_maximal_itemsets = Set{Vector{Int}}()
    
    function fpmax!(tree::FPTree, suffix::Vector{Int}, min_support::Int)
        # Process items in reverse order (largest to smallest support)
        header_items = sort(collect(keys(tree.header_table)), 
                            by=item -> sum(node.support for node in tree.header_table[item]),
                            rev=true)
        
        is_maximal = true
        
        for item in header_items
            nodes = tree.header_table[item]
            support = sum(node.support for node in nodes)
            
            support < min_support && continue
            
            new_itemset = sort(vcat(tree.col_mapping[item], suffix))
            
            # Create conditional FP-tree
            cond_tree = create_conditional_tree(tree, item, min_support)
            
            if isempty(cond_tree.header_table)
                # This branch has ended, add the itemset to candidates
                push!(candidate_maximal_itemsets, new_itemset)
            else
                # Continue mining with the conditional tree
                fpmax!(cond_tree, new_itemset, min_support)
                is_maximal = false
            end
        end
        
        # If this node is not maximal or is empty skip it
        (~is_maximal || isempty(suffix)) && return
        
        push!(candidate_maximal_itemsets, suffix)

    end

    # Start the mining process
    fpmax!(tree, Int[], min_support)

    # Filter out non-maximal itemsets
    maximal_itemsets = filter(candidate_maximal_itemsets) do itemset
        !any(other -> itemset != other && issubset(itemset, other), candidate_maximal_itemsets)
    end

    # Create the result DataFrame
    result_df = DataFrame(
        Itemset = [RuleMiner.getnames(itemset, txns) for itemset in maximal_itemsets],
        Support = [sum(all(txns.matrix[:, itemset], dims=2)) / n_transactions for itemset in maximal_itemsets],
        N = [sum(all(txns.matrix[:, itemset], dims=2)) for itemset in maximal_itemsets],
        Length = [length(itemset) for itemset in maximal_itemsets]
    )
    
    # Sort results by length in descending order, then by support
    sort!(result_df, [:Length, :Support], rev=true)
    return result_df
end