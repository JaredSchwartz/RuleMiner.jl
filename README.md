# RuleMiner.jl - Association Rule Mining in Julia
[![Build Status](https://github.com/JaredSchwartz/RuleMiner.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JaredSchwartz/RuleMiner.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![codecov](https://codecov.io/github/JaredSchwartz/RuleMiner.jl/graph/badge.svg?token=KDAVR32F6S)](https://codecov.io/github/JaredSchwartz/RuleMiner.jl)

## About
This package was inspired by the [arules](https://github.com/mhahsler/arules) R package and [SPMF](https://www.philippe-fournier-viger.com/spmf/) Java library as a collection of various association rule mining tools.

The goal of this package is to bring association rule mining to the Julia ecosystem, making it easy to read transactional data and extract patterns and insights.

Some of these algorithms make use of Julia's native multithreading support. You will likely see performance gains by allocating Julia more threads at startup. See [this post](https://julialang.org/blog/2019/07/multithreading/) for more info on enabling multithreading in Julia.
## Algorithms
The package currently has support for these algorithms:
- A Priori[^1]
- ECLAT[^2]

## Installation
```julia
pkg> add "https://github.com/JaredSchwartz/RuleMiner.jl"
```
## Usage
Load data to create a Transactions object

```julia
using RuleMiner

data = load_transactions("retail.txt", :wide; sep=',')
```

Generate association rules using _A Priori_ with 5% minimum support and a max rule length of 3.
```julia
apriori(data, 0.05, 3)
```
All algorithms automatically handle either relative support (percentage) or absolute support (count) in the min_support argument.
```julia
apriori(data, 100, 3)
```


## References
[^1]: Rakesh Agrawal and Srikant Ramakrishnan, "Fast Algorithms for Mining Association Rules in Large Databases," in Proceedings of the 20th International Conference On Very Large Data Bases (Morgan Kaufmann UK, 1994), 487–99.

[^2]: Mohammed Zaki, "Scalable Algorithms for Association Mining," _IEEE Transactions on Knowledge and Data Engineering_ 12 (June 1, 2000): 372–90, https://doi.org/10.1109/69.846291.