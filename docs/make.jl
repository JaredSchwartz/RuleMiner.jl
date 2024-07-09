using Documenter, RuleMiner,DataFrames


makedocs(
    format = Documenter.HTML(prettyurls = haskey(ENV, "CI")),
    sitename="RuleMiner.jl",
    pagesonly = true,
    draft = false,
    pages=[
        "Home" => "index.md",
        "Transactions Objects" => "transactions.md",
        "Algorithms" => Any[
            "A Priori" => "algorithms/apriori.md",
            "ECLAT" => "algorithms/eclat.md",
            "FP Growth" => "algorithms/fpgrowth.md"
        ],
    ],
    warnonly = [:missing_docs, :cross_references],
)

deploydocs(
    repo = "github.com/JaredSchwartz/RuleMiner.jl.git",
)