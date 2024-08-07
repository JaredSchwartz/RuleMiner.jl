# carpenter.jl
# Carpenter closed itemset mining in Julia
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

export carpenter

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
CARPENTER is an algorithm that progressively builds larger itemsets, checking closed-ness at each step with three key pruning strategies. 
It is specialized for datasets which have few transactions, but many items per transaction and may not be the best choice for other data.

# Example
```julia
txns = load_transactions("transactions.txt", ' ')

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
    
    # Create tidsets (transaction ID sets) for each item
    tidsets = [BitSet(findall(txns.matrix[:,col])) for col in 1:n_items]
    supports = vec(sum(txns.matrix, dims=1))

    # Create vectors of all items and all frequent items for mining
    allitems = collect(1:n_items)
    frequent_items = findall(supports .>= min_support)

    # Initialize results dictionary and threading lock
    Results = Dict{Vector{Int}, Int}()
    ThreadLock = ReentrantLock()
    
    function carpenter!(closed_itemsets::Dict{Vector{Int}, Int}, X::Vector{Int}, R::Vector{Int}, Lock::ReentrantLock)
        # Pruning 3: Early return if itemset is already present in the output
        haskey(closed_itemsets, X) && return
        
        # Find transactions with the itemset and calculate support
        tidset_X = length(X) == 1 ? tidsets[X[1]] : intersect(tidsets[X]...)
        support_X = length(tidset_X)
        
        # Pruning 1: Early return if the itemset is not frequent
        support_X < min_support && return
    
        # Pruning 2: Find items that can be added without changing support
        Y = filter(i -> length(intersect(tidset_X, tidsets[i])) == support_X, R)

        # Add X to itemsets if it's closed (Y is empty)
        if isempty(Y) 
            lock(Lock) do
                closed_itemsets[X] = support_X
            end
        # If Y is not empty, add the itemset's closure (X ∪ Y)
        else 
            lock(Lock) do
                closed_itemsets[sort(vcat(X, Y))] = support_X
            end
        end
        
        # Recursive enumeration
        for i in setdiff(R, Y)
            carpenter!(closed_itemsets, sort(vcat(X, i)), setdiff(R, [i]), Lock)
        end
    end

    # Parallel Processing of initial itemsets
    @sync begin
        for item in frequent_items
            Threads.@spawn carpenter!(Results, [item], setdiff(allitems, [item]), ThreadLock)
        end
    end
    
    # Create the result DataFrame
    result_df = DataFrame(
        Itemset = [RuleMiner.getnames(itemset, txns) for itemset in keys(Results)],
        Support = [support / n_transactions for support in values(Results)],
        N = collect(values(Results)),
        Length = [length(itemset) for itemset in keys(Results)]
    )
    
    # Sort results by support in descending order
    sort!(result_df, :N, rev=true)
    return result_df
end