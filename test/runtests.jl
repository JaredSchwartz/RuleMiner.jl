using RuleMiner
using Test

@testset "loader.jl" begin
    data = load_transactions(joinpath(@__DIR__,"files/testdata.txt"),:wide)
    @test size(data.matrix) == (9,16)
    @test sum(data.matrix) == 36
    @test data.colkeys[10] == "hamburger"
    @test data.linekeys[7] == "7"
end

@testset "apriori.jl" begin
    data = load_transactions(joinpath(@__DIR__,"files/testdata.txt"),:wide)
    rules = apriori(data,0.3,2)
    @test sort(rules.RHS) == ["beer", "bread", "cheese", "eggs", "eggs", "ham", "milk", "milk"]
end

@testset "eclat.jl" begin
    data = load_transactions(joinpath(@__DIR__,"files/testdata.txt"),:wide)
    sets = eclat(data,3)
    @test sets.Itemset == [["beer"], ["bread"], ["cheese"], ["ham"], ["eggs"], ["eggs", "milk"], ["milk"]]
    @test sets.Support == [3, 3, 3, 3, 5, 4, 5]
end