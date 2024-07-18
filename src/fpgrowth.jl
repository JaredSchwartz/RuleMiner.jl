# fpgrowth.jl
# FP Growth mining in Julia
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

# FP Growth
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
function mine_frequent(tree::FPTree, suffix::Vector{Int}, min_support::Int)
    frequent_patterns = Dict{Vector{Int}, Int}()
    
    for (item, nodes) in tree.header_table
        support = sum(node.support for node in nodes)

        if support >= min_support
            original_item = tree.col_mapping[item]
            new_suffix = vcat([original_item], suffix)
            frequent_patterns[new_suffix] = support
            
            # Create and mine conditional FP-tree
            cond_tree = create_conditional_tree(tree, item, min_support)
            if !isempty(cond_tree.header_table)
                merge!(frequent_patterns, mine_frequent(cond_tree, new_suffix, min_support))
            end
        end
    end
    
    return frequent_patterns
end

"""
    fpgrowth(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

Identify frequent itemsets in a transactional dataset `txns` with a minimum support: `min_support`.

When an Int value is supplied to min_support, eclat will use absolute support (count) of transactions as minimum support.

When a Float value is supplied, it will use relative support (percentage).
"""
function fpgrowth(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

    n_transactions = size(txns.matrix,1)
    
    # Handle min_support as a float value
    if min_support isa Float64
        min_support = ceil(Int, min_support * n_transactions)
    end

    # Generate tree
    tree = make_FPTree(txns, min_support)

    # Mine frequent sets
    frequent_items = mine_frequent(tree, Int[], min_support)
    
    # Convert the dictionary to a DataFrame
    df = DataFrame(
        Itemset = [getnames(i,txns) for i in collect(keys(frequent_items))], 
        Support = collect(values(frequent_items)) ./ n_transactions,
        N = collect(values(frequent_items)),
        Length = [length(i) for i in collect(keys(frequent_items))]
        )
    
    # Sort by support in descending order
    sort!(df, :N, rev=true)
    
    return df
end

# FPClose
# -----------------
struct ClosedItemset
    itemset::Vector{Int}
    support::Int
end

function mine_closed(tree::FPTree, suffix::Vector{Int}, min_support::Int)
    closed_itemsets = Vector{ClosedItemset}()
    header_items = collect(keys(tree.header_table))
    
    # Pre-allocate buffers
    new_itemset = Vector{Int}(undef, length(suffix) + 1)
    copyto!(new_itemset, 2, suffix, 1, length(suffix))
    
    for item in header_items
        nodes = tree.header_table[item]
        support = sum(node.support for node in nodes)
        
        if support >= min_support
            new_itemset[1] = tree.col_mapping[item]
            
            # Create conditional FP-tree
            cond_tree = create_conditional_tree(tree, item, min_support)
            
            if isempty(cond_tree.header_table)
                # If there's no conditional tree, this itemset is closed
                push!(closed_itemsets, ClosedItemset(copy(new_itemset), support))
            else
                sub_closed_itemsets = mine_closed(cond_tree, new_itemset, min_support)
                
                # Check if this itemset is closed
                is_closed = !any(sci -> sci.support == support, sub_closed_itemsets)
                
                if is_closed
                    push!(closed_itemsets, ClosedItemset(copy(new_itemset), support))
                end
                
                # Merge sub_closed_itemsets
                append!(closed_itemsets, sub_closed_itemsets)
            end
        end
    end
    
    # Final pruning step
    sort!(closed_itemsets, by = ci -> length(ci.itemset))
    filter!(closed_itemsets) do ci1
        !any(ci2 -> ci1 !== ci2 && 
                    length(ci1.itemset) < length(ci2.itemset) && 
                    ci1.support == ci2.support && 
                    issubset(ci1.itemset, ci2.itemset),
            closed_itemsets)
    end
    
    return closed_itemsets
end

"""
    fpclose(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

Identify closed itemsets in a transactional dataset `txns` with a minimum support: `min_support`.

When an Int value is supplied to min_support, eclat will use absolute support (count) of transactions as minimum support.

When a Float value is supplied, it will use relative support (percentage).
"""
function fpclose(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
    n_transactions = size(txns.matrix, 1)
    
    if min_support isa Float64
        min_support = ceil(Int, min_support * n_transactions)
    end

    tree = make_FPTree(txns, min_support)
    
    closed_itemsets = mine_closed(tree, Int[], min_support)
    
    df = DataFrame(
        Itemset = [getnames(ci.itemset, txns) for ci in closed_itemsets], 
        Support = [ci.support / n_transactions for ci in closed_itemsets],
        N = [ci.support for ci in closed_itemsets],
        Length = [length(ci.itemset) for ci in closed_itemsets]
    )
    
    sort!(df, [:Length, :N], rev=[false, true])
    
    return df
end