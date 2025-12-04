#= txns.jl
Functions for creating and working with sparse transaction objects
Licensed under the MIT license. See https://github.com/JaredSchwartz/RuleMiner.jl/blob/main/LICENSE
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
    matrix, colkeys, rowkeys, _ = parse_transaction_file(
            file, item_delimiter;
            set_delimiter = nothing,
            id_col = id_col,
            skiplines = skiplines,
            nlines = nlines
        )
        
        return new(matrix, colkeys, rowkeys, size(matrix, 1))
    end
end

#=== Indexing Functions ===#
Base.length(txns::Txns) =  txns.n_transactions
Base.lastindex(txns::Txns) = txns.n_transactions
Base.first(txns::Txns) = txns[1]
Base.first(txns::Txns, n::Integer) = [txns[i] for i in 1:min(n, txns.n_transactions)]
Base.last(txns::Txns) = txns[end]
Base.last(txns::Txns, n::Integer) = [txns[i] for i in max(1, txns.n_transactions-n+1):txns.n_transactions]

function Base.getindex(txns::Txns, i::Integer)
    1 <= i <= length(txns) || throw(BoundsError(txns, i))
    items = findall(@view txns.matrix[i, :])
    isempty(txns.linekeys) || return (id = txns.linekeys[i], items = txns.colkeys[items])
    return txns.colkeys[items]
end

function Base.getindex(txns::Txns, r::AbstractUnitRange{<:Integer})
    isempty(r) && return []
    1 <= first(r) && last(r) <= txns.n_transactions || throw(BoundsError(txns, r))
    return [txns[i] for i in r]
end

#=== Printing Functions ===#
Base.show(io::IO, txns::Txns) = show(io, MIME("text/plain"), txns)

function Base.show(io::IO, ::MIME"text/plain", txns::Txns)
    n_transactions, n_items = size(txns.matrix)
    n_nonzero = nnz(txns.matrix)
    
    println(io, "Txns with $n_transactions transactions, $n_items items, and $n_nonzero non-zero elements")

    # Terminal dimensions and display limits
    term_height, term_width = displaysize(io)
    max_rows = min(term_height - 6, n_transactions, 40)  # -6 for margins and headers
    max_rows < 1 && return

    # Select rows to display
    if n_transactions <= max_rows
        row_indices = 1:n_transactions
    else
        half_rows = div(max_rows - 1, 2)
        row_indices = [1:half_rows; (n_transactions - half_rows + 1):n_transactions]
    end

    # Calculate column widths
    indices = isempty(txns.linekeys) ? string.(row_indices) : txns.linekeys[row_indices]
    index_width = max(5, length("Index"), maximum(length, indices))
    available_width = max(20, term_width - index_width - 5)  # -5 for separators and padding

    # Build (and truncate) item strings
    item_strings = Vector{String}(undef, length(row_indices))
    for (i, row) in enumerate(row_indices)
        items = txns.colkeys[findall(txns.matrix[row, :])]
        isempty(items) && (item_strings[i] = ""; continue)
        
        str = join(items, ", ")
        if length(str) ≤ available_width - 1
            item_strings[i] = str
        else
            pos = findprev(',', str, available_width - 1)
            item_strings[i] = isnothing(pos) ? "…" : str[1:pos] * "…"
        end
    end

    # Create display matrix and add ellipsis if needed
    display_data = hcat(indices, item_strings)
    items_width = min(available_width, maximum(length, item_strings))
    if n_transactions > max_rows
        display_data = vcat(
            display_data[1:half_rows, :],
            ["⋮" "⋮"],
            display_data[half_rows+1:end, :]
        )
    end 

    format = TextTableFormat(;
        @text__no_horizontal_lines,
        vertical_line_at_beginning = false,
        vertical_line_after_data_columns = false,
        horizontal_line_after_column_labels = true,
    )

    # Display table using PrettyTables.jl 3.0 API
    pretty_table(
        io, 
        display_data;
        column_labels = ["Index","Items"],
        alignment = [:r,:l],
        table_format = format,
        fit_table_in_display_horizontally = false
    )
end
