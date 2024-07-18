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

        @testset "n lines" begin
            data = load_transactions(joinpath(@__DIR__,"files/data.txt"),',',nlines = 1)
            @test size(data.matrix) == (1,3)
            @test sum(data.matrix) == 3
            @test sort(collect(values(data.colkeys))) == ["bread", "eggs", "milk"]
            @test sort(collect(values(data.linekeys))) == ["1"]
        end
    end

    @testset "convert df" begin
        data = load_transactions(joinpath(@__DIR__,"files/data.txt"),',')
        dftest = txns_to_df(data)
        data = load_transactions(joinpath(@__DIR__,"files/data_indexed.txt"),',';id_col = true)
        dftest_index =  txns_to_df(data,id_col=true)

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

# Load Data Once for all Algorithm Tests
data = load_transactions(joinpath(@__DIR__,"files/data.txt"),',')

@testset "apriori.jl" begin

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

# Define Frequent Itemset results at support of 3/0.3
freq_items = [["beer"], ["bread"], ["cheese"], ["eggs"], ["ham"], ["milk"], ["eggs", "milk"]]
freq_supports = [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.5555555555555556, 0.3333333333333333, 0.5555555555555556, 0.4444444444444444]
freq_N = [3, 3, 3, 5, 3, 5, 4]
freq_length = [1, 1, 1, 1, 1, 1, 2]

# Define Closed Itemset results at support of 2/0.2
closed_items = [["beer"], ["bread"], ["cheese"], ["eggs"], ["ham"], ["ketchup"], ["milk"], ["bacon", "eggs"], ["beer", "hamburger"], ["beer", "milk"], ["bread", "ham"], ["cheese", "ham"], ["eggs", "milk"], ["eggs", "milk", "sugar"]]
closed_supports = [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.5555555555555556, 0.3333333333333333, 0.2222222222222222, 0.5555555555555556, 0.2222222222222222, 0.2222222222222222, 0.2222222222222222, 0.2222222222222222, 0.2222222222222222, 0.4444444444444444, 0.2222222222222222]
closed_N = [3, 3, 3, 5, 3, 2, 5, 2, 2, 2, 2, 2, 4, 2]
closed_length = [1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 3]

# Define cusutom itemset sorting function 
function setsorter!(itemsets::DataFrame)
    transform!(itemsets,:Itemset => ( x -> sort.(x) ) => :Itemset)
    transform!(itemsets,:Itemset => ( x -> join.(x) ) => :SetHash)
    sort!(itemsets,[:Length,:SetHash])
    select!(itemsets,Not(:SetHash))
end

@testset "eclat.jl" begin

    @testset "percentage support" begin
        sets = eclat(data,0.3)
        setsorter!(sets)
        @test sets.Itemset == freq_items
        @test sets.Support ≈ freq_supports
        @test sets.N == freq_N
        @test sets.Length == freq_length
    end
    
    @testset "asbolute support" begin
        sets = eclat(data,3)
        setsorter!(sets)
        @test sets.Itemset == freq_items
        @test sets.Support ≈ freq_supports
        @test sets.N == freq_N
        @test sets.Length == freq_length
    end
end

@testset "fpgrowth.jl" begin

    @testset "fpgrowth" begin
        @testset "percentage support" begin
            sets = fpgrowth(data,0.3)
            setsorter!(sets)
            @test sets.Itemset == freq_items
            @test sets.Support ≈ freq_supports
            @test sets.N == freq_N
            @test sets.Length == freq_length
        end
        
        @testset "asbolute support" begin
            sets = fpgrowth(data,3)
            setsorter!(sets)
            @test sets.Itemset == freq_items
            @test sets.Support ≈ freq_supports
            @test sets.N == freq_N
            @test sets.Length == freq_length
        end
    end

    @testset "fpclose" begin
        @testset "percentage support" begin
            sets = fpclose(data,0.2)
            setsorter!(sets)
            @test sets.Itemset == closed_items
            @test sets.Support ≈ closed_supports
            @test sets.N == closed_N
            @test sets.Length == closed_length
        end
        
        @testset "asbolute support" begin
            sets = fpclose(data,2)
            setsorter!(sets)
            @test sets.Itemset == closed_items
            @test sets.Support ≈ closed_supports
            @test sets.N == closed_N
            @test sets.Length == closed_length
        end
    end
end

@testset "charm.jl" begin
        
    @testset "percentage support" begin
        sets = charm(data,0.2)
        setsorter!(sets)
        @test sets.Itemset == closed_items
        @test sets.Support ≈ closed_supports
        @test sets.N == closed_N
        @test sets.Length == closed_length
    end
    
    @testset "asbolute support" begin
        sets = charm(data,2)
        setsorter!(sets)
        @test sets.Itemset == closed_items
        @test sets.Support ≈ closed_supports
        @test sets.N == closed_N
        @test sets.Length == closed_length
    end
end

@testset "carpenter.jl" begin
        
    @testset "percentage support" begin
        sets = carpenter(data,0.2)
        setsorter!(sets)
        @test sets.Itemset == closed_items
        @test sets.Support ≈ closed_supports
        @test sets.N == closed_N
        @test sets.Length == closed_length
    end
    
    @testset "asbolute support" begin
        sets = carpenter(data,2)
        setsorter!(sets)
        @test sets.Itemset == closed_items
        @test sets.Support ≈ closed_supports
        @test sets.N == closed_N
        @test sets.Length == closed_length
    end
end

@testset "lcm.jl" begin
        
    @testset "percentage support" begin
        sets = LCM(data,0.2)
        setsorter!(sets)
        @test sets.Itemset == closed_items
        @test sets.Support ≈ closed_supports
        @test sets.N == closed_N
        @test sets.Length == closed_length
    end
    
    @testset "asbolute support" begin
        sets = LCM(data,2)
        setsorter!(sets)
        @test sets.Itemset == closed_items
        @test sets.Support ≈ closed_supports
        @test sets.N == closed_N
        @test sets.Length == closed_length
    end
end
