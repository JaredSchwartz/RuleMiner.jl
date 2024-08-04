# Transactions Objects
## Transactions
```@docs
    Transactions
```
## load_transactions
```@docs
load_transactions(file::String, delimiter::Char; id_col::Bool = false, skiplines::Int = 0)
```

## txns\_to\_df
```@docs
txns_to_df(txns::Transactions; indexcol::Bool= false)
```