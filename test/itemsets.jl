data = Txns(joinpath(@__DIR__,"files/frequent/data.txt"),',')

# Define custom itemset sorting function 
function setsorter!(itemsets::DataFrame)
    transform!(itemsets,:Itemset => ( x -> sort.(x) ) => :Itemset)
    transform!(itemsets,:Itemset => ( x -> join.(x) ) => :SetHash)
    sort!(itemsets,[:Length,:SetHash])
    select!(itemsets,Not(:SetHash))
end

@testset "frequent" begin
    # Define Frequent Itemset results at support of 3/0.3
    freq_abs_sup = 3
    freq_perc_sup = 0.3
    freq_items = [["beer"], ["bread"], ["cheese"], ["eggs"], ["ham"], ["milk"], ["eggs", "milk"]]
    freq_supports = [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.5555555555555556, 0.3333333333333333, 0.5555555555555556, 0.4444444444444444]
    freq_N = [3, 3, 3, 5, 3, 5, 4]
    freq_length = [1, 1, 1, 1, 1, 1, 2]

    @testset "eclat.jl" begin
        @testset "percentage support" begin
            sets = eclat(data,freq_perc_sup)
            setsorter!(sets)
            @test sets.Itemset == freq_items
            @test sets.Support ≈ freq_supports
            @test sets.N == freq_N
            @test sets.Length == freq_length
        end
        @testset "absolute support" begin
            sets = eclat(data,freq_abs_sup)
            setsorter!(sets)
            @test sets.Itemset == freq_items
            @test sets.Support ≈ freq_supports
            @test sets.N == freq_N
            @test sets.Length == freq_length
        end
    end
    @testset "fpgrowth.jl" begin
        @testset "percentage support" begin
            sets = fpgrowth(data,freq_perc_sup)
            setsorter!(sets)
            @test sets.Itemset == freq_items
            @test sets.Support ≈ freq_supports
            @test sets.N == freq_N
            @test sets.Length == freq_length
        end
        @testset "absolute support" begin
            sets = fpgrowth(data,freq_abs_sup)
            setsorter!(sets)
            @test sets.Itemset == freq_items
            @test sets.Support ≈ freq_supports
            @test sets.N == freq_N
            @test sets.Length == freq_length
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
end

@testset "closed" begin
    # Define Closed Itemset results at support of 2/0.2
    closed_abs_sup = 2
    closed_perc_sup = 0.2
    closed_items = [["beer"], ["bread"], ["cheese"], ["eggs"], ["ham"], ["ketchup"], ["milk"], ["bacon", "eggs"], ["beer", "hamburger"], ["beer", "milk"], ["bread", "ham"], ["cheese", "ham"], ["eggs", "milk"], ["eggs", "milk", "sugar"]]
    closed_supports = [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.5555555555555556, 0.3333333333333333, 0.2222222222222222, 0.5555555555555556, 0.2222222222222222, 0.2222222222222222, 0.2222222222222222, 0.2222222222222222, 0.2222222222222222, 0.4444444444444444, 0.2222222222222222]
    closed_N = [3, 3, 3, 5, 3, 2, 5, 2, 2, 2, 2, 2, 4, 2]
    closed_length = [1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 3]

    @testset "fpclose.jl" begin
        @testset "percentage support" begin
            sets = fpclose(data,closed_perc_sup)
            setsorter!(sets)
            @test sets.Itemset == closed_items
            @test sets.Support ≈ closed_supports
            @test sets.N == closed_N
            @test sets.Length == closed_length
        end
        @testset "absolute support" begin
            sets = fpclose(data,closed_abs_sup)
            setsorter!(sets)
            @test sets.Itemset == closed_items
            @test sets.Support ≈ closed_supports
            @test sets.N == closed_N
            @test sets.Length == closed_length
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
        @testset "absolute support" begin
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
        @testset "absolute support" begin
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
        @testset "absolute support" begin
            sets = LCM(data,closed_abs_sup)
            setsorter!(sets)
            @test sets.Itemset == closed_items
            @test sets.Support ≈ closed_supports
            @test sets.N == closed_N
            @test sets.Length == closed_length
        end
    end
end

@testset "maximal" begin
    # Define Maximal Itemset results at support of 3/0.3
    max_abs_sup = 3
    max_perc_sup = 0.3
    max_items = [["beer"], ["bread"], ["cheese"], ["ham"], ["eggs", "milk"]]
    max_supports = [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.4444444444444444]
    max_N = [3, 3, 3, 3, 4]
    max_length = [1, 1, 1, 1, 2]

    @testset "fpmax.jl" begin
        @testset "percentage support" begin
            sets = fpmax(data,max_perc_sup)
            setsorter!(sets)
            @test sets.Itemset == max_items
            @test sets.Support ≈ max_supports
            @test sets.N == max_N
            @test sets.Length == max_length
        end
        @testset "absolute support" begin
            sets = fpmax(data,max_abs_sup)
            setsorter!(sets)
            @test sets.Itemset == max_items
            @test sets.Support ≈ max_supports
            @test sets.N == max_N
            @test sets.Length == max_length
        end
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
        @testset "absolute support" begin
            sets = genmax(data,max_abs_sup)
            setsorter!(sets)
            @test sets.Itemset == max_items
            @test sets.Support ≈ max_supports
            @test sets.N == max_N
            @test sets.Length == max_length
        end
    end

end