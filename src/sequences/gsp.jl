#= gsp.jl
GSP (Generalized Sequential Pattern) algorithm for sequential pattern mining in Julia
Licensed under the MIT license. See https://github.com/JaredSchwartz/RuleMiner.jl/blob/main/LICENSE
=#

struct SeqPattern
    pattern::Vector{Vector{String}}  # Vector of itemsets representing the sequential pattern
    support::Int                     # Absolute support count
end

struct SequenceBuffer
    itemsets::Vector{Vector{String}}    # Buffer for sequence itemsets
    pattern_items::Vector{String}       # Buffer for pattern items
    patterns::Vector{SeqPattern}        # Thread-local pattern results
    
    SequenceBuffer() = new(
        Vector{Vector{String}}(),
        Vector{String}(),
        Vector{SeqPattern}()
    )
end

"""
    gsp(seqtxns::SeqTxns, min_support::Union{Int,Float64})::DataFrame

Identify frequent sequential patterns in sequential transaction data using the GSP algorithm.

# Arguments
- `seqtxns::SeqTxns`: A `SeqTxns` object containing the sequential transaction dataset to mine.
- `min_support::Union{Int,Float64}`: The minimum support threshold. If an `Int`, it represents 
  the absolute support (number of sequences). If a `Float64`, it represents relative support.

# Returns
- `DataFrame`: A DataFrame containing the frequent sequential patterns, with columns:
  - `Pattern`: The sequential pattern as a vector of itemsets.
  - `Support`: The relative support of the pattern as a proportion of total sequences.
  - `N`: The absolute support count of the pattern (number of sequences containing it).
  - `Length`: The total number of items across all itemsets in the pattern.
  - `NumItemsets`: The number of itemsets in the pattern.

# Description
The GSP (Generalized Sequential Pattern) algorithm discovers frequent sequential patterns
in sequence databases. A sequential pattern is a sequence of itemsets that appears in
a sufficient number of data sequences with the same order.

The algorithm operates in multiple phases:

1. **Candidate Generation**: Generate candidate sequential patterns of length k from 
   frequent patterns of length k-1 using join and prune operations.

2. **Support Counting**: Count the support of each candidate pattern by scanning 
   the sequence database to find sequences that contain the pattern.

3. **Pruning**: Remove infrequent candidate patterns that don't meet the minimum 
   support threshold.

4. **Iteration**: Repeat until no more frequent patterns can be found.

Key features:
- Supports itemsets within sequence elements (generalized sequences)
- Uses efficient candidate generation with join and prune steps
- Employs parallel processing for support counting
- Handles complex sequential pattern matching

# Pattern Representation
Sequential patterns are represented as vectors of itemsets, where each itemset
is a vector of item names. For example:
- `[["A"], ["B", "C"]]` represents the pattern: A followed by (B and C together)
- `[["A", "B"], ["C"]]` represents the pattern: (A and B together) followed by C

# Example
```julia
# Load sequential transaction data
seqtxns = SeqTxns("sequential_data.txt", ',', ';')

# Find frequent sequential patterns with 10% minimum support
patterns = gsp(seqtxns, 0.1)

# Find patterns with absolute support of at least 5 sequences
patterns = gsp(seqtxns, 5)

# Display results
println("Found ", nrow(patterns), " frequent sequential patterns")
for row in eachrow(patterns)
    println("Pattern: ", row.Pattern, " Support: ", row.Support)
end
```

# References
Srikant, Ramakrishnan, and Rakesh Agrawal. "Mining Sequential Patterns: Generalizations and Performance Improvements." 
In Advances in Database Technology — EDBT '96, edited by Peter M. G. Apers, Mokrane Bouzeghoub, and Georges Gardarin, 
1–17. Berlin, Heidelberg: Springer, 1996. https://doi.org/10.1007/BFb0014140.
"""
function gsp(seqtxns::SeqTxns, min_support::Union{Int,Float64})::DataFrame
    # Initial setup
    n_sequences = seqtxns.n_sequences
    min_support = clean_support(min_support, n_sequences)
    
    # Set up processing channels
    num_buffers = nthreads(:default)
    buffer_channel = Channel{SequenceBuffer}(num_buffers)
    for _ in 1:num_buffers
        put!(buffer_channel, SequenceBuffer())
    end
    
    # Find frequent 1-patterns (single items)
    current_patterns, all_patterns = find_L1_patterns(seqtxns, min_support)
    
    k = 2
    while !isempty(current_patterns)
        # Generate candidate k-patterns
        candidates = generate_k_candidates(current_patterns, k)
        isempty(candidates) && break
        
        # Results collection channel
        patterns_channel = Channel{Vector{SeqPattern}}(Inf)
        
        # Process candidates in parallel
        @sync begin
            for candidate in candidates
                @spawn begin
                    buf = take!(buffer_channel)
                    count_pattern_support(candidate, seqtxns, min_support, buf)
                    
                    if !isempty(buf.patterns)
                        put!(patterns_channel, copy(buf.patterns))
                        empty!(buf.patterns)
                    end
                    
                    put!(buffer_channel, buf)
                end
            end
        end
        
        close(patterns_channel)
        level_patterns = vcat(patterns_channel...)
        append!(all_patterns, level_patterns)
        
        # Set up for next level
        current_patterns = [p.pattern for p in level_patterns]
        k += 1
    end
    
    # Create output DataFrame
    df = DataFrame(
        Pattern = [p.pattern for p in all_patterns],
        Support = [p.support / n_sequences for p in all_patterns],
        N = [p.support for p in all_patterns],
        Length = [sum(length(itemset) for itemset in p.pattern) for p in all_patterns],
        NumItemsets = [length(p.pattern) for p in all_patterns]
    )
    
    sort!(df, [:N, :Length], rev = [true, false])
    return df
end

# Helper function to find frequent 1-patterns
function find_L1_patterns(seqtxns::SeqTxns, min_support::Int)
    item_counts = Dict{String, Int}()
    
    # Count item occurrences across sequences
    for seq_idx in 1:seqtxns.n_sequences
        start_idx = seqtxns.index[seq_idx]
        end_idx = seq_idx < seqtxns.n_sequences ? seqtxns.index[seq_idx + 1] - 1 : seqtxns.n_transactions
        
        sequence_items = Set{String}()
        for txn_idx in start_idx:end_idx
            items = seqtxns.colkeys[findall(seqtxns.matrix[txn_idx, :])]
            union!(sequence_items, items)
        end
        
        for item in sequence_items
            item_counts[item] = get(item_counts, item, 0) + 1
        end
    end
    
    # Create frequent 1-patterns
    patterns_1 = Vector{Vector{Vector{String}}}()
    all_patterns = Vector{SeqPattern}()
    
    for (item, count) in item_counts
        if count >= min_support
            pattern = [[item]]
            push!(patterns_1, pattern)
            push!(all_patterns, SeqPattern(pattern, count))
        end
    end
    
    return patterns_1, all_patterns
end

# Helper function to generate candidate k-patterns
function generate_k_candidates(frequent_patterns::Vector{Vector{Vector{String}}}, k::Int)
    candidates = Set{Vector{Vector{String}}}()
    
    for i in 1:length(frequent_patterns)
        for j in 1:length(frequent_patterns)
            i == j && continue
            
            pattern1, pattern2 = frequent_patterns[i], frequent_patterns[j]
            
            if k == 2
                # Generate 2-candidates: sequential and simultaneous patterns
                item1, item2 = pattern1[1][1], pattern2[1][1]
                
                # Sequential pattern
                push!(candidates, [[item1], [item2]])
                
                # Simultaneous pattern (avoid duplicates)
                if item1 < item2
                    push!(candidates, [sort([item1, item2])])
                end
            else
                # Generate k-candidates using join operation
                candidate = nothing
                
                # Check if patterns can be joined
                if length(pattern1) == length(pattern2)
                    # Check prefix match for join
                    if length(pattern1) > 1 && pattern1[1:end-1] == pattern2[1:end-1]
                        last1, last2 = Set(pattern1[end]), Set(pattern2[end])
                        if last1 != last2
                            # Sequential join
                            candidate = vcat(pattern1, [pattern2[end]])
                        end
                    elseif length(pattern1) == 1
                        # Join single-itemset patterns
                        candidate = [pattern1[1], pattern2[1]]
                    end
                end
                
                # Add valid candidate and check if all subsequences are frequent
                if !isnothing(candidate) && has_frequent_subsequences(candidate, frequent_patterns)
                    push!(candidates, candidate)
                end
            end
        end
    end
    
    return collect(candidates)
end

# Helper function to check if all subsequences of a candidate are frequent
function has_frequent_subsequences(candidate::Vector{Vector{String}}, frequent_patterns::Vector{Vector{Vector{String}}})
    frequent_set = Set(frequent_patterns)
    
    # Check removal of each itemset
    for i in 1:length(candidate)
        if length(candidate) > 1
            subseq = [candidate[j] for j in 1:length(candidate) if j != i]
            subseq ∉ frequent_set && return false
        end
    end
    
    # Check removal of items from multi-item itemsets
    for i in 1:length(candidate)
        if length(candidate[i]) > 1
            for item in candidate[i]
                subseq = copy(candidate)
                subseq[i] = filter(x -> x != item, candidate[i])
                if !isempty(subseq[i]) && subseq ∉ frequent_set
                    return false
                end
            end
        end
    end
    
    return true
end

# Helper function to count support for a candidate pattern
function count_pattern_support(candidate::Vector{Vector{String}}, seqtxns::SeqTxns, min_support::Int, buf::SequenceBuffer)
    empty!(buf.patterns)
    support_count = 0
    
    for seq_idx in 1:seqtxns.n_sequences
        if sequence_contains_pattern(candidate, seqtxns, seq_idx, buf)
            support_count += 1
        end
    end
    
    if support_count >= min_support
        push!(buf.patterns, SeqPattern(candidate, support_count))
    end
end

# Helper function to check if a sequence contains a pattern
function sequence_contains_pattern(pattern::Vector{Vector{String}}, seqtxns::SeqTxns, seq_idx::Int, buf::SequenceBuffer)
    start_idx = seqtxns.index[seq_idx]
    end_idx = seq_idx < seqtxns.n_sequences ? seqtxns.index[seq_idx + 1] - 1 : seqtxns.n_transactions
    
    # Build sequence itemsets
    empty!(buf.itemsets)
    for txn_idx in start_idx:end_idx
        empty!(buf.pattern_items)
        for (item_idx, has_item) in enumerate(seqtxns.matrix[txn_idx, :])
            has_item && push!(buf.pattern_items, seqtxns.colkeys[item_idx])
        end
        if !isempty(buf.pattern_items)
            push!(buf.itemsets, sort(copy(buf.pattern_items)))
        end
    end
    
    # Check if pattern is subsequence of sequence
    return is_subsequence(pattern, buf.itemsets)
end

# Helper function to check subsequence matching
function is_subsequence(pattern::Vector{Vector{String}}, sequence::Vector{Vector{String}})
    length(pattern) > length(sequence) && return false
    isempty(pattern) && return true
    
    pat_idx, seq_idx = 1, 1
    
    while pat_idx <= length(pattern) && seq_idx <= length(sequence)
        pattern_itemset = Set(pattern[pat_idx])
        sequence_itemset = Set(sequence[seq_idx])
        
        if issubset(pattern_itemset, sequence_itemset)
            pat_idx += 1
        end
        seq_idx += 1
    end
    
    return pat_idx > length(pattern)
end