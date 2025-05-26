# Function to test show() methods with various io dimensions 
function trunc_tester(object, nlines::Int, ncols::Int)
    buf = IOBuffer()
    io = IOContext(buf, :limit=>true, :displaysize=>(nlines, ncols))
    show(io, object)
    result = String(take!(buf))
    return(result)
end

# Generalized printing test function
function test_printing_outputs(object, file_prefix::String, truncated_dims::Tuple{Int,Int})
    # Define test scenarios: (test_name, dimensions, filename)
    scenarios = [
        ("Full", (1000, 1000), "$(file_prefix).txt"),
        ("Truncated", truncated_dims, "$(file_prefix)_truncated.txt"),
        ("Minimal", (1, 10), "$(file_prefix)_minimal.txt")
    ]
    
    @testset "Printing" begin
        for (test_name, dims, filename) in scenarios
            @testset "$test_name" begin
                output = trunc_tester(object, dims...)
                expected_output = read(joinpath(@__DIR__, "files", "display_outputs", filename), String)
                @test output == expected_output
            end
        end
    end
end

@testset "fptree.jl" begin
    txns = Txns(joinpath(@__DIR__,"files/frequent/data.txt"),',')
    @testset "convert Txns" begin
        tree = FPTree(txns,0.3)
        @test sort(collect(keys(tree.header_table))) == [1, 2, 3, 4, 5, 6]
        @test sort([length(i) for i in values(tree.header_table)]) == [1, 2, 2, 2, 3, 3]
    end

    data = FPTree(txns,0.3)
    test_printing_outputs(data, "fptree", (12, 20))
end
@testset "txns.jl" begin
    item_vals = ["bacon", "beer", "bread", "buns", "butter", "cheese", "eggs", "flour", "ham", "hamburger", "hot dogs", "ketchup", "milk", "mustard", "sugar", "turkey"]
    index_vals = ["1111", "1112", "1113", "1114", "1115", "1116", "1117", "1118", "1119"]

    @testset "Load Files" begin
        @testset "regular load" begin
            data = Txns(joinpath(@__DIR__,"files/frequent/data.txt"),',')
            @test size(data.matrix) == (9,16)
            @test sum(data.matrix) == 36
            @test sort(data.colkeys) == item_vals
            @test isempty(data.linekeys)
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
            @test isempty(data.linekeys)
        end

        @testset "n lines" begin
            data = Txns(joinpath(@__DIR__,"files/frequent/data.txt"),',',nlines = 1)
            @test size(data.matrix) == (1,3)
            @test sum(data.matrix) == 3
            @test sort(data.colkeys) == ["bread", "eggs", "milk"]
            @test isempty(data.linekeys)
        end
        @testset "multi delim" begin
            data = Txns(joinpath(@__DIR__,"files/frequent/data_multidelim.txt"),"||")
            @test size(data.matrix) == (9,16)
            @test sum(data.matrix) == 36
            @test sort(data.colkeys) == item_vals
            @test isempty(data.linekeys)
        end
    end

    @testset "convert df" begin
        data = Txns(joinpath(@__DIR__,"files/frequent/data.txt"),',')
        dftest = txns_to_df(data)
        dftest_invalid = insertcols(dftest, :x_column => fill('x', nrow(dftest)))
        data = Txns(joinpath(@__DIR__,"files/frequent/data_indexed.txt"),',';id_col = true)
        dftest_index =  txns_to_df(data)

        @testset "without index" begin
            data = Txns(dftest)
            @test size(data.matrix) == (9,16)
            @test sum(data.matrix) == 36
            @test sort(data.colkeys) == item_vals
            @test isempty(data.linekeys)
        end

        @testset "with index" begin
            data = Txns(dftest_index,:Index)
            @test size(data.matrix) == (9,16)
            @test sum(data.matrix) == 36
            @test sort(data.colkeys) == item_vals
            @test sort(data.linekeys) == index_vals
        end

        @testset "invalid" begin
            @test_throws "Column 'x_column' contains values that cannot be coerced to boolean." Txns(dftest_invalid)
        end
    end
    @testset "Default Constructor" begin
        newstruct = Txns(joinpath(@__DIR__,"files/frequent/data.txt"),',')
        data = Txns(newstruct.matrix, newstruct.colkeys, newstruct.linekeys)
        @test size(data.matrix) == (9,16)
        @test sum(data.matrix) == 36
        @test sort(data.colkeys) == item_vals
        @test isempty(data.linekeys)
    end
    @testset "Auxiliary Functions" begin
        data = Txns(joinpath(@__DIR__,"files/frequent/data.txt"),',')
        @testset "first()" begin
            firstline = ["milk", "eggs", "bread"]
            first2 = [["milk", "eggs", "bread"], ["milk", "eggs", "butter", "sugar", "flour"]]
            @test first(data) == firstline
            @test first(data,2) == first2
            @test data[1:2] == first2
        end
        @testset "last()" begin
            lastline = ["eggs", "bacon", "ham", "cheese"]
            last2 = [["milk", "beer", "ketchup", "hamburger"], ["eggs", "bacon", "ham", "cheese"]]
            @test last(data) == lastline
            @test last(data,2) == last2
        end
        
    test_printing_outputs(data,"frequent",(13,30))
    end
end
@testset "seqtxns.jl" begin

    item_vals = ["bacon", "beer", "bread", "buns", "butter", "cheese", "eggs", "flour", "ham", "hamburger", "hot dogs", "ketchup", "milk", "mustard", "sugar", "turkey"]
    index_vals = ["1111", "1112", "1113", "1114", "1115", "1116", "1117", "1118", "1119","1120", "1121", "1122"]
    seq_index = UInt32[1, 3, 4, 5, 6, 9, 10, 11, 12]

    @testset "Load Files" begin
        @testset "regular load" begin
            data = SeqTxns(joinpath(@__DIR__,"files/sequential/data.txt"),',',';')
            @test size(data.matrix) == (12,16)
            @test sum(data.matrix) == 46
            @test sort(data.colkeys) == item_vals
            @test data.index == seq_index
        end

        @testset "skip lines" begin
            data = SeqTxns(joinpath(@__DIR__,"files/sequential/data_header.txt"),',',';';skiplines=2)
            @test size(data.matrix) == (12,16)
            @test sum(data.matrix) == 46
            @test sort(data.colkeys) == item_vals
            @test data.index == seq_index
        end

        @testset "n lines" begin
            data = SeqTxns(joinpath(@__DIR__,"files/sequential/data.txt"),',',';',nlines = 1)
            @test size(data.matrix) == (2,6)
            @test sum(data.matrix) == 7
            @test sort(data.colkeys) == ["bacon", "bread", "cheese", "eggs", "ham", "milk"]
            @test data.index == UInt32[1]
        end
    end
    @testset "convert df" begin
        data = SeqTxns(joinpath(@__DIR__,"files/sequential/data.txt"),',',';')
        dftest = txns_to_df(data,true)
        dftest_data = txns_to_df(data,false)
        dftest_invalid = insertcols(dftest, :x_column => fill('x', nrow(dftest)))

        @testset "without index" begin
            data = SeqTxns(dftest,:SequenceIndex)
            @test size(data.matrix) == (12,16)
            @test sum(data.matrix) == 46
            @test sort(data.colkeys) == item_vals
            @test data.index == seq_index
        end
        
        @testset "data only" begin
            data = Txns(dftest_data)
            @test size(data.matrix) == (12,16)
            @test sum(data.matrix) == 46
            @test sort(data.colkeys) == item_vals
        end

        @testset "invalid" begin
            @test_throws "Column 'x_column' contains values that cannot be coerced to boolean." SeqTxns(dftest_invalid,:SequenceIndex)
        end

    end
    @testset "Default Constructor" begin
        newstruct = SeqTxns(joinpath(@__DIR__,"files/sequential/data.txt"),',',';')
        data = SeqTxns(newstruct.matrix, newstruct.colkeys, newstruct.index)
        @test size(data.matrix) == (12,16)
        @test sum(data.matrix) == 46
        @test sort(data.colkeys) == item_vals
        @test data.index == seq_index
    end
    @testset "Auxiliary Functions" begin
        data = SeqTxns(joinpath(@__DIR__,"files/sequential/data.txt"),',',';')
        @testset "length" begin
            @test length(data) == 9
        end
        @testset "getbounds" begin
            bounds = UInt32[2, 3, 4, 5, 8, 9, 10, 11, 12]
            @test RuleMiner.getends(data) == bounds
        end
        @testset "first()" begin
            firstline = [["milk", "eggs", "bread"], ["eggs", "ham", "cheese", "bacon"]]
            first2 = [[["milk", "eggs", "bread"], ["eggs", "ham", "cheese", "bacon"]], [["milk", "eggs", "butter", "sugar", "flour"]]]
            @test first(data) == firstline
            @test first(data,2) == first2
            @test data[1:2] == first2
        end
        @testset "last()" begin
            lastline = [["eggs", "ham", "cheese", "bacon"]]
            last2 = [[["milk", "beer", "ketchup", "hamburger"]], [["eggs", "ham", "cheese", "bacon"]]]
            @test last(data) == lastline
            @test last(data,2) == last2
        end
        
        test_printing_outputs(data,"sequential",(13,30))
    end
end
