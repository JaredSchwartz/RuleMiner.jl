# fpclose.jl
# Algorithm for mining closed itemsets from FP Trees
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
    fpclose(data::Union{Transactions,FPTree}, min_support::Union{Int,Float64})::DataFrame

Identify closed frequent itemsets in a transactional dataset or an FP-tree with the FPClose algorithm.

# Arguments
- `data::Union{Transactions,FPTree}`: Either a `Transactions` object containing the dataset to mine,
  or a pre-constructed `FPTree` object.
- `min_support::Union{Int,Float64}`: The minimum support threshold. If an `Int`, it represents 
  the absolute support. If a `Float64`, it represents relative support.

# Returns
- `DataFrame`: A DataFrame containing the closed frequent itemsets, with columns:
  - `Itemset`: The items in the closed frequent itemset.
  - `Support`: The relative support of the itemset as a proportion of total transactions.
  - `N`: The absolute support count of the itemset.
  - `Length`: The number of items in the itemset.

# Description
The FPClose algorithm is an extension of FP-Growth with additional pruning techniques 
to focus on mining closed itemsets. The algorithm operates in two main phases:

1. FP-tree Construction: Builds a compact representation of the dataset, organizing items 
   by their frequency to allow efficient mining. This step is skipped if an FPTree is provided.

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
# Using a Transactions object
txns = Txns("transactions.txt", ' ')
result = fpclose(txns, 0.05)  # Find closed frequent itemsets with 5% minimum support

# Using a pre-constructed FPTree
tree = FPTree(txns, 5000)  # Construct FP-tree with minimum support of 5000
result = fpclose(tree, 6000)  # Find closed frequent itemsets with minimum support of 6000
```
# References
Grahne, Gösta, and Jianfei Zhu. "Fast Algorithms for Frequent Itemset Mining Using FP-Trees." 
IEEE Transactions on Knowledge and Data Engineering 17, no. 10 (October 2005): 1347–62. 
https://doi.org/10.1109/TKDE.2005.166.
"""
function fpclose(data::Union{Transactions,FPTree}, min_support::Union{Int,Float64})
    n_transactions = data.n_transactions
    min_support = min_support isa Float64 ? ceil(Int, min_support * n_transactions) : min_support
    tree = data isa FPTree ? data : FPTree(data,min_support)

    min_support >= tree.min_support || throw(DomainError(min_support,"Minimum support must be greater than or equal to the FPTree's min_support: $(tree.min_support)"))
    
    # Initialize results dictionary
    Results = Dict{Vector{Int}, Int}()
    
    function fpclose!(closed_itemsets::Dict{Vector{Int}, Int}, tree::FPTree, suffix::Vector{Int}, min_support::Int)
        # Process items in reverse order (largest to smallest support)
        header_items = sort(
            collect(keys(tree.header_table)), 
            by=item -> sum(node.support for node in tree.header_table[item]), 
            rev=true
        )
        
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
        Itemset = [data.colkeys[itemset] for itemset in keys(Results)], 
        Support = [support / n_transactions for support in values(Results)],
        N = collect(values(Results)),
        Length = [length(itemset) for itemset in keys(Results)]
    )
    
    sort!(df, [:Length, :N], rev=[false, true])
    
    return df
end