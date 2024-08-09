# Maximal Itemset Mining

![Diagram showing maximal itemsets as a subset of closed itemsets which are a subset of frequent itemsets](assets/maximal.png)
## Description

Maximal itemset mining is a set of techniques focused on discovering maximal itemsets in a transactional dataset. A maximal itemset is one which appears frequently in the data (above the minimum support threshold) and which is not a subset of any other frequent itemset. 

In other words, maximal itemsets are the largest possible combinations in the dataset of the items that meet a specified frequency threshold. They are a subset of closed itemsets, which in turn are a subset of all frequent itemsets.

The key advantage of mining maximal itemsets is its compact representation of all frequent patterns in the data. By identifying only the maximal frequent itemsets, the number of patterns generated is significantly reduced compared to frequent itemset mining. This approach is particularly valuable when dealing with high-dimensional data or datasets with long transactions.

## Formal Definition
Let:
- ``I`` be the set of all items in the dataset
- ``X`` be an itemset, where ``X \subseteq I``
- ``D`` be the set of all transactions in the dataset
- ``\sigma(X)`` be the support of itemset ``X`` in ``D``
- ``\sigma_{min}`` be the minimum support threshold

Then, an itemset ``X`` is a maximal frequent itemset if and only if:
1.	The support of ``X`` is greater than or equal to the minimum support threshold: 
```math
\sigma(X) \geq \sigma_{min}
```
2.	There does not exist a superset ``Y`` of ``X`` such that ``Y`` is also frequent: 
```math
\nexists Y \supset X : \sigma(Y) \geq \sigma_{min}
```

Thus, ``MFI``, the set of all maximal frequent itemsets in ``I`` can be expressed as:

```math
MFI = {X \mid X \subseteq I \wedge \sigma(X) \geq \sigma_{min} \wedge \nexists Y \supset X : \sigma(Y) \geq \sigma_{min}}
```
## Frequent Itemset Recovery

Maximal itemsets can be used to recover all frequent itemsets by generating combinations from the mined itemset. However, unlike with closed itemsets, recovering the support of the frequent combinations is not possible.

## Algorithms
### FPMax

The `fpmax` function implements the FPMax ([F]requent [P]attern Max) algorithm for mining closed itemsets. This algorithm, proposed by Gösta Grahne and Jianfei Zhu in 2005, builds on the FP-Growth alogrithm by mining FP trees to discover maximal itemsets in a dataset. It inherits many of the advantages of FP-Growth when it comes to dense datasets.

```@docs
fpmax(txns::Transactions, min_support::Union{Int,Float64})
```

### GenMax

The `genmax` function implements the GenMax algorithm for mining closed itemsets. This algorithm, proposed by Karam Gouda and Mohammad Zaki in 2005, utilizes a technique called progressive focusing to reduce the search space for maximal itemset mining.

```@docs
genmax(txns::Transactions, min_support::Union{Int,Float64})
```
