# RuleMiner.jl - Association Rule Mining in Julia
[![Build Status](https://github.com/JaredSchwartz/RuleMiner.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JaredSchwartz/RuleMiner.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![codecov](https://codecov.io/github/JaredSchwartz/RuleMiner.jl/graph/badge.svg?token=KDAVR32F6S)](https://codecov.io/github/JaredSchwartz/RuleMiner.jl)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://jaredschwartz.github.io/RuleMiner.jl/stable/)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://jaredschwartz.github.io/RuleMiner.jl/dev/)

## About
RuleMiner.jl is a Julia package for association rule and frequent itemset mining inspired by the [arules](https://github.com/mhahsler/arules) R package and [SPMF](https://www.philippe-fournier-viger.com/spmf/) Java library.

Key features of RuleMiner.jl include:

- Support for Julia's native multithreading capabilities for improved performance
- Direct interfaces with DataFrames.jl for loading transactional data and exporting results
- Flexible handling of either relative (percentage) support or absolute (count) support in minimum support thresholds

## Algorithms
The package currently has support for these algorithms:

**Frequent Itemset Mining**
- A Priori[^1]
- ECLAT[^2]
- FP-Growth[^3]

**Closed Itemset Mining**
- FPClose[^4]

## Installation
```
julia> ]

pkg> add RuleMiner
```
## Usage
These examples use the `retail` dataset from the [Frequent Itemset Mining Implementenations (FIMI)](http://fimi.uantwerpen.be/data/) repository hosted by the University of Antwerp.
```julia
using RuleMiner
```

Load data to create a Transactions object or alternatively convert an existing 1-hot encoded DataFrame. 

```julia
data = load_transactions("retail.txt",' ')

data = transactions(df)
```

Generate association rules using _A Priori_ with 10% minimum support and a max rule length of 3.

```julia
arules = apriori(data, 0.1, 3)
```
Result:
```
13×8 DataFrame
 Row │ LHS       RHS     Support   Confidence  Coverage  Lift       N      Length 
     │ Array…    String  Float64   Float64     Float64   Float64    Int64  Int64  
─────┼────────────────────────────────────────────────────────────────────────────
   1 │ String[]  33      0.172036    0.172036  1.0          1.0     15167       1
   2 │ String[]  39      0.176902    0.176902  1.0          1.0     15596       1
   3 │ String[]  40      0.574794    0.574794  1.0          1.0     50675       1
   4 │ String[]  42      0.169517    0.169517  1.0          1.0     14945       1
   5 │ String[]  49      0.477927    0.477927  1.0          1.0     42135       1
   6 │ ["40"]    42      0.129466    0.225239  0.574794  2482.19    11414       2
   7 │ ["49"]    42      0.102289    0.214026  0.477927  2358.62     9018       2
   8 │ ["39"]    40      0.117341    0.663311  0.176902   106.519   10345       2
   9 │ ["40"]    49      0.330551    0.575076  0.574794  2668.42    29142       2
  10 │ ["49"]    40      0.330551    0.691634  0.477927   111.067   29142       2
  11 │ ["42"]    49      0.102289    0.603413  0.169517  2799.9      9018       2
  12 │ ["40"]    39      0.117341    0.204144  0.574794    67.6607  10345       2
  13 │ ["42"]    40      0.129466    0.763734  0.169517   122.645   11414       2
```

Generate frequent itemsets with a minimum support of 5,000 transactions using _ECLAT_

```julia
itemsets = eclat(data, 5000)
```
Result:
```
15×4 DataFrame
 Row │ Itemset             Support    N      Length 
     │ Array…              Float64    Int64  Int64  
─────┼──────────────────────────────────────────────
   1 │ ["42"]              0.169517   14945       1
   2 │ ["33"]              0.172036   15167       1
   3 │ ["39"]              0.176902   15596       1
   4 │ ["49"]              0.477927   42135       1
   5 │ ["40"]              0.574794   50675       1
   6 │ ["39", "49"]        0.0901068   7944       2
   7 │ ["49", "40"]        0.330551   29142       2
   8 │ ["39", "49", "40"]  0.0692135   6102       3
   9 │ ["39", "40"]        0.117341   10345       2
  10 │ ["42", "49"]        0.102289    9018       2
  11 │ ["42", "49", "40"]  0.0835507   7366       3
  12 │ ["42", "40"]        0.129466   11414       2
  13 │ ["33", "49"]        0.0911277   8034       2
  14 │ ["33", "49", "40"]  0.0612736   5402       3
  15 │ ["33", "40"]        0.095903    8455       2
```
## Multithreading
RuleMiner.jl makes use of Julia's native multithreading support for significant performance gains. Enabling multithreading is done by using the `-t` flag when launching Julia and either specifying the number of threads or passing in the `auto` argument to launch julia with all available threads.

```bash
$ julia -t auto
```
Once Julia is launched, you can can view the enabled threads with `nthreads()` from the `Base.Threads` module.
```julia-repl
julia> using Base.Threads

julia> nthreads()
```
See [this post](https://julialang.org/blog/2019/07/multithreading/) for more info on multithreading in Julia.

> [!TIP]
> Multithreading can be configured for the VScode integrated terminal by setting the `julia.NumThreads` parameter in VScode settings.

## Future Work
Support for the FP-Growth Algorithm is planned for RuleMiner 0.2.0. Future releases will support additional mining algorithms.

## References
[^1]: Agrawal, Rakesh, and Ramakrishnan Srikant. “Fast Algorithms for Mining Association Rules in Large Databases.” In Proceedings of the 20th International Conference on Very Large Data Bases, 487–99. VLDB ’94. San Francisco, CA, USA: Morgan Kaufmann Publishers Inc., 1994.

[^2]: Zaki, Mohammed. “Scalable Algorithms for Association Mining.” Knowledge and Data Engineering, IEEE Transactions On 12 (June 1, 2000): 372–90. https://doi.org/10.1109/69.846291.

[^3]: Han, Jiawei, Jian Pei, and Yiwen Yin. “Mining Frequent Patterns without Candidate Generation.” SIGMOD Rec. 29, no. 2 (May 16, 2000): 1–12. https://doi.org/10.1145/335191.335372.

[^4]: Grahne, Gösta, and Jianfei Zhu. “Fast Algorithms for Frequent Itemset Mining Using FP-Trees.” IEEE Transactions on Knowledge and Data Engineering 17, no. 10 (October 2005): 1347–62. https://doi.org/10.1109/TKDE.2005.166.