# carpenter.jl
# Carpenter closed itemset mining in Julia
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
    carpenter(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

Identify closed frequent itemsets in a transactional dataset with the CARPENTER algorithm.

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
CARPENTER is an algorithm that progressively builds larger itemsets, checking closed-ness at each step with three key pruning strategies:
- Itemsets are skipped if they have already been marked as closed on another branch
- Itemsets are skipped if they do not meet minimum support
- Itemsets' child itemsets are skipped if they change the support when the new items are added

CARPENTER is specialized for datasets which have few transactions, but many items per transaction and may not be the best choice for other data.

# Example
```julia
txns = Txns("transactions.txt", ' ')

# Find closed frequent itemsets with 5% minimum support
result = carpenter(txns, 0.05)

# Find closed frequent itemsets with minimum 5,000 transactions
result = carpenter(txns, 5_000)
```
# References
Pan, Feng, Gao Cong, Anthony K. H. Tung, Jiong Yang, and Mohammed J. Zaki. “Carpenter: Finding Closed Patterns in Long Biological Datasets.” In Proceedings of the Ninth ACM SIGKDD International Conference on Knowledge Discovery and Data Mining, 637–42. KDD ’03. New York, NY, USA: Association for Computing Machinery, 2003. https://doi.org/10.1145/956750.956832.
"""
function carpenter(txns::Transactions, min_support::Union{Int,Float64})
    n_transactions, n_items = size(txns.matrix)
    
    # Handle min_support as a float value
    min_support = min_support isa Float64 ? ceil(Int, min_support * n_transactions) : min_support
    
    matrix, sorted_items = RuleMiner.prune_matrix(txns.matrix, min_support)
    
    # Initialize results dictionary and threading lock
    Results = Dict{Vector{Int}, Int}()
    ThreadLock = ReentrantLock()
    
    function carpenter!(closed_itemsets::Dict{Vector{Int}, Int}, X::Vector{Int}, R::Vector{Int}, Lock::ReentrantLock)
        # Pruning 3: Early return if itemset is already present in the output
        haskey(closed_itemsets, X) && return
        
        # Get closure of current itemset and map back to original indices
        X_pos = Vector{Int}(findall(in(X), sorted_items))
        closed_pos = RuleMiner.closure(matrix, X_pos)
        closed = sorted_items[closed_pos]
        
        # Calculate support
        rows = vec(all(view(matrix, :, X_pos), dims=2))
        support = count(rows)
        
        # Pruning 1: Early return if not frequent
        support < min_support && return
        
        # Pruning 2: Add closure to results if not empty
        if !isempty(closed)
            lock(Lock) do
                closed_itemsets[closed] = support
            end
        end
        
        # Recursive enumeration
        remaining = filter(i -> i ∉ closed, R)
        for i in remaining
            carpenter!(closed_itemsets, sort(vcat(X, i)), filter(>(i), remaining), Lock)
        end
    end
    
    # Parallel Processing of initial itemsets
    @sync begin
        for item in sorted_items
            remaining_items = filter(x -> x > item, sorted_items)
            Threads.@spawn carpenter!(Results, [item], remaining_items, ThreadLock)
        end
    end
    
    return RuleMiner.make_itemset_df(Results, txns)
end