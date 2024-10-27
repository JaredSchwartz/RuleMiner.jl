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

struct Arule
    lhs::Vector{Int}    # Vector containing the integer indices of the left-hand side of the rule
    rhs::Int            # Integer index of the right-hand side of the rule
    n::Int              # Count (n) value
    cov::Int            # Coverage (parent support) value
    conf::Float64       # Confidence (n / cov)
    lin::Vector{Int}    # Lineage of the rule (LHS union RHS)
    cand::Vector{Int}   # Candidate children rules
end

"""
    apriori(
        txns::Transactions,
        min_support::Union{Int,Float64},
        min_confidence::Float64=0.0,
        max_length::Int=0
    )::DataFrame

Identify association rules in a transactional dataset using the A Priori Algorithm

# Arguments
- `txns::Transactions`: A `Transactions` object containing the dataset to mine.
- `min_support::Union{Int,Float64}`: The minimum support threshold. If an `Int`, it represents 
  the absolute support. If a `Float64`, it represents relative support.
- `min_confidence::Float64`: The minimum confidence percentage for returned rules.
- `max_length::Int`: The maximum length of the rules to be generated. Length of 0 searches for all rules.

# Returns
A DataFrame containing the discovered association rules with the following columns:
- `LHS`: The left-hand side (antecedent) of the rule.
- `RHS`: The right-hand side (consequent) of the rule.
- `Support`: Relative support of the rule.
- `Confidence`: Confidence of the rule.
- `Coverage`: Coverage (RHS support) of the rule.
- `Lift`: Lift of the association rule.
- `N`: Absolute support of the association rule.
- `Length`: The number of items in the association rule.

# Description
The Apriori algorithm employs a breadth-first, level-wise search strategy to discover 
frequent itemsets. It starts by identifying frequent individual items and iteratively 
builds larger itemsets by combining smaller frequent itemsets. At each iteration, it 
generates candidate itemsets of size k from itemsets of size k-1, then prunes infrequent candidates and their subsets. 

The algorithm uses the downward closure property, which states that any subset of a frequent itemset must also be frequent. This is the defining pruning technique of A Priori.
Once all frequent itemsets up to the specified maximum length are found, the algorithm generates association rules and 
calculates their support, confidence, and other metrics.

# Examples
```julia
txns = Txns("transactions.txt", ' ')

# Find all rules with 5% min support and max length of 3
result = apriori(txns, 0.05, 0.0, 3)

# Find rules with with at least 5,000 instances and minimum confidence of 50%
result = apriori(txns, 5_000, 0.5)
```

# References
Agrawal, Rakesh, and Ramakrishnan Srikant. “Fast Algorithms for Mining Association Rules in Large Databases.” In Proceedings of the 20th International Conference on Very Large Data Bases, 487–99. VLDB ’94. San Francisco, CA, USA: Morgan Kaufmann Publishers Inc., 1994.
"""
function apriori(txns::Transactions, min_support::Union{Int,Float64}, min_confidence::Float64=0.0, max_length::Int=0)::DataFrame
    function rulehash(s::Arule)
        return hash(vcat([getfield(s, f) for f in fieldnames(typeof(s))]))
    end

    n_transactions = txns.n_transactions
    basenum = vec(count(txns.matrix, dims=1))
    min_support = min_support isa Float64 ? ceil(Int, min_support * n_transactions) : min_support

    subtxns, items = RuleMiner.prune_matrix(txns.matrix,min_support)
    rules = Vector{Arule}()

    initials = Vector{Arule}()
    for (index, item) in enumerate(items)
        rule = Arule(
            Int[],                             
            index,                             
            basenum[item],                     
            n_transactions,
            basenum[item] / n_transactions,
            [index],
            setdiff(1:length(items), index)
        )
        push!(initials, rule)
    end
    filter!((x -> (x.conf >= min_confidence)), initials)
    append!(rules, initials)

    function apriori!(rules, parents, k)
        if isempty(parents) || (max_length > 0 && k > max_length)
            return rules
        end

        levelrules = [Arule[] for _ in 1:nthreads()]

        @sync begin
            for parent in parents
                @spawn begin
                    mask = vec(all(view(subtxns,:, parent.lin), dims=2))
                    subtrans = subtxns[mask, :]

                    subnum = vec(count(subtrans, dims=1))
                    subitems = findall(subnum .>= min_support)
                    subitems = filter(x -> (x in parent.cand), subitems)
                    
                    for i in subitems
                        subrule = Arule(
                            parent.lin,
                            i,
                            subnum[i],
                            parent.n,
                            subnum[i] / parent.n,
                            sort(vcat(parent.lin, i)),
                            setdiff(subitems, vcat(i, parent.lin))
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
        new_parents = unique_rules
        filter!((x -> (x.conf >= min_confidence)), unique_rules)
        append!(rules, unique_rules)

        apriori!(rules, new_parents, k + 1)
    end

    apriori!(rules, initials, 2)

    df = DataFrame(
        LHS = [RuleMiner.getnames([items[i] for i in rule.lhs], txns) for rule in rules],
        RHS = [txns.colkeys[items[rule.rhs]] for rule in rules],
        Support = [rule.n / n_transactions for rule in rules],
        Confidence = [rule.conf for rule in rules],
        Coverage = [rule.cov / n_transactions for rule in rules],
        Lift = [(rule.n / n_transactions) / ((rule.cov / n_transactions) * (basenum[items[rule.rhs]] / n_transactions)) for rule in rules],
        N = [rule.n for rule in rules],
        Length = [length(rule.lin) for rule in rules]
    )
    return df
end