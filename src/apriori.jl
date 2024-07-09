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
    apriori(txns::Transactions, min_support::Union{Int,Float64}, max_length::Int)::DataFrame


Identify association rules in a transactional dataset `txns`, with minimum support, `min_support`, 
and maximum rule length, `max_length`.

When an Int value is supplied to min_support, apriori will use absolute support (count) of transactions as minimum support.

When a Float value is supplied, it will use relative support (percentage).
"""
function apriori(txns::Transactions, min_support::Union{Int,Float64}, max_length::Int)::DataFrame
    
    # Function to find siblings
    function siblings(items::AbstractArray{Int},value::Int,lineage::Vector{Int})
        return setdiff(items, vcat(lineage,value))
    end

    # Function to hash the rules to check uniqueness
    function rulehash(s::Arule)
        return hash(vcat([getfield(s, f) for f in fieldnames(typeof(s))]))
    end

    # Use multiple dispatch to handle item filtering based on count support or percentage support
    function filtersupport(num::AbstractArray{Int},support::Vector{Float64},min_support::Int)
        return findall(x -> x > min_support, num)
    end
    function filtersupport(num::AbstractArray{Int},support::Vector{Float64},min_support::Float64)
        return findall(x -> x > min_support, support)
    end

    # Find Base nodes
    baselen = size(txns.matrix, 1)
    basenum = vec(sum(txns.matrix, dims=1))
    basesupport = basenum ./ baselen

    items = filtersupport(basenum,basesupport,min_support)
    subtxns = txns.matrix[:,items]

    rules = Vector{Arule}()

    for (index, item) in enumerate(items)
        rule = Arule(
                Vector{String}(), # LHS
                txns.colkeys[item], # RHS
                basesupport[item], # Support
                basesupport[item], # Confidence (same as support on base nodes)
                1.0, # Coverage (1 on base nodes)
                1.0, # Lift (1 on base nodes)
                basenum[item], # N
                1, # Length
                Vector([index]), # Lineage
                siblings(1:length(items),index,Vector{Int}()) # Candidate Nodes
            )
        push!(rules,rule)
    end

    # Find Child nodes
    if max_length > 1
        parents = rules
        for level in 2:max_length

            # Create output array to prevent thread race conditions
            levelrules = Vector{Vector{Arule}}()
            for i in 1:Threads.nthreads()
                push!(levelrules,Arule[])
            end
            
            # Use multitheading to find child nodes
            @threads for parent in parents
                
                mask = vec(all(subtxns[:, parent.lin], dims=2))
                subtrans = subtxns[mask, :]

                subnum = vec(sum(subtrans, dims=1))
                subsupport = subnum ./ baselen

                subitems = filtersupport(subnum,subsupport,min_support)
                subitems = filter(x -> (x in parent.cand), subitems)
                for i in subitems
                    subrule = Arule(
                        getnames([items[i] for i in parent.lin],txns), # LHS
                        txns.colkeys[items[i]], # RHS
                        subsupport[i], # Support
                        subsupport[i] / parent.supp, # Confidence
                        parent.supp, # Coverage
                        (subsupport[i] / parent.supp) / basesupport[i], # Lift
                        subnum[i], # N
                        level, # length
                        sort(vcat(parent.lin, i)), # lineage
                        siblings(subitems, i, parent.lin) # Potential Next Nodes
                    )
                    push!(levelrules[Threads.threadid()],subrule)
                end
            end
            
            # Ensure rules are unique
            unique_dict = Dict{UInt64, RuleMiner.Arule}()
            for rule in vcat(levelrules...)
                rule_hash = rulehash(rule)
                unique_dict[rule_hash] = rule
            end
            unique_rules = collect(values(unique_dict))

            append!(rules,unique_rules)
            parents = unique_rules
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
    return rules
end