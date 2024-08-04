# Transactions Objects
## Transactions
```Julia
struct Transactions
    matrix::SparseMatrixCSC{Bool,Int64}
    colkeys::Dict{Int,String} 
    linekeys::Dict{Int,String} 
end
```
The `Transactions` struct consists of three fields:
- `matrix`: Sparse matrix showing the locations of the items (columns) in the transactions(rows)
- `colkeys`: Dictionary mapping column indexes to their original values in the source
- `linekeys`: Dictionary mapping line indexes to their original values in the source (or generated index number)

## load_transactions
    Note: this reads basket-format data, not tabular data!


```@docs
load_transactions(file::String, delimiter::Char; id_col::Bool = false, skiplines::Int = 0)
```

Reads transaction data from a file basket-format file, where each line is a list of items, and returns a Transactions object.

    
Parameters:

- `file`: Path to the input file
- `delimiter`: Character used to separate items in each transaction
- `id_col`: Set to true if the first item in each line is a transaction identifier (default: false)
- `skiplines`: Number of header lines to skip (optional)
- `nlines`:Number of lines to read (optional)

Returns: 
- `Transactions`: A Transactions object with a sparse matrix representing the treansactions (rows) and items (columns) as well as dictionary keys for the names of the rows and columns


## txns\_to\_df
```@docs
txns_to_df(txns::Transactions; indexcol::Bool= false)
```
Parameters:
- `txns`: The `Transactions` object to be converted.
- `id_col`: If true, an additional 'Index' column is added to the DataFrame containing the values from the linekeys dictionary.

Returns
- `DataFrame`: A one-hot encoded DataFrame representation of the Transactions object.


Usage Examples

```julia
# Load transactions from a file
txns = load_transactions("transactions.txt", ' ', id_col=true, skiplines=1)

# Convert a DataFrame to Transactions
df = DataFrame(Index = [1,2,3], A=[1,0,1], B=[0,1,1], C=[1,1,0])

txns = transactions(df, indexcol=:Index)
```
