#= itemset_utils.jl
Utilities for mining frequent itemsets
Licensed under the MIT license. See https://github.com/JaredSchwartz/RuleMiner.jl/blob/main/LICENSE
=#

"""
    make_itemset_df(results::Dict{Vector{Int}, Int}, txns::Transactions)::DataFrame

Convert a dictionary of frequent itemsets and their supports into a formatted DataFrame.

# Arguments
- `results::Dict{Vector{Int}, Int}`: Dictionary mapping itemsets (as vectors of integer indices) to
   their absolute support counts. Keys are vectors representing itemsets and values are 
   the number of transactions containing that itemset.
- `txns::Transactions`: The Transactions object used for mining, containing item names and 
   the total number of transactions.

# Returns
A DataFrame with the following columns:
- `Itemset`: Vector{String} - The items in each frequent itemset, with integer indices converted 
   to their original item names
- `Support`: Float64 - The relative support of each itemset (proportion of transactions containing it)
- `N`: Int - The absolute support count (number of transactions containing the itemset)
- `Length`: Int - The number of items in each itemset

The DataFrame is sorted by absolute support (N) in descending order.

# Example
```julia
# Assuming we have mined results and a transactions object
results = Dict(
    [1, 2] => 50,  # Itemset of items 1 and 2 appears in 50 transactions
    [1] => 75      # Item 1 appears in 75 transactions
)
txns = Txns(...)   # Transactions object with item names "A" and "B"

df = make_itemset_df(results, txns)

# Returns DataFrame:
# Itemset        Support    N    Length
# ["A"]         0.75      75      1
# ["A", "B"]    0.50      50      2
```
"""
function make_itemset_df(results::Dict{Vector{Int}, Int}, txns::Union{Transactions,FPTree})::DataFrame
    result_df = DataFrame(
        Itemset = [RuleMiner.getnames(itemset, txns) for itemset in keys(results)],
        Support = [support / txns.n_transactions for support in values(results)],
        N = collect(values(results)),
        Length = [length(itemset) for itemset in keys(results)]
    )
    sort!(result_df, :N, rev=true)
    return result_df
end


"""
    closure(matrix::BitMatrix, itemset::Vector{Int}) -> Vector{Int}

Calculate the closure of an itemset in a binary transaction matrix.

# Arguments
- `matrix::BitMatrix`: A binary matrix where rows represent transactions and columns represent items.
   True values indicate item presence in a transaction.
- `itemset::Vector{Int}`: Vector of column indices representing the itemset whose closure 
   should be computed.

# Returns
- `Vector{Int}`: Column indices of the closure - all items that appear in every transaction 
   containing the input itemset.

# Description
The closure operation finds all items that are functionally implied by a given itemset
in the transaction data. It works by:
1. Finding all transactions that contain the input itemset
2. Identifying which items appear in all of these transactions

An item is in the closure if it appears in every transaction that contains the input itemset.
The input itemset is always a subset of its closure.

# Example
```julia
# Create a binary matrix with 3 transactions and 4 items
matrix = BitMatrix([
    1 1 1 0;  # Transaction 1 contains items 1, 2, and 3
    1 1 1 0;  # Transaction 2 contains items 1, 2, and 3
    0 0 0 1   # Transaction 3 contains only item 4
])

# Find closure of itemset [1]
closed = closure(matrix, [1])  # Returns [1, 2, 3]
# Items 2 and 3 are in the closure because they appear in
# all transactions containing item 1
```
"""
function closure(matrix::BitMatrix, itemset::Vector{Int})
        rows = vec(all(view(matrix,:, itemset), dims=2))
        return findall(vec(all(view(matrix, rows, :), dims=1)))
end