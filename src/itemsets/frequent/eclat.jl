# eclat.jl
# ECLAT frequent itemset mining in Julia
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
    eclat(txns::Transactions, min_support::Union{Int,Float64})::DataFrame

Perform frequent itemset mining using the ECLAT (Equivalence CLAss Transformation) algorithm 
on a transactional dataset.

ECLAT is an efficient algorithm for discovering frequent itemsets, which are sets of items 
that frequently occur together in the dataset.

# Arguments
- `txns::Transactions`: A `Transactions` object containing the dataset to mine.
- `min_support::Union{Int,Float64}`: The minimum support threshold. If an `Int`, it represents 
  the absolute support. If a `Float64`, it represents relative support.

# Returns
A DataFrame containing the discovered frequent itemsets with the following columns:
- `Itemset`: Vector of item names in the frequent itemset.
- `Support`: Relative support of the itemset.
- `N`: Absolute support count of the itemset.
- `Length`: Number of items in the itemset.

# Algorithm Description
The ECLAT algorithm uses a depth-first search strategy and a vertical database layout to 
efficiently mine frequent itemsets. It starts by computing the support of individual items, 
sorts them in descending order of frequency, and then recursively builds larger itemsets.
ECLAT's depth-first approach enables it to quickly identify long frequent itemsets, and it is most efficient for sparse datasets

# Example
```julia
txns = Txns("transactions.txt", ' ')

# Find frequent itemsets with 5% minimum support
result = eclat(txns, 0.05)

# Find frequent itemsets with minimum 5,000 transactions
result = eclat(txns, 5_000)
```
# References
Zaki, Mohammed. “Scalable Algorithms for Association Mining.” Knowledge and Data Engineering, IEEE Transactions On 12 (June 1, 2000): 372–90. https://doi.org/10.1109/69.846291.
"""
function eclat(txns::Transactions, min_support::Union{Int,Float64})#::DataFrame
    n_transactions = size(txns.matrix, 1)
    
    # Handle min_support as a float value
    min_support = min_support isa Float64 ? ceil(Int, min_support * n_transactions) : min_support

    matrix, sorted_items = prune_matrix(txns.matrix, min_support)

    # Initialize results dictionary and threading lock
    results = Dict(zip([[i] for i in sorted_items], vec(sum(matrix,dims=1))))
    thread_lock = ReentrantLock()

    # Define recursive eclat function and run it on the data
    function eclat!(results::Dict{Vector{Int}, Int}, lineage::Vector{Int}, items::Vector{Int}, matrix::BitMatrix, min_support::Int)
        for (i, item) in enumerate(items)
            new_lineage = vcat(lineage, item)
            support = sum(all(view(matrix, :, new_lineage), dims=2))
    
            # Skip this itemset if it does not meet minimum suppot
            support < min_support && continue

            # Add the Itemset to results
            lock(thread_lock) do
                results[sorted_items[new_lineage]] = support
            end

            # Generate new possible items
            new_items = items[i+1:end]

            # If no additional items, skip recursion
            isempty(new_items) && continue
            
            # Recurse with new items
            eclat!(results, new_lineage, new_items, matrix, min_support)
        end
    end

    @sync begin
        for item in eachindex(sorted_items)
            Threads.@spawn eclat!(results, [item], collect(item+1:length(sorted_items)), matrix, min_support)
        end
    end
    
    return make_itemset_df(results,txns)
end