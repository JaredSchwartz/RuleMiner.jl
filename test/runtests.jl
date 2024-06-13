using RuleMiner
using Test

@testset "loader.jl" begin
    data = load_transactions(joinpath(@__DIR__,"files/testdata.txt"),:wide; sep=',')
    @test size(data.matrix) == (9,16)
    @test sum(data.matrix) == 36
    @test data.colkeys[10] == "hamburger"
    @test data.linekeys[7] == "7"
end

@testset "apriori.jl" begin
    data = load_transactions(joinpath(@__DIR__,"files/testdata.txt"),:wide; sep=',')
    rules = apriori(data,0.3,2)
    @test sort(rules.RHS) == ["beer", "bread", "cheese", "eggs", "eggs", "ham", "milk", "milk"]
end