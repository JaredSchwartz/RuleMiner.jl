# Closed Itemset Mining

![Diagram showing maximal itemsets as a subset of closed itemsets which are a subset of frequent itemsets](assets/closed.png)
## Description

Closed itemset mining is a set of techniques focused on discovering closed itemsets in a transactional dataset. A closed itemset is one which appears frequently in the data (above the minimum support threshold) and which has no superset with the same support. In other words, closed itemsets are the largest possible combinations of items that share the same transactions. They represent a lossless compression of the set of all frequent itemsets, as the support of any frequent itemset can be derived from the closed itemsets. 

The key advantage of mining closed itemsets is that it provides a compact yet complete representation of all frequent patterns in the data. By identifying only the closed frequent itemsets, the number of patterns generated is significantly reduced compared to mining all frequent itemsets while still retaining all support information. This approach strikes a balance between the compactness of maximal itemsets and the completeness of all frequent itemsets. Closed itemset mining is particularly useful in scenarios where both the frequency and the exact composition of itemsets are important, but compression of the results is desired.

## Formal Definition
Let:
- ``I`` be the set of all items in the dataset
- ``X`` be an itemset, where ``X \subseteq I``
- ``D`` be the set of all transactions in the dataset
- ``\sigma(X)`` be the support of itemset ``X`` in ``D``
- ``\sigma_{min}`` be the minimum support threshold

Then, an itemset ``X`` is a closed frequent itemset if and only if:

- The support of ``X`` is greater than or equal to the minimum support threshold:
```math
\sigma(X) \geq \sigma_{min}
```
- There does not exist a proper superset ``Y`` of ``X`` with the same support: 
```math
\nexists Y \supset X : \sigma(Y) = \sigma(X)
```

Thus, ``CFI``, the set of all closed frequent itemsets in ``I``, can be expressed as:

```math
CFI = {X \mid X \subseteq I \wedge \sigma(X) \geq \sigma_{min} \wedge \nexists Y \supset X : \sigma(Y) = \sigma(X)}
```
## Algorithms

### CHARM
The `charm` function implements the CHARM ([C]losed, [H]ash-based [A]ssociation [R]ule [M]ining) algorithm for mining closed itemsets proposed by Mohammad Zaki and Ching-Jui Hsiao in 2002. This algorithm uses a depth-first search with hash-based pruning approaches for non-closed itemsets and is particularly efficient for sparse datasets.

```@docs
charm(txns::Transactions, min_support::Union{Int,Float64})
```

### FPClose
The `fpclose` function implements the FPClose ([F]requent [P]attern Close) algorithm for mining closed itemsets. This algorithm, proposed by Gösta Grahne and Jianfei Zhu in 2005, builds on the FP-Growth alogrithm to discover closed itemsets in a dataset without candidate generation. It inherits many of the advantages of FP-Growth when it comes to dense datasets.

```@docs
fpclose(txns::Transactions, min_support::Union{Int,Float64})
```

### LCM
The `LCM` function implements the LCM ([L]inear-time [C]losed [M]iner) algorithm for mining frequent closed itemsets first proposed by Uno et al. in 2004. This is an efficient method for discovering closed itemsets in a dataset with a linear time complexity. It is typically faster than other algorithms and has a more balance profile that achieves fast mining on both sparse and dense datasets.

```@docs
   LCM(txns::Transactions, min_support::Union{Int,Float64})
```

### CARPENTER
The `carpenter` function implements the CARPENTER ([C]losed [P]att[e]r[n] Discovery by [T]ransposing Tabl[e]s that a[r]e Extremely Long) algorithm for mining closed itemsets proposed by Pan et al. in 2003. This algorithm uses a transposed structure to optimize for datasets that have far more items than transactions, such as those found in genetic research and bioinformatics. It is not well suited to datasets in the more standard transaction-major format.

```@docs
carpenter(txns::Transactions, min_support::Union{Int,Float64})
```