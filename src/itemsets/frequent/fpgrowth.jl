# fpgrowth.jl
# FP tree-based mining in Julia
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
    fpgrowth(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

Identify frequent itemsets in a transactional dataset with the FPGrowth algorithm.

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
The FPGrowth algorithm is a mining technique that builds a compact summary of the transction data called an FP tree. 
This tree structure summarizes the supports and relationships between items in a way that can be easily transversed and processed to find frequent itemsets. 
FPGrowth is particularly efficient for datasets with long transactions or sparse frequent itemsets.

1. FP-tree Construction: Builds a compact representation of the dataset, organizing items 
   by their frequency to allow efficient mining.

2. Recursive Tree Traversal: 
   - Processes itemsets from least frequent to most frequent.
   - For each item, creates a conditional FP-tree and recursively mines it.

# Example
```julia
txns = load_transactions("transactions.txt", ' ')

# Find frequent itemsets with 5% minimum support
result = fpgrowth(txns, 0.05)

# Find frequent itemsets with minimum 5,000 transactions
result = fpgrowth(txns, 5_000)
```
# References
Han, Jiawei, Jian Pei, and Yiwen Yin. “Mining Frequent Patterns without Candidate Generation.” SIGMOD Rec. 29, no. 2 (May 16, 2000): 1–12. https://doi.org/10.1145/335191.335372.
"""
function fpgrowth(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
    n_transactions = size(txns.matrix, 1)
    
    # Handle min_support as a float value
    min_support = min_support isa Float64 ? ceil(Int, min_support * n_transactions) : min_support

    # Generate tree
    tree = make_FPTree(txns, min_support)

    # Initialize results dictionary
    Results = Dict{Vector{Int}, Int}()

    function fpgrowth!(frequent_patterns::Dict{Vector{Int}, Int}, tree::FPTree, suffix::Vector{Int}, min_support::Int)
        for (item, nodes) in tree.header_table
            # Calculate support for the current item
            support = sum(node.support for node in nodes)
    
            # Skip infrequent items
            support < min_support && continue
            
            # Map the item back to its original index
            original_item = tree.col_mapping[item]
            new_suffix = vcat([original_item], suffix)
            
            # Add the new itemset to frequent patterns
            frequent_patterns[new_suffix] = support
            
            # Create conditional FP-tree
            cond_tree = create_conditional_tree(tree, item, min_support)
            
            # Skip if the conditional tree is empty
            isempty(cond_tree.header_table) && continue
            
            # Recursively mine the conditional FP-tree
            fpgrowth!(frequent_patterns, cond_tree, new_suffix, min_support)
        end
    end

    # Mine frequent sets
    fpgrowth!(Results,tree, Int[], min_support)
    
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