@testset "Test model after creating alternative problem optimization with Random Vector as modeling_method." begin
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
            modeling_method = :Random_Vector,
        )
        # Test that the correct alternative problem is created.
        # Random_Vector: weights uniformly chosen from [-1, 1]
        obj = objective_function(model)
        @test objective_sense(model) == MIN_SENSE &&
              -1 ≤ weights[1] ≤ 1 &&
              -1 ≤ weights[2] ≤ 1 &&
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
            modeling_method = :Random_Vector,
        )
        # Test that the correct alternative problem is created.
        # Random_Vector: weights uniformly chosen from [-1, 1]
        obj = objective_function(model)
        @test objective_sense(model) == MIN_SENSE &&
              -1 ≤ weights[1] ≤ 1 &&
              -1 ≤ weights[2] ≤ 1 &&
              JuMP.coefficient(obj, x_1) == weights[1] &&
              JuMP.coefficient(obj, x_2) == weights[2] &&
              constraint_object(model[:original_objective]).func ==
              AffExpr(0, x_1 => 1, x_2 => 1) &&
              constraint_object(model[:original_objective]).set ==
              MOI.LessThan(1.1 * (x_1_res + x_2_res))
    end
end

@testset "Test Random_Vector weights are continuous in [-1, 1]" begin
    @testset "Test Random_Vector_initial! sets weights in [-1, 1]" begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @variable(model, 0 ≤ x_3 ≤ 1)
        @objective(model, Max, x_1 + x_2 + x_3)
        JuMP.optimize!(model)

        weights = zeros(3)
        Random_Vector_initial!(model, [x_1, x_2, x_3], VariableRef[]; weights = weights)

        # Random_Vector: weights are uniformly chosen from [-1, 1]
        @test -1 ≤ weights[1] ≤ 1
        @test -1 ≤ weights[2] ≤ 1
        @test -1 ≤ weights[3] ≤ 1
    end

    @testset "Test Random_Vector_update! also sets weights in [-1, 1]" begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @variable(model, 0 ≤ x_3 ≤ 1)
        @objective(model, Max, x_1 + x_2 + x_3)
        JuMP.optimize!(model)

        weights = zeros(3)
        Random_Vector_update!(model, [x_1, x_2, x_3]; weights = weights)

        # Random_Vector: weights are uniformly chosen from [-1, 1]
        @test -1 ≤ weights[1] ≤ 1
        @test -1 ≤ weights[2] ≤ 1
        @test -1 ≤ weights[3] ≤ 1
    end
end

@testset "Test model after updating a solution with Random Vector as modeling_method." begin
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
        modeling_method = :Random_Vector,
    )
    # Test that the correct alternative problem is created.
    # Random_Vector: weights uniformly chosen from [-1, 1]
    obj = objective_function(model)
    @test objective_sense(model) == MIN_SENSE &&
          -1 ≤ weights[1] ≤ 1 &&
          -1 ≤ weights[2] ≤ 1 &&
          JuMP.coefficient(obj, x_1) == weights[1] &&
          JuMP.coefficient(obj, x_2) == weights[2] &&
          constraint_object(model[:original_objective]).func ==
          AffExpr(0, x_1 => 1, x_2 => 1) &&
          constraint_object(model[:original_objective]).set == MOI.GreaterThan(1.8)
end

@testset "Test generate alternatives with Max Distance as modeling_method." begin
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
            modeling_method = :Random_Vector,
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
            modeling_method = :Random_Vector,
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
            modeling_method = :Random_Vector,
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
