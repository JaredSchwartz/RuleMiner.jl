```@meta
CollapsedDocStrings = true
```

# API Reference

## Association Rule Mining
```@docs
apriori(txns::Transactions, min_support::Union{Int,Float64},min_confidence::Float64, max_length::Int)
```

## Itemset Mining

### Frequent Itemset Mining
```@docs
eclat(txns::Transactions, min_support::Union{Int,Float64})
```
```@docs
fpgrowth(txns::Transactions, min_support::Union{Int,Float64})
```

### Closed Itemset Mining
```@docs
charm(txns::Transactions, min_support::Union{Int,Float64})
```
```@docs
fpclose(txns::Transactions, min_support::Union{Int,Float64})
```
```@docs
   LCM(txns::Transactions, min_support::Union{Int,Float64})
```
```@docs
carpenter(txns::Transactions, min_support::Union{Int,Float64})
```

### Maximal Itemset Mining
```@docs
fpmax(txns::Transactions, min_support::Union{Int,Float64})
```
```@docs
genmax(txns::Transactions, min_support::Union{Int,Float64})
```

### Frequent Itemset Recovery
```@docs
recover_closed(df::DataFrame, min_n::Int)
```
```@docs
recover_maximal(df::DataFrame)
```

## Data Structures

### `Transactions` Objects
```@docs
    Txns
```

### FP Mining Objects

```@docs
    FPTree
```
```@docs
    FPNode
```

## Utility Functions
```@docs
txns_to_df(txns::Txns)
```