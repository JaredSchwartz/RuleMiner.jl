# fptree.jl
# Definition and constructors for FP Tree objects
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
    min_support::Int
    n_transactions::Int
    colkeys::Vector{String}

    # Default constructor
    FPTree() = new(FPNode(-1), Dict{Int, Vector{FPNode}}(), Dict{Int, Int}(), 0, 0, String[])

    # Constructor from Transactions
    function FPTree(txns::Transactions, min_support::Union{Int,Float64})
        n_transactions = txns.n_transactions
        min_support = min_support isa Float64 ? ceil(Int, min_support * n_transactions) : min_support

        # Sort and filter items based on support
        col_sums = vec(sum(txns.matrix, dims=1))
        sorted_cols = sort(findall(>=(min_support), col_sums), by=i -> col_sums[i], rev=true)

        # Initialize FPTree structure
        tree = new(
            FPNode(-1),
            Dict{Int, Vector{FPNode}}(),
            Dict(i => col for (i, col) in enumerate(sorted_cols)),
            min_support,
            n_transactions,
            txns.colkeys
        )

        # Determine chunks for parallel processing
        min_chunk_size = 50
        max_chunks = min(nthreads() * 4, cld(n_transactions, min_chunk_size))
        chunk_size = max(min_chunk_size, cld(n_transactions, max_chunks))
        n_chunks = min(max_chunks, cld(n_transactions, chunk_size))

        # Pre-allocate fixed-size buffers for each thread
        buffer_size = length(sorted_cols)
        thread_buffers = [Vector{Int}(undef, buffer_size) for _ in 1:nthreads()]

        # Process transactions in parallel
        local_trees = Vector{FPNode}(undef, n_chunks)
        @sync begin
            for (chunk_id, chunk_start) in enumerate(1:chunk_size:n_transactions)
                Threads.@spawn begin
                    chunk_end = min(chunk_start + chunk_size - 1, n_transactions)
                    local_tree = FPNode(-1)  # Local tree for this chunk
                    buffer = thread_buffers[Threads.threadid()]
                    
                    # Process each transaction in the chunk
                    for row in chunk_start:chunk_end
                        transaction_size = 0
                        @inbounds for (new_idx, col) in enumerate(sorted_cols)
                            if txns.matrix[row, col]
                                transaction_size += 1
                                buffer[transaction_size] = new_idx
                            end
                        end
                        
                        # Insert the transaction into the local tree
                        node = local_tree
                        @inbounds for i in 1:transaction_size
                            item = buffer[i]
                            child = get(node.children, item, nothing)
                            if isnothing(child)
                                child = FPNode(item, node)
                                node.children[item] = child
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
end