<p align="center">
<img width="400px" src="./docs/src/assets/hero.svg" title="RuleMiner logo">
</p>

# RuleMiner.jl - Data Mining in Julia
[![Build Status](https://github.com/JaredSchwartz/RuleMiner.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JaredSchwartz/RuleMiner.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![codecov](https://codecov.io/github/JaredSchwartz/RuleMiner.jl/graph/badge.svg?token=KDAVR32F6S)](https://codecov.io/github/JaredSchwartz/RuleMiner.jl)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://jaredschwartz.github.io/RuleMiner.jl/stable/)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://jaredschwartz.github.io/RuleMiner.jl/dev/)

## About
RuleMiner.jl is a Julia package for data mining inspired by the [arules](https://github.com/mhahsler/arules) R package and [SPMF](https://www.philippe-fournier-viger.com/spmf/) Java library.

## Features
- Native Julia multithreading for performance
- Integration with DataFrames.jl
- Flexible support for both relative and absolute minimum thresholds
- Association rule mining (Apriori[^1])
- Frequent itemset mining (ECLAT[^2], FP-Growth[^3])
- Closed itemset mining (CHARM[^4], FPClose[^5], LCM[^6], CARPENTER[^7])
- Maximal itemset mining (GenMax[^8], FPMax[^5])
- Frequent itemset recovery

## Documentation
To get started with RuleMiner, check out the [quick start guide](https://jaredschwartz.github.io/RuleMiner.jl/tutorials/getting_started)

The full API reference guides and tutorials can be found at the documentation site: [jaredschwartz.github.io/RuleMiner.jl](https://jaredschwartz.github.io/RuleMiner.jl/stable/)

## License
RuleMiner.jl is licensed under the MIT license

## References
[^1]: Agrawal, Rakesh, and Ramakrishnan Srikant. “Fast Algorithms for Mining Association Rules in Large Databases.” In Proceedings of the 20th International Conference on Very Large Data Bases, 487–99. VLDB ’94. San Francisco, CA, USA: Morgan Kaufmann Publishers Inc., 1994.

[^2]: Zaki, Mohammed. “Scalable Algorithms for Association Mining.” Knowledge and Data Engineering, IEEE Transactions On 12 (June 1, 2000): 372–90. https://doi.org/10.1109/69.846291.

[^3]: Han, Jiawei, Jian Pei, and Yiwen Yin. “Mining Frequent Patterns without Candidate Generation.” SIGMOD Rec. 29, no. 2 (May 16, 2000): 1–12. https://doi.org/10.1145/335191.335372.

[^4]: Zaki, Mohammed, and Ching-Jui Hsiao. “CHARM: An Efficient Algorithm for Closed Itemset Mining.” In Proceedings of the 2002 SIAM International Conference on Data Mining (SDM), 457–73. Proceedings. Society for Industrial and Applied Mathematics, 2002. https://doi.org/10.1137/1.9781611972726.27.

[^5]: Grahne, Gösta, and Jianfei Zhu. “Fast Algorithms for Frequent Itemset Mining Using FP-Trees.” IEEE Transactions on Knowledge and Data Engineering 17, no. 10 (October 2005): 1347–62. https://doi.org/10.1109/TKDE.2005.166.

[^6]: Uno, Takeaki, Tatsuya Asai, Yuzo Uchida, and Hiroki Arimura. “An Efficient Algorithm for Enumerating Closed Patterns in Transaction Databases.” In Discovery Science, edited by Einoshin Suzuki and Setsuo Arikawa, 16–31. Berlin, Heidelberg: Springer, 2004. https://doi.org/10.1007/978-3-540-30214-8_2.

[^7]: Pan, Feng, Gao Cong, Anthony K. H. Tung, Jiong Yang, and Mohammed J. Zaki. “Carpenter: Finding Closed Patterns in Long Biological Datasets.” In Proceedings of the Ninth ACM SIGKDD International Conference on Knowledge Discovery and Data Mining, 637–42. KDD ’03. New York, NY, USA: Association for Computing Machinery, 2003. https://doi.org/10.1145/956750.956832.

[^8]: Gouda, Karam, and Mohammed J. Zaki. “GenMax: An Efficient Algorithm for Mining Maximal Frequent Itemsets.” Data Mining and Knowledge Discovery 11, no. 3 (November 1, 2005): 223–42. https://doi.org/10.1007/s10618-005-0002-x.
