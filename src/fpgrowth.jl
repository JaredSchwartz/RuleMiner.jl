# fpgrowth.jl
# FP tree-based mining in Julia
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

export fpgrowth, fpclose, fpmax

"""

    FPNode

This is a struct which represents an FP Node with an integer support field. It is the final product mining algorithms use to mine patterns.

# Fields
- `value`: The item index of the node
- `support`: An integer representing the support count of the node
- `children`: A Dict with integer keys representing the item index of the child nodes and `FPNode`` values representing the child nodes
- `parent`: An `FPNode` object representing the node's parent node

# Examples
Generate a root node with value -1
```julia
node = FPNode(-1)
```
"""
mutable struct FPNode
    value::Int
    support::Int
    children::Dict{Int, FPNode}
    parent::Union{FPNode, Nothing}
    
    # Default constructor
    FPNode(value::Int, parent::Union{FPNode, Nothing}=nothing) = new(value, 0, Dict{Int, FPNode}(), parent)
end

"""

    FPTree

This is a struct which represents an FP-Tree structure. It also holds a header table of nodes to enable faster calculations.

# Fields
- `root`: The FPNode that serves as the root of the tree
- `header_table`: A dict where the keys are the items and the values are a vector of FPNodes representing the item
- `col_mapping`: A dictionary mapping the subsetted item indices to the original item indices

# Examples
Initialize a tree with a root node with the item value -1
```julia
tree = FPTree()
```
"""
mutable struct FPTree
    root::FPNode
    header_table::Dict{Int, Vector{FPNode}}
    col_mapping::Dict{Int, Int}
    
    FPTree() = new(FPNode(-1), Dict{Int, Vector{FPNode}}(), Dict{Int, Int}())
end

"""

    make_FPTree(txns::Transactions, min_support::Int)::FPTree

This is a function which constructs an `FPTree`` object from a `Transactions` object.
"""
function make_FPTree(txns::Transactions, min_support::Int)::FPTree
    n_transactions = size(txns.matrix, 1)

    # Sort and filter items based on support
    col_sums = vec(sum(txns.matrix, dims=1))
    sorted_cols = sort(findall(>=(min_support), col_sums), by=i -> col_sums[i], rev=true)

    # Initialize FPTree structure
    tree = FPTree()
    tree.root = FPNode(-1)  # Root node with value -1
    tree.col_mapping = Dict(i => col for (i, col) in enumerate(sorted_cols))
    tree.header_table = Dict{Int, Vector{FPNode}}()

    # Determine chunks for parallel processing
    min_chunk_size = 50
    max_chunks = min(nthreads() * 4, cld(n_transactions, min_chunk_size))
    chunk_size = max(min_chunk_size, cld(n_transactions, max_chunks))
    n_chunks = min(max_chunks, cld(n_transactions, chunk_size))

    # Process transactions in parallel
    local_trees = Vector{FPNode}(undef, n_chunks)
    @sync begin
        for (chunk_id, chunk_start) in enumerate(1:chunk_size:n_transactions)
            Threads.@spawn begin
                chunk_end = min(chunk_start + chunk_size - 1, n_transactions)
                local_tree = FPNode(-1)  # Local tree for this chunk
                
                # Process each transaction in the chunk
                for row in chunk_start:chunk_end
                    node = local_tree
                    for (new_idx, col) in enumerate(sorted_cols)
                        txns.matrix[row, col] || continue
                        
                        # Add item to the local tree
                        child = get(node.children, new_idx, nothing)
                        if isnothing(child)
                            child = FPNode(new_idx, node)
                            node.children[new_idx] = child
                        end
                        child.support += 1
                        node = child
                    end
                end

                local_trees[chunk_id] = local_tree
            end
        end
    end

    # Merge local trees into the main tree
    for local_tree in local_trees
        merge_tree!(tree.root, local_tree, tree.header_table)
    end

    return tree
end


"""

    merge_tree!(main::FPNode, local_node::FPNode, header::Dict{Int, Vector{FPNode}})

Helper function which is used to combine multiple FP Trees.
"""
function merge_tree!(main::FPNode, local_node::FPNode, header::Dict{Int, Vector{FPNode}})
    main.support += local_node.support
    for (item, local_child) in local_node.children
        main_child = get!(main.children, item) do
            # Create new child if it doesn't exist
            child = FPNode(item, main)
            push!(get!(Vector{FPNode}, header, item), child)
            child
        end
        merge_tree!(main_child, local_child, header)
    end
end


"""

    create_conditional_tree(tree::FPTree, item::Int, min_support::Int)::FPTree

Helper function which is used to create conditional subtrees based on a given item.
"""
function create_conditional_tree(tree::FPTree, item::Int, min_support::Int)::FPTree
    cond_tree = FPTree()
    cond_tree.col_mapping = tree.col_mapping

    function insert_transaction!(tree::FPTree, transaction::Vector{Int}, count::Int=1)
        node = tree.root
        for item in transaction
            if !haskey(node.children, item)
                child = FPNode(item, node)
                node.children[item] = child
                push!(get!(Vector{FPNode}, tree.header_table, item), child)
            else
                child = node.children[item]
            end
            child.support += count
            node = child
        end
    end
    
    for node in tree.header_table[item]
        path = Int[]
        support = node.support
        current = node.parent
        
        while !isnothing(current) && current.value != -1
            push!(path, current.value)
            current = current.parent
        end
        
        if !isempty(path)
            reverse!(path)
                insert_transaction!(cond_tree, path, support)
        end
    end
    
    filter!(pair -> sum(n.support for n in pair.second) >= min_support, cond_tree.header_table)
    
    return cond_tree
end


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


"""
    fpclose(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

Identify closed frequent itemsets in a transactional dataset with the FPClose algorithm.

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
The FPClose algorithm is an extension of FP-Growth with 
additional pruning techniques to focus on mining closed itemsets. The algorithm operates in two main phases:

1. FP-tree Construction: Builds a compact representation of the dataset, organizing items 
   by their frequency to allow efficient mining.

2. Recursive Tree Traversal: 
   - Processes itemsets from least frequent to most frequent.
   - For each item, creates a conditional FP-tree and recursively mines it.
   - Uses a depth-first search strategy, exploring longer itemsets before shorter ones.
   - Employs pruning techniques to avoid generating non-closed itemsets.

FPClose is particularly efficient for datasets with long transactions or sparse frequent itemsets, 
as it can significantly reduce the number of generated itemsets compared to algorithms that 
find all frequent itemsets.

# Example
```julia
txns = load_transactions("transactions.txt", ' ')

# Find closed frequent itemsets with 5% minimum support
result = fpclose(txns, 0.05)

# Find closed frequent itemsets with minimum 5,000 transactions
result = fpclose(txns, 5_000)
```
# References
Grahne, Gösta, and Jianfei Zhu. “Fast Algorithms for Frequent Itemset Mining Using FP-Trees.” IEEE Transactions on Knowledge and Data Engineering 17, no. 10 (October 2005): 1347–62. https://doi.org/10.1109/TKDE.2005.166.
"""
function fpclose(txns::Transactions, min_support::Union{Int,Float64})
    n_transactions = size(txns.matrix, 1)
    
    # Handle min_support as a float value
    min_support = min_support isa Float64 ? ceil(Int, min_support * n_transactions) : min_support

    tree = make_FPTree(txns, min_support)
    
    # Initialize results dictionary
    Results = Dict{Vector{Int}, Int}()
    
    function fpclose!(closed_itemsets::Dict{Vector{Int}, Int}, tree::FPTree, suffix::Vector{Int}, min_support::Int)
        # Process items in reverse order (largest to smallest support)
        header_items = sort(collect(keys(tree.header_table)), 
                            by=item -> sum(node.support for node in tree.header_table[item]), 
                            rev=true)
        
        for item in header_items
            nodes = tree.header_table[item]
            support = sum(node.support for node in nodes)
            
            support < min_support && continue
            
            new_itemset = vcat(tree.col_mapping[item], suffix)
            
            # Check if this itemset is closed
            is_closed = !any(closed_itemsets) do (other_itemset, other_support)
                other_support == support &&
                issubset(new_itemset, other_itemset)
            end
            
            # If not closed, skip to creating conditional tree
            if is_closed
                
                # Remove any subsets of this itemset with the same support
                filter!(closed_itemsets) do (itemset, itemset_support)
                    !(itemset_support == support && issubset(itemset, new_itemset))
                end
                
                # Add the new closed itemset
                closed_itemsets[new_itemset] = support
            end
            
            # Create conditional FP-tree and continue mining
            cond_tree = create_conditional_tree(tree, item, min_support)
            isempty(cond_tree.header_table) && continue
            
            fpclose!(closed_itemsets, cond_tree, new_itemset, min_support)
        end
    end

    # Start the mining process
    fpclose!(Results, tree, Int[], min_support)

    df = DataFrame(
        Itemset = [RuleMiner.getnames(itemset, txns) for itemset in keys(Results)], 
        Support = [support / n_transactions for support in values(Results)],
        N = collect(values(Results)),
        Length = [length(itemset) for itemset in keys(Results)]
    )
    
    sort!(df, [:Length, :N], rev=[false, true])
    
    return df
end


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

    tree = make_FPTree(txns, min_support)
    
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
        Length = [length(itemset) for itemset in maximal_itemsets],
        Support = [sum(all(txns.matrix[:, itemset], dims=2)) / n_transactions for itemset in maximal_itemsets],
        N = [sum(all(txns.matrix[:, itemset], dims=2)) for itemset in maximal_itemsets]
    )
    
    # Sort results by length in descending order, then by support
    sort!(result_df, [:Length, :Support], rev=true)
    return result_df
end