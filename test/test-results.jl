@testset "Update solutions of NearOptimalAlternatives optimisation" begin
    @testset "Make sure using an unsolved NearOptimalAlternatives model fails." begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)
        results = NearOptimalAlternatives.AlternativeSolutions([], [])
        @test_throws ErrorException NearOptimalAlternatives.update_solutions!(
            results,
            model,
        )
    end

    @testset "Test error when no `original_objective` constraint present." begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        # Initialise simple `square` JuMP model
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, (x_1 - 1)^2 + (x_2 - 1)^2)
        @constraint(model, x_1 + x_2 ≥ 1.8)

        results = NearOptimalAlternatives.AlternativeSolutions([], [])
        JuMP.optimize!(model)
        @test_throws ErrorException NearOptimalAlternatives.update_solutions!(
            results,
            model,
        )
    end

    @testset "Test correct flow for updating the set of results using a solved JuMP model." begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        # Initialise simple `square` JuMP model
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, (x_1 - 1)^2 + (x_2 - 1)^2)
        @constraint(model, original_objective, x_1 + x_2 ≥ 1.8)

        results = NearOptimalAlternatives.AlternativeSolutions([], [])
        JuMP.optimize!(model)
        NearOptimalAlternatives.update_solutions!(results, model)

        # Test that only one solution is generated for 2 variables. Result should be approximately between 1.8 and 2.0 (with room for computational error).
        @test length(results.solutions) == 1 &&
              length(results.solutions[1]) == 2 &&
              length(results.objective_values) == 1 &&
              (
                  results.objective_values[1] ≥ 1.8 ||
                  isapprox(results.objective_values[1], 1.8)
              ) &&
              (
                  results.objective_values[1] ≤ 2.0 ||
                  isapprox(results.objective_values[1], 2.0)
              )
    end
end
