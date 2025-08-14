#= txn_utils.jl
Utility functions for creating and converting Transactions objects
Licensed under the MIT license. See https://github.com/JaredSchwartz/RuleMiner.jl/blob/main/LICENSE
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
function delimcounter(io::Vector{UInt8}, byte_patterns::Vector{UInt8}...)::Vector{Int}
    result = zeros(Int, length(byte_patterns) + 1)
    len = length(io)
    pattern_lengths = length.(byte_patterns)
    
    i = 1
    while i <= len
        # Count lines by looking for \n
        if io[i] == UInt8('\n')
            result[1] += 1
            i += 1
            continue
        end
        
        # Check each delimiter
        advanced = false
        idx = 1
        for pattern in byte_patterns
            if check_delim(io, i, pattern)
                result[idx + 1] += 1
                i += pattern_lengths[idx]
                advanced = true
                break
            end
            idx += 1
        end
        
        if !advanced
            i += 1
        end
    end
    
    return result
end

function check_delim(mmap_array::Vector{UInt8}, pos::Int, delim_bytes::Vector{UInt8})::Bool
    len = length(delim_bytes)
    (pos + len - 1) > length(mmap_array) && return false
    len == 1 && return @inbounds mmap_array[pos] == delim_bytes[1]
    
    @inbounds for i = 1:len
        mmap_array[pos + i - 1] != delim_bytes[i] && return false
    end
    
    return true
end

function check_newline(mmap_array, pos)
    pos > length(mmap_array) && return 0
    mmap_array[pos] == UInt8('\n') && return 1
    pos + 1 <= length(mmap_array) && 
    mmap_array[pos] == UInt8('\r') && 
    mmap_array[pos + 1] == UInt8('\n') && return 2
    return 0
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
    DataFrame(txns::Txns)::DataFrame

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
- Includes an 'Index' column with the original transaction identifiers if they exist.

# Example
```julia
# Assuming 'txns' is a pre-existing Txns object
df = DataFrame(txns)
```
"""
function DataFrames.DataFrame(txns::Txns)::DataFrame
    df = DataFrame(Int.(Matrix(txns.matrix)), txns.colkeys)
    if !isempty(txns.linekeys)
        insertcols!(df, 1, :Index => txns.linekeys)
    end
    return df
end

"""
    DataFrame(txns::SeqTxns; sequence_index::Bool = true)::DataFrame

Convert a `SeqTxns` object into a DataFrame, including sequence information.

# Arguments
- `txns::SeqTxns`: The `SeqTxns` object to be converted.

# Keyword Arguments
- `sequence_index::Bool = true`: If true, includes a 'SequenceIndex' column indicating 
  which sequence each transaction belongs to.

# Returns
- `DataFrame`: A DataFrame representation of the transactions with the following columns:
  - Item columns: One column for each item, with 1 indicating presence and 0 indicating absence.
  - 'SequenceIndex': A column indicating which sequence each transaction belongs to (if sequence_index=true).

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
df = DataFrame(txns_seq)                    # With sequence index
df_no_seq = DataFrame(txns_seq, sequence_index=false)  # Without sequence index
```
"""
function DataFrames.DataFrame(txns::SeqTxns; sequence_index::Bool = true)::DataFrame
    # Convert matrix to DataFrame
    df = DataFrame(Int.(Matrix(txns.matrix)), txns.colkeys)
    
    if sequence_index
        # Add SequenceIndex column
        sequence_indices = Vector{Int}(undef, size(txns.matrix, 1))
        for (seq_idx, start_idx) in enumerate(txns.index)
            end_idx = seq_idx < length(txns.index) ? txns.index[seq_idx + 1] - 1 : size(txns.matrix, 1)
            sequence_indices[start_idx:end_idx] .= seq_idx
        end
        insertcols!(df, 1, :SequenceIndex => sequence_indices)
    end
    
    return df
end

"""
    txns_to_df(txns::Txns)::DataFrame

Convert a Txns object into a DataFrame. 

!!! warning "Deprecated"
    `txns_to_df(txns)` is deprecated. Use `DataFrame(txns)` instead.
"""
function txns_to_df(txns::Txns)
    Base.depwarn("`txns_to_df(txns)` is deprecated, use `DataFrame(txns)` instead.", :txns_to_df)
    return DataFrame(txns)
end

"""
    txns_to_df(txns::SeqTxns, sequence_index::Bool = true)::DataFrame

Convert a SeqTxns object into a DataFrame.

!!! warning "Deprecated"
    `txns_to_df(txns, sequence_index)` is deprecated. Use `DataFrame(txns, sequence_index=sequence_index)` instead.
"""
function txns_to_df(txns::SeqTxns, sequence_index::Bool = true)
    if sequence_index
        Base.depwarn("`txns_to_df(txns, true)` is deprecated, use `DataFrame(txns)` instead.", :txns_to_df)
    else
        Base.depwarn("`txns_to_df(txns, false)` is deprecated, use `DataFrame(txns, sequence_index=false)` instead.", :txns_to_df)
    end
    return DataFrame(txns, sequence_index=sequence_index)
end

"""
    fast_convert(S::SubArray{Bool, 2, <:SparseMatrixCSC{Bool}}) -> BitMatrix

Efficiently convert a 2D sparse matrix view into a dense BitMatrix.

# Arguments
- `S::SubArray{Bool, 2, <:SparseMatrixCSC{Bool}}`: A view into a sparse boolean matrix,
   created using `view()` or array indexing on a SparseMatrixCSC.

# Returns
- `BitMatrix`: A dense binary matrix containing the same values as the input view.

# Description
This function provides an optimized conversion from a sparse matrix view to a BitMatrix by:
1. Directly accessing the underlying sparse matrix storage (colptr, rowval, nzval)
2. Only iterating over non-zero elements
3. Mapping parent matrix indices to view indices
4. Avoiding temporary matrix allocations

This is typically faster than the default conversion path, especially for large sparse
matrices where most elements are false.
# Example
```julia
using SparseArrays

# Create a sparse matrix
S = sparse([1 0 1; 1 1 0; 0 1 1])

# Create a view of the first two rows and columns
V = view(S, 1:2, 1:2)

# Convert to BitMatrix
B = fast_convert(V)
# Returns BitMatrix:
# 1 0
# 1 1
```
"""
function fast_convert(S::SubArray{Bool, 2, <:SparseMatrixCSC{Bool}})::BitMatrix
    parent_mat = parent(S)
    _, col_range = parentindices(S)
    
    m, n = size(S)
    B = falses(m, n)
    chunks = unsafe_wrap(Array{UInt64}, pointer(B.chunks), length(B.chunks))
    total_chunks = length(chunks)
    
    # Determine appropriate chunking for work with balanced size and count
    num_threads = nthreads(:default)
    min_items_per_chunk = 100
    target_chunk_count = num_threads * 4
    
    chunk_size = max(min_items_per_chunk, cld(total_chunks, target_chunk_count)) 
    chunk_counter = Atomic{Int}(1)
    
    @sync begin
        for _ in 1:num_threads
            @spawn begin
                while true
                    # Calculate next chunk range
                    chunk_start = atomic_add!(chunk_counter, chunk_size)
                    chunk_start > total_chunks && break

                    chunk_end = min(chunk_start + chunk_size - 1, total_chunks)
                    
                    # Calculate bit range this thread is responsible for
                    bit_start = (chunk_start - 1) << 6
                    bit_end = (chunk_end << 6) - 1
                    
                    # Calculate which columns intersect with this bit range
                    col_start = bit_start ÷ m + 1
                    col_end = min(bit_end ÷ m + 1, n)
                    
                    # Process each column that intersects with this thread's chunks
                    @inbounds for j in col_start:col_end
                        parent_col = col_range[j]
                        col_offset = (j - 1) * m
                        
                        # Process each nonzero in the column
                        for k in parent_mat.colptr[parent_col]:(parent_mat.colptr[parent_col+1]-1)
                            row = parent_mat.rowval[k]
                            abs_pos = col_offset + (row - 1)
                            
                            # Only process if this bit belongs to one of this thread's chunks
                            (abs_pos < bit_start || abs_pos > bit_end) && continue

                            chunk_idx = abs_pos >> 6
                            bit_pos = abs_pos & 63
                            chunks[chunk_idx + 1] |= UInt64(1) << bit_pos
                        end
                    end
                end
            end
        end
    end
    return B
end

"""
    prune_matrix(matrix::SparseMatrixCSC, min_support::Int) -> Tuple{BitMatrix, Vector{Int}}

Filter and sort sparse matrix columns based on minimum support threshold.

# Arguments
- `matrix::SparseMatrixCSC`: A sparse boolean matrix where rows represent transactions and columns
   represent items. A true value at position (i,j) indicates item j is present in transaction i.
- `min_support::Int`: The minimum absolute support threshold. Columns with fewer than this number
   of true values will be removed.

# Returns
A tuple containing:
- `BitMatrix`: A pruned view of the matrix containing only frequent columns, converted to a BitMatrix
- `Vector{Int}`: A vector of column indices corresponding to the frequent columns, sorted by their sums

# Description
This helper function performs two key preprocessing steps for frequent pattern mining:
1. Removes infrequent columns (pruning): Filters out columns whose sum is less than the minimum
   support threshold
2. Sorts columns by frequency: Reorders the remaining columns based on their sums in ascending order

The pruned matrix is returned as a BitMatrix for efficient boolean operations in pattern mining algorithms.

# Example
```julia
txns = Txns(sparse([1 1 0; 1 0 1; 0 1 1]), ["A", "B", "C"], ["I1", "I2", "I3"])
matrix, indices = prune_matrix(txns, 2)
```
"""
function prune_matrix(matrix::SparseMatrixCSC, min_support::Int)
    supports = sum(matrix, dims=1)
    sorted_items = [i for i in axes(matrix,2) if supports[1,i] >= min_support]
    sort!(sorted_items, by= x -> supports[1,x])
    
    matrix = view(matrix,:, sorted_items) |> fast_convert

    return matrix[vec(any(matrix, dims=2)), :], sorted_items
end