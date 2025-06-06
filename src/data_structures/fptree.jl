#= fptree.jl
Definition and constructors for FPTree objects
Licensed under the MIT license. See https://github.com/JaredSchwartz/RuleMiner.jl/blob/main/LICENSE
=#

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

# Description
The FP-Tree is a compact representation of transaction data, designed for efficient frequent pattern mining. 
It stores frequent items in a tree structure, with shared prefixes allowing for memory-efficient storage and fast traversal.

The tree construction process involves:
1. Counting item frequencies and filtering out infrequent items.
2. Sorting items by frequency.
3. Inserting transactions into the tree, with items ordered by their frequency.

The `header_table` provides quick access to all occurrences of an item in the tree, facilitating efficient mining operations.

# Constructors
## Default Constructor
```julia
FPTree()
```
## Transaction Constructor
```julia
FPTree(txns::Transactions, min_support::Union{Int,Float64})
```
The Transaction constructor allows creation of a `FPTree` object from a `Transactions`-type object:
- `txns`: Transactions object to convert
- `min_support`: Minimum support for an item to be included int the tree

# Examples
```julia
# Create an empty FP-Tree
empty_tree = FPTree()

# Create an FP-Tree from a Transactions object
txns = Txns("transactions.txt", ' ')
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

        # Calculate chunks for parallel processing
        num_threads = nthreads(:default)
        min_chunk_size = 50
        chunk_size = max(min_chunk_size, cld(n_transactions, num_threads * 4))
        total_chunks = cld(n_transactions, chunk_size)
        chunk_counter = Atomic{Int}(0)

        # Set up parallel processing channels
        tree_channel = Channel{FPNode}(total_chunks)        # Output Channel
        buffer_channel = Channel{Vector{Int}}(num_threads)  # Thread-local pool
        for _ in 1:num_threads
            put!(buffer_channel, Vector{Int}(undef, length(sorted_cols)))
        end
        
        @sync begin
            for _ in 1:num_threads
                @spawn begin
                    
                    buffer = take!(buffer_channel)
                    
                    
                    while true

                        # Use a work-stealing pattern with atomic_add! on the chunk_counter
                        chunk_number = atomic_add!(chunk_counter, 1)
                        chunk_number >= total_chunks && break
                        
                        chunk_start = chunk_number * chunk_size + 1
                        chunk_end = min(chunk_start + chunk_size - 1, n_transactions)
                        
                        
                        local_tree = FPNode(-1)
                        
                        for row in chunk_start:chunk_end

                            # Read transaction into the buffer
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
                        
                        put!(tree_channel, local_tree)
                    end
                    
                    put!(buffer_channel, buffer)
                end
            end
        end

        # Merge local trees into the main tree
        close(tree_channel)
        for local_tree in tree_channel
            merge_tree!(tree.root, local_tree, tree.header_table)
        end

        return tree
    end
end

Base.show(io::IO, tree::FPTree) = show(io, MIME("text/plain"), tree)

function Base.show(io::IO, ::MIME"text/plain", tree::FPTree)
    num_items = length(tree.header_table)
    num_nodes = sum([length(i) for i in values(tree.header_table)])
    println(io, "FPTree with $num_items items and $num_nodes nodes")
    
    term_height, term_width = displaysize(io)
    available_height = term_height - 5
    
    term_width >= 20 && print_fptree_recursive(io, tree, tree.root, "", true, 0, available_height, term_width)
end

function print_fptree_recursive(io::IO, tree::FPTree, node::FPNode, prefix::String, is_last::Bool, depth::Int, available_height::Int, term_width::Int)

    # Print the current node
    lines_used = 1
    if node === tree.root
        println(io, "Root")
    else
        branch = is_last ? "└" : "├"
        item_name = tree.colkeys[tree.col_mapping[node.value]]
        node_str = "$(branch)── $item_name ($(node.support))"
        
        if length(prefix) + length(node_str) <= term_width
            println(io, prefix, node_str)
        else
            println(io, prefix, branch, "...")
        end
    end
    available_height -= 1

    # Prepare the prefix for children
    child_prefix = prefix * (is_last ? "    " : "│   ")

    # Get and sort children
    children = collect(values(node.children))
    sort!(children, by = c -> c.support, rev = true)

    # Print children
    hidden_count = 0
    for (i, child) in enumerate(children)
        if available_height > 1  # Ensure we have space for at least one more line after this
            child_lines = print_fptree_recursive(io, tree, child, child_prefix, i == length(children), depth + 1, available_height - 1, term_width)
            lines_used += child_lines
            available_height -= child_lines
        else
            hidden_count += 1
        end
    end

    # If there are hidden children, show a count
    if hidden_count > 0 && available_height > 0 && (term_width - length(child_prefix) >= 5)
        println(io, child_prefix, "└...($hidden_count more)") 
        lines_used += 1
    end

    return lines_used
end
