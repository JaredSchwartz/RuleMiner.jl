#= apriori.jl
Apriori rule mining in Julia
Licensed under the MIT license. See https://github.com/JaredSchwartz/RuleMiner.jl/blob/main/LICENSE
=#

struct Arule
    lhs::Vector{Int}    # Vector containing the integer indices of the left-hand side of the rule
    rhs::Int            # Integer index of the right-hand side of the rule
    n::Int              # Count (n) value
    cov::Int            # Coverage (parent support) value
    conf::Float64       # Confidence (n / cov)
    lin::Vector{Int}    # Lineage of the rule (LHS union RHS)
end

struct ThreadBuffers
    mask::BitVector         # BitVector buffer for filtering rows 
    lhs::Vector{Int}        # LHS buffer
    lineage::Vector{Int}    # Lineage buffer
    rules::Vector{Arule}    # Thread-local output buffer

    ThreadBuffers(n_rows::Int) = new(
        falses(n_rows),
        Vector{Int}(),
        Vector{Int}(),
        Vector{Arule}()
    )
end

# helper function to create the level one rules (k=1)
function create_level_one_rules(items, basenum, n_transactions, min_confidence)
    level_one = Set([i] for i in 1:length(items))
    level_rules = Vector{Arule}()
    sizehint!(level_rules, length(level_one))
    
    for lin in level_one
        index = first(lin)
        confidence = basenum[items[index]] / n_transactions
        
        confidence < min_confidence && continue
        
        rule = Arule(
            Int[],
            index,
            basenum[items[index]],
            n_transactions,
            confidence,
            collect(lin)
        )
        push!(level_rules, rule)
    end
    
    return level_rules, level_one
end

# helper function to generate all candidates at a given k value
function generate_candidates(current_level::Set{Vector{Int}}, k::Int, buffer_channel::Channel{ThreadBuffers}, candidate_channel::Channel{Set{Vector{Int}}})
    level_arr = collect(current_level)
    
    isempty(level_arr) && return Set{Vector{Int}}()
    
    @sync begin
        for i in 1:length(level_arr)
            Threads.@spawn begin
                # Take resources from channels
                buf = take!(buffer_channel)
                local_candidates = take!(candidate_channel)
                
                for j in (i+1):length(level_arr)
                    # Early skip for non-matching prefixes
                    if k > 2 && level_arr[i][1:k-2] != level_arr[j][1:k-2]
                        continue
                    end
                    
                    empty!(buf.lineage)
                    append!(buf.lineage, level_arr[i])
                    append!(buf.lineage, level_arr[j])
                    unique!(sort!(buf.lineage))
                    
                    length(buf.lineage) == k && push!(local_candidates, copy(buf.lineage))
                end
                
                # Return resources to channels
                put!(candidate_channel, local_candidates)
                put!(buffer_channel, buf)
            end
        end
    end
    
    # Combine all candidates
    candidates = Set{Vector{Int}}()
    
    # We don't want to close the channel as it will be reused
    # Instead, collect its current contents
    for _ in 1:nthreads()
        local_candidates = take!(candidate_channel)
        union!(candidates, local_candidates)
        # Return the empty set back to the channel for reuse
        put!(candidate_channel, Set{Vector{Int}}())
    end
    
    return candidates
end

# helper function to generate arules based on candidates at k
function process_candidate(lineage, subtxns, min_support, min_confidence, buf)
    # Clear previous results
    empty!(buf.rules)
    
    # Check support
    fill!(buf.mask, true)
    for item in lineage
        buf.mask .&= view(subtxns, :, item)
    end
    support = count(buf.mask)
    
    support < min_support && return
    
    # Process each item as RHS
    for i in 1:length(lineage)
        empty!(buf.lhs)
        append!(buf.lhs, lineage)
        deleteat!(buf.lhs, i)
        rhs = lineage[i]
        
        # Calculate confidence
        fill!(buf.mask, true)
        for item in buf.lhs
            buf.mask .&= view(subtxns, :, item)
        end
        coverage = count(buf.mask)
        confidence = support / coverage
        
        confidence < min_confidence && continue
        
        rule = Arule(
            copy(buf.lhs),
            rhs,
            support,
            coverage,
            confidence,
            copy(lineage)
        )
        push!(buf.rules, rule)
    end
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
    # Initial setup
    n_transactions = txns.n_transactions
    basenum = vec(count(txns.matrix, dims=1))
    min_support = min_support isa Float64 ? ceil(Int, min_support * n_transactions) : min_support
    
    subtxns, items = RuleMiner.prune_matrix(txns.matrix, min_support)
    n_rows = size(subtxns, 1)
    num_buffers = Threads.nthreads()
    
    # Create channel of thread buffers
    buffer_channel = Channel{ThreadBuffers}(num_buffers)
    for _ in 1:num_buffers
        put!(buffer_channel, ThreadBuffers(n_rows))
    end
    
    # Create channel for candidate chunks
    candidate_channel = Channel{Set{Vector{Int}}}(num_buffers)
    for _ in 1:num_buffers
        put!(candidate_channel, Set{Vector{Int}}())
    end
    
    # Process level one
    level_rules, current_level = create_level_one_rules(items, basenum, n_transactions, min_confidence)
    rules = copy(level_rules)
    
    # Main loop for level-wise processing
    k = 2
    while !isempty(current_level) && (max_length == 0 || k <= max_length)
        candidates = generate_candidates(current_level, k, buffer_channel, candidate_channel)
        isempty(candidates) && break
        
        # Channel for collecting rules from parallel tasks
        rules_channel = Channel{Vector{Arule}}(Inf)
        
        @sync begin
            for lineage in candidates
                Threads.@spawn begin
                    # Take a buffer from the channel
                    buf = take!(buffer_channel)
                    process_candidate(lineage, subtxns, min_support, min_confidence, buf)

                    # Send collected rules to the rules channel
                    if !isempty(buf.rules)
                        put!(rules_channel, copy(buf.rules))
                        empty!(buf.rules) # Clear for reuse
                    end
                    
                    put!(buffer_channel, buf)
                end
            end
        end
        
        # Collect all rules from the channel
        close(rules_channel)
        level_rules = Vector{Arule}()
        for rules_batch in rules_channel
            append!(level_rules, rules_batch)
        end
        append!(rules, level_rules)
        
        # Prepare for next level
        current_level = Set(rule.lin for rule in level_rules)
        k += 1
    end
    
    # Create the output DataFrame 
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