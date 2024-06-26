# RuleMiner.jl - Association Rule Mining in Julia
[![Build Status](https://github.com/JaredSchwartz/RuleMiner.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JaredSchwartz/RuleMiner.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![codecov](https://codecov.io/github/JaredSchwartz/RuleMiner.jl/graph/badge.svg?token=KDAVR32F6S)](https://codecov.io/github/JaredSchwartz/RuleMiner.jl)

## About
RuleMiner.jl is a Julia package for association rule and frequent itemset mining inspired by the [arules](https://github.com/mhahsler/arules) R package and [SPMF](https://www.philippe-fournier-viger.com/spmf/) Java library.

Key features of RuleMiner.jl include:

- Support for Julia's native multithreading capabilities for improved performance
- Direct interfaces with DataFrames.jl for loading transactional data and exporting results
- Flexible handling of either relative (percentage) support or absolute (count) support in minimum support thresholds

## Algorithms
The package currently has support for these algorithms:
- A Priori[^1]
- ECLAT[^2]

## Installation
```
pkg> add "https://github.com/JaredSchwartz/RuleMiner.jl"
```
## Usage
```julia
using RuleMiner
```

Load data to create a Transactions object or alternatively convert an existing 1-hot encoded DataFrame.

```julia
data = load_transactions("retail.txt",',')

data = transactions(df)
```

Generate association rules using _A Priori_ with 5% minimum support and a max rule length of 3.

```julia
arules = apriori(data, 0.05, 3)
```

Generate frequent itemesets with a minimum support of 100 transacations using _ECLAT_

```julia
itemsets = eclat(data, 100)
```
## Multithreading
RuleMiner.jl makes use of Julia's native multithreading support. You will likely see performance gains by allocating Julia more threads at startup. See [this post](https://julialang.org/blog/2019/07/multithreading/) for more info on enabling multithreading in Julia.

## Future Work
Support for the FP-Growth Algorithm is planned for RuleMiner 0.2.0. Future releases will support additional mining algorithms.

## References
[^1]: Rakesh Agrawal and Srikant Ramakrishnan, "Fast Algorithms for Mining Association Rules in Large Databases," in Proceedings of the 20th International Conference On Very Large Data Bases (Morgan Kaufmann UK, 1994), 487–99.

[^2]: Mohammed Zaki, "Scalable Algorithms for Association Mining," _IEEE Transactions on Knowledge and Data Engineering_ 12 (June 1, 2000): 372–90, https://doi.org/10.1109/69.846291.