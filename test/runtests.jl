using RuleMiner, DataFrames
using Test


@testset "transactions.jl" begin
    @testset "Load Files" begin
        @testset "regular load" begin
            data = load_transactions(joinpath(@__DIR__,"files/data.txt"),',')
            @test size(data.matrix) == (9,16)
            @test sum(data.matrix) == 36
            @test hash(sort(collect(values(data.colkeys)))) == UInt64(14154404351539088851)
            @test hash(sort(collect(values(data.linekeys)))) == UInt64(1066772112083085456)
        end

        @testset "line indexes" begin
            data = load_transactions(joinpath(@__DIR__,"files/data_indexed.txt"),',';id_col = true)
            @test size(data.matrix) == (9,16)
            @test sum(data.matrix) == 36
            @test hash(sort(collect(values(data.colkeys)))) == UInt64(14154404351539088851)
            @test hash(sort(collect(values(data.linekeys)))) == UInt64(10356874651475808405)
        end

        @testset "skip lines" begin
            data = load_transactions(joinpath(@__DIR__,"files/data_header.txt"),',';skiplines=2)
            @test size(data.matrix) == (9,16)
            @test sum(data.matrix) == 36
            @test hash(sort(collect(values(data.colkeys)))) == UInt64(14154404351539088851)
            @test hash(sort(collect(values(data.linekeys)))) == UInt64(1066772112083085456)
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
            @test hash(sort(collect(values(data.colkeys)))) == UInt64(14154404351539088851)
            @test hash(sort(collect(values(data.linekeys)))) == UInt64(1066772112083085456)
        end

        @testset "with index" begin
            data = transactions(dftest_index;indexcol=:Index)
            @test size(data.matrix) == (9,16)
            @test sum(data.matrix) == 36
            @test hash(sort(collect(values(data.colkeys)))) == UInt64(14154404351539088851)
            @test hash(sort(collect(values(data.linekeys)))) == UInt64(10356874651475808405)
        end

    end
end

@testset "apriori.jl" begin
    data = load_transactions(joinpath(@__DIR__,"files/data.txt"),',')

    @testset "percentage support" begin
        rules = apriori(data,0.3,5)
        transform!(rules,:LHS =>( x -> hash.(x) ) => :SetHash)
        sort!(rules,[:Length,:SetHash,:RHS])
        @test hash(rules.LHS) == UInt64(10944680318112923216)
        @test hash(rules.RHS) == UInt64(7170342362675143343)
        @test hash(rules.Support) == UInt64(18329550519797518446)
        @test hash(rules.Confidence) == UInt64(10378668557036289636)
        @test hash(rules.Coverage) == UInt64(17208738295533172824)
        @test hash(rules.Lift) == UInt64(18282341198944935968)
        @test hash(rules.N) == UInt64(2389578521758638798)
        @test hash(rules.Length) == UInt64(12370468415001452020)
    end

    @testset "absolute support" begin
        rules = apriori(data,2,5)
        transform!(rules,:LHS =>( x -> hash.(x) ) => :SetHash)
        sort!(rules,[:Length,:SetHash,:RHS])
        @test hash(rules.LHS) == UInt64(10944680318112923216)
        @test hash(rules.RHS) == UInt64(7170342362675143343)
        @test hash(rules.Support) == UInt64(18329550519797518446)
        @test hash(rules.Confidence) == UInt64(10378668557036289636)
        @test hash(rules.Coverage) == UInt64(17208738295533172824)
        @test hash(rules.Lift) == UInt64(18282341198944935968)
        @test hash(rules.N) == UInt64(2389578521758638798)
        @test hash(rules.Length) == UInt64(12370468415001452020)
    end
end

@testset "eclat.jl" begin
    data = load_transactions(joinpath(@__DIR__,"files/data.txt"),',')
    
    @testset "percentage support" begin
        sets = eclat(data,0.3)
        transform!(sets,:Itemset =>( x -> hash.(x) ) => :SetHash)
        sort!(sets,[:Length,:SetHash])
        @test hash(sets.Itemset) == UInt64(9215540465155188081)
        @test hash(sets.Support) == UInt64(9491076249976136591)
        @test hash(sets.N) == UInt64(13538681268459648389)
        @test hash(sets.Length) == UInt64(3041221529991437560)
    end
    
    @testset "asbolute support" begin
        sets = eclat(data,3)
        transform!(sets,:Itemset =>( x -> hash.(x) ) => :SetHash)
        sort!(sets,[:Length,:SetHash])
        @test hash(sets.Itemset) == UInt64(9215540465155188081)
        @test hash(sets.Support) == UInt64(9491076249976136591)
        @test hash(sets.N) == UInt64(13538681268459648389)
        @test hash(sets.Length) == UInt64(3041221529991437560)
    end
end