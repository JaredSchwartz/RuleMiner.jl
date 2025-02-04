# Function to test show() methods with various io dimensions 
function trunc_tester(object, nlines::Int, ncols::Int)
    buf = IOBuffer()
    io = IOContext(buf, :limit=>true, :displaysize=>(nlines, ncols))
    show(io, MIME"text/plain"(), object)
    result = String(take!(buf))
    return(result)
end

@testset "fptree.jl" begin
    txns = Txns(joinpath(@__DIR__,"files/frequent/data.txt"),',')
    @testset "convert Txns" begin
        tree = FPTree(txns,0.3)
        @test sort(collect(keys(tree.header_table))) == [1, 2, 3, 4, 5, 6]
        @test sort([length(i) for i in values(tree.header_table)]) == [1, 2, 2, 2, 3, 3]
    end
    @testset "Printing" begin
        tree = FPTree(txns,0.3)
        buffer = IOBuffer()
        Base.show(buffer,"text/plain", tree)
        output = String(take!(buffer))
        expected_output = """
        FPTree with 6 items and 13 nodes
        Root
            ├── milk (5)
            │   ├── eggs (4)
            │   │   ├── beer (1)
            │   │   └── bread (1)
            │   └── beer (1)
            ├── bread (2)
            │   └── ham (2)
            │       └── cheese (1)
            ├── beer (1)
            │   └── cheese (1)
            └── eggs (1)
                └── ham (1)
                    └── cheese (1)
        """
        lines = [rstrip(line) for line in eachsplit(output,'\n')]
        lines2 = [rstrip(line) for line in eachsplit(expected_output,'\n')]
        @test all(lines .== lines2)
    end
    @testset "Truncated Printing" begin
        tree = FPTree(txns,0.3)
        output = trunc_tester(tree,12,20)
        expected_output = """
        FPTree with 6 items and 13 nodes
        Root
            ├── milk (5)
            │   ├── eggs (4)
            │   │   ├...
            │   │   └...(1 more)
            │   └...(1 more)
            └...(3 more)
        """
        lines = [rstrip(line) for line in eachsplit(output,'\n')]
        lines2 = [rstrip(line) for line in eachsplit(expected_output,'\n')]
        @test all(lines .== lines2)
    end
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
        end
        @testset "last()" begin
            lastline = ["eggs", "bacon", "ham", "cheese"]
            last2 = [["milk", "beer", "ketchup", "hamburger"], ["eggs", "bacon", "ham", "cheese"]]
            @test last(data) == lastline
            @test last(data,2) == last2
        end
        @testset "Printing" begin
            buffer = IOBuffer()
            Base.show(buffer,"text/plain", data)
            output = String(take!(buffer))
            
            expected_output = """
            Txns with 9 transactions, 16 items, and 36 non-zero elements
             Index │ Items                                            
            ───────┼──────────────────────────────────────────────────
                 1 │ milk, eggs, bread
                 2 │ milk, eggs, butter, sugar, flour
                 3 │ milk, eggs, bacon, beer
                 4 │ bread, ham, turkey
                 5 │ bread, ham, cheese, ketchup
                 6 │ beer, cheese, mustard, hot dogs, buns, hamburger
                 7 │ milk, eggs, sugar
                 8 │ milk, beer, ketchup, hamburger
                 9 │ eggs, bacon, ham, cheese
            """
            lines = [rstrip(line) for line in eachsplit(output,'\n')]
            lines2 = [rstrip(line) for line in eachsplit(expected_output,'\n')]
            @test all(lines .== lines2)
        end
        @testset "Truncated Printing" begin
            output = trunc_tester(data,13,30)
            expected_output = """
                Txns with 9 transactions, 16 items, and 36 non-zero elements
                Index │ Items
                ───────┼──────────────────────
                    1 │ milk, eggs, bread
                    2 │ milk, eggs, butter,…
                    3 │ milk, eggs, bacon,…
                    ⋮ │ ⋮
                    7 │ milk, eggs, sugar
                    8 │ milk, beer,…
                    9 │ eggs, bacon, ham,…
            """
            lines = [strip(line) for line in eachsplit(strip(output),'\n')]
            lines2 = [strip(line) for line in eachsplit(strip(expected_output),'\n')]
            @test all(lines .== lines2)
        end
    end
end
@testset "seqtxns.jl" begin

    item_vals = ["bacon", "beer", "bread", "buns", "butter", "cheese", "eggs", "flour", "ham", "hamburger", "hot dogs", "ketchup", "milk", "mustard", "sugar", "turkey"]
    index_vals = ["1111", "1112", "1113", "1114", "1115", "1116", "1117", "1118", "1119","1120", "1121", "1122"]
    seq_index = UInt32.([1, 3, 4, 5, 6, 9, 10, 11, 12])

    @testset "Load Files" begin
        @testset "regular load" begin
            data = SeqTxns(joinpath(@__DIR__,"files/sequential/data.txt"),',',';')
            @test size(data.matrix) == (12,16)
            @test sum(data.matrix) == 46
            @test sort(data.colkeys) == item_vals
            @test isempty(data.linekeys)
            @test data.index == seq_index
        end

        @testset "line indexes" begin
            data = SeqTxns(joinpath(@__DIR__,"files/sequential/data_indexed.txt"),',',';';id_col = true)
            @test size(data.matrix) == (12,16)
            @test sum(data.matrix) == 46
            @test sort(data.colkeys) == item_vals
            @test sort(data.linekeys) == index_vals
            @test data.index == seq_index
        end

        @testset "skip lines" begin
            data = SeqTxns(joinpath(@__DIR__,"files/sequential/data_header.txt"),',',';';skiplines=2)
            @test size(data.matrix) == (12,16)
            @test sum(data.matrix) == 46
            @test sort(data.colkeys) == item_vals
            @test isempty(data.linekeys)
            @test data.index == seq_index
        end

        @testset "n lines" begin
            data = SeqTxns(joinpath(@__DIR__,"files/sequential/data.txt"),',',';',nlines = 1)
            @test size(data.matrix) == (2,6)
            @test sum(data.matrix) == 7
            @test sort(data.colkeys) == ["bacon", "bread", "cheese", "eggs", "ham", "milk"]
            @test isempty(data.linekeys)
            @test data.index == UInt32.([1])
        end
    end
    @testset "convert df" begin
        data = SeqTxns(joinpath(@__DIR__,"files/sequential/data.txt"),',',';')
        dftest = txns_to_df(data,true)
        dftest_data = txns_to_df(data,false)
        dftest_invalid = insertcols(dftest, :x_column => fill('x', nrow(dftest)))
        data = SeqTxns(joinpath(@__DIR__,"files/sequential/data_indexed.txt"),',',';';id_col = true)
        dftest_index =  txns_to_df(data,true)

        @testset "without index" begin
            data = SeqTxns(dftest,:SequenceIndex)
            @test size(data.matrix) == (12,16)
            @test sum(data.matrix) == 46
            @test sort(data.colkeys) == item_vals
            @test isempty(data.linekeys)
            @test data.index == seq_index
        end

        @testset "with index" begin
            data = SeqTxns(dftest_index,:SequenceIndex,:Index)
            @test size(data.matrix) == (12,16)
            @test sum(data.matrix) == 46
            @test sort(data.colkeys) == item_vals
            @test sort(data.linekeys) == index_vals
            @test data.index == seq_index
        end
        
        @testset "data only" begin
            data = Txns(dftest_data)
            @test size(data.matrix) == (12,16)
            @test sum(data.matrix) == 46
            @test sort(data.colkeys) == item_vals
            @test isempty(data.linekeys)
        end

        @testset "invalid" begin
            @test_throws "Column 'x_column' contains values that cannot be coerced to boolean." SeqTxns(dftest_invalid,:SequenceIndex)
        end

    end
    @testset "Default Constructor" begin
        newstruct = SeqTxns(joinpath(@__DIR__,"files/sequential/data.txt"),',',';')
        data = SeqTxns(newstruct.matrix, newstruct.colkeys, newstruct.linekeys, newstruct.index)
        @test size(data.matrix) == (12,16)
        @test sum(data.matrix) == 46
        @test sort(data.colkeys) == item_vals
        @test isempty(data.linekeys)
        @test data.index == seq_index
    end
    @testset "getbounds" begin
        bounds = UInt32.([2, 3, 4, 5, 8, 9, 10, 11, 12])
        data = SeqTxns(joinpath(@__DIR__,"files/sequential/data.txt"),',',';')
        @test RuleMiner.getends(data) == bounds
    end
end
