# Closed Itemset Mining

![Diagram showing maximal itemsets as a subset of closed itemsets which are a subset of frequent itemsets](../assets/closed.png)
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
