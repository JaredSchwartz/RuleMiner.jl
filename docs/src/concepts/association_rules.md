# Association Rule Mining

Association rule mining is a fundamental technique in data mining focused on discovering relationships between items in transaction data. These rules reveal correlations that provide valuable insights for market basket analysis, recommendation systems, and business decision-making, as well as significant applications in computational biology for identifying gene associations and in population health for discovering disease co-occurrence patterns.

## Association Rules

Association rules represent relationships between sets of items in transaction data. A rule takes the form "if A, then B" (written as A → B), where A is the antecedent (left-hand side) and B is the consequent (right-hand side). For example, in retail analysis, a rule {bread, butter} → {milk} suggests that customers who purchase bread and butter are likely to purchase milk as well.

### Formal Definition
Let:
- ``I = \{i_1, i_2, ..., i_n\}`` be the set of all items in the dataset
- ``D = \{T_1, T_2, ..., T_m\}`` be the set of all transactions, where each ``T_j \subseteq I``
- ``A, B \subseteq I`` and ``A \cap B = \emptyset``

An association rule is an implication of the form ``A \Rightarrow B``, where:

- ``A`` is called the antecedent (or left-hand side)
- ``B`` is called the consequent (or right-hand side)

## Mining Process

Let ``\sigma_{min}`` and ``\chi_{min}`` be user-defined minimum thresholds for support and confidence, respectively.

Then, the set of all valid association rules (AR) can be defined as:

```math
AR = \{(A \Rightarrow B) \mid A, B \subseteq I \newline
\wedge  A \cap B = \emptyset \\
\wedge \sigma(A \Rightarrow B) \geq \sigma_{min} \\
\wedge  \chi(A \Rightarrow B) \geq \chi_{min}\}
```

The process of association rule mining involves:

1. Finding all frequent itemsets ``F = \{Z \subseteq I \mid \sigma(Z) \geq \sigma_{min}\}``
2. For each frequent itemset ``Z \in F``, generate all non-empty subsets ``A \subset Z``
3. For each such subset ``A``, form the rule ``A \Rightarrow (Z \setminus A)`` if ``\chi(A \Rightarrow (Z \setminus A)) \geq \chi_{min}``

## Rule Evaluation Metrics

The main challenge in association rule mining is efficiently discovering meaningful rules from large datasets while filtering out weak or uninteresting patterns using various interestingness measures.

To evaluate the strength and significance of association rules, several key metrics are used:

### Support

Support measures how frequently the itemset (A ∪ B) appears in the dataset.

```math
\sigma(A \Rightarrow B) = \frac{|{T_j \in D : A \cup B \subseteq T_j}|}{|D|}
```

### Confidence

Confidence measures how often the rule is found to be true. It represents the conditional probability of finding B given that a transaction contains A.

```math
\chi(A \Rightarrow B) = \frac{\sigma(A \cup B)}{\sigma(A)}
```

### Coverage

Coverage (sometimes called support of A) measures how often A appears in the dataset, regardless of B.

```math
\gamma(A \Rightarrow B) = \sigma(A) = \frac{|{T_j \in D : A \subseteq T_j}|}{|D|}
```

### Lift

Lift measures how much more likely B is to be present when A is present, compared to when A is absent. It indicates the strength of association beyond random co-occurrence.

```math
L(A \Rightarrow B) = \frac{\sigma(A \cup B)}{\sigma(A) \cdot \sigma(B)}
```