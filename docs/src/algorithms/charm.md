# CHARM

The `charm` function implements the CHARM (**C**losed, **H**ash-based **A**ssociation **R**ule **M**ining) algorithm for mining closed itemsets proposed by Mohammad Zaki and Ching-Jui Hsiao in 2002. This algorithm uses a depth-first search with hash-based approaches to pruning non-closed itemsets and is particularly efficient for dense datasets.

```@docs
charm(txns::Transactions, min_support::Union{Int,Float64})
```

## Parameters

- `txns::Transactions`: A `Transactions` type object that contains the encoded transaction dataset as a sparse CSC matrix along with row and column name keys
- `min_support::Union{Int,Float64}`: The minimum support threshold for the rules. This can be specified as either:
    - An `Int` represents the absolute support (count) of transactions.
    - A `Float64` represents the relative support (percentage) of transactions.

## Output
A DataFrame object with four columns:
- `Itemset`: Vector of item names in the frequent itemset
- `Support`: Relative support of the itemset
- `N`: Absolute support count of the itemset
- `Length`: Number of items in the itemset

## Algorithm Overview

1. The function starts by initializing tidsets (transaction ID sets) for each item.
2. It then generates an ordered list of frequent items based on the minimum support threshold.
3. The algorithm uses a depth-first search strategy to explore the itemset lattice.
4. For each itemset, it checks if it's closed by comparing it with previously found closed itemsets.
5. The process continues recursively, building larger itemsets from smaller ones.

## Usage Example
```julia
# Load transactions
txns = load_transactions("transactions.txt", ' ')

# Find frequent itemsets with minimum support of 5%
result = charm(txns, 0.05)
```