#= gsp.jl
GSP (Generalized Sequential Pattern) algorithm for sequential pattern mining in Julia
Licensed under the MIT license. See https://github.com/JaredSchwartz/RuleMiner.jl/blob/main/LICENSE
=#

struct SeqPattern
    pattern::Vector{Vector{Int}}     # Use item indices instead of strings for faster operations
    support::Int                     # Absolute support count
end

struct SequenceBuffer
    temp_mask::BitVector            # Reusable mask for itemset matching
    pattern_mask::BitVector         # Reusable mask for pattern matching
    patterns::Vector{SeqPattern}    # Thread-local pattern results
    
    SequenceBuffer(n_items::Int) = new(
        falses(n_items),
        falses(n_items), 
        Vector{SeqPattern}()
    )
end

"""
    gsp(seqtxns::SeqTxns, min_support::Union{Int,Float64})::DataFrame

Matrix-optimized GSP algorithm for frequent sequential pattern mining.
"""
function gsp(seqtxns::SeqTxns, min_support::Union{Int,Float64})::DataFrame
    # Initial setup
    n_sequences = seqtxns.n_sequences
    n_items = size(seqtxns.matrix, 2)
    min_support = clean_support(min_support, n_sequences)
    idx_e = getends(seqtxns)
    
    # Create item index mapping for faster lookups
    item_to_idx = Dict(item => idx for (idx, item) in enumerate(seqtxns.colkeys))
    
    # Set up processing channels for lock-free operation
    num_workers = nthreads(:default)
    buffer_channel = Channel{SequenceBuffer}(num_workers)
    for _ in 1:num_workers
        put!(buffer_channel, SequenceBuffer(n_items))
    end
    
    # Find frequent 1-patterns using matrix operations
    current_patterns, all_patterns = find_L1_patterns_matrix(seqtxns, min_support, idx_e)
    
    k = 2
    while !isempty(current_patterns)
        # Generate candidate k-patterns
        candidates = generate_k_candidates_indexed(current_patterns, k)
        isempty(candidates) && break
        
        # Use work-stealing pattern with channels for lock-free processing
        level_patterns = process_candidates_lockfree(candidates, seqtxns, min_support, buffer_channel, num_workers, idx_e)
        append!(all_patterns, level_patterns)
        
        # Set up for next level
        current_patterns = [p.pattern for p in level_patterns]
        k += 1
    end
    
    # Convert back to string representation for output
    df = DataFrame(
        Pattern = [[seqtxns.colkeys[itemset] for itemset in p.pattern] for p in all_patterns],
        Support = [p.support / n_sequences for p in all_patterns],
        N = [p.support for p in all_patterns],
        Length = [sum(length(itemset) for itemset in p.pattern) for p in all_patterns],
        NumItemsets = [length(p.pattern) for p in all_patterns]
    )
    
    sort!(df, [:N, :Length], rev = [true, false])
    return df
end

# Matrix-based L1 pattern finding
function find_L1_patterns_matrix(seqtxns::SeqTxns, min_support::Int, idx_e::Vector{UInt32})
    n_items = size(seqtxns.matrix, 2)
    item_counts = zeros(Int, n_items)
    item_cache = zeros(Int, n_items)
    
    # Count items per sequence
    for seq_idx in 1:seqtxns.n_sequences
        start_idx = seqtxns.index[seq_idx]
        end_idx = idx_e[seq_idx]
        
        seq_matrix = view(seqtxns.matrix, start_idx:end_idx, :)

        fill!(item_cache, 0)
        for col_idx in 1:n_items
            if any(view(seq_matrix, :, col_idx))
                item_cache[col_idx] = 1
            end
        end
        
        item_counts .+= item_cache
    end
    
    # Create frequent 1-patterns
    patterns_1 = Vector{Vector{Vector{Int}}}()
    all_patterns = Vector{SeqPattern}()
    
    count::Int = 0
    for item_idx in eachindex(item_counts)
        count = item_counts[item_idx]
        
        count < min_support && continue
        
        pattern = [[item_idx]]
        push!(patterns_1, pattern)
        push!(all_patterns, SeqPattern(pattern, count))
    end
    
    return patterns_1, all_patterns
end

# Chunked parallel processing with early termination optimizations
function process_candidates_lockfree(
    candidates::Vector{Vector{Vector{Int}}}, 
    seqtxns::SeqTxns, 
    min_support::Int, 
    buffer_channel::Channel{SequenceBuffer},
    num_workers::Int,
    idx_e::Vector{UInt32}
)
    n_candidates = length(candidates)
    
    # Calculate optimal chunk size (similar to apriori)
    min_chunk_size = 10
    chunk_size = max(min_chunk_size, cld(n_candidates, num_workers * 4))
    total_chunks = cld(n_candidates, chunk_size)
    chunk_counter = Atomic{Int}(0)
    
    # Results channel for collecting pattern chunks from workers
    results_channel = Channel{Vector{SeqPattern}}(total_chunks)
    
    # Launch workers with chunked processing
    @sync begin
        for _ in 1:num_workers
            @spawn begin
                buf = take!(buffer_channel)
                
                while true
                    # Atomic work-stealing: grab next chunk
                    chunk_idx = atomic_add!(chunk_counter, 1)
                    chunk_idx >= total_chunks && break
                    
                    # Calculate chunk bounds
                    chunk_start = chunk_idx * chunk_size + 1
                    chunk_end = min(chunk_start + chunk_size - 1, n_candidates)
                    
                    # Process this chunk of candidates
                    chunk_patterns = Vector{SeqPattern}()
                    
                    for candidate_idx in chunk_start:chunk_end
                        candidate = candidates[candidate_idx]
                        support_count = count_support_matrix_early_termination(candidate, seqtxns, min_support, buf, idx_e)
                        
                        if support_count >= min_support
                            push!(chunk_patterns, SeqPattern(candidate, support_count))
                        end
                    end
                    
                    # Send chunk results to channel (only if non-empty)
                    if !isempty(chunk_patterns)
                        put!(results_channel, chunk_patterns)
                    end
                end
                
                put!(buffer_channel, buf)
            end
        end
    end
    
    # Close results channel and combine all chunks
    close(results_channel)
    return vcat(results_channel...)
end

# Support counting with early termination when support threshold is reached
function count_support_matrix_early_termination(
    candidate::Vector{Vector{Int}}, 
    seqtxns::SeqTxns, 
    min_support::Int,
    buf::SequenceBuffer,
    idx_e::Vector{UInt32}
)
    support_count = 0
    max_possible_support = seqtxns.n_sequences
    # Process each sequence with early termination checks
    for seq_idx in 1:seqtxns.n_sequences
        start_idx = seqtxns.index[seq_idx]
        end_idx = idx_e[seq_idx]
        
        if sequence_contains_pattern_matrix_early_termination(candidate, seqtxns.matrix, start_idx:end_idx, buf)
            support_count += 1
            
            # Early termination: if we've already found enough support, we can stop
            if support_count >= min_support
                return support_count
            end
        end
        
        # Early termination: if remaining sequences can't possibly reach min_support
        remaining_sequences = seqtxns.n_sequences - seq_idx
        if support_count + remaining_sequences < min_support
            return support_count
        end
    end
    
    return support_count
end

# Pattern matching with early termination for impossible matches
function sequence_contains_pattern_matrix_early_termination(
    pattern::Vector{Vector{Int}}, 
    matrix::SparseMatrixCSC, 
    seq_range::UnitRange{UInt32}, 
    buf::SequenceBuffer
)
    pattern_idx = 1
    seq_length = length(seq_range)
    
    # Early termination: if sequence is shorter than pattern, impossible to match
    seq_length < length(pattern) && (return false)
    
    # Iterate through transactions in the sequence
    for (pos, txn_idx) in enumerate(seq_range)
        pattern_idx > length(pattern) && break
        
        # Early termination: if remaining transactions can't cover remaining pattern
        remaining_txns = seq_length - pos + 1
        remaining_pattern = length(pattern) - pattern_idx + 1
        remaining_txns < remaining_pattern && (return false)
        
        # Check if current transaction contains the required itemset using matrix operations
        pattern_itemset = pattern[pattern_idx]
        
        # Fast check: does this transaction contain all items in the current pattern itemset?
        contains_all = true
        @inbounds for item_idx in pattern_itemset
            if !matrix[txn_idx, item_idx]
                contains_all = false
                break
            end
        end
        
        if contains_all
            pattern_idx += 1
        end
    end
    
    return pattern_idx > length(pattern)
end

# Generate candidates using indexed representation
function generate_k_candidates_indexed(frequent_patterns::Vector{Vector{Vector{Int}}}, k::Int)
    candidates = Set{Vector{Vector{Int}}}()
    
    for i in eachindex(frequent_patterns)
        for j in eachindex(frequent_patterns)
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
                if !isnothing(candidate) && has_frequent_subsequences_indexed(candidate, frequent_patterns)
                    push!(candidates, candidate)
                end
            end
        end
    end
    
    return collect(candidates)
end

# Indexed version of subsequence frequency checking
function has_frequent_subsequences_indexed(candidate::Vector{Vector{Int}}, frequent_patterns::Vector{Vector{Vector{Int}}})
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