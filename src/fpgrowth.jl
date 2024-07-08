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

export fpgrowth

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

    # Compute column sums
    col_sums = vec(sum(txns.matrix, dims=1))
    
    # Filter columns by minimum support
    frequent_cols = findall(col_sums .>= min_support)
    
    # Sort columns by frequency
    sorted_cols = sort(frequent_cols, by=i -> col_sums[i], rev=true)
    
    # Create a new sorted and filtered sparse matrix
    sorted_matrix = txns.matrix[:, sorted_cols]
    
    # Populate col_mapping and preallocate header_table for frequent items
    tree.col_mapping = Dict{Int, Int}(sorted_idx => original_idx for (sorted_idx, original_idx) in enumerate(sorted_cols))
    
    tree.header_table = Dict{Int, Vector{FPNode}}(i => FPNode[] for i in 1:size(sorted_matrix, 2))
    
    # Insert transactions into the tree
    n_rows = size(sorted_matrix, 1)
    
    @threads for row in 1:n_rows
        transaction = findall(sorted_matrix[row, :])
        if !isempty(transaction)
            lock(tree.lock) do
                insert_transaction!(tree, transaction)
            end
        end
    end
    
    return tree
end


function mine_frequent(tree::FPTree, suffix::Vector{Int}, min_support::Int)
    # Initialize a dictionary to store frequent patterns and their support
    frequent_patterns = Dict{Vector{Int}, Int}()
    
    # Iterate through each item in the tree's header table
    for (item, nodes) in tree.header_table
        # Calculate the total support for this item
        support = sum(node.support for node in nodes)
        
        # Check if the item meets the minimum support threshold
        if support >= min_support
            # Map the item back to its original value
            original_item = tree.col_mapping[item]
            
            # Create a new itemset by adding this item to the suffix
            new_suffix = vcat([original_item], suffix)
            
            # Add the new itemset and its support to the frequent patterns
            frequent_patterns[new_suffix] = support
            
            # Create a conditional FP-tree for this item
            cond_tree = FPTree()
            cond_tree.col_mapping = tree.col_mapping
            
            # Build conditional patterns for each path ending with this item
            for node in nodes
                path = FPNode[]
                current = node.parent
                
                # Traverse up the tree to build the path
                while !isnothing(current) && current.value != -1
                    push!(path, current)
                    current = current.parent
                end
                
                # If a valid path exists, add it to the conditional tree
                if !isempty(path)
                    transaction = reverse!([n.value for n in path])
                    lock(cond_tree.lock) do
                        insert_transaction!(cond_tree, transaction, node.support)
                    end
                end
            end
            
            # Recursively mine the conditional tree if it's not empty
            if !isempty(cond_tree.header_table)
                merge!(frequent_patterns, mine_frequent(cond_tree, new_suffix, min_support))
            end
        end
    end
    
    # Return all discovered frequent patterns
    return frequent_patterns
end

function fpgrowth(txns::Transactions, min_support::Union{Int,Float64})

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