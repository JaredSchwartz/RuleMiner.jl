# Levelwise

The `levelwise` function implements a levelwise algorithm for mining closed itemsets proposed by Pasquier et al in 1999. This algorithm, generates all subsets of the closed itemsets, derives their supports, and then returns the results. This particular implementation is designed to take a result datafrom from the various closed itemset mining algorithms in this package as its input.


```@docs
levelwise(df::DataFrame, min_n::Int)
```

## Parameters

- `df::DataFrame`: A `DataFrame` DataFrame object with four columns:
    - `Itemset`: Vector of item names in the frequent itemset
    - `Support`: Relative support of the itemset
    - `N`: Absolute support count of the itemset
    - `Length`: Number of items in the itemset
- `min_support::Int`: The minimum support threshold for the rules. This algorithm only takes absolute (integer) support

## Output
A DataFrame object with three columns:
- `Itemset`: Vector of item names in the frequent itemset
- `N`: Absolute support count of the itemset
- `Length`: Number of items in the itemset

Algorithm Overview

1. The function starts by creating candidates from all subcombinations of the closed itemsets
2. It computes their supports by finding the smallest closed itemset that is a superset of the candiate
3. The algorithm loops thorugh, building larger combinations until there are no combinations left

```julia
# Load transactions
txns = load_transactions("transactions.txt", ' ')

# Find frequent itemsets with minimum support of 5%
result = fpclose(txns, 0.05)
```