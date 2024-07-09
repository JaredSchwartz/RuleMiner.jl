# FP-Growth

The fpgrowth function implements the FP-Growth (**F**requent **P**attern Growth) algorithm for mining frequent itemsets. This algorithm, proposed by Han et al. in 2000, is an efficient method for discovering frequent itemsets in a dataset without candidate generation. It is generally more efficient than other algorithms when transactions have large numbers of items

```@docs
fpgrowth(txns::Transactions, min_support::Union{Int,Float64})
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
2. It then recursively mines the FP-tree to find all frequent itemsets.
3. The algorithm uses a divide-and-conquer approach, creating conditional FP-trees for each frequent item.
4. It traverses the tree in a bottom-up manner, combining frequent items to generate longer frequent itemsets.
5. The process continues until all frequent itemsets are discovered.

```julia
# Load transactions
txns = load_transactions("transactions.txt", ' ')

# Find frequent itemsets with minimum support of 5%
result = fpgrowth(txns, 0.05)
```