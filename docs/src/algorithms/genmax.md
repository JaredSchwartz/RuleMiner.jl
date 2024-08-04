# GenMax

The `genmax` function implements the GenMax algorithm for mining closed itemsets. This algorithm, proposed by Karam Gouda and Mohammad Zaki in 2005, utilizes a technique called progressive focusing to reduce the search space for maximal itemset mining.

```@docs
genmax(txns::Transactions, min_support::Union{Int,Float64})
```