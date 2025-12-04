#= file_parser.jl
State machine-based file parsing for transaction data
Licensed under the MIT license. See https://github.com/JaredSchwartz/RuleMiner.jl/blob/main/LICENSE
=#

"""
Parser states for transaction file reading.
"""
@enum ParserState begin
    SKIPPING_LINES      # Skipping header lines
    START_OF_LINE       # At the beginning of a line
    NULL_FIELD          # In a field but haven't seen non-whitespace yet
    IN_FIELD            # Currently reading a field with content
    AFTER_SET_DELIM     # Just processed a set delimiter (SeqTxns only)
    END_OF_LINE         # At line terminator
    END_OF_PARSING      # Cleanup at end of parsing
end

"""
    ParseContext

Mutable context for tracking parser state during file reading.
"""
mutable struct ParseContext
    # State
    state::ParserState
    position::Int

    # Counters
    line_counter::Int
    set_counter::Int
    item_counter::Int
    item_id::Int

    # Field tracking
    field_start::Int
    line_start_item::Int
    set_start_item::Int
    is_first_field::Bool

    # Configuration
    skiplines::Int
    nlines::Int
    has_id_column::Bool
    has_set_delimiter::Bool

    function ParseContext(;
        skiplines::Int = 0,
        nlines::Int = 0,
        has_id_column::Bool = false,
        has_set_delimiter::Bool = false
    )
        initial_state = skiplines > 0 ? SKIPPING_LINES : START_OF_LINE

        new(
            initial_state,  # state
            1,              # position
            0,              # line_counter (starts at 0, incremented at START_OF_LINE)
            0,              # set_counter
            0,              # item_counter
            0,              # item_id
            1,              # field_start
            0,              # line_start_item
            0,              # set_start_item
            true,           # is_first_field
            skiplines,      # skiplines
            nlines,         # nlines
            has_id_column,  # has_id_column
            has_set_delimiter  # has_set_delimiter
        )
    end
end

"""
    ParsedData

Container for parsed transaction data.
"""
mutable struct ParsedData
    # Storage arrays
    colvals::Vector{UInt32}
    rowvals::Vector{UInt32}
    colkey_views::Vector{SubArray{UInt8,1,Vector{UInt8},Tuple{UnitRange{Int64}},true}}
    rowkey_views::Vector{SubArray{UInt8,1,Vector{UInt8},Tuple{UnitRange{Int64}},true}}
    sequence_indices::Vector{UInt32}

    # Item mapping
    item_map::Dict{SubArray{UInt8,1,Vector{UInt8},Tuple{UnitRange{Int64}},true}, UInt32}

    function ParsedData(est_items::Int, est_lines::Int, has_id_col::Bool, has_sequences::Bool)
        KeyView = SubArray{UInt8,1,Vector{UInt8},Tuple{UnitRange{Int64}},true}

        colvals = Vector{UInt32}(undef, est_items)
        rowvals = Vector{UInt32}(undef, est_items)
        colkey_views = Vector{KeyView}()
        rowkey_views = has_id_col ? Vector{KeyView}(undef, est_lines) : Vector{KeyView}()
        sequence_indices = has_sequences ? Vector{UInt32}(undef, est_lines) : UInt32[]
        item_map = Dict{KeyView, UInt32}()

        return new(colvals, rowvals, colkey_views, rowkey_views, sequence_indices, item_map)
    end
end

"""
    start_new_line!(ctx::ParseContext, data::ParsedData)

Initialize counters and state for a new line.
"""
@inline function start_new_line!(ctx::ParseContext, data::ParsedData)
    # Increment line counter (optimistically - will decrement if empty)
    ctx.line_counter += 1

    # Handle sequence indices for SeqTxns
    if ctx.has_set_delimiter
        if ctx.line_counter <= length(data.sequence_indices)
            data.sequence_indices[ctx.line_counter] = ctx.set_counter + 1
        end
    end

    # Increment set counter for first set in line
    ctx.set_counter += 1

    # Track where this line/set starts in terms of items
    ctx.line_start_item = ctx.item_counter
    ctx.set_start_item = ctx.item_counter
    ctx.is_first_field = true
end

"""
    finalize_line!(ctx::ParseContext)

Finalize the current line, handling empty lines and set delimiters.
"""
@inline function finalize_line!(ctx::ParseContext)
    # Check if this line has any items
    items_in_line = ctx.item_counter - ctx.line_start_item
    items_in_set = ctx.item_counter - ctx.set_start_item

    # If we have set delimiters and ended with an empty set, decrement set_counter
    if ctx.has_set_delimiter && items_in_set == 0 && items_in_line > 0
        ctx.set_counter -= 1
    end

    # If we didn't add any items to this row, decrement the line counter back
    if items_in_line == 0
        ctx.line_counter -= 1
    end
end

"""
    end_field!(ctx::ParseContext, data::ParsedData, io, field_end::Int, delim_len::Int, next_state::ParserState)

Process the end of a field: extract field view, process it, update position, and transition to next state.
"""
@inline function finalize_field!(
    ctx::ParseContext,
    data::ParsedData,
    io,
    field_end::Int,
    delim_len::Int,
    next_state::ParserState
)
    field_view = @view io[ctx.field_start:field_end-1]
    process_field!(ctx, data, field_view)
    ctx.position = field_end + delim_len
    ctx.state = next_state
end

"""
    process_field!(ctx::ParseContext, data::ParsedData, field_view::SubArray)

Process a parsed field and update data structures.
"""
@inline function process_field!(
    ctx::ParseContext,
    data::ParsedData,
    field_view::SubArray
)
    # Handle ID column if this is the first field and ID column is expected
    if ctx.has_id_column && ctx.is_first_field
        if !isempty(data.rowkey_views) && ctx.line_counter <= length(data.rowkey_views)
            @inbounds data.rowkey_views[ctx.line_counter] = field_view
        end
        ctx.is_first_field = false
        return
    end

    # Mark that we've seen a non-ID field
    ctx.is_first_field = false
    ctx.item_counter += 1

    # Get or create item ID
    item_id = get(data.item_map, field_view, nothing)
    if isnothing(item_id)
        ctx.item_id += 1
        item_id = ctx.item_id
        data.item_map[field_view] = item_id
        push!(data.colkey_views, field_view)
    end

    # Store the item
    @inbounds data.colvals[ctx.item_counter] = item_id

    # Determine which row/set to assign this to
    if ctx.has_set_delimiter
        @inbounds data.rowvals[ctx.item_counter] = ctx.set_counter
    else
        @inbounds data.rowvals[ctx.item_counter] = ctx.line_counter
    end
end

"""
    parse_transaction_file(
        file::String,
        item_delimiter::Union{Char, String};
        set_delimiter::Union{Char, String, Nothing} = nothing,
        id_col::Bool = false,
        skiplines::Int = 0,
        nlines::Int = 0
    ) -> Tuple{SparseMatrixCSC, Vector{String}, Vector{String}, Vector{UInt32}}

Parse a transaction file using a state machine approach.

Returns: (matrix, colkeys, rowkeys, sequence_indices)
"""
function parse_transaction_file(
    file::String,
    item_delimiter::Union{Char, String};
    set_delimiter::Union{Char, String, Nothing} = nothing,
    id_col::Bool = false,
    skiplines::Int = 0,
    nlines::Int = 0
)
    skiplines >= 0 || throw(DomainError(skiplines, "skiplines must be a non-negative integer"))
    nlines >= 0 || throw(DomainError(nlines, "nlines must be a non-negative integer"))

    # Memory map the file
    io = Mmap.mmap(file)
    len = length(io)

    # Set up delimiters
    whitespace_bytes = UInt8.([' ', '\t', '\n', '\v', '\f', '\r'])
    item_delim_bytes = Vector{UInt8}(string(item_delimiter))
    set_delim_bytes = isnothing(set_delimiter) ? nothing : Vector{UInt8}(string(set_delimiter))
    has_sequences = !isnothing(set_delimiter)

    # Estimate storage requirements
    delim_args = has_sequences ?
        (set_delim_bytes, item_delim_bytes) :
        (item_delim_bytes,)

    counts = delimcounter(io, delim_args...)
    est_lines = counts[1] + 1 - skiplines

    if has_sequences
        est_sets, est_items = counts[2], counts[3]
        est_sets += est_lines
        est_items += est_sets
    else
        est_items = counts[2] + est_lines
    end

    # Initialize parsing context and data structures
    ctx = ParseContext(
        skiplines = skiplines,
        nlines = nlines,
        has_id_column = id_col,
        has_set_delimiter = has_sequences
    )

    data = ParsedData(est_items, est_lines, id_col, has_sequences)

    # Initialize sequence tracking
    if has_sequences && !isempty(data.sequence_indices)
        data.sequence_indices[1] = 1
    end

    # Main parsing loop
    while true
        # Check exit conditions
        if ctx.position > len
            ctx.state = END_OF_PARSING
        end

        if ctx.state == SKIPPING_LINES
            # Skip header lines
            newline_len = check_newline(io, ctx.position)
            if newline_len > 0
                ctx.skiplines -= 1
                ctx.position += newline_len
                if ctx.skiplines == 0
                    ctx.state = START_OF_LINE
                end
            else
                ctx.position += 1
            end

        elseif ctx.state == START_OF_LINE
            # Early exit if reached nlines limit
            if ctx.nlines != 0 && ctx.line_counter >= ctx.nlines
                ctx.state = END_OF_PARSING
                continue
            end

            start_new_line!(ctx, data)
            ctx.state = NULL_FIELD

        elseif ctx.state == NULL_FIELD
            if (newline_len = check_newline(io, ctx.position)) > 0
                # Empty field before newline - skip it
                ctx.position += newline_len
                ctx.state = END_OF_LINE

            elseif check_delim(io, ctx.position, item_delim_bytes)
                # Empty field before item delimiter - skip it
                ctx.position += length(item_delim_bytes)

            elseif !isnothing(set_delim_bytes) && check_delim(io, ctx.position, set_delim_bytes)
                # Empty field before set delimiter - skip it
                ctx.position += length(set_delim_bytes)
                ctx.state = AFTER_SET_DELIM

            elseif io[ctx.position] ∈ whitespace_bytes
                # Still whitespace - keep scanning
                ctx.position += 1

            else
                # Non-whitespace means actual field content
                ctx.field_start = ctx.position
                ctx.state = IN_FIELD
            end

        elseif ctx.state == IN_FIELD
            # Scan forward to find the end of the field
            field_end = ctx.position
            while true
                # Check for end of file
                if field_end > len
                    field_view = @view io[ctx.field_start:len]
                    process_field!(ctx, data, field_view)
                    ctx.state = END_OF_PARSING
                    ctx.position = len + 1
                    break

                # Check item delimiter first (most common)
                elseif check_delim(io, field_end, item_delim_bytes)
                    finalize_field!(ctx, data, io, field_end, length(item_delim_bytes), NULL_FIELD)
                    break

                # Check set delimiter
                elseif !isnothing(set_delim_bytes) && check_delim(io, field_end, set_delim_bytes)
                    finalize_field!(ctx, data, io, field_end, length(set_delim_bytes), AFTER_SET_DELIM)
                    break

                # Check newline
                elseif (newline_len = check_newline(io, field_end)) > 0
                    finalize_field!(ctx, data, io, field_end, newline_len, END_OF_LINE)
                    break
                end

                field_end += 1
            end

        elseif ctx.state == AFTER_SET_DELIM
            # Only create a new set if the current one had items
            items_in_set = ctx.item_counter - ctx.set_start_item
            if items_in_set > 0
                ctx.set_counter += 1
                ctx.set_start_item = ctx.item_counter
            end
            ctx.is_first_field = false
            ctx.state = NULL_FIELD

        elseif ctx.state == END_OF_LINE
            finalize_line!(ctx)
            ctx.state = START_OF_LINE

        elseif ctx.state == END_OF_PARSING
            finalize_line!(ctx)
            break
        end
    end

    # Finalize storage
    resize!(data.colvals, ctx.item_counter)
    resize!(data.rowvals, ctx.item_counter)

    if has_sequences
        resize!(data.sequence_indices, ctx.line_counter)
    end

    # Build sparse matrix
    n_cols = ctx.item_id
    n_rows = has_sequences ? ctx.set_counter : ctx.line_counter

    colptr, rowval = convert_csc!(data.colvals, data.rowvals, n_cols)
    nzval = fill(true, ctx.item_counter)
    matrix = SparseMatrixCSC(n_rows, n_cols, colptr, rowval, nzval)

    # Convert views to strings
    colkeys = unsafe_string.(pointer.(data.colkey_views), length.(data.colkey_views))
    rowkeys = unsafe_string.(pointer.(data.rowkey_views), length.(data.rowkey_views))

    return (matrix, colkeys, rowkeys, data.sequence_indices)
end