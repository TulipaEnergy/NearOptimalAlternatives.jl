@testset "Test create alternative problem" begin
    @testset "Test simple maximisation problem" begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        # Initialise simple `square` JuMP model
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
            SqEuclidean(),
            VariableRef[],
        )
        # Test that the correct alternative problem is created and that `x_2` is fixed.
        @test objective_sense(model) == MAX_SENSE &&
              constraint_object(model[:original_objective]).set ==
              MOI.GreaterThan(0.9 * (x_1_res + x_2_res))
    end

    @testset "Test simple minimisation problem" begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        # Initialise simple `square` JuMP model
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
            SqEuclidean(),
            VariableRef[],
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

    @testset "Test maximisation with selected variables" begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        # Initialise simple `square` JuMP model
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
            SqEuclidean(),
            [x_2],
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
end

@testset "Test adding a solution to a model with an alternative found." begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # Initialise simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, (x_1 - 1)^2 + (x_2 - 1)^2)
    @constraint(model, original_objective, x_1 + x_2 ≥ 1.8)
    JuMP.optimize!(model)
    # Store the values of `x_1` and `x_2` to test that the correct values are used in the created alternative generation problem.
    x_1_res = value(x_1)
    x_2_res = value(x_2)

    NearOptimalAlternatives.add_solution!(model, SqEuclidean())
    # Test that the correct alternative problem is created and that `x_2` is fixed.
    @test objective_sense(model) == MAX_SENSE &&
          objective_function(model) == QuadExpr(
              AffExpr(
                  2 + x_1_res^2 + x_2_res^2,
                  x_1 => -2 * (1 + x_1_res),
                  x_2 => -2 * (1 + x_2_res),
              ),
              UnorderedPair(x_1, x_1) => 2,
              UnorderedPair(x_2, x_2) => 2,
          ) &&
          constraint_object(model[:original_objective]).func ==
          AffExpr(0, x_1 => 1, x_2 => 1) &&
          constraint_object(model[:original_objective]).set == MOI.GreaterThan(1.8)
end
