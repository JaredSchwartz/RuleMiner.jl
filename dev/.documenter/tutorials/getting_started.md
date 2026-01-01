
# Getting Started {#Getting-Started}

This guide will walk you through installing RuleMiner.jl, setting up multithreading for optimal performance, and running your first association rule mining analysis. By the end, you&#39;ll be ready to discover patterns in your own transaction data.

## Installation {#Installation}

Julia packages can be added from the general registry using the `Pkg` package manager in the Julia REPL or in a Julia script.

```julia
include Pkg

Pkg.add("RuleMiner")
```


## Enabling Multithreading {#Enabling-Multithreading}

The mining algorithms in RuleMiner utilize multithreading to process data concurrently, which can lead to dramatic performance improvements, especially for larger datasets or lower support thresholds. Multithreading must be enabled when launching julia to take advantage of these performance gains.

To enable multithreading when launching Julia from a terminal, use the `-t` argument:

```shell
julia -t auto # Use all available CPU cores for computation
```


```shell
julia -t 8 # Dedicate 8 cores for computation
```


Starting with Julia 1.12, the above commands automatically include one additional interactive thread (so `julia -t 8` creates 8 computational threads + 1 interactive thread for 9 total), which helps keep Julia responsive during computation.

It is recommended to use the `auto` setting with RuleMiner.jl for best performance.

If you&#39;re using the official Julia extension for VS Code, the parameter passed into -t is called `julia.NumThreads` in VS Code settings for all Julia instances created in that IDE. Other IDEs may have similar ways to configure the arguments passed into Julia on startup.

You can verify the number of computational threads available to Julia with:

```julia
using Base.Threads
println("Julia is using $(nthreads(:default)) computational threads")
```


## Creating a `Txns` object {#Creating-a-Txns-object}

The first step in mining association rules in RuleMiner is to create a `Txns` object. This stores the information about the transactions in a format that can be easily mined. These can be created either by reading a basket-format file or by converting an existing 1-hot encoded dataframe.

Generally, loading from files is more efficient and can handle larger datasets, as data is read directly into a sparse stroage format.

### From a file {#From-a-file}

This example demonstrates reading the &quot;mushrooms&quot; dataset that is commonly used for data mining examples and benchmarking hosted by the [University of Antwerp FIMI Project](http://fimi.uantwerpen.be/).

```julia
# Download the data to a local file
using Downloads
Downloads.download("https://fimi.uantwerpen.be/data/mushroom.dat", "mushrooms.txt")

# Read the data into a Txns object, specifying a single space as the delimiter
mushrooms = Txns("mushrooms.txt", ' ')
println(mushrooms)
```


```ansi
Txns with 8124 transactions, 119 items, and 186852 non-zero elements
 Index │ Items
───────┼────────────────────────────────────────────────────────────────────────
     1 │ 1, 3, 9, 13, 23, 25, 34, 36, 38, 40, 52, 54, 59, 63, 67, 76, 85, 86,…
     2 │ 3, 9, 23, 34, 36, 40, 52, 59, 63, 67, 76, 85, 86, 90, 93, 2, 14, 26,…
     3 │ 9, 23, 34, 36, 52, 59, 63, 67, 76, 85, 86, 90, 93, 2, 39, 55, 99,…
     4 │ 1, 3, 23, 25, 34, 36, 38, 52, 54, 59, 63, 67, 76, 85, 86, 90, 93, 98,…
     5 │ 3, 9, 34, 40, 54, 59, 63, 67, 76, 85, 86, 90, 2, 39, 99, 114, 16, 24,…
     6 │ 3, 23, 34, 36, 52, 59, 63, 67, 76, 85, 86, 90, 93, 98, 2, 14, 26, 39,…
     7 │ 9, 23, 34, 36, 52, 59, 63, 67, 76, 85, 86, 90, 93, 98, 2, 26, 39, 55,…
     8 │ 23, 34, 36, 52, 59, 63, 67, 76, 85, 86, 90, 93, 107, 2, 39, 55, 99,…
     ⋮ │ ⋮
  8117 │ 1, 13, 34, 36, 38, 59, 76, 85, 86, 90, 10, 24, 53, 94, 110, 69, 66,…
  8118 │ 1, 9, 34, 36, 38, 63, 76, 85, 86, 90, 24, 53, 94, 110, 116, 69, 17,…
  8119 │ 1, 13, 34, 36, 38, 63, 76, 85, 86, 90, 10, 24, 53, 94, 110, 116, 69,…
  8120 │ 9, 13, 36, 52, 59, 63, 85, 90, 93, 2, 39, 24, 28, 58, 112, 119, 7,…
  8121 │ 3, 9, 13, 36, 52, 59, 63, 85, 90, 93, 2, 39, 24, 28, 110, 58, 119,…
  8122 │ 9, 13, 36, 52, 59, 63, 85, 90, 93, 2, 39, 41, 24, 28, 6, 58, 112,…
  8123 │ 1, 13, 34, 36, 38, 59, 67, 76, 85, 86, 90, 10, 24, 53, 94, 110, 66,…
  8124 │ 3, 9, 13, 36, 52, 59, 63, 85, 90, 93, 2, 39, 24, 28, 58, 112, 119,…
```


### From a DataFrame {#From-a-DataFrame}

Say the mushrooms data was in a 1-hot tabular format instead of a basket file format. By creating a DataFrame where the item labels are the column headers and the columns are boolean 1-hot encodings, these can also be easily converted into Txns objects.

The original 1-hot encoded dataframe:

```julia
# print first 10 rows of the mushroom df
println(first(mushroom_df,10))
```


```ansi
10×119 DataFrame
 Row │ 1      3      9      13     23     25     34     36     38     40     52     54     59     63     67     76     85     86     90     93     98     107    113    2      14     26     39     55     99     108    114    4      15     27     41     115    10     16     24     28     37     53     94     109    42     43     110    44     11     64     5      111    6      56     116    57     65     117    100    60     45     68     77     69     78     46     17     29     61     66     70     79     95     101    71     18     30     80     19     47     58     72     91     102    112    118    31     48     20     96     119    103    21     7      81     22     32     82     12     8      49     35     50     73     83     87     51     88     104    33     74     84     92     97     105    106    62     75     89
     │ Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64  Int64
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │     1      1      1      1      1      1      1      1      1      1      1      1      1      1      1      1      1      1      1      1      1      1      1      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0
   2 │     0      1      1      0      1      0      1      1      0      1      1      0      1      1      1      1      1      1      1      1      0      0      0      1      1      1      1      1      1      1      1      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0
   3 │     0      0      1      0      1      0      1      1      0      0      1      0      1      1      1      1      1      1      1      1      0      0      0      1      0      0      1      1      1      1      0      1      1      1      1      1      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0
   4 │     1      1      0      0      1      1      1      1      1      0      1      1      1      1      1      1      1      1      1      1      1      1      1      0      0      0      0      0      0      0      0      0      1      0      1      0      1      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0
   5 │     0      1      1      0      0      0      1      0      0      1      0      1      1      1      1      1      1      1      1      0      0      0      0      1      0      0      1      0      1      0      1      0      0      0      0      0      0      1      1      1      1      1      1      1      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0
   6 │     0      1      0      0      1      0      1      1      0      0      1      0      1      1      1      1      1      1      1      1      1      0      0      1      1      1      1      1      0      1      1      0      0      0      1      0      1      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0
   7 │     0      0      1      0      1      0      1      1      0      0      1      0      1      1      1      1      1      1      1      1      1      0      0      1      0      1      1      1      0      1      0      1      1      0      0      1      0      0      0      0      0      0      0      0      1      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0
   8 │     0      0      0      0      1      0      1      1      0      0      1      0      1      1      1      1      1      1      1      1      0      1      0      1      0      0      1      1      1      0      0      1      1      1      1      1      1      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0
   9 │     1      1      0      0      1      1      1      1      1      0      1      1      1      1      1      1      1      1      1      1      1      0      0      0      0      0      0      0      0      0      1      0      1      0      0      0      1      0      0      0      0      0      0      0      0      1      1      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0
  10 │     0      0      1      0      1      0      1      1      0      0      1      0      1      1      1      1      1      1      1      1      1      1      0      1      1      1      1      1      0      0      0      1      0      0      0      1      0      0      0      0      0      0      0      0      1      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0      0
```


The Txns object:

```julia
mushrooms = Txns(mushroom_df)
println(mushrooms)
```


```ansi
Txns with 8124 transactions, 119 items, and 186852 non-zero elements
 Index │ Items
───────┼────────────────────────────────────────────────────────────────────────
     1 │ 1, 3, 9, 13, 23, 25, 34, 36, 38, 40, 52, 54, 59, 63, 67, 76, 85, 86,…
     2 │ 3, 9, 23, 34, 36, 40, 52, 59, 63, 67, 76, 85, 86, 90, 93, 2, 14, 26,…
     3 │ 9, 23, 34, 36, 52, 59, 63, 67, 76, 85, 86, 90, 93, 2, 39, 55, 99,…
     4 │ 1, 3, 23, 25, 34, 36, 38, 52, 54, 59, 63, 67, 76, 85, 86, 90, 93, 98,…
     5 │ 3, 9, 34, 40, 54, 59, 63, 67, 76, 85, 86, 90, 2, 39, 99, 114, 16, 24,…
     6 │ 3, 23, 34, 36, 52, 59, 63, 67, 76, 85, 86, 90, 93, 98, 2, 14, 26, 39,…
     7 │ 9, 23, 34, 36, 52, 59, 63, 67, 76, 85, 86, 90, 93, 98, 2, 26, 39, 55,…
     8 │ 23, 34, 36, 52, 59, 63, 67, 76, 85, 86, 90, 93, 107, 2, 39, 55, 99,…
     ⋮ │ ⋮
  8117 │ 1, 13, 34, 36, 38, 59, 76, 85, 86, 90, 10, 24, 53, 94, 110, 69, 66,…
  8118 │ 1, 9, 34, 36, 38, 63, 76, 85, 86, 90, 24, 53, 94, 110, 116, 69, 17,…
  8119 │ 1, 13, 34, 36, 38, 63, 76, 85, 86, 90, 10, 24, 53, 94, 110, 116, 69,…
  8120 │ 9, 13, 36, 52, 59, 63, 85, 90, 93, 2, 39, 24, 28, 58, 112, 119, 7,…
  8121 │ 3, 9, 13, 36, 52, 59, 63, 85, 90, 93, 2, 39, 24, 28, 110, 58, 119,…
  8122 │ 9, 13, 36, 52, 59, 63, 85, 90, 93, 2, 39, 41, 24, 28, 6, 58, 112,…
  8123 │ 1, 13, 34, 36, 38, 59, 67, 76, 85, 86, 90, 10, 24, 53, 94, 110, 66,…
  8124 │ 3, 9, 13, 36, 52, 59, 63, 85, 90, 93, 2, 39, 24, 28, 58, 112, 119,…
```


## Mining association Rules {#Mining-association-Rules}

Using the created `Txns` object, association rules can be mined with the `apriori` function. These examples use the same toy data from the dataframe example above.

### Example 1: Relative support {#Example-1:-Relative-support}

Only minimum support is required by the apriori function, but a minimum confidence can also be specified. In this example, apriori is being used to search for rules with a minimum support of 80% and a minimum confidence of 90%.

```julia
rules = apriori(mushrooms, 0.8, 0.9)

println(first(rules,15))
```


```ansi
15×8 DataFrame
 Row │ LHS       RHS     Support   Confidence  Coverage  Lift      N      Length
     │ Array…    String  Float64   Float64     Float64   Float64   Int64  Int64
─────┼───────────────────────────────────────────────────────────────────────────
   1 │ String[]  34      0.974151    0.974151  1.0       1.0        7914       1
   2 │ String[]  85      1.0         1.0       1.0       1.0        8124       1
   3 │ String[]  86      0.975382    0.975382  1.0       1.0        7924       1
   4 │ String[]  90      0.921713    0.921713  1.0       1.0        7488       1
   5 │ ["34"]    90      0.89808     0.921911  0.974151  1.00021    7296       2
   6 │ ["90"]    34      0.89808     0.974359  0.921713  1.00021    7296       2
   7 │ ["36"]    34      0.812654    0.969172  0.838503  0.994889   6602       2
   8 │ ["85"]    90      0.921713    0.921713  1.0       1.0        7488       2
   9 │ ["90"]    85      0.921713    1.0       0.921713  1.0        7488       2
  10 │ ["86"]    90      0.897095    0.919738  0.975382  0.997856   7288       2
  11 │ ["90"]    86      0.897095    0.973291  0.921713  0.997856   7288       2
  12 │ ["36"]    85      0.838503    1.0       0.838503  1.0        6812       2
  13 │ ["36"]    86      0.81487     0.971814  0.838503  0.996343   6620       2
  14 │ ["85"]    34      0.974151    0.974151  1.0       1.0        7914       2
  15 │ ["34"]    85      0.974151    1.0       0.974151  1.0        7914       2
```


### Example 2: Absolute Support {#Example-2:-Absolute-Support}

Specifying an integer value for `min_support` is used to indicate absolute support, rather than relative support.

Here, apriori is used to search for rules which occur at least 6500 transactions in the data. The results are identical to the above example because the min_support threshold of 6500 (out of 8124) is approximately equal to the 80% threshhold in the last example.

```julia
rules = apriori(mushrooms, 6500, 0.9)

println(first(rules,15))
```


```ansi
15×8 DataFrame
 Row │ LHS       RHS     Support   Confidence  Coverage  Lift      N      Length
     │ Array…    String  Float64   Float64     Float64   Float64   Int64  Int64
─────┼───────────────────────────────────────────────────────────────────────────
   1 │ String[]  34      0.974151    0.974151  1.0       1.0        7914       1
   2 │ String[]  85      1.0         1.0       1.0       1.0        8124       1
   3 │ String[]  86      0.975382    0.975382  1.0       1.0        7924       1
   4 │ String[]  90      0.921713    0.921713  1.0       1.0        7488       1
   5 │ ["34"]    90      0.89808     0.921911  0.974151  1.00021    7296       2
   6 │ ["90"]    34      0.89808     0.974359  0.921713  1.00021    7296       2
   7 │ ["36"]    34      0.812654    0.969172  0.838503  0.994889   6602       2
   8 │ ["85"]    90      0.921713    0.921713  1.0       1.0        7488       2
   9 │ ["90"]    85      0.921713    1.0       0.921713  1.0        7488       2
  10 │ ["86"]    90      0.897095    0.919738  0.975382  0.997856   7288       2
  11 │ ["90"]    86      0.897095    0.973291  0.921713  0.997856   7288       2
  12 │ ["36"]    85      0.838503    1.0       0.838503  1.0        6812       2
  13 │ ["36"]    86      0.81487     0.971814  0.838503  0.996343   6620       2
  14 │ ["85"]    34      0.974151    0.974151  1.0       1.0        7914       2
  15 │ ["34"]    85      0.974151    1.0       0.974151  1.0        7914       2
```


### Results analysis {#Results-analysis}

Even from this very preliminary analysis, an interesting pattern emerges.

Item 85 by its self has a support of 1.0, meaning it appears in every transaction in the dataset. This has some interesting implications, like any rule where 85 is the RHS will have a confidence value of 1.0.

The reason for this is because confidence calculates the percentage of transactions in the LHS set that also apear in the LHS ∪ RHS set. If the RHS item appears in every transaction then all LHS transactions are guaranteed to have the RHS item

## Next Steps {#Next-Steps}

Hopefully, you feel prepared to used RuleMiner load data and to mine association rules!

To find good sample data sets to try out RuleMiner, check out the [FIMI repository](http://fimi.uantwerpen.be/data/).

If you want to dig deeper into the other capabilities of RuleMiner, check out the [RuleMiner API Reference](../api_reference.md).
