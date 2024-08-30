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


export Transactions, load_transactions, txns_to_df, Txns


abstract type Transactions end

"""
    Txns <: Transactions

A struct representing a collection of transactions in a sparse matrix format.

# Fields
- `matrix::SparseMatrixCSC{Bool,Int64}`: A sparse boolean matrix representing the transactions.
  Rows correspond to transactions, columns to items. A `true` value at position (i,j) 
  indicates that the item j is present in transaction i.
- `colkeys::Vector{String}`: A vector of item names corresponding to matrix columns.
- `linekeys::Vector{String}`: A vector of transaction identifiers corresponding to matrix rows.

# Description
The `Txns` struct provides an efficient representation of transaction data, 
particularly useful for large datasets in market basket analysis, association rule mining,
or similar applications where memory efficiency is crucial.

The sparse matrix representation allows for efficient storage and computation, 
especially when dealing with datasets where each transaction contains only a small 
subset of all possible items.

# Constructors
```julia
Txns(matrix::SparseMatrixCSC{Bool,Int64}, colkeys::Vector{String}, linekeys::Vector{String})
Txns(df::DataFrame, indexcol::Union{Symbol,Nothing}=nothing)
Txns(file::String, delimiter::Union{Char,String}; id_col::Bool = false, skiplines::Int = 0, nlines::Int = 0)
```

## DataFrame Constructor
The DataFrame constructor allows direct creation of a `Txns` object from a DataFrame:
- `df`: Input DataFrame where each row is a transaction and each column is an item.
- `indexcol`: Optional. Specifies a column to use as transaction identifiers. 
   If not provided, row numbers are used as identifiers.

## File Constructor
The file constructor allows creation of a `Txns` object directly from a file:
- `file`: Path to the input file containing transaction data.
- `delimiter`: Character or string used to separate items in each transaction.
Keyword Arguments:
- `id_col`: If true, treats the first item in each line as a transaction identifier.
- `skiplines`: Number of lines to skip at the beginning of the file (e.g., for headers).
- `nlines`: Maximum number of lines to read. If 0, reads the entire file.

# Examples
```julia
# Create from existing data
matrix = SparseMatrixCSC{Bool,Int64}(...)
colkeys = ["apple", "banana", "orange"]
linekeys = ["T001", "T002", "T003"]
txns = Txns(matrix, colkeys, linekeys)

# Create from DataFrame
df = DataFrame(
    ID = ["T1", "T2", "T3"],
    Apple = [1, 0, 1],
    Banana = [1, 1, 0],
    Orange = [0, 1, 1]
)
txns_from_df = Txns(df, indexcol=:ID)

# Create from file with character delimiter
txns_from_file_char = Txns("transactions.txt", ',', id_col=true, skiplines=1)

# Create from file with string delimiter
txns_from_file_string = Txns("transactions.txt", "||", id_col=true, skiplines=1)

# Access data
item_in_transaction = txns.matrix[2, 1]  # Check if item 1 is in transaction 2
item_name = txns.colkeys[1]              # Get the name of item 1
transaction_id = txns.linekeys[2]        # Get the ID of transaction 2
```
"""
struct Txns <: Transactions
    matrix::SparseMatrixCSC{Bool,Int64}
    colkeys::Vector{String}
    linekeys::Vector{String}

    # Original constructor
    function Txns(matrix::SparseMatrixCSC{Bool,Int64}, colkeys::Vector{String}, linekeys::Vector{String})
        @assert size(matrix, 2) == length(colkeys) "Number of columns in matrix must match length of colkeys"
        @assert size(matrix, 1) == length(linekeys) "Number of rows in matrix must match length of linekeys"
        new(matrix, colkeys, linekeys)
    end

    # Constructor from DataFrame
    function Txns(df::DataFrame, indexcol::Union{Symbol,Nothing}=nothing)
        df = copy(df)
        if !isnothing(indexcol)
            linekeys = string.(df[:, indexcol])
            select!(df, Not(indexcol))
        else
            linekeys = string.(1:nrow(df))
        end
        colkeys = string.(names(df))
        matrix = SparseMatrixCSC(Bool.(Matrix(df)))
        new(matrix, colkeys, linekeys)
    end

    # Constructor from file
    function Txns(file::String, delimiter::Union{Char,String}; id_col::Bool = false, skiplines::Int = 0, nlines::Int = 0)
        # Memory-map the file for efficient reading
        io = Mmap.mmap(file)

        # Estimate the number of lines and items for preallocation
        estimated_lines = count(==(UInt8('\n')), io) - skiplines
        estimated_items = count(x -> x in delimiter, io) + estimated_lines

        # Initialize data structures
        ItemKey = Dict{String, Int}()  # Maps items to their unique IDs
        RowKeys = String[]  # Stores transaction identifiers
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
            !id_col && push!(RowKeys, string(line_number))

            # Process each item in the line
            for (index, item) in enumerate(items)
                # If there's an ID column, use the first item as the row key
                if id_col && index == 1
                    push!(RowKeys, item)
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

        # Create a sorted vector of item names
        ColKeys = sort!(collect(keys(ItemKey)), by=k->ItemKey[k])

        # Return the Txns struct
        new(matrix, ColKeys, RowKeys)
    end
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
    getnames(indexes::Vector{Int}, txns::Transactions) -> Vector{String}

Retrieve the item names corresponding to the given indexes from a Transactions object.

# Arguments
- `indexes::Vector{Int}`: A vector of integer indices representing the positions of items in the transaction data.
- `txns::Transactions`: A Transactions object (such as Txns) containing the transaction data and item names.

# Returns
- `Vector{String}`: A vector of item names corresponding to the input indexes.

# Description
This function maps a set of integer indices to their corresponding item names in a Transactions object.
It's useful for translating the numeric representation of items (as used in the sparse matrix) back to
their original string names.

# Example
```julia
# Assume we have a Txns object 'txns' with items "apple", "banana", "orange" at indices 1, 2, 3
txns = Txns(...)  # Some Txns object

# Get names for items at indices 1 and 3
item_names = getnames([1, 3], txns)
println(item_names)  # Output: ["apple", "orange"]
```
"""
function getnames(indexes::Vector{Int}, txns::Transactions)
    return txns.colkeys[indexes]
end


"""
    txns_to_df(txns::Txns, id_col::Bool = false)::DataFrame

Convert a Txns object into a DataFrame.

# Arguments
- `txns::Txns`: The Txns object to be converted.
- `id_col::Bool = false`: (Optional) If true, includes an 'Index' column with transaction identifiers.

# Returns
- `DataFrame`: A DataFrame representation of the transactions.

# Description
This function converts a Txns object, which uses a sparse matrix representation,
into a DataFrame. Each row of the resulting DataFrame represents a transaction,
and each column represents an item.

The values in the DataFrame are integers, where 1 indicates the presence of an item
in a transaction, and 0 indicates its absence.

# Features
- Preserves the original item names as column names.
- Optionally includes an 'Index' column with the original transaction identifiers.

# Example
```julia
# Assuming 'txns' is a pre-existing Txns object
df = txns_to_df(txns, id_col=true)
```
"""
function txns_to_df(txns::Txns, id_col::Bool = false)::DataFrame
    df = DataFrame(Int.(Matrix(txns.matrix)), txns.colkeys)
    if id_col
        insertcols!(df, 1, :Index => txns.linekeys)
    end
    return df
end