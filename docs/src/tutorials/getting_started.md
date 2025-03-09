# Getting Started

## Installation

Packages can be added from the general registry either using Julia's `Pkg` pacakge manager
```julia
include Pkg

Pkg.add("RuleMiner")
```

Alternatively, if running interactively in the Julia REPL, pressing the `]` hotkey will switch to an interactive package management interface that can be used to install RuleMiner. Pressing `backspace` will return to the standard Julia REPL.
```julia-repl
julia> ]
Pkg> add RuleMiner
```

## Enabling Multithreading
RuleMiner can take advantage of modern CPUs with multiple cores to increase the speed of computation. If launching directly Julia from a shell or terminal, ensure that you are including the `-t` argument to enable multithreading. `-t` takes either a specific number of threads or 'auto' to use all available system threads.

```shell
julia -t auto
```

If you are using the official Julia extension for VS Code, the parameter passed into `-t` is called `julia.NumThreads` in VS Code settings for all Julia instances created in that IDE. Other IDEs may have similar ways to configure the arguments passed into Julia on startup.

## Creating a `Txns` object

```@setup setup
using RuleMiner
using DataFrames

df = DataFrame(
    :milk => [1, 1, 1, 0, 0, 0, 1, 1, 0],
    :eggs => [1, 1, 1, 0, 0, 0, 1, 0, 1],
    :bread => [1, 0, 0, 1, 1, 0, 0, 0, 0],
    :butter => [0, 1, 0, 0, 0, 0, 0, 0, 0],
    :sugar => [0, 1, 0, 0, 0, 0, 1, 0, 0],
    :flour => [0, 1, 0, 0, 0, 0, 0, 0, 0],
    :bacon => [0, 0, 1, 0, 0, 0, 0, 0, 1],
    :beer => [0, 0, 1, 0, 0, 1, 0, 1, 0],
    :ham => [0, 0, 0, 1, 1, 0, 0, 0, 1],
    :turkey => [0, 0, 0, 1, 0, 0, 0, 0, 0],
    :cheese => [0, 0, 0, 0, 1, 1, 0, 0, 1],
    :ketchup => [0, 0, 0, 0, 1, 0, 0, 1, 0],
    :mustard => [0, 0, 0, 0, 0, 1, 0, 0, 0],
    :hot_dogs => [0, 0, 0, 0, 0, 1, 0, 0, 0],
    :buns => [0, 0, 0, 0, 0, 1, 0, 0, 0],
    :hamburger => [0, 0, 0, 0, 0, 1, 0, 1, 0]
)
data = Txns(df)
```

The first step in mining association rules in RuleMiner is to create a `Txns` object. This stores the information about the transactions in a format that can be easily mined.

Here is example of converting a 1-hot encoded DataFrames.jl `DataFrame` to a Txns object.

The original 1-hot encoded dataframe:
```@repl setup
df
```

The Txns object:
```@repl setup
data = Txns(df)
```

## Mining association Rules

Using the created `Txns` object, association rules can be mined with the `apriori` function.

### Example 1: Relative support

Only minimum support is required by the apriori function, but a minimum confidence can also be specified. In this example, apriori is being used to search for rules with a minimum support of 20% and a minimum confidence of 60%.
```@example setup
rules = apriori(data, 0.2, 0.6)

println(rules)
```

### Example 2: Absolute Support
Specifying an integer value for `min_support` is used to indicate absolute support, rather than relative support.

Here, apriori is used to search for rules which occur at least 2 transactions in the data. The results are identical to the above example because the min_support threshold of 2 (out of 9, so approximately 22%) is very similar to the 20% threshhold in the last example.

```@example setup
rules = apriori(data, 2, 0.6)

println(rules)
```