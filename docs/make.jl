using Documenter, RuleMiner,DataFrames


makedocs(
    format = Documenter.HTML(prettyurls = haskey(ENV, "CI")),
    sitename="RuleMiner.jl",
    pagesonly = true,
    draft = false,
    pages=[
        "Home" => "index.md",
        "Association Rule Mining" => "association_rules.md",
        "Itemset Mining" => Any[
            "Frequent Itemset Mining" => "frequent_itemsets.md",
            "Closed Itemset Mining" => "closed_itemsets.md",
            "Maximal Itemset Mining" => "maximal_itemsets.md",
        ],
        "Transactions Objects" => "transactions.md",
    ],
    warnonly = [:missing_docs, :cross_references],
)

deploydocs(
    repo = "github.com/JaredSchwartz/RuleMiner.jl.git",
)