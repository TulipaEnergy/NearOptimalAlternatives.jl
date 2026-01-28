@testset "Test model after creating alternative problem optimization with HSJ as modeling_method." begin
    @testset "Test simple maximization problem" begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        # initialize simple `square` JuMP model
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, x_1 + x_2)
        JuMP.optimize!(model)
        # Store the values of `x_1` and `x_2` to test that the correct values are used in the created alternative generation problem.
        x_1_res = value(x_1)
        x_2_res = value(x_2)

        weights = zeros(2)
        NearOptimalAlternatives.create_alternative_generating_problem!(
            model,
            0.1,
            VariableRef[],
            all_variables(model);
            weights = weights,
            modeling_method = :HSJ,
        )
        # Test that the correct alternative problem is created.
        # HSJ: weights are 0 or 1 based on zero/non-zero value
        obj = objective_function(model)
        @test objective_sense(model) == MIN_SENSE &&
              weights[1] in [0, 1] &&
              weights[2] in [0, 1] &&
              JuMP.coefficient(obj, x_1) == weights[1] &&
              JuMP.coefficient(obj, x_2) == weights[2] &&
              constraint_object(model[:original_objective]).func ==
              AffExpr(0, x_1 => 1, x_2 => 1) &&
              constraint_object(model[:original_objective]).set ==
              MOI.GreaterThan(0.9 * (x_1_res + x_2_res))
    end

    @testset "Test simple minimization problem" begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        # initialize simple `square` JuMP model
        @variable(model, 1 ≤ x_1 ≤ 2)
        @variable(model, 1 ≤ x_2 ≤ 2)
        @objective(model, Min, x_1 + x_2)
        JuMP.optimize!(model)
        # Store the values of `x_1` and `x_2` to test that the correct values are used in the created alternative generation problem.
        x_1_res = value(x_1)
        x_2_res = value(x_2)

        weights = zeros(2)
        NearOptimalAlternatives.create_alternative_generating_problem!(
            model,
            0.1,
            VariableRef[],
            all_variables(model);
            weights = weights,
            modeling_method = :HSJ,
        )
        # Test that the correct alternative problem is created.
        # HSJ: weights are 0 or 1 based on zero/non-zero value
        obj = objective_function(model)
        @test objective_sense(model) == MIN_SENSE &&
              weights[1] in [0, 1] &&
              weights[2] in [0, 1] &&
              JuMP.coefficient(obj, x_1) == weights[1] &&
              JuMP.coefficient(obj, x_2) == weights[2] &&
              constraint_object(model[:original_objective]).func ==
              AffExpr(0, x_1 => 1, x_2 => 1) &&
              constraint_object(model[:original_objective]).set ==
              MOI.LessThan(1.1 * (x_1_res + x_2_res))
    end
end

@testset "Test HSJ weights based on zero/non-zero variable values" begin
    @testset "Test HSJ_initial! sets weights to 0 or 1" begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        # Create a model where x_1 will be non-zero and x_2 is forced to 0
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, x_2 == 0)  # Force x_2 to be exactly 0
        @objective(model, Max, x_1 + x_2)
        JuMP.optimize!(model)

        # Verify setup: x_1 should be 1, x_2 should be 0
        @test value(x_1) ≈ 1.0
        @test value(x_2) == 0.0

        weights = zeros(2)
        HSJ_initial!(model, [x_1, x_2], VariableRef[]; weights = weights)

        # HSJ: weight = 1 if value ≠ 0, weight = 0 if value = 0
        @test weights[1] == 1  # x_1 was non-zero
        @test weights[2] == 0  # x_2 was zero
    end

    @testset "Test HSJ_update! also sets weights based on current values" begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, x_1 + x_2)
        JuMP.optimize!(model)

        # Both should be 1 at optimum
        @test value(x_1) ≈ 1.0
        @test value(x_2) ≈ 1.0

        weights = zeros(2)
        HSJ_update!(model, [x_1, x_2]; weights = weights)

        # Both were non-zero, so both weights should be 1
        @test weights[1] == 1
        @test weights[2] == 1
    end
end

@testset "Test model after updating a solution with HSJ as modeling_method." begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # initialize simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, 2 * x_1 + x_2)
    @constraint(model, original_objective, x_1 + x_2 ≥ 1.8)
    JuMP.optimize!(model)

    weights = zeros(2)
    NearOptimalAlternatives.update_objective_function!(
        model,
        all_variables(model);
        weights = weights,
        modeling_method = :HSJ,
    )
    # Test that the correct alternative problem is created.
    # HSJ: weights are 0 or 1 based on zero/non-zero value
    obj = objective_function(model)
    @test objective_sense(model) == MIN_SENSE &&
          weights[1] in [0, 1] &&
          weights[2] in [0, 1] &&
          JuMP.coefficient(obj, x_1) == weights[1] &&
          JuMP.coefficient(obj, x_2) == weights[2] &&
          constraint_object(model[:original_objective]).func ==
          AffExpr(0, x_1 => 1, x_2 => 1) &&
          constraint_object(model[:original_objective]).set == MOI.GreaterThan(1.8)
end

@testset "Test generate alternatives with HSJ as modeling_method." begin
    @testset "Test regular run with one alternative." begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        # initialize simple `square` JuMP model
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, x_1 + x_2)
        JuMP.optimize!(model)

        results = NearOptimalAlternatives.generate_alternatives_optimization!(
            model,
            0.1,
            all_variables(model),
            1;
            modeling_method = :HSJ,
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

        results = NearOptimalAlternatives.generate_alternatives_optimization!(
            model,
            0.1,
            all_variables(model),
            1;
            fixed_variables = [x_2],
            modeling_method = :HSJ,
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

        results = NearOptimalAlternatives.generate_alternatives_optimization!(
            model,
            0.1,
            all_variables(model),
            2;
            modeling_method = :HSJ,
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
end
