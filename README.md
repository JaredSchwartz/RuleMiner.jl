<p align="center">
<img width="400px" src="./docs/src/assets/logo.svg" title="RuleMiner logo">
</p>

# RuleMiner.jl - Data Mining in Julia
[![Build Status](https://github.com/JaredSchwartz/RuleMiner.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JaredSchwartz/RuleMiner.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![codecov](https://codecov.io/github/JaredSchwartz/RuleMiner.jl/graph/badge.svg?token=KDAVR32F6S)](https://codecov.io/github/JaredSchwartz/RuleMiner.jl)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://jaredschwartz.github.io/RuleMiner.jl/stable/)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://jaredschwartz.github.io/RuleMiner.jl/dev/)

## About
RuleMiner.jl is a Julia package for data mining inspired by the [arules](https://github.com/mhahsler/arules) R package and [SPMF](https://www.philippe-fournier-viger.com/spmf/) Java library.

Key features of RuleMiner.jl include:

- Support for Julia's native multithreading capabilities for improved performance
- Direct interfaces with DataFrames.jl for loading transactional data and exporting results
- Flexible handling of either relative (percentage) support or absolute (count) support in minimum support thresholds

## Algorithms
The package currently has support for these algorithms:

**Association Rule Mining**
- A Priori[^1]

**Frequent Itemset Mining**
- FP-Growth[^2]
- ECLAT[^3]

**Closed Itemset Mining**
- FPClose[^4]
- CHARM[^5]
- LCM[^6]
- CARPENTER[^7]

**Maximal Itemset Mining**
- FPMax[^8]
- GenMax[^9]

**Frequent Itemset Recovery**
- RecoverClosed[^10] (recovery from closed itemsets)
- RecoverMax (recovery from maximal itemsets)

## Contributing
Contributions are welcome!

Please open an issue before opening a PR.

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
### Create Txns objects
Load transactions from a file into Txns

```julia
data = Txns("retail.txt",' ')
```
Result:
```
Txns with 88162 transactions, 16470 items, and 908576 non-zero elements
 Index │ Items                                                                                                                               
───────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
     1 │ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30
     2 │ 31, 32, 33
     3 │ 34, 35, 36
     4 │ 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47
     5 │ 39, 40, 48, 49
     6 │ 39, 40, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59
     ⋮ │ ⋮
 88156 │ 40, 42, 49, 244, 343, 439, 549, 704, 927, 968, 1061, 1281, 1773, 1815, 2013, 2715, 2793, 4593, 4647, 4699, 9151, 12933, 13335, 4894…
 88157 │ 49, 202, 256, 279, 408, 480, 768, 825, 987, 1396, 1599, 2023, 2284, 2376, 6726, 13335, 14007, 14100
 88158 │ 40, 876, 2666, 2963, 12960, 14071, 14407, 15519, 16380
 88159 │ 40, 42, 102, 347, 394, 414, 480, 523, 587, 636, 696, 800, 1467, 1787, 1995, 2450, 2831, 3036, 3592, 3723, 6218, 11494, 12130, 13034
 88160 │ 2311, 4268
 88161 │ 40, 49, 2529
 88162 │ 33, 40, 206, 243, 1394
```
Or alternatively convert an existing 1-hot encoded DataFrame. 
```julia
data = Txns(df)
```
### Mine patterns from Txns objects
Generate association rules using _A Priori_ with 10% minimum support, any confidence, and a max rule length of 3.

```julia
arules = apriori(data, 0.1, 0.0, 3)
```
Result:
```
13×8 DataFrame
 Row │ LHS       RHS     Support   Confidence  Coverage  Lift     N      Length 
     │ Array…    String  Float64   Float64     Float64   Float64  Int64  Int64  
─────┼──────────────────────────────────────────────────────────────────────────
   1 │ String[]  33      0.172036    0.172036  1.0       1.0      15167       1
   2 │ String[]  39      0.176902    0.176902  1.0       1.0      15596       1
   3 │ String[]  40      0.574794    0.574794  1.0       1.0      50675       1
   4 │ String[]  42      0.169517    0.169517  1.0       1.0      14945       1
   5 │ String[]  49      0.477927    0.477927  1.0       1.0      42135       1
   6 │ ["42"]    40      0.129466    0.763734  0.169517  1.32871  11414       2
   7 │ ["40"]    42      0.129466    0.225239  0.574794  1.32871  11414       2
   8 │ ["40"]    39      0.117341    0.204144  0.574794  1.154    10345       2
   9 │ ["39"]    40      0.117341    0.663311  0.176902  1.154    10345       2
  10 │ ["40"]    49      0.330551    0.575076  0.574794  1.20327  29142       2
  11 │ ["42"]    49      0.102289    0.603413  0.169517  1.26256   9018       2
  12 │ ["49"]    40      0.330551    0.691634  0.477927  1.20327  29142       2
  13 │ ["49"]    42      0.102289    0.214026  0.477927  1.26256   9018       2
```

Generate frequent itemsets with a minimum support of 5,000 transactions using _ECLAT_

```julia
itemsets = eclat(data, 5_000)
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
Future versions will support sequential mining algorithms and high-utility mining algorithms.

## References
[^1]: Agrawal, Rakesh, and Ramakrishnan Srikant. “Fast Algorithms for Mining Association Rules in Large Databases.” In Proceedings of the 20th International Conference on Very Large Data Bases, 487–99. VLDB ’94. San Francisco, CA, USA: Morgan Kaufmann Publishers Inc., 1994.

[^2]: Han, Jiawei, Jian Pei, and Yiwen Yin. “Mining Frequent Patterns without Candidate Generation.” SIGMOD Rec. 29, no. 2 (May 16, 2000): 1–12. https://doi.org/10.1145/335191.335372.

[^3]: Zaki, Mohammed. “Scalable Algorithms for Association Mining.” Knowledge and Data Engineering, IEEE Transactions On 12 (June 1, 2000): 372–90. https://doi.org/10.1109/69.846291.

[^4]: Grahne, Gösta, and Jianfei Zhu. “Fast Algorithms for Frequent Itemset Mining Using FP-Trees.” IEEE Transactions on Knowledge and Data Engineering 17, no. 10 (October 2005): 1347–62. https://doi.org/10.1109/TKDE.2005.166.

[^5]: Zaki, Mohammed, and Ching-Jui Hsiao. “CHARM: An Efficient Algorithm for Closed Itemset Mining.” In Proceedings of the 2002 SIAM International Conference on Data Mining (SDM), 457–73. Proceedings. Society for Industrial and Applied Mathematics, 2002. https://doi.org/10.1137/1.9781611972726.27.

[^6]: Uno, Takeaki, Tatsuya Asai, Yuzo Uchida, and Hiroki Arimura. “An Efficient Algorithm for Enumerating Closed Patterns in Transaction Databases.” In Discovery Science, edited by Einoshin Suzuki and Setsuo Arikawa, 16–31. Berlin, Heidelberg: Springer, 2004. https://doi.org/10.1007/978-3-540-30214-8_2.

[^7]: Pan, Feng, Gao Cong, Anthony K. H. Tung, Jiong Yang, and Mohammed J. Zaki. “Carpenter: Finding Closed Patterns in Long Biological Datasets.” In Proceedings of the Ninth ACM SIGKDD International Conference on Knowledge Discovery and Data Mining, 637–42. KDD ’03. New York, NY, USA: Association for Computing Machinery, 2003. https://doi.org/10.1145/956750.956832.

[^8]: Grahne and Zhu, “Fast Algorithms for Frequent Itemset Mining Using FP-Trees.”

[^9]: Gouda, Karam, and Mohammed J. Zaki. “GenMax: An Efficient Algorithm for Mining Maximal Frequent Itemsets.” Data Mining and Knowledge Discovery 11, no. 3 (November 1, 2005): 223–42. https://doi.org/10.1007/s10618-005-0002-x.

[^10]: Pasquier, Nicolas, Yves Bastide, Rafik Taouil, and Lotfi Lakhal. “Efficient Mining of Association Rules Using Closed Itemset Lattices.” Information Systems 24, no. 1 (March 1, 1999): 25–46. https://doi.org/10.1016/S0306-4379(99)00003-4.
