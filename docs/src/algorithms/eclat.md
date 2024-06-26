# ECLAT

The `eclat` function implements the **E**quivalence **CLA**ss **T**ransformation algorithm for frequent itemset mining proposed by Mohammad Zaki in 2000. This algorithm identifies frequent itemsets in a dataset utilizing a column-first search and supplied minimum support.

## Function signature
```@docs
eclat(txns::Transactions, min_support::Union{Int,Float64})
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

1. The algorithm calculates support for individual items and keeps only items meeting the minimum support threshold.
2. It then orders the remaining items by their support (ascending).
3. Then it begins recursively build itemsets from the initial items. 
4. For each itemset, it adds one item at a time from the remaining sorted items, calculates the support, and if the support meets the threshold, it stores the itemset and continue building larger sets with it. If not, it stops exploring that branch and backtracks.

## Usage Example

```julia

# Load transactions
txns = load_transactions("transactions.txt", ' ')

# Find frequent itemsets with minimum support of 5%
result = eclat(txns, 0.05)
```