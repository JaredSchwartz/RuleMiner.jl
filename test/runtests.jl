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
    rules = apriori(data,0.3,5)
    sorted = sort(rules,[:Support,:RHS])
    @test sorted.LHS == [String[], String[], String[], String[], ["milk"], ["eggs"], String[], String[]]
    @test sorted.RHS == ["beer", "bread", "cheese", "ham", "eggs", "milk", "eggs", "milk"]
    @test sorted.Support == [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.4444444444444444, 0.4444444444444444, 0.5555555555555556, 0.5555555555555556]
    @test sorted.Confidence ≈ [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.7999999999999999, 0.7999999999999999, 0.5555555555555556, 0.5555555555555556]
    @test sorted.Coverage ≈ [1.0, 1.0, 1.0, 1.0, 0.5555555555555556, 0.5555555555555556, 1.0, 1.0]
    @test sorted.Lift ≈ [1.0, 1.0, 1.0, 1.0, 1.4399999999999997, 1.4399999999999997, 1.0, 1.0]
    @test sorted.N == [3, 3, 3, 3, 4, 4, 5, 5]
    @test sorted.Length == [1, 1, 1, 1, 2, 2, 1, 1]
end

@testset "eclat.jl" begin
    data = load_transactions(joinpath(@__DIR__,"files/testdata.txt"),:wide)
    sets = eclat(data,3)
    @test sets.Itemset == [["beer"], ["bread"], ["cheese"], ["ham"], ["eggs"], ["eggs", "milk"], ["milk"]]
    @test sets.Support == [3, 3, 3, 3, 5, 4, 5]
end