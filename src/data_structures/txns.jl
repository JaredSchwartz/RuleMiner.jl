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

"""
    Txns <: Transactions

A struct representing a collection of transactions in a sparse matrix format.

# Fields
- `matrix::SparseMatrixCSC{Bool,Int64}`: A sparse boolean matrix representing the transactions.
  Rows correspond to transactions, columns to items. A `true` value at position (i,j) 
  indicates that the item j is present in transaction i.
- `colkeys::Vector{String}`: A vector of item names corresponding to matrix columns.
- `linekeys::Vector{String}`: A vector of transaction identifiers corresponding to matrix rows.
- `n_transactions::Int`: The total number of transactions in the dataset.

# Description
The `Txns` struct provides an efficient representation of transaction data, 
particularly useful for large datasets in market basket analysis, association rule mining,
or similar applications where memory efficiency is crucial.

The sparse matrix representation allows for efficient storage and computation, 
especially when dealing with datasets where each transaction contains only a small 
subset of all possible items.

# Constructors
## Default Constructor
```julia
Txns(matrix::SparseMatrixCSC{Bool,Int64}, colkeys::Vector{String}, linekeys::Vector{String})
```
## DataFrame Constructor
```julia
Txns(df::DataFrame, indexcol::Union{Symbol,Nothing}=nothing)
```
The DataFrame constructor allows direct creation of a `Txns` object from a DataFrame:
- `df`: Input DataFrame where each row is a transaction and each column is an item.
- `indexcol`: Optional. Specifies a column to use as transaction identifiers. 
   If not provided, row numbers are used as identifiers.

## File Constructor
```julia
Txns(file::String, delimiter::Union{Char,String}; id_col::Bool = false, skiplines::Int = 0, nlines::Int = 0)
```
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
total_transactions = txns.n_transactions # Get the total number of transactions
```
"""
struct Txns <: Transactions
    matrix::SparseMatrixCSC{Bool,UInt32}
    colkeys::Vector{String}
    linekeys::Vector{String}
    n_transactions::Int

    # Original constructor
    function Txns(matrix::SparseMatrixCSC{Bool,UInt32}, colkeys::Vector{String}, linekeys::Vector{String})
        size(matrix, 2) == length(colkeys) || throw(ArgumentError("Number of columns in matrix ($(size(matrix, 2))) must match length of colkeys ($(length(colkeys)))"))
        
        (isempty(linekeys) || size(matrix, 1) == length(linekeys)) || throw(ArgumentError("Length of linekeys ($(length(linekeys))) must be 0 or match the number of rows in matrix ($(size(matrix, 1)))"))
        
        return new(matrix, colkeys, linekeys, size(matrix, 1))
    end

    # Constructor from DataFrame
    function Txns(df::DataFrame, index_col::Union{Symbol,Nothing}=nothing)
        df = copy(df)

        # Handle Row Index column
        linekeys = String[]
        if !isnothing(index_col)
            linekeys = string.(df[:, index_col])
            select!(df, Not(index_col))  
        end

        for col in names(df)
            try
                df = transform(df, col => ByRow(Bool) => col)
            catch e
                throw(DomainError("Column '$col' contains values that cannot be coerced to boolean."))
            end
        end

        colkeys = string.(names(df))
        matrix = SparseMatrixCSC((Matrix(df)))
        
        return new(matrix, colkeys, linekeys,size(matrix,1))
    end

    # Constructor from file
    function Txns(
        file::String, item_delimiter::Union{Char,String};
        id_col::Bool = false, skiplines::Int = 0, nlines::Int = 0,
    )
        skiplines >= 0 || throw(DomainError(skiplines, "skiplines must be a non-negative integer"))
        nlines >= 0 || throw(DomainError(nlines, "nlines must be a non-negative integer"))
    
        io = Mmap.mmap(file)

        est_lines, est_items = RuleMiner.delimcounter(io, '\n', item_delimiter)

        est_lines = est_lines + 1 - skiplines   # Est. lines is one more than num of line delims minus any skipped
        est_items = est_items + est_lines       # Line delims also act as item delims
    
        item_map = Dict{String, UInt32}()
        rowkeys = id_col ? Vector{String}(undef, est_lines) : String[]
        colvals = Vector{UInt32}(undef, est_items)
        rowvals = Vector{UInt32}(undef, est_items)
    
        line_counter = 0
        item_counter = 0
        item_id = 0

        for line in eachline(IOBuffer(io))
            skiplines > 0 && (skiplines -= 1; continue)     # Skip supplied number of lines at beginning
            nlines != 0 && line_counter >= nlines && break  # Break if we've reached the specified number of lines
            isempty(strip(line)) && continue                # Skip empty lines

            line_counter += 1            
            for (index, item) in enumerate(eachsplit(line, item_delimiter; keepempty=false))
                if id_col && index == 1
                    @inbounds rowkeys[line_counter] = item
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
                @inbounds rowvals[item_counter] = line_counter
            end
        end

        resize!(colvals, item_counter)
        resize!(rowvals, item_counter)

        n = item_id
        m = line_counter
        colptr, rowval = RuleMiner.convert_csc!(colvals, rowvals, n)
        nzval = fill(true, item_counter)

        matrix = SparseMatrixCSC(m, n, colptr, rowval, nzval)
        ColKeys = sort!(collect(keys(item_map)), by=k->item_map[k])

        return new(matrix, ColKeys, rowkeys, m)
    end
end