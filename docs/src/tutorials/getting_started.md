# Getting Started

```@setup setup
using RuleMiner
using DataFrames

using Downloads
Downloads.download("http://fimi.uantwerpen.be/data/mushroom.dat", "mushrooms.txt")
mushrooms = Txns("mushrooms.txt", ' ')
mushroom_df = txns_to_df(mushrooms)
```

This guide will walk you through installing RuleMiner.jl, setting up multithreading for optimal performance, and running your first association rule mining analysis. By the end, you'll be ready to discover patterns in your own transaction data.

## Installation

Julia packages can be added from the general registry using the `Pkg` package manager in the Julia REPL or in a Julia script.
```julia
include Pkg

Pkg.add("RuleMiner")
```

## Enabling Multithreading
The mining algorithms in RuleMiner utilize multithreading to process data concurrently, which can lead to dramatic performance improvements, especially for larger datasets or lower support thresholds. Multithreading must be enabled when launching julia to take advantage of these performance gains.

To enable multithreading when launching Julia from a terminal, use the `-t` argument:
```shell
julia -t auto # Use all available CPU cores
```
```shell
julia -t 8 # Dedicate 8 cores specifically
```

It is recommended to use the `auto` setting with RuleMiner.jl for best performance.

If you're using the official Julia extension for VS Code, the parameter passed into -t is called `julia.NumThreads` in VS Code settings for all Julia instances created in that IDE. Other IDEs may have similar ways to configure the arguments passed into Julia on startup.

You can verify the number of threads available to Julia with:
```julia
using Base.Threads
println("Julia is using $(nthreads()) threads")
```
## Creating a `Txns` object

The first step in mining association rules in RuleMiner is to create a `Txns` object. This stores the information about the transactions in a format that can be easily mined. These can be created either by reading a basket-format file or by converting an existing 1-hot encoded dataframe.

Generally, loading from files is more efficient and can handle larger datasets, as data is read directly into a sparse stroage format.

### From a file
This example demonstrates reading the "mushrooms" dataset that is commonly used for data mining examples and benchmarking hosted by the [University of Antwerp FIMI Project](http://fimi.uantwerpen.be/).

```@example setup
# Download the data to a local file
using Downloads
Downloads.download("http://fimi.uantwerpen.be/data/mushroom.dat", "mushrooms.txt")

# Read the data into a Txns object, specifying a single space as the delimiter
mushrooms = Txns("mushrooms.txt", ' ')
println(mushrooms)
```

### From a DataFrame
Say the mushrooms data was in a 1-hot tabular format instead of a basket file format. By creating a DataFrame where the item labels are the column headers and the columns are boolean 1-hot encodings, these can also be easily converted into Txns objects.

The original 1-hot encoded dataframe:
```@example setup
# print first 10 rows of the mushroom df
println(first(mushroom_df,10))
```

The Txns object:
```@example setup
mushrooms = Txns(mushroom_df)
println(mushrooms)
```

## Mining association Rules

Using the created `Txns` object, association rules can be mined with the `apriori` function. These examples use the same toy data from the dataframe example above.

### Example 1: Relative support

Only minimum support is required by the apriori function, but a minimum confidence can also be specified. In this example, apriori is being used to search for rules with a minimum support of 80% and a minimum confidence of 90%.
```@example setup
rules = apriori(mushrooms, 0.8, 0.9)

println(first(rules,15))
```

### Example 2: Absolute Support
Specifying an integer value for `min_support` is used to indicate absolute support, rather than relative support.

Here, apriori is used to search for rules which occur at least 6500 transactions in the data. The results are identical to the above example because the min_support threshold of 6500 (out of 8124) is approximately equal to the 80% threshhold in the last example.

```@example setup
rules = apriori(mushrooms, 6500, 0.9)

println(first(rules,15))
```

### Results analysis
Even from this very preliminary analysis, an interesting pattern emerges.

Item 85 by its self has a support of 1.0, meaning it appears in every transaction in the dataset. This has some interesting implications, like any rule where 85 is the RHS will have a confidence value of 1.0.

The reason for this is because confidence calculates the percentage of transactions in the LHS set that also apear in the LHS ∪ RHS set. If the RHS item appears in every transaction then all LHS transactions are guaranteed to have the RHS item

## Next Steps
Hopefully, you feel prepared to used RuleMiner load data and to mine association rules!

To find good sample data sets to try out RuleMiner, check out the [FIMI repository](http://fimi.uantwerpen.be/data/).

If you want to dig deeper into the other capabilities of RuleMiner, check out the [RuleMiner API Reference](../api_reference.md).