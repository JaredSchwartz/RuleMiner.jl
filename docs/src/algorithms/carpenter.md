# Carpenter

The `carpenter` function implements the CARPENTER (**C**losed **P**att**e**r**n** Discovery by **T**ransposing Tabl**e**s that a**r**e Extremely Long) algorithm for mining closed itemsets proposed by Pan et al. in 2003. This algorithm uses a transposed structure to optimize for datasets that have far more items than transactions, such as those found in genetic research and bioinformatics. It may not be the best choice if your data does not fit that format.

```@docs
carpenter(txns::Transactions, min_support::Union{Int,Float64})
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

1. Check if the current itemset has been discovered before (pruning 3)
2. Calculate the support of the current itemset
3. Remove infrequent itemsets (pruning 1)
4. Verify if the itemset is closed 
5. Find items that can be added without changing support (pruning 2)
6. Add closed frequent itemsets to the results
7. Recursively enumerate larger itemsets

```julia
# Load transactions
txns = load_transactions("transactions.txt", ' ')

# Find frequent itemsets with minimum support of 5%
result = carpenter(txns, 0.05)
```