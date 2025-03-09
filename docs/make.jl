using Documenter, RuleMiner,DataFrames,DocumenterVitepress


makedocs(
    format = DocumenterVitepress.MarkdownVitepress(repo = "github.com/JaredSchwartz/RuleMiner.jl"),
    sitename="RuleMiner.jl",
    pagesonly = true,
    draft = false,
    pages=[
        "Home" => "index.md",
        "Tutorials" => Any[
           "Getting Started" => "tutorials/getting_started.md"
        ],
        "Concepts" => Any[
            "Association Rule Mining" => "concepts/association_rules.md",
            "Frequent Itemset Mining" => "concepts/frequent_itemsets.md",
            "Closed Itemset Mining" => "concepts/closed_itemsets.md",
            "Maximal Itemset Mining" => "concepts/maximal_itemsets.md",
        ],
        "API Reference" => "api_reference.md",
        #"FP Tree Objects" => "fptree.md"
    ],
    warnonly = [:missing_docs, :cross_references],
)

deploydocs(;
    repo = "github.com/JaredSchwartz/RuleMiner.jl",
    target = "build",
)