# LCM

The `LCM` function implements the LCM (**L**inear-time **C**losed **M**ier) algorithm for mining frequent closed itemsets first proposed by Uno et al. in 2004. This is an efficient method for discovering closed itemsets in a dataset with a linear time complexity.


```@docs
   LCM(txns::Transactions, min_support::Union{Int,Float64})
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

1. The function starts by identifying frequent items based on the minimum support threshold.
2. It then recursively explores the search space, using a depth-first approach.
3. For each itemset explored, it computes the closure (the largest superset with the same support).
4. The algorithm uses several pruning techniques to avoid generating non-closed or infrequent itemsets:
    - It skips itemsets whose closure has already been discovered.
    - It only extends itemsets with items that come after the current items in the frequency order.
    - It stops exploring when the support falls below the minimum threshold.
5. The process continues until all frequent closed itemsets are discovered.

## Usage Example
```julia
# Load transactions
txns = load_transactions("transactions.txt", ' ')

# Find frequent itemsets with minimum support of 5%
result = LCM(txns, 0.05)
```