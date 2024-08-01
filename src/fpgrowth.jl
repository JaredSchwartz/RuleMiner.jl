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

abstract type FPNode end

"""

    AtomicNode

This is a struct which represents an FP Node with an atomic support field. It is used during the construction of the tree to multithread the insertion of transactions

# Fields
- `value`: The item index of the node
- `support`: An atomic integer for storing the support count of the item
- `children`: A Dict with integer keys representing the item index of the child nodes and Atomic node values representing the child nodes
- `parent`: An `AtomicNode` object representing the node's parent node

# Examples
Generate a root node with value -1
```julia
node = AtomicNode(-1)
```
"""
mutable struct AtomicNode <: FPNode
    value::Int
    support::Atomic{Int}
    children::Dict{Int, AtomicNode}
    parent::Union{AtomicNode, Nothing}
    
    AtomicNode(value::Int, parent::Union{AtomicNode, Nothing}=nothing) = new(value, Atomic{Int}(0), Dict{Int, AtomicNode}(), parent)
end


"""

    IntNode

This is a struct which represents an FP Node with an integer support field. It is the final product mining algorithms use to mine patterns.

# Fields
- `value`: The item index of the node
- `support`: An integer representing the support count of the node
- `children`: A Dict with integer keys representing the item index of the child nodes and `IntNode`` values representing the child nodes
- `parent`: An `IntNode` object representing the node's parent node

# Examples
Generate a root node with value -1
```julia
node = IntNode(-1)
```
"""
mutable struct IntNode <: FPNode
    value::Int
    support::Int
    children::Dict{Int, IntNode}
    parent::Union{IntNode, Nothing}
    
    # Default constructor
    IntNode(value::Int, parent::Union{IntNode, Nothing}=nothing) = new(value, 0, Dict{Int, IntNode}(), parent)

    # Constructor for converting from AtomicNode
    function IntNode(anode::AtomicNode, parent::Union{IntNode, Nothing}=nothing)
        inode = new(anode.value, anode.support[], Dict{Int, IntNode}(), parent)
        for (item, child) in anode.children
            inode.children[item] = IntNode(child, inode)
        end
        return inode
    end
end

"""

    FPTree

This is a struct which represents an FP-Tree structure. It also holds a header table of nodes to enable faster calculations.

# Fields
- `root`: The FPNode that serves as the root of the tree
- `header_table`: A dict where the keys are the items and the values are a vector of FPNodes representing the item
- `lock`: A `ReentrantLock` to enable multithreaded construction
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
    lock::ReentrantLock
    col_mapping::Dict{Int, Int}
    
    FPTree() = new(IntNode(-1), Dict{Int, Vector{IntNode}}(), ReentrantLock(), Dict{Int, Int}())
end

"""

    make_FPTree(txns::Transactions, min_support::Int)::FPTree

This is a function which constructs an `FPTree`` object from a `Transactions` object.
"""
function make_FPTree(txns::Transactions, min_support::Int)::FPTree
    n_transactions = size(txns.matrix, 1)

    # Create a construction tree using the existing FPTree struct
    construction_tree = FPTree()
    construction_tree.root = AtomicNode(-1)

    # Sort and filter items based on support
    col_sums = vec(sum(txns.matrix, dims=1))
    frequent_cols = findall(col_sums .>= min_support)
    sorted_cols = sort(frequent_cols, by=i -> col_sums[i], rev=true)
    colset = sorted_cols[eachindex(sorted_cols)]

    # Populate col_mapping and preallocate header_table
    construction_tree.col_mapping = Dict{Int, Int}(sorted_idx => original_idx for (sorted_idx, original_idx) in enumerate(sorted_cols))
    construction_tree.header_table = Dict{Int, Vector{AtomicNode}}(i => AtomicNode[] for i in eachindex(sorted_cols))

    function insert_transaction_atomic!(tree::FPTree, transaction::Vector{Int})
        node = tree.root::AtomicNode
        for item in transaction
            # Check if Child exists
            child = get(node.children, item, nothing)
            
            # If not, create it
            if isnothing(child)
                child = create_new_child!(tree, node, item)
            end
            
            # Add the support to the child's support
            atomic_add!(child.support, 1)
            node = child
        end
    end
    
    function create_new_child!(tree::FPTree, node::AtomicNode, item::Int)
        lock(tree.lock) do
            # Check again in case another thread created the child while waiting for the lock
            child = get(node.children, item, nothing)
            !isnothing(child) && return child
            
            child = AtomicNode(item, node)
            node.children[item] = child
            push!(get!(Vector{AtomicNode}, tree.header_table, item), child)
            return child
        end
    end

    n_chunks = 4 * nthreads()
    chunk_size = ceil(Int, n_transactions / n_chunks)
    
    @sync begin
        for chunk in 1:n_chunks
            Threads.@spawn begin
                start_row = (chunk - 1) * chunk_size + 1
                end_row = min(chunk * chunk_size, n_transactions)
                
                for row in start_row:end_row
                    transaction = findall(txns.matrix[row, colset])

                    # Skip transaction if it is empty
                    isempty(transaction) && continue

                    insert_transaction_atomic!(construction_tree, transaction)
                end
            end
        end
    end

    function convert_to_int_tree!(tree::FPTree)
        # Convert the root node
        tree.root = IntNode(tree.root::AtomicNode)
        
        # Clear and repopulate the header table
        empty!(tree.header_table)
        
        function populate_header_table!(node::IntNode)
            # Skip the root node
            if node.value != -1  
                push!(get!(Vector{IntNode}, tree.header_table, node.value), node)
            end
            for child in values(node.children)
                populate_header_table!(child)
            end
        end
    
        populate_header_table!(tree.root)
        return tree
    end
    
    return convert_to_int_tree!(construction_tree)
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
                child = IntNode(item, node)
                node.children[item] = child
                push!(get!(Vector{IntNode}, tree.header_table, item), child)
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
        
        # Build path directly within this function
        while !isnothing(current) && current.value != -1
            push!(path, current.value)
            current = current.parent
        end
        
        if !isempty(path)
            reverse!(path)  # Reverse the path to get correct order
            lock(cond_tree.lock) do
                insert_transaction!(cond_tree, path, support)
            end
        end
    end
    
    # Prune infrequent items
    filter!(pair -> sum(n.support for n in pair.second) >= min_support, cond_tree.header_table)
    
    return cond_tree
end


"""
    fpgrowth(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

Identify frequent itemsets in a transactional dataset `txns` with a minimum support: `min_support`.

When an Int value is supplied to min_support, eclat will use absolute support (count) of transactions as minimum support.
When a Float value is supplied, it will use relative support (percentage).
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
        Itemset = [getnames(itemset, txns) for itemset in keys(Results)],
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

Identify closed itemsets in a transactional dataset `txns` with a minimum support: `min_support`.

When an Int value is supplied to min_support, eclat will use absolute support (count) of transactions as minimum support.
When a Float value is supplied, it will use relative support (percentage).
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
        Itemset = [getnames(itemset, txns) for itemset in keys(Results)], 
        Support = [support / n_transactions for support in values(Results)],
        N = collect(values(Results)),
        Length = [length(itemset) for itemset in keys(Results)]
    )
    
    sort!(df, [:Length, :N], rev=[false, true])
    
    return df
end


"""
    fpmax(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

Identify maximal frequent itemsets in a transactional dataset `txns` with a minimum support: `min_support`.

When an Int value is supplied to min_support, fpmax will use absolute support (count) of transactions as minimum support.
When a Float value is supplied, it will use relative support (percentage).
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
        Itemset = [getnames(itemset, txns) for itemset in maximal_itemsets],
        Length = [length(itemset) for itemset in maximal_itemsets],
        Support = [sum(all(txns.matrix[:, itemset], dims=2)) / n_transactions for itemset in maximal_itemsets],
        N = [sum(all(txns.matrix[:, itemset], dims=2)) for itemset in maximal_itemsets]
    )
    
    # Sort results by length in descending order, then by support
    sort!(result_df, [:Length, :Support], rev=true)
    return result_df
end