# RuleMiner.jl
# Pattern Mining in Julia
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

module RuleMiner

# Package Dependencies
using DataFrames
using Combinatorics
using PrettyTables

# Base and Standard Library Dependencies
using Mmap
using Base.Threads
using SparseArrays

#==============Transactions Objects==============#
abstract type Transactions end
include("data_structures/txns.jl")
include("data_structures/seqtxns.jl")
include("data_structures/txnutils.jl")

export Txns
export SeqTxns
export Transactions
export txns_to_df

#=================FPTree Objects=================#
include("data_structures/fpnode.jl")
include("data_structures/fptree.jl")
include("data_structures/fputils.jl")

export FPNode
export FPTree

#=============Association Rule Mining============#
include("association_rules/apriori.jl")

export apriori

#============Frequent Itemset Mining=============#
include("itemsets/frequent/eclat.jl")
include("itemsets/frequent/fpgrowth.jl")
include("itemsets/frequent/recovery.jl")

export eclat
export fpgrowth
export recover_closed
export recover_maximal

#=============Closed Itemset Mining==============#
include("itemsets/closed/charm.jl")
include("itemsets/closed/carpenter.jl")
include("itemsets/closed/lcm.jl")
include("itemsets/closed/fpclose.jl")

export charm
export carpenter
export LCM
export fpclose

#=============Maximal Itemset Mining=============#
include("itemsets/maximal/fpmax.jl")
include("itemsets/maximal/genmax.jl")

export fpmax
export genmax

end