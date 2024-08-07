# RuleMiner.jl

## Introduction
RuleMiner.jl is a Julia package for association rule and frequent itemset mining inspired by the [arules](https://github.com/mhahsler/arules) R package and [SPMF](https://www.philippe-fournier-viger.com/spmf/) Java library.

Key features of RuleMiner.jl include:

- Support for Julia's native multithreading capabilities for improved performance
- Direct interfaces with DataFrames.jl for loading transactional data and exporting results
- Flexible handling of either relative (percentage) support or absolute (count) support in minimum support thresholds

## Contents
```@contents
Pages = ["association_rules.md", "frequent_itemsets.md", "closed_itemsets.md","maximal_itemsets.md","transactions.md"]
Depth = 2
```