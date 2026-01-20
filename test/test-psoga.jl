@testset "Test generate alternatives using PSOGA." begin
    @testset "Test regular run with one alternative." begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        # Initialise simple `square` JuMP model
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, x_1 + x_2)
        JuMP.optimize!(model)

        algorithm = NearOptimalAlternatives.PSOGA()

        results = NearOptimalAlternatives.generate_alternatives_metaheuristics(
            model,
            0.1,
            1,
            algorithm,
        )
        println(results)

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

        # Initialise simple `square` JuMP model
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, x_1 + x_2)
        JuMP.optimize!(model)

        algorithm = NearOptimalAlternatives.PSOGA()

        results = NearOptimalAlternatives.generate_alternatives_metaheuristics(
            model,
            0.1,
            1,
            algorithm,
            fixed_variables = [x_2],
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

        # Initialise simple `square` JuMP model
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, x_1 + x_2)
        JuMP.optimize!(model)

        algorithm = NearOptimalAlternatives.PSOGA(N_solutions = 2, N = 200)

        results = NearOptimalAlternatives.generate_alternatives_metaheuristics(
            model,
            0.1,
            2,
            algorithm,
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

    @testset "Test regular run with three alternatives." begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        # Initialise simple `square` JuMP model
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, x_1 + x_2)
        JuMP.optimize!(model)

        algorithm = NearOptimalAlternatives.PSOGA(N_solutions = 3, N = 300)

        results = NearOptimalAlternatives.generate_alternatives_metaheuristics(
            model,
            0.1,
            3,
            algorithm,
        )

        # Test that `results` contains 3 solutions with two variables each, where the objective values of both solutions are between 1.8 and 2.0.
        @test length(results.solutions) == 3 &&
              length(results.solutions[1]) == 2 &&
              length(results.solutions[2]) == 2 &&
              length(results.solutions[3]) == 2 &&
              length(results.objective_values) == 3 &&
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
              ) &&
              (
                  results.objective_values[3] ≥ 1.8 ||
                  isapprox(results.objective_values[3], 1.8)
              ) &&
              (
                  results.objective_values[3] ≤ 2.0 ||
                  isapprox(results.objective_values[3], 2.0)
              )
    end

    @testset "Test regular run with two alternatives and maximise minimum distance." begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        # Initialise simple `square` JuMP model
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, x_1 + x_2)
        JuMP.optimize!(model)

        algorithm =
            NearOptimalAlternatives.PSOGA(N_solutions = 2, N = 200, maximise_total = false)

        results = NearOptimalAlternatives.generate_alternatives_metaheuristics(
            model,
            0.1,
            2,
            algorithm,
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
