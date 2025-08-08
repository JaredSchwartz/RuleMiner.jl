#= fp_utils.jl
Utility functions for working with FP trees
Licensed under the MIT license. See https://github.com/JaredSchwartz/RuleMiner.jl/blob/main/LICENSE
=#


"""

    merge_tree!(main::FPNode, local_node::FPNode, header::Dict{Int, Vector{FPNode}})

Helper function which is used to combine multiple FP Trees.
"""
function merge_tree!(main::FPNode, local_node::FPNode, header::Dict{Int, Vector{FPNode}})
    main.support += local_node.support

    function update_header!(header::Dict{Int, Vector{FPNode}}, item::Int, node::FPNode)
        if haskey(header, item)
            push!(header[item], node)
        else
            header[item] = [node]
        end
    end
    
    function update_descendant_headers!(header::Dict{Int, Vector{FPNode}}, node::FPNode)
        for (item, child) in node.children
            update_header!(header, item, child)
            update_descendant_headers!(header, child)
        end
    end
    
    for (item, local_child) in local_node.children
        if haskey(main.children, item)
            # If the child already exists, recursively merge
            merge_tree!(main.children[item], local_child, header)
        else
            # If the child doesn't exist, we can directly attach the local subtree
            main.children[item] = local_child
            local_child.parent = main
            
            # Update the header table
            update_header!(header, item, local_child)
            
            # Recursively update the header for all descendants
            update_descendant_headers!(header, local_child)
        end
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