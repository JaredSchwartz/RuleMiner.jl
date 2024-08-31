# transactions.jl
# Functions for creating and working with sparse transactional objects for efficient rule mining
#=
Copyright (c) 2024 Jared Schwartz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
=#

export Transactions, load_transactions, txns_to_df, Txns, SeqTxns


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
    function Txns(file::String, item_delimiter::Union{Char,String}; id_col::Bool = false, skiplines::Int = 0, nlines::Int = 0)
        
        # Ensure skiplines and nlines are positive
        @assert skiplines >= 0 "skiplines must be a positive integer or zero"
        @assert nlines >= 0 "nlines must be a positive integer or zero"
        
        # Memory-map the file for efficient reading
        io = Mmap.mmap(file)

        # Estimate the number of lines and items for preallocation
        estimated_lines = count(==(UInt8('\n')), io) - skiplines
        estimated_items = count(x -> x in item_delimiter, io) + estimated_lines

        # Initialize data structures
        ItemKey = Dict{String, Int}()   # Maps items to their unique IDs
        RowKeys = String[]              # Stores transaction identifiers
        ColumnValues = Int[]            # Stores column indices for sparse matrix
        RowValues = Int[]               # Stores row indices for sparse matrix

        # Provide size hints to reduce reallocation
        sizehint!(ItemKey, div(estimated_items, 2))
        sizehint!(RowKeys, estimated_lines)
        sizehint!(ColumnValues, estimated_items)
        sizehint!(RowValues, estimated_items)

        # Initialize Loop Variables
        line_number = 1
        item_id = 1

        for line in eachline(IOBuffer(io))
            # Skip lines if necessary
            skiplines > 0 && (skiplines -= 1; continue)

            # Break if we've reached the specified number of lines
            nlines != 0 && line_number > nlines && break

            # Split the line into items
            items = split(line, item_delimiter; keepempty=false)

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
    SeqTxns <: Transactions

A struct representing a collection of transactions in a sparse matrix format, with support for sequence grouping.

# Fields
- `matrix::SparseMatrixCSC{Bool,Int64}`: A sparse boolean matrix representing the transactions.
  Rows correspond to transactions, columns to items. A `true` value at position (i,j) 
  indicates that the item j is present in transaction i.
- `colkeys::Vector{String}`: A vector of item names corresponding to matrix columns.
- `linekeys::Vector{String}`: A vector of transaction identifiers corresponding to matrix rows.
- `sequence_index::Vector{UInt32}`: A vector of indices indicating the start of each new sequence.
  The last sequence ends at the last row of the matrix.

# Constructors
```julia
SeqTxns(matrix::SparseMatrixCSC{Bool,Int64}, colkeys::Vector{String}, linekeys::Vector{String}, sequence_index::Vector{UInt32})
SeqTxns(df::DataFrame, sequence_col::Symbol, index_col::Union{Symbol,Nothing}=nothing)
SeqTxns(file::String, item_delimiter::Union{Char,String}, set_delimiter::Union{Char,String}; id_col::Bool = false, skiplines::Int = 0, nlines::Int = 0)
```

# Description
The `SeqTxns` struct extends the concept of transaction data to include sequence information.
It provides an efficient representation for datasets where transactions are grouped into sequences,
such as time-series data or grouped purchasing behaviors. This structure is particularly useful
for sequential pattern mining and other sequence-aware data mining tasks.

The sparse matrix representation allows for efficient storage and computation, 
especially when dealing with datasets where each transaction contains only a small 
subset of all possible items.

# DataFrame Constructor
The DataFrame constructor allows direct creation of a `SeqTxns` object from a DataFrame:
- `df`: Input DataFrame where each row is a transaction and each column is an item.
- `sequence_col`: Specifies the column used to determine sequence groupings.
- `index_col`: Optional. Specifies a column to use as transaction identifiers. 
   If not provided, row numbers are used as identifiers.

# File Constructor
The file constructor allows creation of a `SeqTxns` object directly from a file:
- `file`: Path to the input file containing transaction data.
- `item_delimiter`: Character or string used to separate items within a transaction.
- `set_delimiter`: Character or string used to separate transactions within a sequence.
Keyword Arguments:
- `id_col`: If true, treats the first item in each transaction as a transaction identifier.
- `skiplines`: Number of lines to skip at the beginning of the file (e.g., for headers).
- `nlines`: Maximum number of lines to read. If 0, reads the entire file.

# Examples
```julia
# Create from DataFrame
df = DataFrame(
    ID = ["T1", "T2", "T3", "T4", "T5", "T6"],
    Sequence = ["A", "A", "B", "B", "B", "C"],
    Apple = [1, 0, 1, 0, 1, 1],
    Banana = [1, 1, 0, 1, 0, 1],
    Orange = [0, 1, 1, 1, 0, 0]
)
txns_seq = SeqTxns(df, :Sequence, index_col=:ID)

# Create from file
txns_seq_file = SeqTxns("transactions.txt", ',', ';', id_col=true, skiplines=1)

# Access data
item_in_transaction = txns_seq.matrix[2, 1]  # Check if item 1 is in transaction 2
item_name = txns_seq.colkeys[1]              # Get the name of item 1
transaction_id = txns_seq.linekeys[2]        # Get the ID of transaction 2
sequence_starts = txns_seq.sequence_index    # Get the starting indices of each sequence

# Get bounds of a specific sequence (e.g., second sequence)
seq_start = txns_seq.sequence_index[2]
seq_end = txns_seq.sequence_index[3] - 1  # Or length(txns_seq.linekeys) if it's the last sequence
```
"""
struct SeqTxns <: Transactions
    matrix::SparseMatrixCSC{Bool,Int64}
    colkeys::Vector{String}
    linekeys::Vector{String}
    sequence_index::Vector{UInt}

    # Constructor
    function SeqTxns(matrix::SparseMatrixCSC{Bool,Int64}, colkeys::Vector{String}, linekeys::Vector{String}, sequence_index::Vector{UInt32})
        @assert size(matrix, 2) == length(colkeys) "Number of columns in matrix must match length of colkeys"
        @assert size(matrix, 1) == length(linekeys) "Number of rows in matrix must match length of linekeys"
        @assert issorted(sequence_index) "sequence_index must be sorted"
        @assert first(sequence_index) == 1 "First series must start at index 1"
        @assert last(sequence_index) <= length(linekeys) "Last series start must not exceed number of rows"
        return new(matrix, colkeys, linekeys, sequence_index)
    end

    # Constructor from DataFrame
    function SeqTxns(df::DataFrame, sequence_col::Symbol, index_col::Union{Symbol,Nothing}=nothing)
        df = sort(df, sequence_col)
        
        # Handle index column
        if !isnothing(index_col)
            linekeys = string.(df[:, index_col])
            select!(df, Not(index_col))
        else
            linekeys = string.(1:nrow(df))
        end

        # Extract sequence column and remove it from the DataFrame
        sequences = df[:, sequence_col]
        select!(df, Not(sequence_col))

        # Get column names (excluding sequence and index columns)
        colkeys = string.(names(df))

        # Create the sparse matrix
        matrix = SparseMatrixCSC(Bool.(Matrix(df)))

        # Create sequence_index
        sequence_index = UInt[1]  # First series always starts at 1
        for i in eachindex(sequences)[2:end]
            if sequences[i] != sequences[i-1]
                push!(sequence_index, i)
            end
        end

        return new(matrix, colkeys, linekeys, sequence_index)
    end

    # Constructor from file
    function SeqTxns(
        file::String, item_delimiter::Union{Char,String}, set_delimiter::Union{Char,String};
        id_col::Bool = false, skiplines::Int = 0, nlines::Int = 0
    )
        @assert skiplines >= 0 "skiplines must be a positive integer or zero"
        @assert nlines >= 0 "nlines must be a positive integer or zero"
        
        io = Mmap.mmap(file)
        
        # Estimate the number of lines, sequences and items for preallocation
        estimated_lines = count(==(UInt8('\n')), io) - skiplines
        estimated_sets = count(x -> x in set_delimiter, io) + estimated_lines
        estimated_items = count(x -> x in item_delimiter, io) + estimated_lines + estimated_sets
        
        # Initialize data structures
        itemkeys = Dict{String, Int}()  # Maps items to their unique IDs
        rowkeys = String[]              # Stores transaction identifiers
        colvals = Int[]                 # Stores column indices for sparse matrix
        rowvals = Int[]                 # Stores row indices for sparse matrix
        index = UInt[1]                 # Stores the start of each new sequence
    
        sizehint!(itemkeys, div(estimated_items, 2))
        sizehint!(rowkeys, estimated_sets)
        sizehint!(colvals, estimated_items)
        sizehint!(rowvals, estimated_items)
        sizehint!(index, estimated_lines)
        
        # Initialize Loop Variables
        line_number = 1
        set_number = 1
        item_id = 1
        
        for line in eachline(IOBuffer(io))
            # Skip lines if necessary
            skiplines > 0 && (skiplines -= 1; continue)
            
            # Break if we've reached the specified number of lines
            nlines != 0 && line_number > nlines && break
            
            # Split line into sets
            sets = split(line, set_delimiter; keepempty=false)
            
            for set in sets
                # Split the set into items
                items = split(set, item_delimiter; keepempty=false)
                
                # If there's no ID column, use the set number as the row key
                !id_col && push!(rowkeys, string(set_number))
                
                # Process each item in the set
                for (index, item) in enumerate(items)
                    # If there's an ID column, use the first item as the row key
                    if id_col && index == 1
                        push!(rowkeys, item)
                        continue
                    end
                    
                    # Assign a unique ID to each item if it doesn't have one
                    if !haskey(itemkeys, item)
                        itemkeys[item] = item_id
                        item_id += 1
                    end
                    
                    # Record the item's presence in this transaction
                    push!(colvals, itemkeys[item])
                    push!(rowvals, set_number)
                end
                set_number += 1
            end
            
            # Store the start index of the next sequence
            if line_number < estimated_lines
                push!(index, set_number)
            end
            
            line_number += 1
        end
        
        # Create the sparse matrix
        n = length(itemkeys)  # Number of unique items
        m = set_number - 1    # Number of transactions
        colptr, rowval = convert_csc!(colvals, rowvals, n)
        nzval = fill(true, length(colvals))
        
        matrix = SparseMatrixCSC(m, n, colptr, rowval, nzval)
        
        # Create a sorted vector of item names
        colkeys = sort!(collect(keys(itemkeys)), by=k->itemkeys[k])
        
        return new(matrix, colkeys, rowkeys, index)
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
    get_seq_bounds(txns::SeqTxns, seq_index::Int) -> Tuple{UInt32, UInt32}

Get the start and stop indices for a specific sequence in a `SeqTxns` object.

# Arguments
- `txns::SeqTxns`: The `SeqTxns` object containing the transaction data and sequence information.
- `seq_index::Int`: The index of the sequence for which to retrieve the bounds.

# Returns
A tuple `(start, stop)` where:
- `start::UInt32`: The index of the first transaction in the sequence.
- `stop::UInt32`: The index of the last transaction in the sequence.

# Description
This function calculates the boundaries (start and stop indices) of a specific sequence
within a `SeqTxns` object. It uses the `sequence_index` field of the `SeqTxns` struct
to determine where each sequence begins and ends.

For any sequence except the last, the stop index is calculated as the start index of the
next sequence minus one. For the last sequence, the stop index is the total number of
transactions in the `SeqTxns` object.

# Examples
```julia
txns = SeqTxns(...)  # Assume we have a SeqTxns object

# Get bounds of the second sequence
start, stop = get_seq_bounds(txns, 2)
println("Sequence 2 starts at index \$start and ends at index \$stop")

# Process all transactions in the third sequence
start, stop = get_seq_bounds(txns, 3)
for i in start:stop
    # Process transaction i
    # ...
end
```
"""
function get_seq_bounds(txns::SeqTxns, seq_index::Int)
    start = txns.series_starts[seq_index]
    stop = seq_index < length(txns.series_starts) ? txns.series_starts[seq_index + 1] - 1 : length(txns.linekeys)
    return (start, stop)
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


"""
    txns_to_df(txns::SeqTxns, id_col::Bool = false)::DataFrame

Convert a `SeqTxns` object into a DataFrame, including sequence information.

# Arguments
- `txns::SeqTxns`: The `SeqTxns` object to be converted.
- `id_col::Bool = false`: If true, includes an 'Index' column with transaction identifiers.

# Returns
- `DataFrame`: A DataFrame representation of the transactions with the following columns:
  - Item columns: One column for each item, with 1 indicating presence and 0 indicating absence.
  - 'SequenceIndex': A column indicating which sequence each transaction belongs to.
  - 'Index': (Optional) A column with transaction identifiers, if `id_col` is true.

# Description
This function converts a `SeqTxns` object, which uses a sparse matrix representation with sequence 
information, into a DataFrame. Each row of the resulting DataFrame represents a transaction, 
each column represents an item, and an additional column represents the sequence index.

The values in the item columns are integers, where 1 indicates the presence of an item
in a transaction, and 0 indicates its absence.

The 'SequenceIndex' column contains an integer for each row, indicating which sequence the 
transaction belongs to. Sequences are numbered starting from 1.

# Features
- Preserves the original item names as column names.
- Includes a 'SequenceIndex' column to maintain sequence grouping information.
- Optionally includes an 'Index' column with the original transaction identifiers.

# Example
```julia
# Assuming 'txns_seq' is a pre-existing SeqTxns object
df = txns_to_df(txns_seq, id_col=true)

```
"""
function txns_to_df(txns::SeqTxns, id_col::Bool = false, sequence_index::Bool = true)::DataFrame
    # Convert matrix to DataFrame
    df = DataFrame(Int.(Matrix(txns.matrix)), txns.colkeys)
    
    if sequence_index
        # Add SequenceIndex column
        sequence_indices = Vector{Int}(undef, size(txns.matrix, 1))
        for (seq_idx, start_idx) in enumerate(txns.sequence_index)
            end_idx = seq_idx < length(txns.sequence_index) ? txns.sequence_index[seq_idx + 1] - 1 : size(txns.matrix, 1)
            sequence_indices[start_idx:end_idx] .= seq_idx
        end
        insertcols!(df, 1, :SequenceIndex => sequence_indices)
    end

    # Add Index column if requested
    if id_col
        insertcols!(df, 1, :Index => txns.linekeys)
    end
    
    return df
end