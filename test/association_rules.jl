# Load data
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

@testset "apriori.jl" begin
    @testset "percentage support" begin
        rules = apriori(data,rule_perc_sup,0.0,rule_max_len)
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
        rules = apriori(data,rule_abs_sup,0.0,rule_max_len)
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
    @testset "minimum confidence" begin
        min_conf = 0.5
        rules = apriori(data,rule_abs_sup,min_conf,rule_max_len)
        @test minimum(rules[:,:Confidence]) >= min_conf
    end
    @testset "Errors" begin
        invalid_supports = Any[-1,0,-0.5,0.0]
        for val in invalid_supports
            @test_throws DomainError apriori(data,val)
        end
    end
end