# loader.jl
# Functions for creating a sparse transactional objects for efficient rule mining
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


export load_transactions


"""
    load_transactions(filepath::AbstractString, format::Symbol=:wide; sep::Union{String,Char}=',', indexcol::Union{Nothing,Integer}=nothing, skip::Integer=0)

Used for loading transactions from a transactional file.

- Use `:wide` format for basket-like transactions where each line is a transaction
"""
function load_transactions(filepath::AbstractString, format::Symbol=:wide; sep::Union{String,Char}=',', indexcol::Union{Nothing,Integer}=nothing, skip::Integer=0)

    if format == :wide
        # Read File
        data = readlines(filepath)
        data = data[skip+1:end]
        data = [split(item,sep) for item in data]
        
        # Prep Data Frame
        data = DataFrame( zip(1:length(data), data), [:line_idx, :col_val])
        if !isnothing(indexcol)
            data = transform(data,
                :col_val => ByRow(x -> x[indexcol]) => :line_val,
                :col_val => ByRow(x -> x[indexcol+1:end]) => :col_val
            )
        else
            data = transform(data, :line_idx => :line_val)
        end
        data = flatten(data, :col_val)
        data = transform(data,
            :col_val => denserank => :col_idx,
            :col_val => ByRow(string) => :col_val,
            :line_val =>  ByRow(string) => :line_val,
            )
        data = insertcols(data, :Values => true)

        # Get Matrix Dimensions
        m = maximum(data.line_idx)
        n = maximum(data.col_idx)

        # Construct Matrix
        matrix = SparseMatrixCOO(data.line_idx, data.col_idx, data.Values, m, n) |> SparseMatrixCSC

        # Construct Value Dicts
        Colkeys = Dict(zip(data.col_idx, data.col_val))
        LineKeys = Dict(zip(data.line_idx, data.line_val))

        return Transactions(matrix, Colkeys, LineKeys)
    end
end