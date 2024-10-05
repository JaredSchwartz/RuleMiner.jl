# datautils.jl
# Utility functions for creating and converting Transactions objects
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
function convert_csc!(column_values::Vector{UInt32}, row_values::Vector{UInt32}, n_cols::Integer)
    
    # Sort both arrays based on column values
    p = sortperm(column_values)
    permute!(column_values, p)
    permute!(row_values, p)
    
    # Initialize colptr
    colptr = zeros(UInt32, n_cols + 1)
    colptr[1] = 1
    
    # Fill colptr
    for col in column_values
        colptr[col + 1] += 1
    end
    
    # Convert counts to cumulative sum
    cumsum!(colptr, colptr)
    
    return colptr, row_values
end


"""
    delimcounter(io::Vector{UInt8}, items::Union{Char, String}...)::Vector{Int}

Count occurrences of delimiters in a byte array.

# Arguments
- `io::Vector{UInt8}`: The input byte array to search through.
- `items::Union{Char, String}...`: One or many delimiters to count. Can be characters or strings.

# Returns
- `Vector{Int}`: A vector of counts corresponding to each input delimiter, in the order they were provided.

# Description
This function efficiently counts the occurrences of multiple delimiters in a given byte array. 
It groups delimiters by length for optimized searching and makes n passes through the array where n is is the number of distinct delimiter lengths.

# Features
- Supports both character and string items.
- Handles overlapping occurrences by advancing the search position after each match.
- Groups items by length for more efficient searching.
- Uses direct byte comparisons for performance.

# Example
```julia
data = Vector{UInt8}("hello world")
counts = itemcounter(data, 'l', "o", "ll")
# Returns [3, 2, 1]
```
"""
function delimcounter(io::Vector{UInt8}, items::Union{Char, String}...)::Vector{Int}
    # Group items by length
    item_groups = Dict{Int, Vector{Vector{UInt8}}}()
    item_indices = Dict{Vector{UInt8}, Int}()

    for (index, item) in enumerate(items)
        bytes = item isa String ? Vector{UInt8}(item) : UInt8[item]
        push!(get!(item_groups, length(bytes), Vector{Vector{UInt8}}()), bytes)
        item_indices[bytes] = index
    end

    # Initialize result vector
    result = zeros(Int, length(items))

    # Iterate through grouped items
    for (item_length, group) in sort(collect(item_groups))
        i = 1
        while i <= length(io) - item_length + 1
            for target_bytes in group
                match = true
                for j in 1:item_length
                    if io[i+j-1] != target_bytes[j]
                        match = false
                        break
                    end
                end
                if match
                    result[item_indices[target_bytes]] += 1
                    i += item_length - 1
                    break
                end
            end
            i += 1
        end
    end

    return result
end

"""
    getends(txns::SeqTxns)::Vector{UInt}

Compute the end indices of each sequence in a `SeqTxns` object.

# Arguments
- `txns::SeqTxns`: A `SeqTxns` object representing sequential transactions.

# Returns
- `Vector{UInt}`: A vector of unsigned integers where each element represents the end index of a sequence.

# Description
This function calculates the end indices for each sequence in the given `SeqTxns` object. 
It uses the `index` field of `SeqTxns`, which stores the starting indices of each sequence, 
to compute where each transaction ends.

The function works as follows:
1. For all sequences except the last, the end index is one less than the start index of the next sequence.
2. For the last sequence, the end index is the total number of items (length of `linekeys`).

# Example
```julia
txns = SeqTxns(...)  # Assume we have a SeqTxns object
end_indices = getends(txns)
```
"""
function getends(txns::SeqTxns)::Vector{UInt32}
    n = length(txns.index)
    result = Vector{UInt32}(undef, n)
    result[1:end-1] .= view(txns.index, 2:n) .- 1
    result[end] = size(txns.matrix,1)
    
    return result
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
function getnames(indexes::Union{Vector{UInt32},Vector{Int}}, txns::Transactions)::Vector{String}
    return txns.colkeys[indexes]
end


"""
    txns_to_df(txns::Txns, id_col::Bool = false)::DataFrame

Convert a Txns object into a DataFrame.

# Arguments
- `txns::Txns`: The Txns object to be converted.

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
function txns_to_df(txns::Txns)::DataFrame
    df = DataFrame(Int.(Matrix(txns.matrix)), txns.colkeys)
    if !isempty(txns.linekeys)
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

# Description
This function converts a `SeqTxns` object, which uses a sparse matrix representation with sequence 
information, into a DataFrame. Each row of the resulting DataFrame represents a transaction, 
each column represents an item, and an additional column represents the sequence index.

The values in the item columns are integers, where 1 indicates the presence of an item
in a transaction, and 0 indicates its absence.

The 'SequenceIndex' column contains an integer for each row, indicating which sequence the 
transaction belongs to. Sequences are numbered starting from 1.

# Example
```julia
# Assuming 'txns_seq' is a pre-existing SeqTxns object
df = txns_to_df(txns_seq, id_col=true)

```
"""
function txns_to_df(txns::SeqTxns, index::Bool = true)::DataFrame
    # Convert matrix to DataFrame
    df = DataFrame(Int.(Matrix(txns.matrix)), txns.colkeys)
    
    if index
        # Add SequenceIndex column
        sequence_indices = Vector{Int}(undef, size(txns.matrix, 1))
        for (seq_idx, start_idx) in enumerate(txns.index)
            end_idx = seq_idx < length(txns.index) ? txns.index[seq_idx + 1] - 1 : size(txns.matrix, 1)
            sequence_indices[start_idx:end_idx] .= seq_idx
        end
        insertcols!(df, 1, :SequenceIndex => sequence_indices)
    end

    # Add Index column if requested
    if !isempty(txns.linekeys)
        insertcols!(df, 1, :Index => txns.linekeys)
    end
    
    return df
end