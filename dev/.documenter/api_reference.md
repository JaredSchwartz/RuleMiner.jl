


# API Reference {#API-Reference}

## Association Rule Mining {#Association-Rule-Mining}
<details class='jldocstring custom-block' >
<summary><a id='RuleMiner.apriori-Tuple{Transactions, Union{Float64, Int64}, Float64, Int64}' href='#RuleMiner.apriori-Tuple{Transactions, Union{Float64, Int64}, Float64, Int64}'><span class="jlbinding">RuleMiner.apriori</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
apriori(
    txns::Transactions,
    min_support::Union{Int,Float64},
    min_confidence::Float64=0.0,
    max_length::Int=0
)::DataFrame
```


Identify association rules in a transactional dataset using the A Priori Algorithm

**Arguments**
- `txns::Transactions`: A `Transactions` object containing the dataset to mine.
  
- `min_support::Union{Int,Float64}`: The minimum support threshold. If an `Int`, it represents  the absolute support. If a `Float64`, it represents relative support.
  
- `min_confidence::Float64`: The minimum confidence percentage for returned rules.
  
- `max_length::Int`: The maximum length of the rules to be generated. Length of 0 searches for all rules.
  

**Returns**

A DataFrame containing the discovered association rules with the following columns:
- `LHS`: The left-hand side (antecedent) of the rule.
  
- `RHS`: The right-hand side (consequent) of the rule.
  
- `Support`: Relative support of the rule.
  
- `Confidence`: Confidence of the rule.
  
- `Coverage`: Coverage (RHS support) of the rule.
  
- `Lift`: Lift of the association rule.
  
- `N`: Absolute support of the association rule.
  
- `Length`: The number of items in the association rule.
  

**Description**

The Apriori algorithm employs a breadth-first, level-wise search strategy to discover  frequent itemsets. It starts by identifying frequent individual items and iteratively  builds larger itemsets by combining smaller frequent itemsets. At each iteration, it  generates candidate itemsets of size k from itemsets of size k-1, then prunes infrequent candidates and their subsets. 

The algorithm uses the downward closure property, which states that any subset of a frequent itemset must also be frequent. This is the defining pruning technique of A Priori. Once all frequent itemsets up to the specified maximum length are found, the algorithm generates association rules and  calculates their support, confidence, and other metrics.

**Examples**

```julia
txns = Txns("transactions.txt", ' ')

# Find all rules with 5% min support and max length of 3
result = apriori(txns, 0.05, 0.0, 3)

# Find rules with with at least 5,000 instances and minimum confidence of 50%
result = apriori(txns, 5_000, 0.5)
```


**References**

Agrawal, Rakesh, and Ramakrishnan Srikant. “Fast Algorithms for Mining Association Rules in Large Databases.” In Proceedings of the 20th International Conference on Very Large Data Bases, 487–99. VLDB ’94. San Francisco, CA, USA: Morgan Kaufmann Publishers Inc., 1994.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JaredSchwartz/RuleMiner.jl/blob/cdfcb894ff501dfa1444c692c53c1f6d1be0a5b4/src/association_rules/apriori.jl#L29-L80" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Itemset Mining {#Itemset-Mining}

### Frequent Itemset Mining {#Frequent-Itemset-Mining}
<details class='jldocstring custom-block' >
<summary><a id='RuleMiner.eclat-Tuple{Transactions, Union{Float64, Int64}}' href='#RuleMiner.eclat-Tuple{Transactions, Union{Float64, Int64}}'><span class="jlbinding">RuleMiner.eclat</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
eclat(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
```


Perform frequent itemset mining using the ECLAT (Equivalence CLAss Transformation) algorithm  on a transactional dataset.

ECLAT is an efficient algorithm for discovering frequent itemsets, which are sets of items  that frequently occur together in the dataset.

**Arguments**
- `txns::Transactions`: A `Transactions` object containing the dataset to mine.
  
- `min_support::Union{Int,Float64}`: The minimum support threshold. If an `Int`, it represents  the absolute support. If a `Float64`, it represents relative support.
  

**Returns**

A DataFrame containing the discovered frequent itemsets with the following columns:
- `Itemset`: Vector of item names in the frequent itemset.
  
- `Support`: Relative support of the itemset.
  
- `N`: Absolute support count of the itemset.
  
- `Length`: Number of items in the itemset.
  

**Algorithm Description**

The ECLAT algorithm uses a depth-first search strategy and a vertical database layout to  efficiently mine frequent itemsets. It starts by computing the support of individual items,  sorts them in descending order of frequency, and then recursively builds larger itemsets. ECLAT&#39;s depth-first approach enables it to quickly identify long frequent itemsets, and it is most efficient for sparse datasets

**Example**

```julia
txns = Txns("transactions.txt", ' ')

# Find frequent itemsets with 5% minimum support
result = eclat(txns, 0.05)

# Find frequent itemsets with minimum 5,000 transactions
result = eclat(txns, 5_000)
```


**References**

Zaki, Mohammed. “Scalable Algorithms for Association Mining.” Knowledge and Data Engineering, IEEE Transactions On 12 (June 1, 2000): 372–90. https://doi.org/10.1109/69.846291.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JaredSchwartz/RuleMiner.jl/blob/cdfcb894ff501dfa1444c692c53c1f6d1be0a5b4/src/itemsets/frequent/eclat.jl#L6-L45" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' >
<summary><a id='RuleMiner.fpgrowth-Tuple{Transactions, Union{Float64, Int64}}' href='#RuleMiner.fpgrowth-Tuple{Transactions, Union{Float64, Int64}}'><span class="jlbinding">RuleMiner.fpgrowth</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
fpgrowth(data::Union{Transactions,FPTree}, min_support::Union{Int,Float64})::DataFrame
```


Identify frequent itemsets in a transactional dataset or an FP-tree with the FPGrowth algorithm.

**Arguments**
- `data::Union{Transactions,FPTree}`: Either a `Transactions` object containing the dataset to mine, or a pre-constructed `FPTree` object.
  
- `min_support::Union{Int,Float64}`: The minimum support threshold. If an `Int`, it represents  the absolute support. If a `Float64`, it represents relative support.
  

**Returns**
- `DataFrame`: A DataFrame containing the frequent itemsets, with columns:
  - `Itemset`: The items in the frequent itemset.
    
  - `Support`: The relative support of the itemset as a proportion of total transactions.
    
  - `N`: The absolute support count of the itemset.
    
  - `Length`: The number of items in the itemset.
    
  

**Description**

The FPGrowth algorithm is a mining technique that builds a compact summary of the transaction  data called an FP-tree. This tree structure summarizes the supports and relationships between  items in a way that can be easily traversed and processed to find frequent itemsets.  FPGrowth is particularly efficient for datasets with long transactions or sparse frequent itemsets.

The algorithm operates in two main phases:
1. FP-tree Construction: Builds a compact representation of the dataset, organizing items  by their frequency to allow efficient mining. This step is skipped if an FPTree is provided.
  
2. Recursive Tree Traversal: 
  - Processes itemsets from least frequent to most frequent.
    
  - For each item, creates a conditional FP-tree and recursively mines it.
    
  

**Example**

```julia
# Using a Transactions object
txns = Txns("transactions.txt", ' ')
result = fpgrowth(txns, 0.05)  # Find frequent itemsets with 5% minimum support

# Using a pre-constructed FPTree
tree = FPTree(txns, 5000)  # Construct FP-tree with minimum support of 5000
result = fpgrowth(tree, 6000)  # Find frequent itemsets with minimum support of 6000
```


**References**

Han, Jiawei, Jian Pei, and Yiwen Yin. &quot;Mining Frequent Patterns without Candidate Generation.&quot;  SIGMOD Rec. 29, no. 2 (May 16, 2000): 1–12. https://doi.org/10.1145/335191.335372.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JaredSchwartz/RuleMiner.jl/blob/cdfcb894ff501dfa1444c692c53c1f6d1be0a5b4/src/itemsets/frequent/fpgrowth.jl#L6-L52" target="_blank" rel="noreferrer">source</a></Badge>

</details>


### Closed Itemset Mining {#Closed-Itemset-Mining}
<details class='jldocstring custom-block' >
<summary><a id='RuleMiner.charm-Tuple{Transactions, Union{Float64, Int64}}' href='#RuleMiner.charm-Tuple{Transactions, Union{Float64, Int64}}'><span class="jlbinding">RuleMiner.charm</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
charm(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
```


Identify closed frequent itemsets in a transactional dataset with the CHARM algorithm.

**Arguments**
- `txns::Transactions`: A `Transactions` object containing the dataset to mine.
  
- `min_support::Union{Int,Float64}`: The minimum support threshold. If an `Int`, it represents  the absolute support. If a `Float64`, it represents relative support.
  

**Returns**
- `DataFrame`: A DataFrame containing the maximal frequent itemsets, with columns:
  - `Itemset`: The items in the maximal frequent itemset.
    
  - `Support`: The relative support of the itemset as a proportion of total transactions.
    
  - `N`: The absolute support count of the itemset.
    
  - `Length`: The number of items in the itemset.
    
  

**Description**

CHARM is an algorithm that builds on the ECLAT algorithm but adds additional closed-ness checking to return only closed itemsets. It uses a depth-first approach, exploring the search space and checking found itemsets against previously discovered itemsets to determine closedness.

**Example**

```julia
txns = Txns("transactions.txt", ' ')

# Find closed frequent itemsets with 5% minimum support
result = charm(txns, 0.05)

# Find closed frequent itemsets with minimum 5,000 transactions
result = charm(txns, 5_000)
```


**References**

Zaki, Mohammed, and Ching-Jui Hsiao. “CHARM: An Efficient Algorithm for Closed Itemset Mining.” In Proceedings of the 2002 SIAM International Conference on Data Mining (SDM), 457–73. Proceedings. Society for Industrial and Applied Mathematics, 2002. https://doi.org/10.1137/1.9781611972726.27.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JaredSchwartz/RuleMiner.jl/blob/cdfcb894ff501dfa1444c692c53c1f6d1be0a5b4/src/itemsets/closed/charm.jl#L6-L39" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' >
<summary><a id='RuleMiner.fpclose-Tuple{Transactions, Union{Float64, Int64}}' href='#RuleMiner.fpclose-Tuple{Transactions, Union{Float64, Int64}}'><span class="jlbinding">RuleMiner.fpclose</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
fpclose(data::Union{Transactions,FPTree}, min_support::Union{Int,Float64})::DataFrame
```


Identify closed frequent itemsets in a transactional dataset or an FP-tree with the FPClose algorithm.

**Arguments**
- `data::Union{Transactions,FPTree}`: Either a `Transactions` object containing the dataset to mine, or a pre-constructed `FPTree` object.
  
- `min_support::Union{Int,Float64}`: The minimum support threshold. If an `Int`, it represents  the absolute support. If a `Float64`, it represents relative support.
  

**Returns**
- `DataFrame`: A DataFrame containing the closed frequent itemsets, with columns:
  - `Itemset`: The items in the closed frequent itemset.
    
  - `Support`: The relative support of the itemset as a proportion of total transactions.
    
  - `N`: The absolute support count of the itemset.
    
  - `Length`: The number of items in the itemset.
    
  

**Description**

The FPClose algorithm is an extension of FP-Growth with additional pruning techniques  to focus on mining closed itemsets. The algorithm operates in two main phases:
1. FP-tree Construction: Builds a compact representation of the dataset, organizing items  by their frequency to allow efficient mining. This step is skipped if an FPTree is provided.
  
2. Recursive Tree Traversal: 
  - Processes itemsets from least frequent to most frequent.
    
  - For each item, creates a conditional FP-tree and recursively mines it.
    
  - Uses a depth-first search strategy, exploring longer itemsets before shorter ones.
    
  - Employs pruning techniques to avoid generating non-closed itemsets.
    
  

FPClose is particularly efficient for datasets with long transactions or sparse frequent itemsets,  as it can significantly reduce the number of generated itemsets compared to algorithms that  find all frequent itemsets.

**Example**

```julia
# Using a Transactions object
txns = Txns("transactions.txt", ' ')
result = fpclose(txns, 0.05)  # Find closed frequent itemsets with 5% minimum support

# Using a pre-constructed FPTree
tree = FPTree(txns, 5000)  # Construct FP-tree with minimum support of 5000
result = fpclose(tree, 6000)  # Find closed frequent itemsets with minimum support of 6000
```


**References**

Grahne, Gösta, and Jianfei Zhu. &quot;Fast Algorithms for Frequent Itemset Mining Using FP-Trees.&quot;  IEEE Transactions on Knowledge and Data Engineering 17, no. 10 (October 2005): 1347–62.  https://doi.org/10.1109/TKDE.2005.166.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JaredSchwartz/RuleMiner.jl/blob/cdfcb894ff501dfa1444c692c53c1f6d1be0a5b4/src/itemsets/closed/fpclose.jl#L6-L55" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' >
<summary><a id='RuleMiner.LCM-Tuple{Transactions, Union{Float64, Int64}}' href='#RuleMiner.LCM-Tuple{Transactions, Union{Float64, Int64}}'><span class="jlbinding">RuleMiner.LCM</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
LCM(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
```


Identify closed frequent itemsets in a transactional dataset with the LCM algorithm.

**Arguments**
- `txns::Transactions`: A `Transactions` object containing the dataset to mine.
  
- `min_support::Union{Int,Float64}`: The minimum support threshold. If an `Int`, it represents  the absolute support. If a `Float64`, it represents relative support.
  

**Returns**
- `DataFrame`: A DataFrame containing the maximal frequent itemsets, with columns:
  - `Itemset`: The items in the maximal frequent itemset.
    
  - `Support`: The relative support of the itemset as a proportion of total transactions.
    
  - `N`: The absolute support count of the itemset.
    
  - `Length`: The number of items in the itemset.
    
  

**Description**

LCM is an algorithm that uses a depth-first search pattern with closed-ness checking to return only closed itemsets. It utilizes two key pruning techniques to avoid redundant mining: prefix-preserving closure extension (PPCE) and progressive database reduction (PDR).
- PPCE ensures that each branch will never overlap in the itemsets they explore by enforcing the order of the itemsets. This reduces redunant search space.
  
- PDR works with PPCE to remove data from a branch&#39;s dataset once it is determined to be not nescessary.
  

**Example**

```julia
txns = Txns("transactions.txt", ' ')

# Find closed frequent itemsets with 5% minimum support
result = LCM(txns, 0.05)

# Find closed frequent itemsets with minimum 5,000 transactions
result = LCM(txns, 5_000)
```


**References**

Uno, Takeaki, Tatsuya Asai, Yuzo Uchida, and Hiroki Arimura. “An Efficient Algorithm for Enumerating Closed Patterns in Transaction Databases.”  In Discovery Science, edited by Einoshin Suzuki and Setsuo Arikawa, 16–31. Berlin, Heidelberg: Springer, 2004. https://doi.org/10.1007/978-3-540-30214-8_2.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JaredSchwartz/RuleMiner.jl/blob/cdfcb894ff501dfa1444c692c53c1f6d1be0a5b4/src/itemsets/closed/lcm.jl#L6-L43" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' >
<summary><a id='RuleMiner.carpenter-Tuple{Transactions, Union{Float64, Int64}}' href='#RuleMiner.carpenter-Tuple{Transactions, Union{Float64, Int64}}'><span class="jlbinding">RuleMiner.carpenter</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
carpenter(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
```


Identify closed frequent itemsets in a transactional dataset with the CARPENTER algorithm.

**Arguments**
- `txns::Transactions`: A `Transactions` object containing the dataset to mine.
  
- `min_support::Union{Int,Float64}`: The minimum support threshold. If an `Int`, it represents  the absolute support. If a `Float64`, it represents relative support.
  

**Returns**
- `DataFrame`: A DataFrame containing the maximal frequent itemsets, with columns:
  - `Itemset`: The items in the maximal frequent itemset.
    
  - `Support`: The relative support of the itemset as a proportion of total transactions.
    
  - `N`: The absolute support count of the itemset.
    
  - `Length`: The number of items in the itemset.
    
  

**Description**

CARPENTER is an algorithm that progressively builds larger itemsets, checking closed-ness at each step with three key pruning strategies:
- Itemsets are skipped if they have already been marked as closed on another branch
  
- Itemsets are skipped if they do not meet minimum support
  
- Itemsets&#39; child itemsets are skipped if they change the support when the new items are added
  

CARPENTER is specialized for datasets which have few transactions, but many items per transaction and may not be the best choice for other data.

**Example**

```julia
txns = Txns("transactions.txt", ' ')

# Find closed frequent itemsets with 5% minimum support
result = carpenter(txns, 0.05)

# Find closed frequent itemsets with minimum 5,000 transactions
result = carpenter(txns, 5_000)
```


**References**

Pan, Feng, Gao Cong, Anthony K. H. Tung, Jiong Yang, and Mohammed J. Zaki. “Carpenter: Finding Closed Patterns in Long Biological Datasets.” In Proceedings of the Ninth ACM SIGKDD International Conference on Knowledge Discovery and Data Mining, 637–42. KDD ’03. New York, NY, USA: Association for Computing Machinery, 2003. https://doi.org/10.1145/956750.956832.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JaredSchwartz/RuleMiner.jl/blob/cdfcb894ff501dfa1444c692c53c1f6d1be0a5b4/src/itemsets/closed/carpenter.jl#L6-L43" target="_blank" rel="noreferrer">source</a></Badge>

</details>


### Maximal Itemset Mining {#Maximal-Itemset-Mining}
<details class='jldocstring custom-block' >
<summary><a id='RuleMiner.fpmax-Tuple{Transactions, Union{Float64, Int64}}' href='#RuleMiner.fpmax-Tuple{Transactions, Union{Float64, Int64}}'><span class="jlbinding">RuleMiner.fpmax</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
fpmax(data::Union{Transactions,FPTree}, min_support::Union{Int,Float64})::DataFrame
```


Identify maximal frequent itemsets in a transactional dataset or an FP-tree with the FPMax algorithm.

**Arguments**
- `data::Union{Transactions,FPTree}`: Either a `Transactions` object containing the dataset to mine, or a pre-constructed `FPTree` object.
  
- `min_support::Union{Int,Float64}`: The minimum support threshold. If an `Int`, it represents  the absolute support. If a `Float64`, it represents relative support.
  

**Returns**
- `DataFrame`: A DataFrame containing the maximal frequent itemsets, with columns:
  - `Itemset`: The items in the maximal frequent itemset.
    
  - `Support`: The relative support of the itemset as a proportion of total transactions.
    
  - `N`: The absolute support count of the itemset.
    
  - `Length`: The number of items in the itemset.
    
  

**Description**

The FPMax algorithm is an extension of FP-Growth with additional pruning techniques  to focus on mining maximal itemsets. The algorithm operates in three main phases:
1. FP-tree Construction: Builds a compact representation of the dataset, organizing items  by their frequency to allow efficient mining. This step is skipped if an FPTree is provided.
  
2. Recursive Tree Traversal: 
  - Processes itemsets from least frequent to most frequent.
    
  - For each item, creates a conditional FP-tree and recursively mines it.
    
  - Uses a depth-first search strategy, exploring longer itemsets before shorter ones.
    
  - Employs pruning techniques to avoid generating non-maximal itemsets.
    
  - Adds an itemset to the candidate set when no frequent superset exists.
    
  
3. Maximality Checking: After the recursive traversal, filters the candidate set to ensure  only truly maximal itemsets are included in the final output.
  

FPMax is particularly efficient for datasets with long transactions or sparse frequent itemsets,  as it can significantly reduce the number of generated itemsets compared to algorithms that  find all frequent itemsets.

**Example**

```julia
# Using a Transactions object
txns = Txns("transactions.txt", ' ')
result = fpmax(txns, 0.05)  # Find maximal frequent itemsets with 5% minimum support

# Using a pre-constructed FPTree
tree = FPTree(txns, 5000)  # Construct FP-tree with minimum support of 5000
result = fpmax(tree, 6000)  # Find maximal frequent itemsets with minimum support of 6000
```


**References**

Grahne, Gösta, and Jianfei Zhu. &quot;Fast Algorithms for Frequent Itemset Mining Using FP-Trees.&quot;  IEEE Transactions on Knowledge and Data Engineering 17, no. 10 (October 2005): 1347–62.  https://doi.org/10.1109/TKDE.2005.166.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JaredSchwartz/RuleMiner.jl/blob/cdfcb894ff501dfa1444c692c53c1f6d1be0a5b4/src/itemsets/maximal/fpmax.jl#L6-L59" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' >
<summary><a id='RuleMiner.genmax-Tuple{Transactions, Union{Float64, Int64}}' href='#RuleMiner.genmax-Tuple{Transactions, Union{Float64, Int64}}'><span class="jlbinding">RuleMiner.genmax</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
genmax(txns::Transactions, min_support::Union{Int,Float64})::DataFrame
```


Identify maximal frequent itemsets in a transactional dataset with the GenMax algorithm.

**Arguments**
- `txns::Transactions`: A `Transactions` object containing the dataset to mine.
  
- `min_support::Union{Int,Float64}`: The minimum support threshold. If an `Int`, it represents  the absolute support. If a `Float64`, it represents relative support.
  

**Returns**
- `DataFrame`: A DataFrame containing the maximal frequent itemsets, with columns:
  - `Itemset`: The items in the maximal frequent itemset.
    
  - `Support`: The relative support of the itemset as a proportion of total transactions.
    
  - `N`: The absolute support count of the itemset.
    
  - `Length`: The number of items in the itemset.
    
  

**Description**

The GenMax algorithm finds maximal frequent itemsets, which are frequent itemsets that are not  proper subsets of any other frequent itemset. It uses a depth-first search strategy with  pruning techniques like progressive focusing to discover these itemsets.

The algorithm proceeds in two main phases:
1. Candidate Generation: Uses a depth-first search to generate candidate maximal frequent itemsets.
  
2. Maximality Checking: Ensures that only truly maximal itemsets are retained in the final output.
  

**Example**

```julia
txns = Txns("transactions.txt", ' ')

# Find maximal frequent itemsets with 5% minimum support
result = genmax(txns, 0.05)

# Find maximal frequent itemsets with minimum 5,000 transactions
result = genmax(txns, 5_000)
```


**References**

Gouda, Karam, and Mohammed J. Zaki. “GenMax: An Efficient Algorithm for Mining Maximal Frequent Itemsets.” Data Mining and Knowledge Discovery 11, no. 3 (November 1, 2005): 223–42. https://doi.org/10.1007/s10618-005-0002-x.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JaredSchwartz/RuleMiner.jl/blob/cdfcb894ff501dfa1444c692c53c1f6d1be0a5b4/src/itemsets/maximal/genmax.jl#L6-L45" target="_blank" rel="noreferrer">source</a></Badge>

</details>


### Frequent Itemset Recovery {#Frequent-Itemset-Recovery}
<details class='jldocstring custom-block' >
<summary><a id='RuleMiner.recover_closed-Tuple{DataFrame, Int64}' href='#RuleMiner.recover_closed-Tuple{DataFrame, Int64}'><span class="jlbinding">RuleMiner.recover_closed</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
recover_closed(df::DataFrame, min_n::Int)::DataFrame
```


Recover frequent itemsets from a DataFrame of closed itemsets.

**Arguments**
- `df::DataFrame`: A DataFrame containing the closed frequent itemsets, with columns:
  - `Itemset`: The items in the closed frequent itemset.
    
  - `Support`: The relative support of the itemset as a proportion of total transactions.
    
  - `N`: The absolute support count of the itemset.
    
  - `Length`: The number of items in the itemset.
    
  
- `min_n::Int`: The minimum support threshold for the rules. This is the absolute (integer) support.
  

**Returns**
- `DataFrame`: A DataFrame containing all frequent itemsets, with columns:
  - `Itemset`: The items in the frequent itemset.
    
  - `N`: The absolute support count of the itemset.
    
  - `Length`: The number of items in the itemset.
    
  

**Description**

This function recovers all frequent itemsets from a set of closed itemsets. It generates all possible subsets of the closed itemsets and calculates their supports based on the smallest containing closed itemset.

The function works as follows:
1. It filters the input DataFrame to only include closed sets above the minimum support.
  
2. For each length k from 1 to the maximum itemset length: a. It generates all k-subsets of the closed itemsets. b. For each subset, it finds the smallest closed itemset containing it. c. It assigns the support of the smallest containing closed itemset to the subset.
  
3. It combines all frequent itemsets and their supports into a result DataFrame.
  

**Example**

```julia
txns = Txns("transactions.txt", ' ')

# Find closed frequent itemsets with minimum 5,000 transactions
closed_sets = fpclose(txns, 5_000)

# Recover frequent itemsets from the closed itemsets
frequent_sets = recover_closed(closed_sets, 5_000)
```


**References**

Pasquier, Nicolas, Yves Bastide, Rafik Taouil, and Lotfi Lakhal. &quot;Efficient Mining of Association Rules Using Closed Itemset Lattices.&quot; Information Systems 24, no. 1 (March 1, 1999): 25–46. https://doi.org/10.1016/S0306-4379(99)00003-4.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JaredSchwartz/RuleMiner.jl/blob/cdfcb894ff501dfa1444c692c53c1f6d1be0a5b4/src/itemsets/frequent/recovery.jl#L6-L51" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' >
<summary><a id='RuleMiner.recover_maximal-Tuple{DataFrame}' href='#RuleMiner.recover_maximal-Tuple{DataFrame}'><span class="jlbinding">RuleMiner.recover_maximal</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
recover_maximal(df::DataFrame)::DataFrame
```


Recover all frequent itemsets from a DataFrame of maximal frequent itemsets.

**Arguments**
- `df::DataFrame`: A DataFrame containing the maximal frequent itemsets, with columns:
  - `Itemset`: The items in the maximal frequent itemset.
    
  - `Length`: The number of items in the itemset.
    
  

**Returns**
- `DataFrame`: A DataFrame containing all frequent itemsets, with columns:
  - `Itemset`: The items in the frequent itemset.
    
  - `Length`: The number of items in the itemset.
    
  

**Description**

This function takes a DataFrame of maximal frequent itemsets and generates all possible subsets (including the maximal itemsets themselves) to recover the complete set of frequent itemsets. It does not calculate or recover support values, as these cannot be determined from maximal itemsets alone.

The function works as follows:
1. For each maximal itemset, it generates all possible subsets.
  
2. It combines all these subsets into a single collection of frequent itemsets.
  
3. It removes any duplicate itemsets that might arise from overlapping maximal itemsets.
  
4. It returns the result as a DataFrame, sorted by itemset length in descending order.
  

**Example**

```julia
txns = Txns("transactions.txt", ' ')

# Find maximal frequent itemsets with minimum 5,000 transactions
maximal_sets = fpmax(txns, 5_000)

# Recover frequent itemsets from the maximal itemsets
frequent_sets = recover_maximal(maximal_sets)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/JaredSchwartz/RuleMiner.jl/blob/cdfcb894ff501dfa1444c692c53c1f6d1be0a5b4/src/itemsets/frequent/recovery.jl#L121-L158" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Data Structures {#Data-Structures}

### `Transactions` Objects {#Transactions-Objects}
<details class='jldocstring custom-block' >
<summary><a id='RuleMiner.Txns' href='#RuleMiner.Txns'><span class="jlbinding">RuleMiner.Txns</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Txns <: Transactions
```


A struct representing a collection of transactions in a sparse matrix format.

**Fields**
- `matrix::SparseMatrixCSC{Bool,Int64}`: A sparse boolean matrix representing the transactions. Rows correspond to transactions, columns to items. A `true` value at position (i,j)  indicates that the item j is present in transaction i.
  
- `colkeys::Vector{String}`: A vector of item names corresponding to matrix columns.
  
- `linekeys::Vector{String}`: A vector of transaction identifiers corresponding to matrix rows.
  
- `n_transactions::Int`: The total number of transactions in the dataset.
  

**Description**

The `Txns` struct provides an efficient representation of transaction data,  particularly useful for large datasets in market basket analysis, association rule mining, or similar applications where memory efficiency is crucial.

The sparse matrix representation allows for efficient storage and computation,  especially when dealing with datasets where each transaction contains only a small  subset of all possible items.

**Constructors**

**Default Constructor**

```julia
Txns(matrix::SparseMatrixCSC{Bool,Int64}, colkeys::Vector{String}, linekeys::Vector{String})
```


**DataFrame Constructor**

```julia
Txns(df::DataFrame, indexcol::Union{Symbol,Nothing}=nothing)
```


The DataFrame constructor allows direct creation of a `Txns` object from a DataFrame:
- `df`: Input DataFrame where each row is a transaction and each column is an item.
  
- `indexcol`: Optional. Specifies a column to use as transaction identifiers.   If not provided, row numbers are used as identifiers.
  

**File Constructor**

```julia
Txns(file::String, delimiter::Union{Char,String}; id_col::Bool = false, skiplines::Int = 0, nlines::Int = 0)
```


The file constructor allows creation of a `Txns` object directly from a file:
- `file`: Path to the input file containing transaction data.
  
- `delimiter`: Character or string used to separate items in each transaction.
  

Keyword Arguments:
- `id_col`: If true, treats the first item in each line as a transaction identifier.
  
- `skiplines`: Number of lines to skip at the beginning of the file (e.g., for headers).
  
- `nlines`: Maximum number of lines to read. If 0, reads the entire file.
  

**Examples**

```julia
# Create from existing data
matrix = SparseMatrixCSC{Bool,Int64}(...)
colkeys = ["apple", "banana", "orange"]
linekeys = ["T001", "T002", "T003"]
txns = Txns(matrix, colkeys, linekeys)

# Create from DataFrame
df = DataFrame(
    ID = ["T1", "T2", "T3"],
    Apple = [1, 0, 1],
    Banana = [1, 1, 0],
    Orange = [0, 1, 1]
)
txns_from_df = Txns(df, indexcol=:ID)

# Create from file with character delimiter
txns_from_file_char = Txns("transactions.txt", ',', id_col=true, skiplines=1)

# Create from file with string delimiter
txns_from_file_string = Txns("transactions.txt", "||", id_col=true, skiplines=1)

# Access data
item_in_transaction = txns.matrix[2, 1]  # Check if item 1 is in transaction 2
item_name = txns.colkeys[1]              # Get the name of item 1
transaction_id = txns.linekeys[2]        # Get the ID of transaction 2
total_transactions = txns.n_transactions # Get the total number of transactions
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/JaredSchwartz/RuleMiner.jl/blob/cdfcb894ff501dfa1444c692c53c1f6d1be0a5b4/src/data_structures/txns.jl#L6-L83" target="_blank" rel="noreferrer">source</a></Badge>

</details>


### FP Mining Objects {#FP-Mining-Objects}
<details class='jldocstring custom-block' >
<summary><a id='RuleMiner.FPTree' href='#RuleMiner.FPTree'><span class="jlbinding">RuleMiner.FPTree</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
FPTree
```


A struct representing an FP-Tree (Frequent Pattern Tree) structure, used for efficient frequent itemset mining.

**Fields**
- `root::FPNode`: The root node of the FP-Tree.
  
- `header_table::Dict{Int, Vector{FPNode}}`: A dictionary where keys are item indices and values are vectors of FPNodes representing the item occurrences in the tree.
  
- `col_mapping::Dict{Int, Int}`: A dictionary mapping the condensed item indices to the original item indices.
  
- `min_support::Int`: The minimum support threshold used to construct the tree.
  
- `n_transactions::Int`: The total number of transactions used to build the tree.
  
- `colkeys::Vector{String}`: The original item names corresponding to the column indices.
  

**Description**

The FP-Tree is a compact representation of transaction data, designed for efficient frequent pattern mining.  It stores frequent items in a tree structure, with shared prefixes allowing for memory-efficient storage and fast traversal.

The tree construction process involves:
1. Counting item frequencies and filtering out infrequent items.
  
2. Sorting items by frequency.
  
3. Inserting transactions into the tree, with items ordered by their frequency.
  

The `header_table` provides quick access to all occurrences of an item in the tree, facilitating efficient mining operations.

**Constructors**

**Default Constructor**

```julia
FPTree()
```


**Transaction Constructor**

```julia
FPTree(txns::Transactions, min_support::Union{Int,Float64})
```


The Transaction constructor allows creation of a `FPTree` object from a `Transactions`-type object:
- `txns`: Transactions object to convert
  
- `min_support`: Minimum support for an item to be included int the tree
  

**Examples**

```julia
# Create an empty FP-Tree
empty_tree = FPTree()

# Create an FP-Tree from a Transactions object
txns = Txns("transactions.txt", ' ')
tree = FPTree(txns, 0.05)  # Using 5% minimum support

# Access tree properties
println("Minimum support: ", tree.min_support)
println("Number of transactions: ", tree.n_transactions)
println("Number of unique items: ", length(tree.header_table))

# Traverse the tree (example)
function traverse(node::FPNode, prefix::Vector{String}=String[])
    if node.value != -1
        println(join(vcat(prefix, tree.colkeys[node.value]), " -> "))
    end
    for child in values(node.children)
        traverse(child, vcat(prefix, node.value != -1 ? [tree.colkeys[node.value]] : String[]))
    end
end

traverse(tree.root)
```


**Notes**
- The FP-Tree structure is particularly useful for algorithms like FP-Growth, FP-Close, and FP-Max.
  
- When constructing from a Transactions object, items not meeting the minimum support threshold are excluded from the tree.
  
- The tree construction process is parallelized for efficiency on multi-core systems.
  

**References**

Han, J., Pei, J., &amp; Yin, Y. (2000). Mining Frequent Patterns without Candidate Generation.  In proceedings of the 2000 ACM SIGMOD International Conference on Management of Data (pp. 1-12).


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JaredSchwartz/RuleMiner.jl/blob/cdfcb894ff501dfa1444c692c53c1f6d1be0a5b4/src/data_structures/fptree.jl#L6-L78" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' >
<summary><a id='RuleMiner.FPNode' href='#RuleMiner.FPNode'><span class="jlbinding">RuleMiner.FPNode</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
FPNode
```


A mutable struct representing a node in an FP-tree (Frequent Pattern Tree) structure.

**Fields**
- `value::Int`: The item index this node represents. For the root node, this is typically -1.
  
- `support::Int`: The number of transactions that contain this item in the path from the root to this node.
  
- `children::Dict{Int, FPNode}`: A dictionary of child nodes, where keys are item indices and values are `FPNode` objects.
  
- `parent::Union{FPNode, Nothing}`: The parent node in the FP-tree. For the root node, this is `nothing`.
  

**Description**

`FPNode` is the fundamental building block of an FP-tree. Each node represents an item in the dataset  and keeps track of how many transactions contain the path from the root to this item. The tree structure  allows for efficient mining of frequent patterns without repeated database scans.

The `children` dictionary allows for quick access to child nodes, facilitating efficient tree traversal. The `parent` reference enables bottom-up traversal, which is crucial for some frequent pattern mining algorithms.

**Constructor**

```julia
FPNode(value::Int, parent::Union{FPNode, Nothing}=nothing)
```


**Examples**

```julia
# Create a root node
root = FPNode(-1)

# Create child nodes
child1 = FPNode(1, root)
child2 = FPNode(2, root)

# Add children to the root
root.children[1] = child1
root.children[2] = child2

# Increase support of a node
child1.support += 1

# Create a grandchild node
grandchild = FPNode(3, child1)
child1.children[3] = grandchild

# Traverse the tree
function print_tree(node::FPNode, depth::Int = 0)
    println(" "^depth, "Item: ", node.value, ", Support: ", node.support)
    for child in values(node.children)
        print_tree(child, depth + 2)
    end
end

print_tree(root)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/JaredSchwartz/RuleMiner.jl/blob/cdfcb894ff501dfa1444c692c53c1f6d1be0a5b4/src/data_structures/fpnode.jl#L6-L60" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Utility Functions {#Utility-Functions}
<details class='jldocstring custom-block' >
<summary><a id='RuleMiner.txns_to_df-Tuple{Txns}' href='#RuleMiner.txns_to_df-Tuple{Txns}'><span class="jlbinding">RuleMiner.txns_to_df</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
txns_to_df(txns::Txns, id_col::Bool = false)::DataFrame
```


Convert a Txns object into a DataFrame.

**Arguments**
- `txns::Txns`: The Txns object to be converted.
  

**Returns**
- `DataFrame`: A DataFrame representation of the transactions.
  

**Description**

This function converts a Txns object, which uses a sparse matrix representation, into a DataFrame. Each row of the resulting DataFrame represents a transaction, and each column represents an item.

The values in the DataFrame are integers, where 1 indicates the presence of an item in a transaction, and 0 indicates its absence.

**Features**
- Preserves the original item names as column names.
  
- Optionally includes an &#39;Index&#39; column with the original transaction identifiers.
  

**Example**

```julia
# Assuming 'txns' is a pre-existing Txns object
df = txns_to_df(txns, id_col=true)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/JaredSchwartz/RuleMiner.jl/blob/cdfcb894ff501dfa1444c692c53c1f6d1be0a5b4/src/data_structures/txnutils.jl#L210-L238" target="_blank" rel="noreferrer">source</a></Badge>

</details>

