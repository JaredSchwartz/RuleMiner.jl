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


export Transactions, getnames, load_transactions, transactions


struct Transactions
    matrix::SparseMatrixCSC{Bool,Int64} # Sparse matrix showing the locations of the items (columns) in the transactions(rows)
    colkeys::Dict{Int,String} # Dictionary mapping column indexes to their original values in the source
    linekeys::Dict{Int,String} # Dictionary mapping line indexes to their original values in the source (or generated index #)
end

# Helper function to take indexes and return their column names
function getnames(indexes::Vector{Int},txns::Transactions)
    return getindex.(Ref(txns.colkeys), indexes)
end

"""
    load_transactions(file::String, delimiter::Char; id_col::Bool = false)::Transactions

Read transaction data from a `file`` where each line is a list of items separated by a given `delimiter`
If the first item of each list is a transaction identifier, set `id_col` to `true`
Specify the number header lines to skip with `skiplines`
"""
function load_transactions(file::String, delimiter::Char; id_col::Bool = false, skiplines::Int = 0)::Transactions

    io = Mmap.mmap(file)
    
    # Estimate the number of lines and items
    estimated_lines = count(==(UInt8('\n')), io) - abs(skiplines)
    estimated_items =  count(==(UInt8(delimiter)), io) + estimated_lines + 1

    # Initialize data structures
    ItemKey = Dict{String, Int}()
    RowKeys = Dict{Int, String}()
    RowValues = Vector{Int}(undef, estimated_items)
    ColumnValues = Vector{Int}(undef, estimated_items)
    
    sizehint!(ItemKey, estimated_items)
    sizehint!(RowKeys, estimated_lines)
    
    line_number = 1
    item_id = 1
    value_index = 1
    skipcounter = abs(skiplines)
    
    # Read File
    for line in eachline(IOBuffer(io))
        if skipcounter > 0
            skipcounter -=1
            continue
        end
        items = split(line, delimiter;keepempty=false)
        first_item = true
        if !id_col
            RowKeys[line_number] = string(line_number)
        end
        for item in items
            if (id_col * first_item)
                RowKeys[line_number] = item
            else
                if !haskey(ItemKey, item)
                    ItemKey[item] = item_id
                    item_id += 1
                end
                @inbounds ColumnValues[value_index] = ItemKey[item]
                @inbounds RowValues[value_index] = line_number
                value_index += 1
            end
            first_item = false
        end
        line_number += 1
    end

    # Trim excess capacity
    resize!(RowValues, value_index - 1)
    resize!(ColumnValues, value_index - 1)

    # Reverse item Dict
    ColKeys = Dict(value => key for (key, value) in ItemKey)

    # Get Matrix Dimensions
    m = length(RowKeys)
    n = length(ColKeys)

    # Construct Matrix
    matrix = SparseMatrixCOO(RowValues, ColumnValues, [true for i in ColumnValues], m, n) |> SparseMatrixCSC
    
    return Transactions(matrix,ColKeys,RowKeys)
end

"""
    transactions(df::DataFrame;indexcol::Union{Symbol,Nothing}=nothing)::Transactions

Converts a one-hot encoded `DataFrame` object into a `Transactions` object
Designate a column as an index column with `indexcol` 
"""
function transactions(df::DataFrame;indexcol::Union{Symbol,Nothing}=nothing)::Transactions
    df = copy(df)
    if !isnothing(indexcol)
        lineindex = Dict(zip(1:length(df[:,indexcol]),string.(df[:,indexcol])))
        select!(df,Not(indexcol))
    else
        lineindex = Dict(zip(1:length(df[:,1]),string.(1:length(df[:,1]))))
    end
    colindex = Dict(zip(1:length(names(df)),names(df)))

    matrix = Bool.(Matrix(df)) |> SparseMatrixCSC

    return Transactions(matrix,colindex,lineindex)
end