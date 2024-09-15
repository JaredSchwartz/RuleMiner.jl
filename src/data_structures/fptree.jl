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

A mutable struct representing a node in an FP-tree (Frequent Pattern Tree) structure.

# Fields
- `value::Int`: The item index this node represents. For the root node, this is typically -1.
- `support::Int`: The number of transactions that contain this item in the path from the root to this node.
- `children::Dict{Int, FPNode}`: A dictionary of child nodes, where keys are item indices and values are `FPNode` objects.
- `parent::Union{FPNode, Nothing}`: The parent node in the FP-tree. For the root node, this is `nothing`.

# Description
`FPNode` is the fundamental building block of an FP-tree. Each node represents an item in the dataset 
and keeps track of how many transactions contain the path from the root to this item. The tree structure 
allows for efficient mining of frequent patterns without repeated database scans.

The `children` dictionary allows for quick access to child nodes, facilitating efficient tree traversal.
The `parent` reference enables bottom-up traversal, which is crucial for some frequent pattern mining algorithms.

# Constructor
    FPNode(value::Int, parent::Union{FPNode, Nothing}=nothing)


# Examples
```julia
# Create a root node
root = FPNode(-1)

# Create child nodes
child1 = FPNode(1, root)
child2 = FPNode(2, root)

# Add children to the root
root.children[1] = child1
root.children[2] = child2

# Increase support of a node
child1.support += 1

# Create a grandchild node
grandchild = FPNode(3, child1)
child1.children[3] = grandchild

# Traverse the tree
function print_tree(node::FPNode, depth::Int = 0)
    println(" "^depth, "Item: ", node.value, ", Support: ", node.support)
    for child in values(node.children)
        print_tree(child, depth + 2)
    end
end

print_tree(root)
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

A struct representing an FP-Tree (Frequent Pattern Tree) structure, used for efficient frequent itemset mining.

# Fields
- `root::FPNode`: The root node of the FP-Tree.
- `header_table::Dict{Int, Vector{FPNode}}`: A dictionary where keys are item indices and values are vectors of FPNodes representing the item occurrences in the tree.
- `col_mapping::Dict{Int, Int}`: A dictionary mapping the condensed item indices to the original item indices.
- `min_support::Int`: The minimum support threshold used to construct the tree.
- `n_transactions::Int`: The total number of transactions used to build the tree.
- `colkeys::Vector{String}`: The original item names corresponding to the column indices.

# Constructors
```julia
# Default Constructor
FPTree()

# Transaction Constructor
FPTree(txns::Transactions, min_support::Union{Int,Float64})
```

# Description
The FP-Tree is a compact representation of transaction data, designed for efficient frequent pattern mining. 
It stores frequent items in a tree structure, with shared prefixes allowing for memory-efficient storage and fast traversal.

The tree construction process involves:
1. Counting item frequencies and filtering out infrequent items.
2. Sorting items by frequency.
3. Inserting transactions into the tree, with items ordered by their frequency.

The `header_table` provides quick access to all occurrences of an item in the tree, facilitating efficient mining operations.

# Examples
```julia
# Create an empty FP-Tree
empty_tree = FPTree()

# Create an FP-Tree from a Transactions object
txns = load_transactions("transactions.txt", ' ')
tree = FPTree(txns, 0.05)  # Using 5% minimum support

# Access tree properties
println("Minimum support: ", tree.min_support)
println("Number of transactions: ", tree.n_transactions)
println("Number of unique items: ", length(tree.header_table))

# Traverse the tree (example)
function traverse(node::FPNode, prefix::Vector{String}=String[])
    if node.value != -1
        println(join(vcat(prefix, tree.colkeys[node.value]), " -> "))
    end
    for child in values(node.children)
        traverse(child, vcat(prefix, node.value != -1 ? [tree.colkeys[node.value]] : String[]))
    end
end

traverse(tree.root)
```

# Notes
- The FP-Tree structure is particularly useful for algorithms like FP-Growth, FP-Close, and FP-Max.
- When constructing from a Transactions object, items not meeting the minimum support threshold are excluded from the tree.
- The tree construction process is parallelized for efficiency on multi-core systems.

# References
Han, J., Pei, J., & Yin, Y. (2000). Mining Frequent Patterns without Candidate Generation. 
In proceedings of the 2000 ACM SIGMOD International Conference on Management of Data (pp. 1-12).
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