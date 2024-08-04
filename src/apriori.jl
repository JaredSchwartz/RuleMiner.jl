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
    lhs::Vector{Int} # Vector containing the integer indices of the left-hand side of the rule
    rhs::Int # Integer index of the right-hand side of the rule
    n::Int # Count (n) value
    cov::Int # Coverage (parent support) value
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
    
    function siblings(items::AbstractArray{Int}, value::Int, lineage::Vector{Int})
        return setdiff(items, vcat(lineage, value))
    end

    function rulehash(s::Arule)
        return hash(vcat([getfield(s, f) for f in fieldnames(typeof(s))]))
    end

    baselen = size(txns.matrix, 1)
    basenum = vec(sum(txns.matrix, dims=1))
    min_support = min_support isa Float64 ? ceil(Int, min_support * baselen) : min_support

    items = findall(basenum .>= min_support)
    subtxns = txns.matrix[:, items]

    rules = Vector{Arule}()

    for (index, item) in enumerate(items)
        rule = Arule(
            Int[], # LHS
            index, # RHS
            basenum[item], # N
            baselen, # Coverage (baselen for base nodes)
            [index], # Lineage
            siblings(1:length(items), index, Int[]) # Candidate Nodes
        )
        push!(rules, rule)
    end

    if max_length > 1
        parents = rules
        for k in 2:max_length
            levelrules = [Arule[] for _ in 1:Threads.nthreads()]
            @sync begin
                for parent in parents
                    Threads.@spawn begin
                        mask = vec(all(subtxns[:, parent.lin], dims=2))
                        subtrans = subtxns[mask, :]

                        subnum = vec(sum(subtrans, dims=1))
                        subitems = findall(subnum .>= min_support)
                        subitems = filter(x -> (x in parent.cand), subitems)
                        
                        for i in subitems
                            subrule = Arule(
                                parent.lin, # LHS
                                i, # RHS
                                subnum[i], # N
                                parent.n, # Coverage (parent support)
                                sort(vcat(parent.lin, i)), # lineage
                                siblings(subitems, i, parent.lin) # Potential Next Nodes
                            )
                            push!(levelrules[Threads.threadid()], subrule)
                        end
                    end
                end
            end
            
            unique_dict = Dict{UInt64, Arule}()
            for rule in vcat(levelrules...)
                rule_hash = rulehash(rule)
                unique_dict[rule_hash] = rule
            end
            unique_rules = collect(values(unique_dict))

            append!(rules, unique_rules)
            parents = unique_rules
        end
    end

    # Convert rules to DataFrame and calculate metrics
    df = DataFrame(
        LHS = [getnames([items[i] for i in rule.lhs], txns) for rule in rules],
        RHS = [txns.colkeys[items[rule.rhs]] for rule in rules],
        Support = [rule.n / baselen for rule in rules],
        Confidence = [rule.n / rule.cov for rule in rules],
        Coverage = [rule.cov / baselen for rule in rules],
        Lift = [(rule.n / baselen) / ((rule.cov / baselen) * (basenum[items[rule.rhs]] / baselen)) for rule in rules],
        N = [rule.n for rule in rules],
        Length = [length(rule.lin) for rule in rules]
    )
    return df
end