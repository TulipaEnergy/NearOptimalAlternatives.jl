@testset "Test generate alternatives with Directionally Weighted Variables as modeling_method." begin
    @testset "Test regular run with one alternative." begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        # initialize simple `square` JuMP model
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, x_1 + x_2)
        JuMP.optimize!(model)

        results = generate_alternatives_optimization!(
            model,
            0.1,
            all_variables(model),
            1;
            modeling_method = :Directionally_Weighted_Variables,
        )

        # Test that `results` contains one solution with 2 variables, and an objective value between 1.8 and 2.0.
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

    @testset "Test regular run with one alternative with one fixed variable." begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        # initialize simple `square` JuMP model
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, x_1 + x_2)
        JuMP.optimize!(model)

        results = generate_alternatives_optimization!(
            model,
            0.1,
            all_variables(model),
            1;
            fixed_variables = [x_2],
            modeling_method = :Directionally_Weighted_Variables,
        )

        # Test that `results` contains one solution with 2 variables, and an objective value between 1.8 and 2.0. Also, `x_2` should remain around 1.0 and `x_1` should be between 0.8 and 1.0.
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
              ) &&
              (
                  results.solutions[1][x_1] ≥ 0.8 ||
                  isapprox(results.solutions[1][x_1], 0.8)
              ) &&
              (
                  results.solutions[1][x_1] ≤ 1.0 ||
                  isapprox(results.solutions[1][x_1], 1.0)
              ) &&
              isapprox(results.solutions[1][x_2], 1.0)
    end

    @testset "Test regular run with two alternatives." begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        # initialize simple `square` JuMP model
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, x_1 + x_2)
        JuMP.optimize!(model)

        results = generate_alternatives_optimization!(
            model,
            0.1,
            all_variables(model),
            2;
            modeling_method = :Directionally_Weighted_Variables,
        )

        # Test that `results` contains 2 solutions with two variables each, where the objective values of both solutions are between 1.8 and 2.0.
        @test length(results.solutions) == 2 &&
              length(results.solutions[1]) == 2 &&
              length(results.solutions[2]) == 2 &&
              length(results.objective_values) == 2 &&
              (
                  results.objective_values[1] ≥ 1.8 ||
                  isapprox(results.objective_values[1], 1.8)
              ) &&
              (
                  results.objective_values[1] ≤ 2.0 ||
                  isapprox(results.objective_values[1], 2.0)
              ) &&
              (
                  results.objective_values[2] ≥ 1.8 ||
                  isapprox(results.objective_values[2], 1.8)
              ) &&
              (
                  results.objective_values[2] ≤ 2.0 ||
                  isapprox(results.objective_values[2], 2.0)
              )
    end
    @testset "Test weights" begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @variable(model, 0 ≤ x_3 ≤ 1)

        @objective(model, Max, x_1 - x_2 + 0 * x_3)
        JuMP.optimize!(model)

        old_objective = JuMP.objective_function(model)
        weights = zeros(3)
        DWV_initial!(
            model,
            [x_1, x_2, x_3],
            VariableRef[];
            weights = weights,
            old_objective = old_objective,
        )

        @test weights[1] in (0, 1)
        @test weights[2] in (-1, 0)
        @test weights[3] in (-1, 0, 1)

        weights_update = zeros(3)
        DWV_update!(
            model,
            [x_1, x_2, x_3];
            weights = weights_update,
            old_objective = old_objective,
        )

        @test weights_update[1] in (0, 1)
        @test weights_update[2] in (-1, 0)
        @test weights_update[3] in (-1, 0, 1)
    end
end
