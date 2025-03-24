#= seqtxns.jl
Transactions-type object which stores sequential transaction data
Licensed under the MIT license. See https://github.com/JaredSchwartz/RuleMiner.jl/blob/main/LICENSE
=#

"""
    SeqTxns <: Transactions

A struct representing a collection of transactions in a sparse matrix format, with support for sequence grouping.

# Fields
- `matrix::SparseMatrixCSC{Bool,UInt32}`: A sparse boolean matrix representing the transactions.
  Rows correspond to transactions, columns to items. A `true` value at position (i,j) 
  indicates that the item j is present in transaction i.
- `colkeys::Vector{String}`: A vector of item names corresponding to matrix columns.
- `index::Vector{UInt32}`: A vector of indices indicating the start of each new sequence.
  The last sequence ends at the last row of the matrix.
- `n_transactions::Int`: The total number of transactions in the dataset.
- `n_sequences::Int`: The total number of sequences in the dataset.

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
SeqTxns(matrix::SparseMatrixCSC{Bool,UInt32}, colkeys::Vector{String}, index::Vector{UInt32})
```

## DataFrame Constructor
```julia
SeqTxns(df::DataFrame, sequence_col::Symbol)
```
The DataFrame constructor allows direct creation of a `SeqTxns` object from a DataFrame:
- `df`: Input DataFrame where each row is a transaction and each column is an item.
- `sequence_col`: Specifies the column used to determine sequence groupings.

## File Constructor
```julia
SeqTxns(file::String, item_delimiter::Union{Char,String}, set_delimiter::Union{Char,String}; skiplines::Int = 0, nlines::Int = 0)
```
The file constructor allows creation of a `SeqTxns` object directly from a file:
- `file`: Path to the input file containing transaction data.
- `item_delimiter`: Character or string used to separate items within a transaction.
- `set_delimiter`: Character or string used to separate transactions within a sequence.
Keyword Arguments:
- `skiplines`: Number of lines to skip at the beginning of the file (e.g., for headers).
- `nlines`: Maximum number of lines to read. If 0, reads the entire file.

# Examples
```julia
# Create from DataFrame
df = DataFrame(
    Sequence = ["A", "A", "B", "B", "B", "C"],
    Apple = [1, 0, 1, 0, 1, 1],
    Banana = [1, 1, 0, 1, 0, 1],
    Orange = [0, 1, 1, 1, 0, 0]
)
txns_seq = SeqTxns(df, :Sequence)

# Create from file
txns_seq_file = SeqTxns("transactions.txt", ',', ';', skiplines=1)

# Access data
item_in_transaction = txns_seq.matrix[2, 1]  # Check if item 1 is in transaction 2
item_name = txns_seq.colkeys[1]              # Get the name of item 1
sequence_starts = txns_seq.index             # Get the starting indices of each sequence
total_transactions = txns_seq.n_transactions # Get the total number of transactions
total_sequences = txns_seq.n_sequences       # Get the total number of sequences

# Get bounds of a specific sequence (e.g., second sequence)
seq_start = txns_seq.index[2]
seq_end = seq_start < length(txns_seq.index) ? txns_seq.index[3] - 1 : txns_seq.n_transactions
```
"""
struct SeqTxns <: Transactions
    matrix::SparseMatrixCSC{Bool,UInt32}
    colkeys::Vector{String}
    index::Vector{UInt32}
    n_transactions::Int
    n_sequences::Int

    # Constructor
    function SeqTxns(matrix::SparseMatrixCSC{Bool,UInt32}, colkeys::Vector{String}, index::Vector{UInt32})
        size(matrix, 2) == length(colkeys) || throw(ArgumentError("Number of columns in matrix ($(size(matrix, 2))) must match length of colkeys ($(length(colkeys)))"))
        
        issorted(index) || throw(ArgumentError("index must be sorted"))
        
        first(index) == 1 || throw(DomainError(first(index), "First series must start at index 1"))
        
        last(index) <= size(matrix,1) || throw(DomainError(last(index), "Last series start must not exceed number of rows ($(size(matrix,1)))"))
        
        return new(matrix, colkeys, index, size(matrix,1), length(index))
    end

    # Constructor from DataFrame
    function SeqTxns(df::DataFrame, sequence_col::Symbol)
        df = sort(df, sequence_col)

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

        return new(matrix, colkeys, index, size(matrix,1), length(index))
    end

    # Constructor from file
    function SeqTxns(
        file::String, 
        item_delimiter::Union{Char,String}, 
        set_delimiter::Union{Char,String};
        skiplines::Int = 0, 
        nlines::Int = 0
    )
        skiplines >= 0 || throw(DomainError(skiplines, "skiplines must be a non-negative integer"))
        nlines >= 0 || throw(DomainError(nlines, "nlines must be a non-negative integer"))

        io = Mmap.mmap(file)
        whitespace_bytes = UInt8.([' ', '\t', '\n', '\v', '\f', '\r'])
        item_delim_bytes = Vector{UInt8}(string(item_delimiter))
        set_delim_bytes = Vector{UInt8}(string(set_delimiter))
        
        # Estimate lines, sets, and items from delimiter counts - preallocate arrays properly
        est_lines, est_sets, est_items = delimcounter(io, set_delim_bytes, item_delim_bytes)
        est_lines = est_lines + 1 - skiplines   # Est. lines is one more than num of line delims minus any skipped
        est_sets = est_sets + est_lines         # Line delims also act as set delims
        est_items = est_items + est_sets        # Set delims also act as item delims
        
        # Pre-allocate storage structures
        KeyView = SubArray{UInt8,1,Vector{UInt8},Tuple{UnitRange{Int64}},true}
        item_map = Dict{KeyView, UInt32}()
        colkey_views = Vector{KeyView}()
        colvals = Vector{UInt32}(undef, est_items)
        rowvals = Vector{UInt32}(undef, est_items)
        index = Vector{UInt32}(undef, est_lines)  # Sequence start indices
        
        len = length(io)
        word_start = 1
        line_counter = 1
        set_counter = 0
        item_counter = 0
        items_in_row = 0
        item_id = 0
        
        # Skip header lines if requested
        while skiplines > 0 && word_start <= len
            newline_len = check_newline(io, word_start)
            newline_len > 0 && (skiplines -= 1; word_start += newline_len; continue)
            word_start += 1
        end
        
        # First sequence always starts at position 1
        index[1] = 1
        
        # Main parsing loop
        while word_start <= len
            nlines != 0 && line_counter > nlines && break
            
            # Handle newline (starts a new sequence)
            newline_len = check_newline(io, word_start)
            if newline_len > 0
                if items_in_row > 0
                    nlines != 0 && line_counter == nlines && break
                    line_counter += 1
                    if line_counter <= length(index)
                        index[line_counter] = set_counter + 1
                    end
                end
                items_in_row = 0
                word_start += newline_len
                continue
            end
            
            # Find end of current field by scanning until delimiter/newline
            word_end = word_start
            has_content = false
            while word_end <= len
                if check_delim(io, word_end, item_delim_bytes) || 
                check_delim(io, word_end, set_delim_bytes) ||
                check_newline(io, word_end) > 0
                    break
                end
                io[word_end] ∈ whitespace_bytes || (has_content = true)
                word_end += 1
            end
            
            # Skip empty/whitespace-only fields
            if !has_content
                word_start = word_end
                if check_delim(io, word_end, item_delim_bytes)
                    word_start += length(item_delim_bytes)
                elseif check_delim(io, word_end, set_delim_bytes)
                    word_start += length(set_delim_bytes)
                end
                continue
            end
            
            # Handle set boundary - increment set counter when starting a new set
            if items_in_row == 0
                set_counter += 1
            end
            word_view = @view io[word_start:word_end-1]
            
            # Process regular field - dedup and store
            items_in_row += 1
            item_counter += 1
            
            # avoided get!()do...end block because the closure causes serious performance issues
            key = get(item_map, word_view, nothing)
            if isnothing(key)
                item_id += 1
                key = item_id
                item_map[word_view] = key
                push!(colkey_views, word_view)
            end
            
            @inbounds colvals[item_counter] = key
            @inbounds rowvals[item_counter] = set_counter
            
            word_start = word_end
            if check_delim(io, word_end, item_delim_bytes)
                word_start += length(item_delim_bytes)
            elseif check_delim(io, word_end, set_delim_bytes)
                word_start += length(set_delim_bytes)
                items_in_row = 0
            end
        end

        # Resize arrays to actual data size
        resize!(colvals, item_counter)
        resize!(rowvals, item_counter)
        resize!(index, line_counter)
        
        # Generate sparse matrix
        n = item_id
        m = set_counter
        colptr, rowval = RuleMiner.convert_csc!(colvals, rowvals, n)
        nzval = fill(true, item_counter)
        matrix = SparseMatrixCSC(m, n, colptr, rowval, nzval)
        
        # Convert views to strings
        colkeys = sort!(collect(keys(item_map)), by=k->item_map[k])
        colkeys = unsafe_string.(pointer.(colkeys), length.(colkeys))
        
        return new(matrix, colkeys, index, m, line_counter)
    end
end

#=== Indexing Functions ===#
Base.length(seqtxns::SeqTxns) = seqtxns.n_sequences
Base.lastindex(seqtxns::SeqTxns) = seqtxns.n_sequences
Base.first(seqtxns::SeqTxns) = seqtxns[1]
Base.first(seqtxns::SeqTxns, n::Integer) = [seqtxns[i] for i in 1:min(n, seqtxns.n_sequences)]
Base.last(seqtxns::SeqTxns) = seqtxns[end]
Base.last(seqtxns::SeqTxns, n::Integer) = [seqtxns[i] for i in max(1, seqtxns.n_sequences-n+1):seqtxns.n_sequences]

function Base.getindex(seqtxns::SeqTxns, i::Integer)
    1 <= i <= seqtxns.n_sequences || throw(BoundsError(seqtxns, i))
    
    # Get the start and end indices for the sequence
    start_idx = seqtxns.index[i]
    end_idx = i < seqtxns.n_sequences ? seqtxns.index[i+1] - 1 : seqtxns.n_transactions

    return [seqtxns.colkeys[vec(@view seqtxns.matrix[row_idx, :])] for row_idx in start_idx:end_idx]
end

function Base.getindex(seqtxns::SeqTxns, r::AbstractUnitRange{<:Integer})
    isempty(r) && return []
    1 <= first(r) && last(r) <= seqtxns.n_sequences || throw(BoundsError(seqtxns, r))
    return [seqtxns[i] for i in r]
end

#=== Printing Functions ===#
Base.show(io::IO, seqtxns::SeqTxns) = show(io, MIME("text/plain"), seqtxns)

function Base.show(io::IO, ::MIME"text/plain", seqtxns::SeqTxns)
    n_sequences = seqtxns.n_sequences
    n_transactions = seqtxns.n_transactions
    n_items = size(seqtxns.matrix, 2)
    n_nonzero = nnz(seqtxns.matrix)
    
    println(io, "SeqTxns with $n_sequences sequences, $n_transactions transactions, $n_items items, and $n_nonzero non-zero elements")

    # Terminal dimensions and display limits
    term_height, term_width = displaysize(io)
    max_rows = min(term_height - 6, n_transactions, 40)
    max_rows < 1 && return

    # Select transactions to display
    if n_transactions <= max_rows
        row_indices = 1:n_transactions
    else
        half_rows = div(max_rows - 1, 2)
        row_indices = [1:half_rows; (n_transactions - half_rows + 1):n_transactions]
    end

    # Find sequence and relative index for each displayed transaction
    seq_for_display = zeros(Int, length(row_indices))
    idx_in_seq = zeros(Int, length(row_indices))
    
    for (i, row) in enumerate(row_indices)
        seq_idx = searchsortedlast(seqtxns.index, row)
        seq_for_display[i] = seq_idx
        idx_in_seq[i] = row - seqtxns.index[seq_idx] + 1
    end

    # Calculate column widths
    seq_indices = seq_for_display
    seq_names = string.(seq_indices)
    
    seq_width = max(8, length("Sequence"), maximum(length, seq_names))
    idx_width = max(5, length("Transaction"))
    available_width = max(20, term_width - seq_width - idx_width - 5)

    # Build item strings
    item_strings = Vector{String}(undef, length(row_indices))
    max_item_length = 0
    for (i, row) in enumerate(row_indices)
        items = seqtxns.colkeys[findall(seqtxns.matrix[row, :])]
        isempty(items) && (item_strings[i] = ""; continue)
        
        str = join(items, ", ")
        if length(str) ≤ available_width - 1
            item_strings[i] = str
            max_item_length = max(max_item_length, length(str))
        else
            pos = findprev(',', str, available_width - 1)
            item_strings[i] = isnothing(pos) ? "…" : str[1:pos] * "…"
            max_item_length = max(max_item_length, length(item_strings[i]))
        end
    end
    
    # Adjust width based on content
    items_width = min(available_width, max(20, max_item_length))

    # Create display matrix
    display_data = Matrix{String}(undef, length(row_indices), 3)
    
    last_seq = 0
    for i in eachindex(row_indices)
        seq_idx = seq_for_display[i]
        tx_idx = idx_in_seq[i]
        
        # Only show sequence number on first transaction of a sequence
        if seq_idx != last_seq
            display_data[i, 1] = seq_names[i]
        else
            display_data[i, 1] = ""
        end
        
        display_data[i, 2] = string(tx_idx)
        display_data[i, 3] = item_strings[i]
        
        last_seq = seq_idx
    end
    
    # Add ellipsis row if needed
    if n_transactions > max_rows
        display_data = vcat(
            display_data[1:half_rows, :],
            reshape(["⋮", "⋮", "⋮"], 1, 3),
            display_data[(half_rows+1):end, :]
        )
    end

    # Display table
    tf = TextFormat(
        up_intersection='─',
        bottom_intersection='─',
        column='│',
        row='─',
        hlines=[:header]
    )

    pretty_table(io, display_data;
        header=["Sequence", "Transaction", "Items"],
        tf=tf,
        crop=:none,
        show_row_number=false,
        columns_width=[seq_width, idx_width, items_width],
        alignment=[:r, :l, :l],
        vlines=[1, 2]
    )
end