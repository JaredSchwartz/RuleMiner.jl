# FPClose

The `fpclose` function implements the FPClose (**F**requent **P**attern Close) algorithm for mining closed itemsets. This algorithm, proposed by Gösta Grahne and Jianfei Zhu in 2005, builds on the FP-Growth alogrithm to discover closed itemsets in a dataset without candidate generation.

```@docs
fpclose(txns::Transactions, min_support::Union{Int,Float64})
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

Algorithm Overview

1. The function starts by constructing an FP-tree from the transaction dataset.
2. It then recursively mines the FP-tree to find all candiadte closed itemsets.
3. Prune non-closed itemsets by checking for supersets with the same support.
4. The process continues until all frequent itemsets are discovered.

```julia
# Load transactions
txns = load_transactions("transactions.txt", ' ')

# Find frequent itemsets with minimum support of 5%
result = fpclose(txns, 0.05)
```