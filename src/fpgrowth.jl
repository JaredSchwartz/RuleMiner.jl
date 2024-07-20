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

export fpgrowth, fpclose

mutable struct FPNode
    value::Int
    support::Int
    children::Dict{Int, FPNode}
    parent::Union{FPNode, Nothing}
    
    FPNode(value::Int, parent::Union{FPNode, Nothing}=nothing) = new(value, 0, Dict{Int, FPNode}(), parent)
end

mutable struct FPTree
    root::FPNode
    header_table::Dict{Int, Vector{FPNode}}
    lock::ReentrantLock
    col_mapping::Dict{Int, Int}  # Mapping from sorted to original column indices
    
    FPTree() = new(FPNode(-1), Dict{Int, Vector{FPNode}}(), ReentrantLock(), Dict{Int, Int}())
end

# Helper Functions
# -----------------
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

function make_FPTree(txns::Transactions, min_support::Int)

tree = FPTree()

# Sort and filter items based on support
col_sums = vec(sum(txns.matrix, dims=1))
frequent_cols = findall(col_sums .>= min_support)
sorted_cols = sort(frequent_cols, by=i -> col_sums[i], rev=true)

sorted_matrix = txns.matrix[:, sorted_cols]

# Populate col_mapping and preallocate header_table
tree.col_mapping = Dict{Int, Int}(sorted_idx => original_idx for (sorted_idx, original_idx) in enumerate(sorted_cols))

tree.header_table = Dict{Int, Vector{FPNode}}(i => FPNode[] for i in 1:size(sorted_matrix, 2))

# Insert transactions into the tree
n_rows = size(sorted_matrix, 1)

@sync begin
    for row in 1:n_rows
        Threads.@spawn begin
            transaction = findall(sorted_matrix[row, :])
            if !isempty(transaction)
                lock(tree.lock) do
                    insert_transaction!(tree, transaction)
                end
            end
        end
    end
end

return tree
end

function create_conditional_tree(tree::FPTree, item::Int, min_support::Int)
    cond_tree = FPTree()
    cond_tree.col_mapping = tree.col_mapping
    
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

# FP Growth
# -----------------
"""
    fpgrowth(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

Identify frequent itemsets in a transactional dataset `txns` with a minimum support: `min_support`.

When an Int value is supplied to min_support, eclat will use absolute support (count) of transactions as minimum support.
When a Float value is supplied, it will use relative support (percentage).
"""
function fpgrowth(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
    n_transactions = size(txns.matrix, 1)
    
    # Handle min_support as a float value
    if min_support isa Float64
        min_support = ceil(Int, min_support * n_transactions)
    end

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

# FPClose
# -----------------
struct ClosedItemset
    itemset::Vector{Int}
    support::Int
end

"""
    fpclose(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

Identify closed itemsets in a transactional dataset `txns` with a minimum support: `min_support`.

When an Int value is supplied to min_support, eclat will use absolute support (count) of transactions as minimum support.
When a Float value is supplied, it will use relative support (percentage).
"""
function fpclose(txns::Transactions, min_support::Union{Int,Float64})
    n_transactions = size(txns.matrix, 1)
    
    if min_support isa Float64
        min_support = ceil(Int, min_support * n_transactions)
    end

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