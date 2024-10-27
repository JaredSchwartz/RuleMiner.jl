# lcm.jl
# LCM closed itemset mining in Julia
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
    LCM(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

Identify closed frequent itemsets in a transactional dataset with the LCM algorithm.

# Arguments
- `txns::Transactions`: A `Transactions` object containing the dataset to mine.
- `min_support::Union{Int,Float64}`: The minimum support threshold. If an `Int`, it represents 
  the absolute support. If a `Float64`, it represents relative support.

# Returns
- `DataFrame`: A DataFrame containing the maximal frequent itemsets, with columns:
  - `Itemset`: The items in the maximal frequent itemset.
  - `Support`: The relative support of the itemset as a proportion of total transactions.
  - `N`: The absolute support count of the itemset.
  - `Length`: The number of items in the itemset.

# Description
LCM is an algorithm that uses a depth-first search pattern with closed-ness checking to return only closed itemsets.
It utilizes two key pruning techniques to avoid redundant mining: prefix-preserving closure extension (PPCE) and progressive database reduction (PDR).

- PPCE ensures that each branch will never overlap in the itemsets they explore by enforcing the order of the itemsets. This reduces redunant search space.
- PDR works with PPCE to remove data from a branch's dataset once it is determined to be not nescessary.

# Example
```julia
txns = Txns("transactions.txt", ' ')

# Find closed frequent itemsets with 5% minimum support
result = LCM(txns, 0.05)

# Find closed frequent itemsets with minimum 5,000 transactions
result = LCM(txns, 5_000)
```
# References
Uno, Takeaki, Tatsuya Asai, Yuzo Uchida, and Hiroki Arimura. “An Efficient Algorithm for Enumerating Closed Patterns in Transaction Databases.” 
In Discovery Science, edited by Einoshin Suzuki and Setsuo Arikawa, 16–31. Berlin, Heidelberg: Springer, 2004. https://doi.org/10.1007/978-3-540-30214-8_2.
"""
function LCM(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
    n_transactions, n_items = size(txns.matrix)
    
    # Handle min_support as a float value
    min_support = min_support isa Float64 ? ceil(Int, min_support * n_transactions) : min_support

    matrix, sorted_items = prune_matrix(txns.matrix, min_support)
    
    # Dictionary to store closed itemsets and their supports
    results = Dict{Vector{Int}, Int}()
    ThreadLock = ReentrantLock()
    
    function lcm!(closed_itemsets::Dict{Vector{Int}, Int}, current::Vector{Int}, rows::BitVector, dict_lock::ReentrantLock)
        # Get closure of current itemset
        closed = sorted_items[closure(matrix, current)]  # Map back to original indices
        support = count(rows)
        
        lock(dict_lock) do
            # If we've seen this closure with equal or higher support, skip it
            (haskey(closed_itemsets, closed) && closed_itemsets[closed] >= support) && return
            
            # Add Closure to Dict
            if !isempty(closed)
                closed_itemsets[closed] = support
            end
        end
        
        # Get current item's position in sorted_items for comparison
        curr_pos = isempty(current) ? 0 : findfirst(==(current[end]), 1:size(matrix, 2))
        
        # Try extending the itemset with each frequent item
        for new_pos in eachindex(sorted_items)
            orig_item = sorted_items[new_pos]
            
            # Skip if the item is already in the closure
            orig_item ∈ closed && continue
            
            # Skip if the item comes before the last item in the current itemset
            new_pos <= curr_pos && continue
            
            # Compute the new rows that contain both the current itemset and the new item
            new_rows = rows .& matrix[:, new_pos]
            
            # Skip if the new rows don't meet minimum support
            count(new_rows) < min_support && continue
            
            # Recurse with new rows and itemset
            lcm!(closed_itemsets, vcat(current, new_pos), new_rows, dict_lock)
        end
    end
    
    # Start the LCM process with size-1 itemsets
    @sync begin
        for pos in 1:length(sorted_items)
            Threads.@spawn lcm!(results, [pos], matrix[:, pos], ThreadLock)
        end
    end
    
    return make_itemset_df(results, txns)
end