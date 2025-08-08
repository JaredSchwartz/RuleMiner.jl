data = Txns(joinpath(@__DIR__,"files/frequent/data.txt"),',')

# Define custom itemset sorting function 
function setsorter!(itemsets::DataFrame)
    transform!(itemsets,:Itemset => ( x -> sort.(x) ) => :Itemset)
    transform!(itemsets,:Itemset => ( x -> join.(x) ) => :SetHash)
    sort!(itemsets,[:Length,:SetHash])
    select!(itemsets,Not(:SetHash))
end

# Helper function for testing algorithms with both percentage and absolute support
function test_algorithms(algorithms, perc_sup, abs_sup, expected_items, expected_supports, expected_N, expected_length, data)
    support_types = [("percentage support", perc_sup), ("absolute support", abs_sup)]
    
    for (alg_name, alg_func) in algorithms
        @testset "$alg_name" begin
            for (sup_name, sup_value) in support_types
                @testset "$sup_name" begin
                    sets = alg_func(data, sup_value)
                    setsorter!(sets)
                    @test sets.Itemset == expected_items
                    @test sets.Support ≈ expected_supports
                    @test sets.N == expected_N
                    @test sets.Length == expected_length
                end
            end
            @testset "Errors" begin
                invalid_supports = Any[-0.5,0.0,1.5,-1,0,data.n_transactions+1]
                for val in invalid_supports
                    @test_throws DomainError alg_func(data,val)
                end
            end
        end
    end
end

@testset "frequent" begin
    # Define Frequent Itemset results at support of 3/0.3
    freq_items = [["beer"], ["bread"], ["cheese"], ["eggs"], ["ham"], ["milk"], ["eggs", "milk"]]
    freq_supports = [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.5555555555555556, 0.3333333333333333, 0.5555555555555556, 0.4444444444444444]
    freq_N = [3, 3, 3, 5, 3, 5, 4]
    freq_length = [1, 1, 1, 1, 1, 1, 2]

    algorithms = [("eclat.jl", eclat), ("fpgrowth.jl", fpgrowth)]
    test_algorithms(algorithms, 0.3, 3, freq_items, freq_supports, freq_N, freq_length, data)
end

@testset "closed" begin
    # Define Closed Itemset results at support of 2/0.2
    closed_items = [["beer"], ["bread"], ["cheese"], ["eggs"], ["ham"], ["ketchup"], ["milk"], ["bacon", "eggs"], ["beer", "hamburger"], ["beer", "milk"], ["bread", "ham"], ["cheese", "ham"], ["eggs", "milk"], ["eggs", "milk", "sugar"]]
    closed_supports = [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.5555555555555556, 0.3333333333333333, 0.2222222222222222, 0.5555555555555556, 0.2222222222222222, 0.2222222222222222, 0.2222222222222222, 0.2222222222222222, 0.2222222222222222, 0.4444444444444444, 0.2222222222222222]
    closed_N = [3, 3, 3, 5, 3, 2, 5, 2, 2, 2, 2, 2, 4, 2]
    closed_length = [1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 3]

    algorithms = [("fpclose.jl", fpclose), ("charm.jl", charm), ("carpenter.jl", carpenter), ("lcm.jl", LCM)]
    test_algorithms(algorithms, 0.2, 2, closed_items, closed_supports, closed_N, closed_length, data)
end

@testset "maximal" begin
    # Define Maximal Itemset results at support of 3/0.3
    max_items = [["beer"], ["bread"], ["cheese"], ["ham"], ["eggs", "milk"]]
    max_supports = [0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.3333333333333333, 0.4444444444444444]
    max_N = [3, 3, 3, 3, 4]
    max_length = [1, 1, 1, 1, 2]

    algorithms = [("fpmax.jl", fpmax), ("genmax.jl", genmax)]
    test_algorithms(algorithms, 0.3, 3, max_items, max_supports, max_N, max_length, data)
end

@testset "recovery.jl" begin
    test_support = 2
    expected = eclat(data, test_support)
    setsorter!(expected)

    @testset "recover_closed" begin
        closed_sets = LCM(data, test_support)
        recovered = recover_closed(closed_sets, test_support)
        setsorter!(recovered)
        
        @test recovered.Itemset == expected.Itemset
        @test recovered.N == expected.N
        @test recovered.Length == expected.Length
    end
    @testset "recover_maximal" begin
        maximal_sets = genmax(data, test_support)
        recovered = recover_maximal(maximal_sets)
        setsorter!(recovered)
        
        @test recovered.Itemset == expected.Itemset
        @test recovered.Length == expected.Length
    end
end