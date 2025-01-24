#= fpgrowth.jl
FP tree-based mining in Julia
Licensed under the MIT license. See https://github.com/JaredSchwartz/RuleMiner.jl/blob/main/LICENSE
=#

"""
    fpgrowth(data::Union{Transactions,FPTree}, min_support::Union{Int,Float64})::DataFrame

Identify frequent itemsets in a transactional dataset or an FP-tree with the FPGrowth algorithm.

# Arguments
- `data::Union{Transactions,FPTree}`: Either a `Transactions` object containing the dataset to mine,
  or a pre-constructed `FPTree` object.
- `min_support::Union{Int,Float64}`: The minimum support threshold. If an `Int`, it represents 
  the absolute support. If a `Float64`, it represents relative support.

# Returns
- `DataFrame`: A DataFrame containing the frequent itemsets, with columns:
  - `Itemset`: The items in the frequent itemset.
  - `Support`: The relative support of the itemset as a proportion of total transactions.
  - `N`: The absolute support count of the itemset.
  - `Length`: The number of items in the itemset.

# Description
The FPGrowth algorithm is a mining technique that builds a compact summary of the transaction 
data called an FP-tree. This tree structure summarizes the supports and relationships between 
items in a way that can be easily traversed and processed to find frequent itemsets. 
FPGrowth is particularly efficient for datasets with long transactions or sparse frequent itemsets.

The algorithm operates in two main phases:

1. FP-tree Construction: Builds a compact representation of the dataset, organizing items 
   by their frequency to allow efficient mining. This step is skipped if an FPTree is provided.

2. Recursive Tree Traversal: 
   - Processes itemsets from least frequent to most frequent.
   - For each item, creates a conditional FP-tree and recursively mines it.

# Example
```julia
# Using a Transactions object
txns = Txns("transactions.txt", ' ')
result = fpgrowth(txns, 0.05)  # Find frequent itemsets with 5% minimum support

# Using a pre-constructed FPTree
tree = FPTree(txns, 5000)  # Construct FP-tree with minimum support of 5000
result = fpgrowth(tree, 6000)  # Find frequent itemsets with minimum support of 6000
```
# References
Han, Jiawei, Jian Pei, and Yiwen Yin. "Mining Frequent Patterns without Candidate Generation." 
SIGMOD Rec. 29, no. 2 (May 16, 2000): 1–12. https://doi.org/10.1145/335191.335372.
"""
function fpgrowth(data::Union{Transactions,FPTree}, min_support::Union{Int,Float64})::DataFrame
    n_transactions = data.n_transactions
    min_support = min_support isa Float64 ? ceil(Int, min_support * n_transactions) : min_support
    tree = data isa FPTree ? data : FPTree(data,min_support)

    min_support >= tree.min_support || throw(DomainError(min_support,"Minimum support must be greater than or equal to the FPTree's min_support: $(tree.min_support)"))

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
    
    return RuleMiner.make_itemset_df(Results, data)
end