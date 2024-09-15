# fpnode.jl
# Definition and constructors for FPNode objects
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
```julia
FPNode(value::Int, parent::Union{FPNode, Nothing}=nothing)
```

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