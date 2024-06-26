using RuleMiner, DataFrames
using Test


@testset "transactions.jl" begin
    @testset "Load Files" begin
        @testset "regular load" begin
            data = load_transactions(joinpath(@__DIR__,"files/data.txt"),',')
            @test size(data.matrix) == (9,16)
            @test sum(data.matrix) == 36
            @test sort(collect(values(data.colkeys))) == ["bacon", "beer", "bread", "buns", "butter", "cheese", "eggs", "flour", "ham", "hamburger", "hot dogs", "ketchup", "milk", "mustard", "sugar", "turkey"]
            @test sort(collect(values(data.linekeys))) == ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
        end

        @testset "line indexes" begin
            data = load_transactions(joinpath(@__DIR__,"files/data_indexed.txt"),',';id_col = true)
            @test size(data.matrix) == (9,16)
            @test sum(data.matrix) == 36
            @test sort(collect(values(data.colkeys))) == ["bacon", "beer", "bread", "buns", "butter", "cheese", "eggs", "flour", "ham", "hamburger", "hot dogs", "ketchup", "milk", "mustard", "sugar", "turkey"]
            @test sort(collect(values(data.linekeys))) == ["1111", "1112", "1113", "1114", "1115", "1116", "1117", "1118", "1119"]
        end

        @testset "skip lines" begin
            data = load_transactions(joinpath(@__DIR__,"files/data_header.txt"),',';skiplines=2)
            @test size(data.matrix) == (9,16)
            @test sum(data.matrix) == 36
            @test sort(collect(values(data.colkeys))) == ["bacon", "beer", "bread", "buns", "butter", "cheese", "eggs", "flour", "ham", "hamburger", "hot dogs", "ketchup", "milk", "mustard", "sugar", "turkey"]
            @test sort(collect(values(data.linekeys))) == ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
        end
    end

    @testset "convert df" begin
        data = load_transactions(joinpath(@__DIR__,"files/data.txt"),',')
        dftest = DataFrame(Matrix(data.matrix),:auto)
        rename!(dftest,data.colkeys)
        mapcols!(ByRow(Int), dftest)
        dftest_index = transform(dftest, :milk => (x -> (1:length(x)).+1110) => :Index)

        @testset "without index" begin
            data = transactions(dftest)
            @test size(data.matrix) == (9,16)
            @test sum(data.matrix) == 36
            @test sort(collect(values(data.colkeys))) == ["bacon", "beer", "bread", "buns", "butter", "cheese", "eggs", "flour", "ham", "hamburger", "hot dogs", "ketchup", "milk", "mustard", "sugar", "turkey"]
            @test sort(collect(values(data.linekeys))) == ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
        end

        @testset "with index" begin
            data = transactions(dftest_index;indexcol=:Index)
            @test size(data.matrix) == (9,16)
            @test sum(data.matrix) == 36
            @test sort(collect(values(data.colkeys))) == ["bacon", "beer", "bread", "buns", "butter", "cheese", "eggs", "flour", "ham", "hamburger", "hot dogs", "ketchup", "milk", "mustard", "sugar", "turkey"]
            @test sort(collect(values(data.linekeys))) == ["1111", "1112", "1113", "1114", "1115", "1116", "1117", "1118", "1119"]
        end

    end
end

@testset "apriori.jl" begin
    data = load_transactions(joinpath(@__DIR__,"files/data.txt"),',')

    @testset "percentage support" begin
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

    @testset "absolute support" begin
        rules = apriori(data,2,5)
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
end

@testset "eclat.jl" begin
    data = load_transactions(joinpath(@__DIR__,"files/data.txt"),',')
    
    @testset "percentage support" begin
        sets = eclat(data,0.3)
        sorted = sort(sets,[:N,:Itemset])
        @test sets.Itemset == [["bread"], ["beer"], ["ham"], ["cheese"], ["milk"], ["milk", "eggs"], ["eggs"]]
        @test sets.Support ≈ [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.5555555555555556, 0.4444444444444444, 0.5555555555555556]
        @test sets.N == [3, 3, 3, 3, 5, 4, 5]
        @test sets.Length == [1, 1, 1, 1, 1, 2, 1]
    end
    
    @testset "asbolute support" begin
        sets = eclat(data,3)
        sorted = sort(sets,[:N,:Itemset])
        @test sets.Itemset == [["bread"], ["beer"], ["ham"], ["cheese"], ["milk"], ["milk", "eggs"], ["eggs"]]
        @test sets.Support ≈ [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.5555555555555556, 0.4444444444444444, 0.5555555555555556]
        @test sets.N == [3, 3, 3, 3, 5, 4, 5]
        @test sets.Length == [1, 1, 1, 1, 1, 2, 1]
    end
end