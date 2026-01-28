@testset "Test model after creating alternative problem optimization with Max Distance as modeling_method." begin
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

        NearOptimalAlternatives.create_alternative_generating_problem!(
            model,
            0.1,
            VariableRef[],
            all_variables(model);
            metric = SqEuclidean(),
        )
        # Test that the correct alternative problem is created.
        @test objective_sense(model) == MAX_SENSE &&
              objective_function(model) == QuadExpr(
                  AffExpr(x_1_res^2 + x_2_res^2, x_1 => -2 * x_1_res, x_2 => -2 * x_2_res),
                  UnorderedPair(x_1, x_1) => 1,
                  UnorderedPair(x_2, x_2) => 1,
              ) &&
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

        NearOptimalAlternatives.create_alternative_generating_problem!(
            model,
            0.1,
            VariableRef[],
            all_variables(model);
            metric = SqEuclidean(),
        )
        # Test that the correct alternative problem is created.
        @test objective_sense(model) == MAX_SENSE &&
              objective_function(model) == QuadExpr(
                  AffExpr(x_1_res^2 + x_2_res^2, x_1 => -2 * x_1_res, x_2 => -2 * x_2_res),
                  UnorderedPair(x_1, x_1) => 1,
                  UnorderedPair(x_2, x_2) => 1,
              ) &&
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

        NearOptimalAlternatives.create_alternative_generating_problem!(
            model,
            0.1,
            [x_2],
            all_variables(model);
            metric = SqEuclidean(),
        )
        # Test that the correct alternative problem is created and that `x_2` is fixed.
        @test objective_sense(model) == MAX_SENSE &&
              objective_function(model) == QuadExpr(
                  AffExpr(x_1_res^2 + x_2_res^2, x_1 => -2 * x_1_res, x_2 => -2 * x_2_res),
                  UnorderedPair(x_1, x_1) => 1,
                  UnorderedPair(x_2, x_2) => 1,
              ) &&
              constraint_object(model[:original_objective]).func ==
              AffExpr(0, x_1 => 1, x_2 => 1) &&
              constraint_object(model[:original_objective]).set ==
              MOI.GreaterThan(0.9 * (x_1_res + x_2_res)) &&
              is_fixed(x_2)
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

        NearOptimalAlternatives.create_alternative_generating_problem!(
            model,
            0.1,
            [x_1],
            all_variables(model);
            metric = SqEuclidean(),
        )
        # Test that the correct alternative problem is created.
        @test objective_sense(model) == MAX_SENSE &&
              objective_function(model) == QuadExpr(
                  AffExpr(x_1_res^2 + x_2_res^2, x_1 => -2 * x_1_res, x_2 => -2 * x_2_res),
                  UnorderedPair(x_1, x_1) => 1,
                  UnorderedPair(x_2, x_2) => 1,
              ) &&
              constraint_object(model[:original_objective]).func ==
              AffExpr(0, x_1 => 1, x_2 => 1) &&
              constraint_object(model[:original_objective]).set ==
              MOI.LessThan(1.1 * (x_1_res + x_2_res)) &&
              is_fixed(x_1)
    end
end

@testset "Test model after updating a solution with Max Distance as modeling_method." begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # initialize simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, 2 * x_1 + x_2)
    @constraint(model, original_objective, x_1 + x_2 ≥ 1.8)
    JuMP.optimize!(model)
    # Store the values of `x_1` and `x_2` to test that the correct values are used in the created alternative generation problem.
    x_1_res = value(x_1)
    x_2_res = value(x_2)
    old_objective = objective_function(model)

    NearOptimalAlternatives.update_objective_function!(
        model,
        all_variables(model);
        metric = SqEuclidean(),
    )
    # Test that the correct alternative problem is created and that `x_2` is fixed.
    @test objective_sense(model) == MAX_SENSE &&
          objective_function(model) ==
          old_objective +
          Distances.evaluate(SqEuclidean(), [x_1, x_2], [x_1_res, x_2_res]) &&
          constraint_object(model[:original_objective]).func ==
          AffExpr(0, x_1 => 1, x_2 => 1) &&
          constraint_object(model[:original_objective]).set == MOI.GreaterThan(1.8)
end

@testset "Test results with Max Distance as modeling_method." begin
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
            modeling_method = :Max_Distance,
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
            modeling_method = :Max_Distance,
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
            modeling_method = :Max_Distance,
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

    @testset "Test regular run with one alternative and a weighted metric." begin
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
            metric = WeightedSqEuclidean([0.5, 10]),
            modeling_method = :Max_Distance,
        )

        # Test that `results` contains one solution with two variables. Logically, due to the weights this solution should return around 0.8 for `x_2` and 1.0 for `x_1`.
        @test length(results.solutions) == 1 &&
              length(results.solutions[1]) == 2 &&
              length(results.objective_values) == 1 &&
              isapprox(results.objective_values[1], 1.8, atol = 0.01) &&
              isapprox(results.solutions[1][x_2], 0.8, atol = 0.01) &&
              isapprox(results.solutions[1][x_1], 1.0, atol = 0.01)
    end
end
