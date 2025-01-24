#= seqtxns.jl
Transactions-type object which stores sequential transaction data
Licensed under the MIT license. See https://github.com/JaredSchwartz/RuleMiner.jl/blob/main/LICENSE
=#

"""
    SeqTxns <: Transactions

A struct representing a collection of transactions in a sparse matrix format, with support for sequence grouping.

# Fields
- `matrix::SparseMatrixCSC{Bool,Int64}`: A sparse boolean matrix representing the transactions.
  Rows correspond to transactions, columns to items. A `true` value at position (i,j) 
  indicates that the item j is present in transaction i.
- `colkeys::Vector{String}`: A vector of item names corresponding to matrix columns.
- `linekeys::Vector{String}`: A vector of transaction identifiers corresponding to matrix rows.
- `index::Vector{UInt32}`: A vector of indices indicating the start of each new sequence.
  The last sequence ends at the last row of the matrix.
- `n_transactions::Int`: The total number of transactions in the dataset.

# Description
The `SeqTxns` struct extends the concept of transaction data to include sequence information.
It provides an efficient representation for datasets where transactions are grouped into sequences,
such as time-series data or grouped purchasing behaviors. This structure is particularly useful
for sequential pattern mining and other sequence-aware data mining tasks.

The sparse matrix representation allows for efficient storage and computation, 
especially when dealing with datasets where each transaction contains only a small 
subset of all possible items.

# Constructors
## Default Constructor
```julia
SeqTxns(matrix::SparseMatrixCSC{Bool,Int64}, colkeys::Vector{String}, linekeys::Vector{String}, index::Vector{UInt32})
```

## DataFrame Constructor
```julia
SeqTxns(df::DataFrame, sequence_col::Symbol, index_col::Union{Symbol,Nothing}=nothing)
```
The DataFrame constructor allows direct creation of a `SeqTxns` object from a DataFrame:
- `df`: Input DataFrame where each row is a transaction and each column is an item.
- `sequence_col`: Specifies the column used to determine sequence groupings.
- `index_col`: Optional. Specifies a column to use as transaction identifiers. 
   If not provided, row numbers are used as identifiers.

## File Constructor
```julia
SeqTxns(file::String, item_delimiter::Union{Char,String}, set_delimiter::Union{Char,String}; id_col::Bool = false, skiplines::Int = 0, nlines::Int = 0)
```
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
sequence_starts = txns_seq.index             # Get the starting indices of each sequence
total_transactions = txns.n_transactions # Get the total number of transactions

# Get bounds of a specific sequence (e.g., second sequence)
seq_start = txns_seq.index[2]
seq_end = txns_seq.index[3] - 1  # Or length(txns_seq.linekeys) if it's the last sequence
```
"""
struct SeqTxns <: Transactions
    matrix::SparseMatrixCSC{Bool,UInt32}
    colkeys::Vector{String}
    linekeys::Vector{String}
    index::Vector{UInt32}
    n_transactions::Int

    # Constructor
    function SeqTxns(matrix::SparseMatrixCSC{Bool,UInt32}, colkeys::Vector{String}, linekeys::Vector{String}, index::Vector{UInt32})
        size(matrix, 2) == length(colkeys) || throw(ArgumentError("Number of columns in matrix ($(size(matrix, 2))) must match length of colkeys ($(length(colkeys)))"))
        
        (isempty(linekeys) || size(matrix, 1) == length(linekeys)) || throw(ArgumentError("Length of linekeys ($(length(linekeys))) must be 0 or match the number of rows in matrix ($(size(matrix, 1)))"))
        
        issorted(index) || throw(ArgumentError("index must be sorted"))
        
        first(index) == 1 || throw(DomainError(first(index), "First series must start at index 1"))
        
        last(index) <= size(matrix,1) || throw(DomainError(last(index), "Last series start must not exceed number of rows ($(size(matrix,1)))"))
        
        return new(matrix, colkeys, linekeys, index, size(matrix,1))
    end

    # Constructor from DataFrame
    function SeqTxns(df::DataFrame, sequence_col::Symbol, index_col::Union{Symbol,Nothing}=nothing)
        df = sort(df, sequence_col)
        
        # Handle Row Index column
        linekeys = String[]
        if !isnothing(index_col)
            linekeys = string.(df[:, index_col])
            select!(df, Not(index_col))  
        end

        # Handle Sequence Index column
        amts = combine(groupby(df, sequence_col), nrow => :count)[!,:count]
        rawindex = cumsum(amts).+1
        index = UInt32.(vcat([1],rawindex[1:end-1]))
        select!(df, Not(sequence_col))

        for col in names(df)
            try
                df = transform(df, col => ByRow(Bool) => col)
            catch e
                throw(DomainError("Column '$col' contains values that cannot be coerced to boolean."))
            end
        end

        colkeys = string.(names(df))
        matrix = SparseMatrixCSC((Matrix(df)))

        return new(matrix, colkeys, linekeys, index, size(matrix,1))
    end

    # Constructor from file
    function SeqTxns(
        file::String, 
        item_delimiter::Union{Char,String}, 
        set_delimiter::Union{Char,String};
        id_col::Bool = false, 
        skiplines::Int = 0, 
        nlines::Int = 0
    )
        skiplines >= 0 || throw(DomainError(skiplines, "skiplines must be a non-negative integer"))
        nlines >= 0 || throw(DomainError(nlines, "nlines must be a non-negative integer"))
    
        io = Mmap.mmap(file)
        
        est_lines, est_sets, est_items = RuleMiner.delimcounter(io, '\n', set_delimiter, item_delimiter)
        est_lines = est_lines + 1 - skiplines   # Est. lines is one more than num of line delims minus any skipped
        est_sets = est_sets + est_lines         # Line delims also act as set delims
        est_items = est_items + est_sets        # Set delims also act as item delims
    
        item_map = Dict{String, UInt32}()
        rowkeys = id_col ? Vector{String}(undef, est_sets) : String[]
        colvals = Vector{UInt32}(undef, est_items)
        rowvals = Vector{UInt32}(undef, est_items)
        index = Vector{UInt32}(undef, est_sets)
        index[1] = 1
    
        line_counter = 0
        set_counter = 0
        item_counter = 0
        item_id = 0
    
        for line in eachline(IOBuffer(io))
            skiplines > 0 && (skiplines -= 1; continue)     # Skip supplied number of lines at beginning
            nlines != 0 && line_counter >= nlines && break  # Break if we've reached the specified number of lines
            isempty(strip(line)) && continue                # Skip empty lines
            
            line_counter += 1
            for set in eachsplit(line, set_delimiter; keepempty=false)
                set_counter += 1
                for (index, item) in enumerate(eachsplit(set, item_delimiter; keepempty=false))
                    if id_col && index == 1
                        @inbounds rowkeys[set_counter] = item
                        continue
                    end
                    item_counter += 1

                    # avoided get!()do...end block because the closure causes serious performance issues
                    key = get(item_map, item, nothing)
                    if isnothing(key)
                        item_id += 1
                        key = item_id
                        item_map[item] = key
                    end
                    
                    @inbounds colvals[item_counter] = key
                    @inbounds rowvals[item_counter] = set_counter
                end
            end
            @inbounds index[line_counter + 1] = set_counter + 1
        end
    
        resize!(colvals, item_counter)
        resize!(rowvals, item_counter)
        resize!(index, line_counter)
        id_col && resize!(rowkeys, set_counter)

        n = item_id 
        m = set_counter
        colptr, rowval = RuleMiner.convert_csc!(colvals, rowvals, n)
        nzval = fill(true, item_counter)
        
        matrix = SparseMatrixCSC(m, n, colptr, rowval, nzval)
        colkeys = sort!(collect(keys(item_map)), by=k->item_map[k])
        
        return new(matrix, colkeys, rowkeys, index, m)
    end
end