using RuleMiner, DataFrames
using Test


@testset "transactions.jl" begin
    @testset "Frequent" begin
        item_vals = ["bacon", "beer", "bread", "buns", "butter", "cheese", "eggs", "flour", "ham", "hamburger", "hot dogs", "ketchup", "milk", "mustard", "sugar", "turkey"]
        nonindex_vals = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
        index_vals = ["1111", "1112", "1113", "1114", "1115", "1116", "1117", "1118", "1119"]

        @testset "Load Files" begin
            @testset "regular load" begin
                data = Txns(joinpath(@__DIR__,"files/frequent/data.txt"),',')
                @test size(data.matrix) == (9,16)
                @test sum(data.matrix) == 36
                @test sort(data.colkeys) == item_vals
                @test sort(data.linekeys) == nonindex_vals
            end

            @testset "line indexes" begin
                data = Txns(joinpath(@__DIR__,"files/frequent/data_indexed.txt"),',';id_col = true)
                @test size(data.matrix) == (9,16)
                @test sum(data.matrix) == 36
                @test sort(data.colkeys) == item_vals
                @test sort(data.linekeys) == index_vals
            end

            @testset "skip lines" begin
                data = Txns(joinpath(@__DIR__,"files/frequent/data_header.txt"),',';skiplines=2)
                @test size(data.matrix) == (9,16)
                @test sum(data.matrix) == 36
                @test sort(data.colkeys) == item_vals
                @test sort(data.linekeys) == nonindex_vals
            end

            @testset "n lines" begin
                data = Txns(joinpath(@__DIR__,"files/frequent/data.txt"),',',nlines = 1)
                @test size(data.matrix) == (1,3)
                @test sum(data.matrix) == 3
                @test sort(data.colkeys) == ["bread", "eggs", "milk"]
                @test sort(data.linekeys) == ["1"]
            end
        end

        @testset "convert df" begin
            data = Txns(joinpath(@__DIR__,"files/frequent/data.txt"),',')
            dftest = txns_to_df(data)
            data = Txns(joinpath(@__DIR__,"files/frequent/data_indexed.txt"),',';id_col = true)
            dftest_index =  txns_to_df(data,true)

            @testset "without index" begin
                data = Txns(dftest)
                @test size(data.matrix) == (9,16)
                @test sum(data.matrix) == 36
                @test sort(data.colkeys) == item_vals
                @test sort(data.linekeys) == nonindex_vals
            end

            @testset "with index" begin
                data = Txns(dftest_index,:Index)
                @test size(data.matrix) == (9,16)
                @test sum(data.matrix) == 36
                @test sort(data.colkeys) == item_vals
                @test sort(data.linekeys) == index_vals
            end
        end
    end
    @testset "Sequential" begin

        item_vals = ["bacon", "beer", "bread", "buns", "butter", "cheese", "eggs", "flour", "ham", "hamburger", "hot dogs", "ketchup", "milk", "mustard", "sugar", "turkey"]
        nonindex_vals = ["1", "10", "11", "12", "2", "3", "4", "5", "6", "7", "8", "9"]
        index_vals = ["1111", "1112", "1113", "1114", "1115", "1116", "1117", "1118", "1119","1120", "1121", "1122"]

        @testset "Load Files" begin
            @testset "regular load" begin
                data = SeqTxns(joinpath(@__DIR__,"files/sequential/data.txt"),',',';')
                @test size(data.matrix) == (12,16)
                @test sum(data.matrix) == 46
                @test sort(data.colkeys) == item_vals
                @test sort(data.linekeys) == nonindex_vals
            end

            @testset "line indexes" begin
                data = SeqTxns(joinpath(@__DIR__,"files/sequential/data_indexed.txt"),',',';';id_col = true)
                @test size(data.matrix) == (12,16)
                @test sum(data.matrix) == 46
                @test sort(data.colkeys) == item_vals
                @test sort(data.linekeys) == index_vals
            end

            @testset "skip lines" begin
                data = SeqTxns(joinpath(@__DIR__,"files/sequential/data_header.txt"),',',';';skiplines=2)
                @test size(data.matrix) == (12,16)
                @test sum(data.matrix) == 46
                @test sort(data.colkeys) == item_vals
                @test sort(data.linekeys) == nonindex_vals
            end

            @testset "n lines" begin
                data = SeqTxns(joinpath(@__DIR__,"files/sequential/data.txt"),',',';',nlines = 1)
                @test size(data.matrix) == (2,6)
                @test sum(data.matrix) == 7
                @test sort(data.colkeys) == ["bacon", "bread", "cheese", "eggs", "ham", "milk"]
                @test sort(data.linekeys) == ["1","2"]
            end
        end
        @testset "convert df" begin
            data = SeqTxns(joinpath(@__DIR__,"files/sequential/data.txt"),',',';')
            dftest = txns_to_df(data,false,true)
            data = SeqTxns(joinpath(@__DIR__,"files/sequential/data_indexed.txt"),',',';';id_col = true)
            dftest_index =  txns_to_df(data,true,true)
            dftest_data = txns_to_df(data,false,false)

            @testset "without index" begin
                data = SeqTxns(dftest,:SequenceIndex)
                @test size(data.matrix) == (12,16)
                @test sum(data.matrix) == 46
                @test sort(data.colkeys) == item_vals
                @test sort(data.linekeys) == nonindex_vals
            end

            @testset "with index" begin
                data = SeqTxns(dftest_index,:SequenceIndex,:Index)
                @test size(data.matrix) == (12,16)
                @test sum(data.matrix) == 46
                @test sort(data.colkeys) == item_vals
                @test sort(data.linekeys) == index_vals
            end
            @testset "data only" begin
                data = Txns(dftest_data)
                @test size(data.matrix) == (12,16)
                @test sum(data.matrix) == 46
                @test sort(data.colkeys) == item_vals
                @test sort(data.linekeys) == nonindex_vals
            end
        end
    end
end

# Load Data Once for all Algorithm Tests
data = Txns(joinpath(@__DIR__,"files/frequent/data.txt"),',')

# Define Association Rule results at support of 3/0.3 and rule length of 5
rule_abs_sup = 3
rule_perc_sup = 0.3
rule_max_len = 5
rule_LHS = [String[], String[], String[], String[], ["milk"], ["eggs"], String[], String[]]
rule_RHS = ["beer", "bread", "cheese", "ham", "eggs", "milk", "eggs", "milk"]
rule_Support = [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.4444444444444444, 0.4444444444444444, 0.5555555555555556, 0.5555555555555556]
rule_Confidence = [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.7999999999999999, 0.7999999999999999, 0.5555555555555556, 0.5555555555555556]
rule_Coverage = [1.0, 1.0, 1.0, 1.0, 0.5555555555555556, 0.5555555555555556, 1.0, 1.0]
rule_Lift = [1.0, 1.0, 1.0, 1.0, 1.4399999999999997, 1.4399999999999997, 1.0, 1.0]
rule_N = [3, 3, 3, 3, 4, 4, 5, 5]
rule_Length = [1, 1, 1, 1, 2, 2, 1, 1]

# Define Frequent Itemset results at support of 3/0.3
freq_abs_sup = 3
freq_perc_sup = 0.3
freq_items = [["beer"], ["bread"], ["cheese"], ["eggs"], ["ham"], ["milk"], ["eggs", "milk"]]
freq_supports = [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.5555555555555556, 0.3333333333333333, 0.5555555555555556, 0.4444444444444444]
freq_N = [3, 3, 3, 5, 3, 5, 4]
freq_length = [1, 1, 1, 1, 1, 1, 2]

# Define Closed Itemset results at support of 2/0.2
closed_abs_sup = 2
closed_perc_sup = 0.2
closed_items = [["beer"], ["bread"], ["cheese"], ["eggs"], ["ham"], ["ketchup"], ["milk"], ["bacon", "eggs"], ["beer", "hamburger"], ["beer", "milk"], ["bread", "ham"], ["cheese", "ham"], ["eggs", "milk"], ["eggs", "milk", "sugar"]]
closed_supports = [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.5555555555555556, 0.3333333333333333, 0.2222222222222222, 0.5555555555555556, 0.2222222222222222, 0.2222222222222222, 0.2222222222222222, 0.2222222222222222, 0.2222222222222222, 0.4444444444444444, 0.2222222222222222]
closed_N = [3, 3, 3, 5, 3, 2, 5, 2, 2, 2, 2, 2, 4, 2]
closed_length = [1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 3]

# Define Maximal Itemset results at support of 3/0.3
max_abs_sup = 3
max_perc_sup = 0.3
max_items = [["beer"], ["bread"], ["cheese"], ["ham"], ["eggs", "milk"]]
max_supports = [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.4444444444444444]
max_N = [3, 3, 3, 3, 4]
max_length = [1, 1, 1, 1, 2]

# Define custom itemset sorting function 
function setsorter!(itemsets::DataFrame)
    transform!(itemsets,:Itemset => ( x -> sort.(x) ) => :Itemset)
    transform!(itemsets,:Itemset => ( x -> join.(x) ) => :SetHash)
    sort!(itemsets,[:Length,:SetHash])
    select!(itemsets,Not(:SetHash))
end

@testset "apriori.jl" begin

    @testset "percentage support" begin
        rules = apriori(data,rule_perc_sup,rule_max_len)
        sorted = sort(rules,[:Support,:RHS])
        @test sorted.LHS == rule_LHS
        @test sorted.RHS == rule_RHS
        @test sorted.Support == rule_Support
        @test sorted.Confidence ≈ rule_Confidence
        @test sorted.Coverage ≈ rule_Coverage
        @test sorted.Lift ≈ rule_Lift
        @test sorted.N == rule_N
        @test sorted.Length == rule_Length
    end

    @testset "absolute support" begin
        rules = apriori(data,rule_abs_sup,rule_max_len)
        sorted = sort(rules,[:Support,:RHS])
        @test sorted.LHS == rule_LHS
        @test sorted.RHS == rule_RHS
        @test sorted.Support == rule_Support
        @test sorted.Confidence ≈ rule_Confidence
        @test sorted.Coverage ≈ rule_Coverage
        @test sorted.Lift ≈ rule_Lift
        @test sorted.N == rule_N
        @test sorted.Length == rule_Length
    end
end

@testset "eclat.jl" begin

    @testset "percentage support" begin
        sets = eclat(data,freq_perc_sup)
        setsorter!(sets)
        @test sets.Itemset == freq_items
        @test sets.Support ≈ freq_supports
        @test sets.N == freq_N
        @test sets.Length == freq_length
    end
    
    @testset "asbolute support" begin
        sets = eclat(data,freq_abs_sup)
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
            sets = fpgrowth(data,freq_perc_sup)
            setsorter!(sets)
            @test sets.Itemset == freq_items
            @test sets.Support ≈ freq_supports
            @test sets.N == freq_N
            @test sets.Length == freq_length
        end
        
        @testset "asbolute support" begin
            sets = fpgrowth(data,freq_abs_sup)
            setsorter!(sets)
            @test sets.Itemset == freq_items
            @test sets.Support ≈ freq_supports
            @test sets.N == freq_N
            @test sets.Length == freq_length
        end
    end

    @testset "fpclose" begin
        @testset "percentage support" begin
            sets = fpclose(data,closed_perc_sup)
            setsorter!(sets)
            @test sets.Itemset == closed_items
            @test sets.Support ≈ closed_supports
            @test sets.N == closed_N
            @test sets.Length == closed_length
        end
        
        @testset "asbolute support" begin
            sets = fpclose(data,closed_abs_sup)
            setsorter!(sets)
            @test sets.Itemset == closed_items
            @test sets.Support ≈ closed_supports
            @test sets.N == closed_N
            @test sets.Length == closed_length
        end
    end

    @testset "fpmax" begin
        @testset "percentage support" begin
            sets = fpmax(data,max_perc_sup)
            setsorter!(sets)
            @test sets.Itemset == max_items
            @test sets.Support ≈ max_supports
            @test sets.N == max_N
            @test sets.Length == max_length
        end
        
        @testset "asbolute support" begin
            sets = fpmax(data,max_abs_sup)
            setsorter!(sets)
            @test sets.Itemset == max_items
            @test sets.Support ≈ max_supports
            @test sets.N == max_N
            @test sets.Length == max_length
        end
    end
end

@testset "charm.jl" begin
        
    @testset "percentage support" begin
        sets = charm(data,closed_perc_sup)
        setsorter!(sets)
        @test sets.Itemset == closed_items
        @test sets.Support ≈ closed_supports
        @test sets.N == closed_N
        @test sets.Length == closed_length
    end
    
    @testset "asbolute support" begin
        sets = charm(data,closed_abs_sup)
        setsorter!(sets)
        @test sets.Itemset == closed_items
        @test sets.Support ≈ closed_supports
        @test sets.N == closed_N
        @test sets.Length == closed_length
    end
end

@testset "carpenter.jl" begin
        
    @testset "percentage support" begin
        sets = carpenter(data,closed_perc_sup)
        setsorter!(sets)
        @test sets.Itemset == closed_items
        @test sets.Support ≈ closed_supports
        @test sets.N == closed_N
        @test sets.Length == closed_length
    end
    
    @testset "asbolute support" begin
        sets = carpenter(data,closed_abs_sup)
        setsorter!(sets)
        @test sets.Itemset == closed_items
        @test sets.Support ≈ closed_supports
        @test sets.N == closed_N
        @test sets.Length == closed_length
    end
end

@testset "lcm.jl" begin
        
    @testset "percentage support" begin
        sets = LCM(data,closed_perc_sup)
        setsorter!(sets)
        @test sets.Itemset == closed_items
        @test sets.Support ≈ closed_supports
        @test sets.N == closed_N
        @test sets.Length == closed_length
    end
    
    @testset "asbolute support" begin
        sets = LCM(data,closed_abs_sup)
        setsorter!(sets)
        @test sets.Itemset == closed_items
        @test sets.Support ≈ closed_supports
        @test sets.N == closed_N
        @test sets.Length == closed_length
    end
end

@testset "levelwise.jl" begin
    closed_sets = LCM(data,2)
    sets = levelwise(closed_sets,2)
    remainder = subset(sets, :N => (x -> x .< freq_abs_sup))
    subset!(sets, :N => (x -> x .>= freq_abs_sup))
    setsorter!(sets)
    setsorter!(remainder)
    @test sets.Itemset == freq_items
    @test sets.N == freq_N
    @test sets.Length == freq_length
    @test remainder.Itemset == [["bacon"], ["hamburger"], ["ketchup"], ["sugar"], ["bacon", "eggs"], ["beer", "hamburger"], ["beer", "milk"], ["bread", "ham"], ["cheese", "ham"], ["eggs", "sugar"], ["milk", "sugar"], ["eggs", "milk", "sugar"]]
    @test remainder.N == [2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2]
    @test remainder.Length == [1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 3]
end

@testset "genmax.jl" begin
    @testset "percentage support" begin
        sets = genmax(data,max_perc_sup)
        setsorter!(sets)
        @test sets.Itemset == max_items
        @test sets.Support ≈ max_supports
        @test sets.N == max_N
        @test sets.Length == max_length
    end
    
    @testset "asbolute support" begin
        sets = genmax(data,max_abs_sup)
        setsorter!(sets)
        @test sets.Itemset == max_items
        @test sets.Support ≈ max_supports
        @test sets.N == max_N
        @test sets.Length == max_length
    end
end