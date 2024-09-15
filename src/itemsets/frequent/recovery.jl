# recovery.jl
# Functions to recover frequent itemsets
#=
Copyright (c) 2024 Jared Schwartz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
=#

"""
    recover_closed(df::DataFrame, min_n::Int)::DataFrame

Recover frequent itemsets from a DataFrame of closed itemsets.

# Arguments
- `df::DataFrame`: A DataFrame containing the closed frequent itemsets, with columns:
  - `Itemset`: The items in the closed frequent itemset.
  - `Support`: The relative support of the itemset as a proportion of total transactions.
  - `N`: The absolute support count of the itemset.
  - `Length`: The number of items in the itemset.
- `min_n::Int`: The minimum support threshold for the rules. This is the absolute (integer) support.

# Returns
- `DataFrame`: A DataFrame containing all frequent itemsets, with columns:
  - `Itemset`: The items in the frequent itemset.
  - `N`: The absolute support count of the itemset.
  - `Length`: The number of items in the itemset.

# Description
This function recovers all frequent itemsets from a set of closed itemsets. It generates
all possible subsets of the closed itemsets and calculates their supports based on the
smallest containing closed itemset.

The function works as follows:
1. It filters the input DataFrame to only include closed sets above the minimum support.
2. For each length k from 1 to the maximum itemset length:
   a. It generates all k-subsets of the closed itemsets.
   b. For each subset, it finds the smallest closed itemset containing it.
   c. It assigns the support of the smallest containing closed itemset to the subset.
3. It combines all frequent itemsets and their supports into a result DataFrame.

# Example
```julia
txns = Txns("transactions.txt", ' ')

# Find closed frequent itemsets with minimum 5,000 transactions
closed_sets = fpclose(txns, 5_000)

# Recover frequent itemsets from the closed itemsets
frequent_sets = recover_closed(closed_sets, 5_000)
```

# References
Pasquier, Nicolas, Yves Bastide, Rafik Taouil, and Lotfi Lakhal. "Efficient Mining of Association Rules Using Closed Itemset Lattices." Information Systems 24, no. 1 (March 1, 1999): 25–46. https://doi.org/10.1016/S0306-4379(99)00003-4.
"""
function recover_closed(df::DataFrame, min_n::Int)::DataFrame
    # Helper function to generate all k-subsets of an itemset
    function generate_subsets(itemset, k)
        return [Set(collect(c)) for c in combinations(itemset, k)]
    end

    # Helper function to find the smallest closed itemset containing a given itemset
    function find_smallest_closed(itemset, closed_itemsets_df)
        containing = filter(row -> all(item in Set(row.Itemset) for item in itemset), closed_itemsets_df)
        isempty(containing) ? nothing : containing[argmin(containing.Length), :Itemset]
    end

    # Subset the input dataframe to only closed sets above minimum support
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
    sort!(result_df, [:N, :Length], rev = [true, false])

    return result_df
end

"""
    recover_maximal(df::DataFrame)::DataFrame

Recover all frequent itemsets from a DataFrame of maximal frequent itemsets.

# Arguments
- `df::DataFrame`: A DataFrame containing the maximal frequent itemsets, with columns:
  - `Itemset`: The items in the maximal frequent itemset.
  - `Length`: The number of items in the itemset.

# Returns
- `DataFrame`: A DataFrame containing all frequent itemsets, with columns:
  - `Itemset`: The items in the frequent itemset.
  - `Length`: The number of items in the itemset.

# Description
This function takes a DataFrame of maximal frequent itemsets and generates all possible
subsets (including the maximal itemsets themselves) to recover the complete set of
frequent itemsets. It does not calculate or recover support values, as these cannot
be determined from maximal itemsets alone.

The function works as follows:
1. For each maximal itemset, it generates all possible subsets.
2. It combines all these subsets into a single collection of frequent itemsets.
3. It removes any duplicate itemsets that might arise from overlapping maximal itemsets.
4. It returns the result as a DataFrame, sorted by itemset length in descending order.

# Example
```julia
txns = Txns("transactions.txt", ' ')

# Find maximal frequent itemsets with minimum 5,000 transactions
maximal_sets = fpmax(txns, 5_000)

# Recover frequent itemsets from the maximal itemsets
frequent_sets = recover_maximal(maximal_sets)
```
"""
function recover_maximal(df::DataFrame)::DataFrame
    all_subsets = Set{Vector{String}}()
    
    for row in eachrow(df)
        itemset = row.Itemset
        # Generate all subsets of the current itemset
        for k in 1:length(itemset)
            for subset in combinations(itemset, k)
                push!(all_subsets, sort(collect(subset)))
            end
        end
    end
    
    # Convert the set of subsets to a DataFrame
    result_df = DataFrame(
        Itemset = collect(all_subsets),
        Length = length.(collect(all_subsets))
    )
    
    # Sort by length in descending order
    sort!(result_df, :Length, rev=true)
    
    return result_df
end