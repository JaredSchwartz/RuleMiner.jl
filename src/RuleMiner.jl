# RuleMiner.jl
# Asoociation Rule Mining in Julia
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

module RuleMiner

using DataFrames, LuxurySparse, StatsBase, Base.Threads

struct Transactions
    matrix::SparseMatrixCSC{Bool,Int64} # Sparse matrix showing the locations of the items (columns) in the transactions(rows)
    colkeys::Dict{Int,String} # Dictionary mapping column indexes to their original values in the source
    linekeys::Dict{Int,String} # Dictionary mapping line indexes to their original values in the source (or generated index #)
end

# Helper function to take indexes and return their column names
function getnames(indexes::Vector{Int},txns::Transactions)
    return getindex.(Ref(txns.colkeys), indexes)
end

include("loader.jl")
include("apriori.jl")
include("eclat.jl")
end