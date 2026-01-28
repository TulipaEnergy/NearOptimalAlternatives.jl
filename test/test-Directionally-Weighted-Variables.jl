@testset "Test model after creating alternative problem optimization with Directionally Weighted Variables as modeling_method." begin
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
            modeling_method = :Directionally_Weighted_Variables,
        )
        # Test that the correct alternative problem is created.
        # DWV: weights depend on original objective coefficient sign
        # Original objective: x_1 + x_2 (both positive coefficients)
        # So weights should be from {0, 1} for both
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
            modeling_method = :Directionally_Weighted_Variables,
        )
        # Test that the correct alternative problem is created.
        # DWV: weights depend on original objective coefficient sign
        # Original objective: x_1 + x_2 (both positive coefficients)
        # So weights should be from {0, 1} for both
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

    @testset "Test simple maximization with fixed variables" begin
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
            [x_2],
            all_variables(model);
            weights = weights,
            modeling_method = :Directionally_Weighted_Variables,
        )
        # Test that the correct alternative problem is created and that `x_2` is fixed.
        obj = objective_function(model)
        @test objective_sense(model) == MIN_SENSE &&
              weights[1] in [0, 1] &&
              weights[2] in [0, 1] &&
              JuMP.coefficient(obj, x_1) == weights[1] &&
              JuMP.coefficient(obj, x_2) == weights[2] &&
              constraint_object(model[:original_objective]).func ==
              AffExpr(0, x_1 => 1, x_2 => 1) &&
              constraint_object(model[:original_objective]).set ==
              MOI.GreaterThan(0.9 * (x_1_res + x_2_res)) &&
              is_fixed(x_2)
    end

    @testset "Test simple minimization problem with fixed variables" begin
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
            [x_1],
            all_variables(model);
            weights = weights,
            modeling_method = :Directionally_Weighted_Variables,
        )
        # Test that the correct alternative problem is created.
        obj = objective_function(model)
        @test objective_sense(model) == MIN_SENSE &&
              weights[1] in [0, 1] &&
              weights[2] in [0, 1] &&
              JuMP.coefficient(obj, x_1) == weights[1] &&
              JuMP.coefficient(obj, x_2) == weights[2] &&
              constraint_object(model[:original_objective]).func ==
              AffExpr(0, x_1 => 1, x_2 => 1) &&
              constraint_object(model[:original_objective]).set ==
              MOI.LessThan(1.1 * (x_1_res + x_2_res)) &&
              is_fixed(x_1)
    end

    @testset "Test DWV weights depend on original objective coefficient sign" begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        # Create a model with mixed coefficient signs
        @variable(model, 0 ≤ x_1 ≤ 1)  # positive coefficient in objective
        @variable(model, 0 ≤ x_2 ≤ 1)  # negative coefficient in objective
        @variable(model, 0 ≤ x_3 ≤ 1)  # zero coefficient in objective

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

        # DWV: weights depend on original objective coefficient sign:
        # - positive coefficient (x_1): weight from {0, 1}
        # - negative coefficient (x_2): weight from {-1, 0}
        # - zero coefficient (x_3): weight from {-1, 0, 1}
        @test weights[1] in [0, 1]
        @test weights[2] in [-1, 0]
        @test weights[3] in [-1, 0, 1]
    end

    @testset "Test DWV update also respects coefficient signs" begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @variable(model, 0 ≤ x_3 ≤ 1)

        @objective(model, Max, x_1 - x_2 + 0 * x_3)
        JuMP.optimize!(model)

        old_objective = JuMP.objective_function(model)
        weights_update = zeros(3)
        DWV_update!(
            model,
            [x_1, x_2, x_3];
            weights = weights_update,
            old_objective = old_objective,
        )

        # Same rules apply to update
        @test weights_update[1] in [0, 1]
        @test weights_update[2] in [-1, 0]
        @test weights_update[3] in [-1, 0, 1]
    end
end

@testset "Test model after updating a solution with Directionally Weighted Variables as modeling_method." begin
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
        modeling_method = :Directionally_Weighted_Variables,
    )
    # Test that the correct alternative problem is created.
    # DWV: original objective has positive coefficients, so weights from {0, 1}
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

@testset "Test results with Directionally Weighted Variables as modeling_method." begin
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
            JuMP.all_variables(model),
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
            JuMP.all_variables(model),
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
            JuMP.all_variables(model),
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
end
