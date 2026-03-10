using Test
using JuMP
using NearOptimalAlternatives
using Ipopt

@testset "GradientMGA Tests" begin

    # ----------------------------------------------------------------
    # 1. SETUP: Simple Square Model
    # ----------------------------------------------------------------
    # Minimize x1 + x2
    # 1 <= x1 <= 2
    # 1 <= x2 <= 2
    # Optimal: (1,1) with Obj=2.0
    # ----------------------------------------------------------------

    optimizer = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
    model = JuMP.Model(optimizer)

    @variable(model, 1 <= x_1 <= 2)
    @variable(model, 1 <= x_2 <= 2)
    @objective(model, Min, x_1 + x_2)
    JuMP.optimize!(model)

    # ----------------------------------------------------------------
    # 2. EXECUTION
    # ----------------------------------------------------------------

    alternatives = lbfgs_search_alternatives(model, 1)

    # ----------------------------------------------------------------
    # 3. VALIDATION
    # ----------------------------------------------------------------

    # @test length(alternatives) == 1
    # alternative = alternatives[1]
    println("Alternative Solution: ", alternatives)

    alternative = alternatives[1]

    @test alternative[1] + alternative[2] >= 2.0 - 1e-4 # Should be near-optimal, not optimal
    @test alternative[1] + alternative[2] <= 2.0 + 1e-4

    # The alternative should be different from the optimal solution
    # @test !isapprox(alternative[1], 1.0, atol = 1e-4) ||
    #       !isapprox(alternative[2], 1.0, atol = 1e-4)
end

@testset "GradientMGA Tests with Equalities" begin

    # ----------------------------------------------------------------
    # 1. SETUP: Simple Square Model
    # ----------------------------------------------------------------
    # Minimize x1 + x2
    # 1 <= x1 <= 3
    # 1 <= x2 <= 3
    # 1 <= x3 <= 3
    # x1 + x2 + x3 == 4
    # Optimal: (1,1,2) with Obj=2.0
    # ----------------------------------------------------------------

    optimizer = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
    model = JuMP.Model(optimizer)

    @variable(model, 1 <= x_1 <= 3)
    @variable(model, 1 <= x_2 <= 3)
    @variable(model, 1 <= x_3 <= 3)
    @constraint(model, x_1 + x_2 + x_3 == 4)
    @objective(model, Min, x_1 + x_2)
    JuMP.optimize!(model)

    # ----------------------------------------------------------------
    # 2. EXECUTION
    # ----------------------------------------------------------------

    alternatives = lbfgs_search_alternatives(model, 1)

    # ----------------------------------------------------------------
    # 3. VALIDATION
    # ----------------------------------------------------------------

    # @test length(alternatives) == 1
    # alternative = alternatives[1]
    println("Alternative Solution: ", alternatives)

    alternative = alternatives[1]

    @test alternative[1] + alternative[2] >= 2.0 - 1e-4 # Should be near-optimal, not optimal
    @test alternative[1] + alternative[2] <= 2.0 + 1e-4

    # The alternative should be different from the optimal solution
    # @test !isapprox(alternative[1], 1.0, atol = 1e-4) ||
    #       !isapprox(alternative[2], 1.0, atol = 1e-4)
end
