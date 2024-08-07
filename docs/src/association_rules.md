# Association Rule Mining

## Description

Association rule mining is a fundamental technique in data mining and machine learning that aims to uncover interesting relationships, correlations, or patterns within large datasets. Originally developed for market basket analysis in retail, it has since found applications in various fields such as web usage mining, intrusion detection, and bioinformatics. The primary goal of association rule mining is to identify strong rules discovered in databases using different measures of interestingness.

At its core, association rule mining works by examining frequent if-then patterns in transactional databases. These patterns, known as association rules, take the form "if A, then B," where A and B are sets of items. For example, in a supermarket context, a rule might be "if a customer buys bread and butter, they are likely to buy milk." The strength of these rules is typically measured by support (how frequently the items appear together), confidence (how often the rule is found to be true), and lift (the ratio of observed support to expected support if A and B were independent). By setting minimum thresholds for these metrics, analysts can filter out weak or uninteresting rules and focus on those that are most likely to provide valuable insights or actionable information.

## Formal Definition
Let:

- ``I = {i_1, i_2, ..., i_n}`` be the set of all items in the dataset
- ``D = {T_1, T_2, ..., T_m}`` be the set of all transactions, where each ``T_j \subseteq I``
- ``A, B \subseteq I`` and ``A \cap B = \emptyset``

An association rule is an implication of the form ``A \Rightarrow B``, where:

- ``A`` is called the antecedent (or left-hand side)
- ``B`` is called the consequent (or right-hand side)

For a given rule ``A \Rightarrow B``, these measures are defined:

- Support: ``\sigma(A \Rightarrow B) = \frac{|{T_j \in D : A \cup B \subseteq T_j}|}{|D|}``
- Confidence: ``\chi(A \Rightarrow B) = \frac{\sigma(A \cup B)}{\sigma(A)}``
- Lift: ``\gamma(A \Rightarrow B) = \frac{\sigma(A \cup B)}{\sigma(A) \cdot \sigma(B)}``

Let ``\sigma_{min}`` and ``\chi_{min}`` be user-defined minimum thresholds for support and confidence, respectively.

Then, the set of all valid association rules (AR) can be defined as:

```math
AR = {(A \Rightarrow B) \mid A, B \subseteq I \newline
\wedge  A \cap B = \emptyset \\
\wedge \sigma(A \Rightarrow B) \geq \sigma_{min} \\
\wedge  \chi(A \Rightarrow B) \geq \chi_{min}}
```

The process of association rule mining involves:

- Finding all frequent itemsets ``F = {Z \subseteq I \mid \sigma(Z) \geq \sigma_{min}}``
- For each frequent itemset ``Z \in F``, generate all non-empty subsets ``A \subset Z``
- For each such subset ``A``, form the rule ``A \Rightarrow (Z \setminus A)`` if ``\chi(A \Rightarrow (Z \setminus A)) \geq \chi_{min}``

## Algorithms

### A Priori

The `apriori` function implements the A Priori algorithm for association rule mining first proposed by Rakesh Agrawal and Srikant Ramakrishnan in 1994. This algorithm identifies frequent itemsets in a dataset and generates association rules based on specified support thresholds.

```@docs
apriori(txns::Transactions, min_support::Union{Int,Float64}, max_length::Int)
```