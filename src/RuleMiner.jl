#= RuleMiner.jl
Pattern Mining in Julia
Licensed under the MIT license. See https://github.com/JaredSchwartz/RuleMiner.jl/blob/main/LICENSE
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
include("itemsets/itemset_utils.jl")

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