# levelwise.jl
# Levelwise frequent itemset recovery from closed itemsets
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

export levelwise

"""
    levelwise(df::DataFrame, min_n::Int)::DataFrame

Recover frequent itemsets from a dataframe `df` of closed itemsets with minimum absolute support `min_n`
"""
function levelwise(df::DataFrame, min_n::Int)::DataFrame
    # Helper function to generate all k-subsets of an itemset
    function generate_subsets(itemset, k)
        return [Set(collect(c)) for c in combinations(itemset, k)]
    end

    # Helper function to find the smallest closed itemset containing a given itemset
    function find_smallest_closed(itemset, closed_itemsets_df)
        containing = filter(row -> all(item in Set(row.Itemset) for item in itemset), closed_itemsets_df)
        isempty(containing) ? nothing : containing[argmin(containing.Length), :Itemset]
    end

    # Subset the input datafame to only closed sets above minimum support
    closed_df = subset(df, :N => (x -> x .>= min_n))
    
    # Sort the input DataFrame by Length (ascending) for optimization
    sort!(closed_df, :Length)

    # Extract closed itemsets and their supports
    closed_itemsets = Dict(Set(row.Itemset) => row.N for row in eachrow(closed_df))

    frequent_itemsets = Dict{Set{eltype(closed_df.Itemset[1])}, Int}()

    # Add all closed itemsets to frequent itemsets
    merge!(frequent_itemsets, closed_itemsets)

    for k in 1:maximum(closed_df.Length)
         # Initialize Candidate Set
        candidates = Set{Set{eltype(closed_df.Itemset[1])}}()
        # Generate candidates
        for closed_itemset in closed_df.Itemset
            for subset in generate_subsets(closed_itemset, k)
                # Skip if the candidate has already been added
                haskey(frequent_itemsets, subset) && continue    
                push!(candidates, subset)
            end
        end

        # If no more candidates, break out of loop
        isempty(candidates) && break

        # Calculate support and check frequency
        for candidate in collect(candidates)
        
            smallest_closed = find_smallest_closed(candidate, closed_df)
            
            isnothing(smallest_closed) && continue
    
            support = closed_itemsets[Set(smallest_closed)]
            
            support < min_n && continue
                
            frequent_itemsets[candidate] = support
        end
    end

    # Convert the result to a DataFrame
    result_df = DataFrame(
        Itemset = collect.(collect(keys(frequent_itemsets))), 
        N = collect(values(frequent_itemsets)),
        Length = length.(collect(keys(frequent_itemsets)))
    )
    
    # Sort by support (descending) and itemset length (ascending)
    sort!(result_df, :N, rev = true)

    return result_df
end