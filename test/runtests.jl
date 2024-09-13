using RuleMiner, DataFrames
using Test

@testset "Data Structs" begin
    include("data_structures.jl")
end

@testset "Assoc. Rules" begin
    include("association_rules.jl")
end

@testset "Itemsets" begin
    include("itemsets.jl")
end