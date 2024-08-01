# FPMax

The `fpmax` function implements the FPMax (**F**requent **P**attern Max) algorithm for mining closed itemsets. This algorithm, proposed by Gösta Grahne and Jianfei Zhu in 2005, builds on the FP-Growth alogrithm to discover maximal itemsets in a dataset.


```@docs
fpmax(txns::Transactions, min_support::Union{Int,Float64})
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
2. It then recursively mines the FP-tree to find all candidate maximal itemsets.
3. Prune all non-maximal itemsets by checking for supersets.

```julia
# Load transactions
txns = load_transactions("transactions.txt", ' ')

# Find frequent itemsets with minimum support of 5%
result = fpmax(txns, 0.05)
```