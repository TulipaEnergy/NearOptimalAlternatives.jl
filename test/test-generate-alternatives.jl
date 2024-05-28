@testset "Test generate alternatives using optimisation." begin
  @testset "Make sure error is thrown when JuMP model is not solved." begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # Initialise simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, x_1 + x_2)

    @test_throws ArgumentError NearOptimalAlternatives.generate_alternatives!(model, 0.1, 5)
  end

  @testset "Make sure error is thrown when incorrect optimality_gap." begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # Initialise simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, x_1 + x_2)
    JuMP.optimize!(model)

    @test_throws ArgumentError NearOptimalAlternatives.generate_alternatives!(model, -0.1, 5)
  end

  @testset "Make sure error is thrown when incorrect n_alternatives." begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # Initialise simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, x_1 + x_2)
    JuMP.optimize!(model)

    @test_throws ArgumentError NearOptimalAlternatives.generate_alternatives!(model, 0.1, 0)
  end

  @testset "Test regular run with one alternative." begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # Initialise simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, x_1 + x_2)
    JuMP.optimize!(model)

    results = NearOptimalAlternatives.generate_alternatives!(model, 0.1, 1)

    # Test that `results` contains one solution with 2 variables, and an objective value between 1.8 and 2.0.
    @test length(results.solutions) == 1 &&
          length(results.solutions[1]) == 2 &&
          length(results.objective_values) == 1 &&
          (results.objective_values[1] ≥ 1.8 || isapprox(results.objective_values[1], 1.8)) &&
          (results.objective_values[1] ≤ 2.0 || isapprox(results.objective_values[1], 2.0))
  end

  @testset "Test regular run with one alternative with one fixed variable." begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # Initialise simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, x_1 + x_2)
    JuMP.optimize!(model)

    results = NearOptimalAlternatives.generate_alternatives!(model, 0.1, 1, fixed_variables = [x_2])

    # Test that `results` contains one solution with 2 variables, and an objective value between 1.8 and 2.0. Also, `x_2` should remain around 1.0 and `x_1` should be between 0.8 and 1.0.
    @test length(results.solutions) == 1 &&
          length(results.solutions[1]) == 2 &&
          length(results.objective_values) == 1 &&
          (results.objective_values[1] ≥ 1.8 || isapprox(results.objective_values[1], 1.8)) &&
          (results.objective_values[1] ≤ 2.0 || isapprox(results.objective_values[1], 2.0)) &&
          (results.solutions[1][x_1] ≥ 0.8 || isapprox(results.solutions[1][x_1], 0.8)) &&
          (results.solutions[1][x_1] ≤ 1.0 || isapprox(results.solutions[1][x_1], 1.0)) &&
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

    results = NearOptimalAlternatives.generate_alternatives!(model, 0.1, 2)

    # Test that `results` contains 2 solutions with two variables each, where the objective values of both solutions are between 1.8 and 2.0.
    @test length(results.solutions) == 2 &&
          length(results.solutions[2]) == 2 &&
          length(results.objective_values) == 2 &&
          (results.objective_values[1] ≥ 1.8 || isapprox(results.objective_values[1], 1.8)) &&
          (results.objective_values[1] ≤ 2.0 || isapprox(results.objective_values[1], 2.0)) &&
          (results.objective_values[2] ≥ 1.8 || isapprox(results.objective_values[2], 1.8)) &&
          (results.objective_values[2] ≤ 2.0 || isapprox(results.objective_values[2], 2.0))
  end

  @testset "Test regular run with one alternative and a weighted metric." begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # Initialise simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, x_1 + x_2)
    JuMP.optimize!(model)

    results = NearOptimalAlternatives.generate_alternatives!(
      model,
      0.1,
      1,
      metric = WeightedSqEuclidean([0.5, 10]),
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

@testset "Test generate alternatives using metaheuristics." begin
  @testset "Make sure error is thrown when JuMP model is not solved." begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # Initialise simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, x_1 + x_2)

    algorithm = Metaheuristics.PSO(N = 100, C1 = 2.0, C2 = 2.0, ω = 0.8)

    @test_throws ArgumentError NearOptimalAlternatives.generate_alternatives(
      model,
      0.1,
      5,
      algorithm,
    )
  end

  @testset "Make sure error is thrown when incorrect optimality_gap." begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # Initialise simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, x_1 + x_2)
    JuMP.optimize!(model)

    algorithm = Metaheuristics.PSO(N = 100, C1 = 2.0, C2 = 2.0, ω = 0.8)

    @test_throws ArgumentError NearOptimalAlternatives.generate_alternatives(
      model,
      -0.1,
      5,
      algorithm,
    )
  end

  @testset "Make sure error is thrown when incorrect n_alternatives." begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # Initialise simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, x_1 + x_2)
    JuMP.optimize!(model)

    algorithm = Metaheuristics.PSO(N = 100, C1 = 2.0, C2 = 2.0, ω = 0.8)

    @test_throws ArgumentError NearOptimalAlternatives.generate_alternatives(
      model,
      0.1,
      0,
      algorithm,
    )
  end

  @testset "Test regular run with one alternative." begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # Initialise simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, x_1 + x_2)
    JuMP.optimize!(model)

    algorithm = Metaheuristics.PSO(N = 100, C1 = 2.0, C2 = 2.0, ω = 0.8)

    results = NearOptimalAlternatives.generate_alternatives(model, 0.1, 1, algorithm)

    # Test that `results` contains one solution with 2 variables, and an objective value between 1.8 and 2.0.
    @test length(results.solutions) == 1 &&
          length(results.solutions[1]) == 2 &&
          length(results.objective_values) == 1 &&
          (results.objective_values[1] ≥ 1.8 || isapprox(results.objective_values[1], 1.8)) &&
          (results.objective_values[1] ≤ 2.0 || isapprox(results.objective_values[1], 2.0))
  end

  @testset "Test regular run with one alternative with one fixed variable." begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # Initialise simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, x_1 + x_2)
    JuMP.optimize!(model)

    algorithm = Metaheuristics.PSO(N = 100, C1 = 2.0, C2 = 2.0, ω = 0.8)

    results = NearOptimalAlternatives.generate_alternatives(
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
          (results.objective_values[1] ≥ 1.8 || isapprox(results.objective_values[1], 1.8)) &&
          (results.objective_values[1] ≤ 2.0 || isapprox(results.objective_values[1], 2.0)) &&
          (results.solutions[1][x_1] ≥ 0.8 || isapprox(results.solutions[1][x_1], 0.8)) &&
          (results.solutions[1][x_1] ≤ 1.0 || isapprox(results.solutions[1][x_1], 1.0)) &&
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

    algorithm = Metaheuristics.PSO(N = 100, C1 = 2.0, C2 = 2.0, ω = 0.8)

    results = NearOptimalAlternatives.generate_alternatives(model, 0.1, 2, algorithm)

    # Test that `results` contains 2 solutions with two variables each, where the objective values of both solutions are between 1.8 and 2.0.
    @test length(results.solutions) == 2 &&
          length(results.solutions[2]) == 2 &&
          length(results.objective_values) == 2 &&
          (results.objective_values[1] ≥ 1.8 || isapprox(results.objective_values[1], 1.8)) &&
          (results.objective_values[1] ≤ 2.0 || isapprox(results.objective_values[1], 2.0)) &&
          (results.objective_values[2] ≥ 1.8 || isapprox(results.objective_values[2], 1.8)) &&
          (results.objective_values[2] ≤ 2.0 || isapprox(results.objective_values[2], 2.0))
  end

  @testset "Test regular run with one alternative and a weighted metric." begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # Initialise simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, x_1 + x_2)
    JuMP.optimize!(model)

    algorithm = Metaheuristics.PSO(N = 100, C1 = 2.0, C2 = 2.0, ω = 0.8)

    results = NearOptimalAlternatives.generate_alternatives(
      model,
      0.1,
      1,
      algorithm,
      metric = WeightedSqEuclidean([0.5, 10]),
    )
    results = NearOptimalAlternatives.generate_alternatives!(
      model,
      0.1,
      1,
      metric = WeightedSqEuclidean([0.5, 1]),
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
