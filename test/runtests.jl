using RuleMiner
using Test

@testset "loader.jl" begin
    data = load_transactions(joinpath(@__DIR__,"files/testdata.txt"),:wide; sep=',')
    @test size(data.matrix) == (9,16)
    @test sum(data2.matrix) == 36
    @test data2.colkeys[10] == "hamburger"
    @test data2.linekeys[7] == "7"
end

@testset "apriori.jl" begin
    data = load_transactions(joinpath(@__DIR__,"files/testdata.txt"),:wide; sep=',')
    rules = apriori(data,0.3,2)
    @test rules.RHS == ["beer","bread","cheese","eggs","ham","milk","milk","eggs"]
end
