#= gsp.jl
GSP (Generalized Sequential Pattern) algorithm for sequential pattern mining in Julia
Licensed under the MIT license. See https://github.com/JaredSchwartz/RuleMiner.jl/blob/main/LICENSE
=#

struct SeqPattern
    pattern::Vector{Vector{Int}}
    support::Int
    signature::UInt64  # Hash signature for fast comparison
end

struct SequenceBuffer
    patterns::Vector{SeqPattern}
    
    SequenceBuffer() = new(Vector{SeqPattern}())
end

# Helper to create hash signature from pattern
function pattern_hash(pattern::Vector{Vector{Int}})::UInt64
    h = UInt64(0)
    for (pos, itemset) in enumerate(pattern)
        for item in itemset
            h = hash(item, hash(pos, h))
        end
    end
    return h
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
    
    # Set up processing channels for lock-free operation
    num_workers = nthreads(:default)
    buffer_channel = Channel{SequenceBuffer}(num_workers)
    for _ in 1:num_workers
        put!(buffer_channel, SequenceBuffer())
    end
    
    # Find frequent 1-patterns using matrix operations
    current_patterns, all_patterns = generate_l1_patterns(seqtxns, min_support, idx_e)
    
    k = 2
    while !isempty(current_patterns)
        # Generate candidate k-patterns
        candidates = generate_k_candidates(current_patterns, k)
        isempty(candidates) && break
        
        # Use work-stealing pattern with channels for lock-free processing
        level_patterns = process_candidates(candidates, seqtxns, min_support, buffer_channel, num_workers, idx_e)
        append!(all_patterns, level_patterns)
        
        # Set up for next level
        current_patterns = level_patterns
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
function generate_l1_patterns(seqtxns::SeqTxns, min_support::Int, idx_e::Vector{UInt32})
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
    
    # Create frequent 1-patterns with signatures
    patterns_1 = Vector{SeqPattern}()
    all_patterns = Vector{SeqPattern}()
    
    for item_idx in eachindex(item_counts)
        count = item_counts[item_idx]
        count < min_support && continue
        
        pattern = [[item_idx]]
        sig = pattern_hash(pattern)
        seq_pat = SeqPattern(pattern, count, sig)
        
        push!(patterns_1, seq_pat)
        push!(all_patterns, seq_pat)
    end
    
    return patterns_1, all_patterns
end

# Chunked parallel processing
function process_candidates(
    candidates::Vector{Vector{Vector{Int}}}, 
    seqtxns::SeqTxns, 
    min_support::Int, 
    buffer_channel::Channel{SequenceBuffer},
    num_workers::Int,
    idx_e::Vector{UInt32}
)
    n_candidates = length(candidates)
    
    # Calculate optimal chunk size
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
                        support_count = calc_support(candidate, seqtxns.matrix, seqtxns.index, idx_e)
                        
                        if support_count >= min_support
                            sig = pattern_hash(candidate)
                            push!(chunk_patterns, SeqPattern(candidate, support_count, sig))
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

# Optimized support counting function
function calc_support(sequence::Vector{Vector{Int}}, 
                     matrix::SparseMatrixCSC{Bool}, starts::Vector{UInt32}, ends::Vector{UInt32})
    counter = 0
    len_seq = length(sequence)
    
    # For each potential starting position
    for idx_val in eachindex(starts)
        start_row = starts[idx_val]
        end_row = ends[idx_val]
        
        # Try to match the sequence starting from start_row
        matrix_row = start_row  # Current position in matrix
        seq_idx = 1             # Current position in sequence
        
        # Step through the matrix rows
        while matrix_row <= end_row && seq_idx <= len_seq
            
            # Check if current matrix row contains all items from sequence transaction
            match = true
            @inbounds for item in sequence[seq_idx]
                if !matrix[matrix_row, item]
                    match = false
                    break
                end
            end
            
            if match
                # Match found - advance both pointers
                seq_idx += 1
                matrix_row += 1
            else
                # No match - advance only matrix pointer
                matrix_row += 1
            end
        end
        
        # Check if we successfully matched the entire sequence
        if seq_idx > len_seq
            counter += 1
        end
    end
    
    return counter
end

# Generate candidates using indexed representation
function generate_k_candidates(frequent_patterns::Vector{SeqPattern}, k::Int)
    candidates = Set{Vector{Vector{Int}}}()
    
    for i in eachindex(frequent_patterns)
        for j in eachindex(frequent_patterns)
            i == j && continue
            
            pattern1, pattern2 = frequent_patterns[i].pattern, frequent_patterns[j].pattern
            
            # Handle k == 2: generate sequential and simultaneous patterns
            if k == 2
                item1, item2 = pattern1[1][1], pattern2[1][1]
                push!(candidates, [[item1], [item2]])  # Sequential
                item1 < item2 && push!(candidates, [sort([item1, item2])])  # Simultaneous
                continue
            end
            
            # Handle k > 2: levelwise join like Apriori
            # Two ways to extend: add new itemset or extend existing itemset
            
            # Method 1: Extend last itemset (simultaneous items)
            if length(pattern1) == length(pattern2) && pattern1[1:end-1] == pattern2[1:end-1]
                last1, last2 = pattern1[end], pattern2[end]
                if length(last1) == 1 && length(last2) == 1 && last1[1] < last2[1]
                    # Merge single items into one itemset
                    new_pattern = copy(pattern1)
                    new_pattern[end] = sort([last1[1], last2[1]])
                    push!(candidates, new_pattern)
                end
            end
            
            # Method 2: Add new itemset (sequential extension)
            if pattern1 == pattern2[1:end-1]
                # pattern2 extends pattern1 with one more itemset
                push!(candidates, copy(pattern2))
            elseif pattern2 == pattern1[1:end-1] 
                # pattern1 extends pattern2 with one more itemset
                push!(candidates, copy(pattern1))
            end
        end
    end
    
    return collect(candidates)
end