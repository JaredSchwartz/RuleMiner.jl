# apriori.jl
# Apriori rule mining in Julia
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

export apriori

struct Arule
    lhs::Vector{String} # Vector containing the string name(s) of the left-hand side of the rule
    rhs::String # String name of the right-hand side of the rule
    supp::Float64 # Support value
    conf::Float64 # Confidence Value
    cov::Float64 # Coverage Value
    lift::Float64 # Lift Value
    n::Int # Count (n) value
    len::Int # Length of the rule
    lin::Vector{Int} # Lineage of the rule (LHS union RHS)
    cand::Vector{Int} # Candidate children rules
end

"""
    apriori(txns::Transactions, minsup::Real, maxlen::Int; minconf::Union{Real,Nothing}=nothing)


Identify association rules in a transactional dataset `txns`, with minimum support, `minsup`, 
and maximum rule length, `maxlen`.

"""
function apriori(txns::Transactions, minsup::Real, maxlen::Int)::DataFrame
    
    function siblings(items::Vector{Int},value::Int)
        return filter(x -> x != value, items)
    end

    function GetNames(indexes)
        return getindex.(Ref(txns.colkeys), indexes)
    end

    baselen = size(txns.matrix)[1]
    basenum = vec(sum(txns.matrix, dims=1))
    basesupport = basenum / baselen

    items = findall(x -> x > minsup, basesupport)
    
    rules = Vector{Arule}()

    for item in items
        rule = Arule(
                Vector(String[]), # LHS
                txns.colkeys[item], # RHS
                basesupport[item], # Support
                basesupport[item], # Confidence (same as support on base nodes)
                1.0, # Coverage (1 on base nodes)
                1.0, # Lift (1 on base nodes)
                basenum[item], # N
                1, # Length
                Vector([item]), # Lineage
                siblings(items,item) # Potential Next Nodes
            )
        push!(rules,rule)
    end
    if maxlen > 1
        parents = rules
        for level in range(2,maxlen)
            levelrules = Vector{Arule}()
            for parent in parents
                
                mask = vec(all(txns.matrix[:, parent.lin] .!= 0, dims=2))
                subtrans = txns.matrix[mask, :]

                subnum = vec(sum(subtrans, dims=1))
                subsupport = subnum / baselen

                items = findall(x -> x > minsup, subsupport)
                items = filter(x -> (x in parent.cand), items)
                for item in items
                    rule = Arule(
                        GetNames(parent.lin), # LHS
                        txns.colkeys[item], # RHS
                        subsupport[item], # Support
                        subsupport[item]/parent.supp, # Confidence
                        parent.supp, # Coverage
                        (subsupport[item]/parent.supp)/basesupport[item], # Lift
                        subnum[item], # N
                        level, # length
                        sort(vcat(parent.lin,item)), # lineage
                        siblings(items,item) # Potential Next Nodes
                    )
                    push!(levelrules,rule)
                end
            end
            append!(rules,levelrules)
            parents = levelrules
        end
    end
    rules = DataFrame(
            LHS = [rule.lhs for rule in rules],
            RHS = [rule.rhs for rule in rules],
            Support = [rule.supp for rule in rules],
            Confidence = [rule.conf for rule in rules],
            Coverage = [rule.cov for rule in rules],
            Lift = [rule.lift for rule in rules],
            N = [rule.n for rule in rules],
            Length = [rule.len for rule in rules]
        )
    return unique(rules)
end