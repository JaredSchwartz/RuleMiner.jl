# transactions.jl
# Functions for creating and working with sparse transactional objects for efficient rule mining
#
# Copyright (c) 2024 Jared Schwartz
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


export Transactions, load_transactions, txns_to_df


"""
    Transactions

A struct representing a collection of transactions in a sparse matrix format.

# Fields
- `matrix::SparseMatrixCSC{Bool,Int64}`: A sparse boolean matrix representing the transactions.
  Rows correspond to transactions, columns to items. A `true` value at position (i,j) 
  indicates that the item j is present in transaction i.

- `colkeys::Dict{Int,String}`: A dictionary mapping column indices to item names.
  This allows retrieval of the original item names from the matrix column indices.

- `linekeys::Dict{Int,String}`: A dictionary mapping row indices to transaction identifiers.
  This can be used to map matrix rows back to their original transaction IDs or line numbers.

# Constructors
    Transactions(matrix::SparseMatrixCSC{Bool,Int64}, colkeys::Dict{Int,String}, linekeys::Dict{Int,String})

    Transactions(df::DataFrame, indexcol::Union{Symbol,Nothing}=nothing)

# Description
The `Transactions` struct provides an efficient representation of transaction data, 
particularly useful for large datasets in market basket analysis, association rule mining,
or similar applications where memory efficiency is crucial.

The sparse matrix representation allows for efficient storage and computation, 
especially when dealing with datasets where each transaction contains only a small 
subset of all possible items.

# DataFrame Constructor
The DataFrame constructor allows direct creation of a `Transactions` object from a DataFrame:
- `df`: Input DataFrame where each row is a transaction and each column is an item.
- `indexcol`: Optional. Specifies a column to use as transaction identifiers. 
   If not provided, row numbers are used as identifiers.
  
# Examples
```julia
# Create from existing data
matrix = SparseMatrixCSC{Bool,Int64}(...)
colkeys = Dict(1 => "apple", 2 => "banana", 3 => "orange")
linekeys = Dict(1 => "T001", 2 => "T002", 3 => "T003")
txns = Transactions(matrix, colkeys, linekeys)

# Create from DataFrame
df = DataFrame(
    ID = ["T1", "T2", "T3"],
    Apple = [1, 0, 1],
    Banana = [1, 1, 0],
    Orange = [0, 1, 1]
)
txns_from_df = Transactions(df, indexcol=:ID)

# Access data
item_in_transaction = txns.matrix[2, 1]  # Check if item 1 is in transaction 2
item_name = txns.colkeys[1]              # Get the name of item 1
transaction_id = txns.linekeys[2]
```
"""
struct Transactions
    matrix::SparseMatrixCSC{Bool,Int64} # Sparse matrix showing the locations of the items (columns) in the transactions(rows)
    colkeys::Dict{Int,String} # Dictionary mapping column indexes to their original values in the source
    linekeys::Dict{Int,String} # Dictionary mapping line indexes to their original values in the source (or generated index #)
    
    # Original constructor
    Transactions(matrix::SparseMatrixCSC{Bool,Int64}, colkeys::Dict{Int,String}, linekeys::Dict{Int,String}) = new(matrix, colkeys, linekeys)

    # Constructor from DataFrame
    function Transactions(df::DataFrame, indexcol::Union{Symbol,Nothing}=nothing)
        df = copy(df)
        if !isnothing(indexcol)
            linekeys = Dict(zip(1:length(df[:,indexcol]), string.(df[:,indexcol])))
            select!(df, Not(indexcol))
        else
            linekeys = Dict(zip(1:length(df[:,1]), string.(1:length(df[:,1]))))
        end
        colkeys = Dict(zip(1:length(names(df)), names(df)))
        matrix = Bool.(Matrix(df)) |> SparseMatrixCSC
        new(matrix, colkeys, linekeys)
    end
end

# Helper function to take indexes and return their column names
function getnames(indexes::Vector{Int},txns::Transactions)
    return getindex.(Ref(txns.colkeys), indexes)
end

"""
    load_transactions(file::String, delimiter::Char; id_col::Bool = false, skiplines::Int = 0, nlines::Int = 0)::Transactions

Load transaction data from a file and return a Transactions struct.

# Arguments
- `file::String`: Path to the input file containing transaction data.
- `delimiter::Char`: Character used to separate items in each transaction.

# Keyword Arguments
- `id_col::Bool = false`: If true, treats the first item in each line as a transaction identifier.
- `skiplines::Int = 0`: Number of lines to skip at the beginning of the file (e.g., for headers).
- `nlines::Int = 0`: Maximum number of lines to read. If 0, reads the entire file.

# Returns
- `Transactions`: A struct containing:
  - `matrix`: A sparse boolean matrix where rows represent transactions and columns represent items.
  - `colkeys`: A dictionary mapping column indices to item names.
  - `linekeys`: A dictionary mapping row indices to transaction identifiers.

# Description
This function reads transaction data from a file, where each line represents a transaction
and items are separated by the specified delimiter. It constructs a sparse matrix 
representation of the transactions, with rows as transactions and columns as unique items.

The function uses memory mapping to read the file and construct
the sparse matrix directly without materializing dense intermediate representations.

# Note
This function may not be suitable for extremely large files that exceed available system memory.

# Example
```julia
txns = load_transactions("transactions.txt", ',', id_col=true, skiplines=1)
```
"""
function load_transactions(file::String, delimiter::Char; id_col::Bool = false, skiplines::Int = 0, nlines::Int = 0)::Transactions
    # Memory-map the file for efficient reading
    io = Mmap.mmap(file)
    
    # Estimate the number of lines and items for preallocation
    estimated_lines = count(==(UInt8('\n')), io) - skiplines
    estimated_items = count(==(UInt8(delimiter)), io) + estimated_lines

    # Initialize data structures
    ItemKey = Dict{String, Int}()  # Maps items to their unique IDs
    RowKeys = Dict{Int, String}()  # Maps row numbers to their identifiers
    ColumnValues = Int[]  # Stores column indices for sparse matrix
    RowValues = Int[]     # Stores row indices for sparse matrix
    
    # Provide size hints to reduce reallocation
    sizehint!(ItemKey, div(estimated_items, 2))
    sizehint!(RowKeys, estimated_lines)
    sizehint!(ColumnValues, estimated_items)
    sizehint!(RowValues, estimated_items)
    
    # Initialize Loop Variables
    line_number = 1
    item_id = 1
    nlines = abs(nlines)
    
    
    for line in eachline(IOBuffer(io))
        # Skip lines if necessary
        skiplines > 0 && (skiplines -= 1; continue)

        # Break if we've reached the specified number of lines
        nlines != 0 && line_number > nlines && break

        # Split the line into items
        items = split(line, delimiter; keepempty=false)
        
        # If there's no ID column, use the line number as the row key
        !id_col && (RowKeys[line_number] = string(line_number))
        
        # Process each item in the line
        for (index, item) in enumerate(items)
            # If there's an ID column, use the first item as the row key
            if id_col && index == 1
                RowKeys[line_number] = item
                continue
            end
            
            # Assign a unique ID to each item if it doesn't have one
            if !haskey(ItemKey, item)
                ItemKey[item] = item_id
                item_id += 1
            end
            
            # Record the item's presence in this transaction
            push!(ColumnValues, ItemKey[item])
            push!(RowValues, line_number)
        end
        
        line_number += 1
    end

    # Create the sparse matrix
    n = length(ItemKey)  # Number of unique items
    m = line_number - 1  # Number of transactions
    colptr, rowval = convert_csc!(ColumnValues, RowValues, n)
    nzval = fill(true, length(ColumnValues))

    matrix = SparseMatrixCSC(m, n, colptr, rowval, nzval)
    
    # Create a reverse mapping of item IDs to items
    ColKeys = Dict(v => k for (k, v) in ItemKey)
    
    # Return the Txns struct
    return Transactions(matrix, ColKeys, RowKeys)
end

"""
    convert_csc!(column_values::Vector{Int}, row_values::Vector{Int}, n_cols::Int)::Tuple{Vector{Int}, Vector{Int}}

Convert COO (Coordinate) format sparse matrix data to CSC (Compressed Sparse Column) format.

# Arguments
- `column_values::Vector{Int}`: Vector of column indices in COO format.
- `row_values::Vector{Int}`: Vector of row indices in COO format.
- `n_cols::Int`: Number of columns in the matrix.

# Returns
- `Tuple{Vector{Int}, Vector{Int}}`: A tuple containing:
  - `colptr`: Column pointer array for CSC format.
  - `rowval`: Row indices array for CSC format.

# Description
This function takes sparse matrix data in COO format (column_values and row_values)
and converts it to CSC format. It sorts the input data by column indices and
computes the column pointer array required for CSC representation.

# Note
This function assumes that the input vectors are of equal length and contain valid indices.
The caller is responsible for ensuring this precondition.

# Example
```julia
colptr, rowval = convert_csc!([1,2,1,3], [1,2,3,1], 3)
```
"""
function convert_csc!(column_values, row_values, n_cols)
    
    # Sort both arrays based on column values
    p = sortperm(column_values)
    permute!(column_values, p)
    permute!(row_values, p)
    
    # Initialize colptr
    colptr = zeros(Int, n_cols + 1)
    colptr[1] = 1
    
    # Fill colptr
    for col in column_values
        colptr[col + 1] += 1
    end
    
    # Convert counts to cumulative sum
    cumsum!(colptr,colptr)
    
    return colptr, row_values
end


"""
    txns_to_df(txns::Transactions, id_col::Bool = false)::DataFrame

Convert a Transactions object into a DataFrame.

# Arguments
- `txns::Transactions`: The Transactions object to be converted.
- `id_col::Bool = false`: (Optional) If true, includes an 'Index' column with transaction identifiers.

# Returns
- `DataFrame`: A DataFrame representation of the transactions.

# Description
This function converts a Transactions object, which uses a sparse matrix representation,
into a DataFrame. Each row of the resulting DataFrame represents a transaction,
and each column represents an item.

The values in the DataFrame are integers, where 1 indicates the presence of an item
in a transaction, and 0 indicates its absence.

# Features
- Preserves the original item names as column names.
- Optionally includes an 'Index' column with the original transaction identifiers.

# Example
```julia
# Assuming 'txns' is a pre-existing Transactions object
df = txns_to_df(txns, id_col=true)
```
"""
function txns_to_df(txns::Transactions, id_col::Bool= false)::DataFrame
    df = DataFrame(Int.(Matrix(txns.matrix)),:auto)
    rename!(df,txns.colkeys)
    if id_col
        insertcols!(df, 1, :Index => [txns.linekeys[i] for i in 1:nrow(df)])
    end
    return df
end