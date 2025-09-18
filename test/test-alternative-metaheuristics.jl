@testset "Test constraint extraction" begin
    @testset "Test that regular constraint is converted correctly" begin
        # Initialise model
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @constraint(model, x_1 - 2 * x_2 ≥ 1)
        @objective(model, Max, x_1 + x_2)
        # Obtain constraint
        constraint =
            JuMP.all_constraints(model, include_variable_in_set_constraints = true)[1]
        index_map = Dict{Int64,Int64}()
        index_map[1] = 1
        index_map[2] = 2
        # Result should be x_1 - 2 * x_2, which is equal to -3.0 for x_1 = 1.0 and x_2 = 2.0.
        @test NearOptimalAlternatives.extract_constraint(
            MOI.get(model, MOI.ConstraintFunction(), constraint),
            [1.0, 2.0],
            index_map,
            Dict{MOI.VariableIndex,Float64}(),
        ) == -3.0
    end

    @testset "Test that constraint with fixed variable is converted correctly" begin
        # Initialise model
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @constraint(model, x_1 - 2 * x_2 ≥ 1)
        @objective(model, Max, x_1 + x_2)
        # Obtain constraint
        constraint =
            JuMP.all_constraints(model, include_variable_in_set_constraints = true)[1]
        index_map = Dict{Int64,Int64}()
        index_map[1] = 1
        fixed_variables = Dict{MOI.VariableIndex,Float64}()
        fixed_variables[x_2.index] = 2.0
        # Result should be x_1 - 2 * x_2, which is equal to -3.0 for x_1 = 1.0 and x_2 = 2.0.
        @test NearOptimalAlternatives.extract_constraint(
            MOI.get(model, MOI.ConstraintFunction(), constraint),
            [1.0],
            index_map,
            fixed_variables,
        ) == -3.0
    end
end

@testset "Test objective extraction" begin
    @testset "Test that regular objective is converted correctly" begin
        # Initialise model
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, x_1 + x_2)
        # Obtain objective
        objective = JuMP.objective_function(model, AffExpr)

        index_map = Dict{Int64,Int64}()
        index_map[1] = 1
        index_map[2] = 2
        # Result should be x_1 + x_2, which is equal to 3.0 for x_1 = 1.0 and x_2 = 2.0.
        @test NearOptimalAlternatives.extract_objective(
            objective,
            [1.0, 2.0],
            index_map,
            Dict{MOI.VariableIndex,Float64}(),
        ) == 3.0
    end

    @testset "Test that objective with fixed variable is converted correctly" begin
        # Initialise model
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, x_1 + x_2)
        # Obtain objective
        objective = JuMP.objective_function(model, AffExpr)
        index_map = Dict{Int64,Int64}()
        index_map[1] = 1
        fixed_variables = Dict{MOI.VariableIndex,Float64}()
        fixed_variables[x_2.index] = 2.0
        # Result should be x_1 + x_2, which is equal to 3.0 for x_1 = 1.0 and x_2 = 2.0.
        @test NearOptimalAlternatives.extract_objective(
            objective,
            [1.0, 2.0],
            index_map,
            fixed_variables,
        ) == 3.0
    end
end

@testset "Test bound extraction" begin
    @testset "Test less than bounds" begin
        # Initialise model
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)
        @variable(model, x_1 ≤ 1)
        @objective(model, Max, x_1)
        index_map = Dict{Int64,Int64}()
        index_map[1] = 1
        # Result should be a matrix with lower bound -Inf and upper bound 1.
        result = zeros(Float64, (2, 1))
        result[1, 1] = -Inf
        result[2, 1] = 1
        @test NearOptimalAlternatives.extract_bounds(model, index_map) == result
    end
    @testset "Test greater than bounds" begin
        # Initialise model
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)
        @variable(model, x_1 ≥ 1)
        @objective(model, Max, x_1)
        index_map = Dict{Int64,Int64}()
        index_map[1] = 1
        # Result should be a matrix with lower bound -Inf and upper bound 1.
        result = zeros(Float64, (2, 1))
        result[1, 1] = 1
        result[2, 1] = Inf
        @test NearOptimalAlternatives.extract_bounds(model, index_map) == result
    end
    @testset "Test interval bounds" begin
        # Initialise model
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)
        @variable(model, 0 ≤ x_1 ≤ 1)
        @objective(model, Max, x_1)
        index_map = Dict{Int64,Int64}()
        index_map[1] = 1
        # Result should be a matrix with lower bound -Inf and upper bound 1.
        result = zeros(Float64, (2, 1))
        result[1, 1] = 0
        result[2, 1] = 1
        @test NearOptimalAlternatives.extract_bounds(model, index_map) == result
    end
end

@testset "Test creating objective function for metaheuristic" begin
    @testset "Test simple problem with all types of variable bounds" begin
        # Initialise model.
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)
        @variable(model, x_1 ≤ 1)
        @variable(model, 0 ≤ x_2)
        @variable(model, 0 ≤ x_3 ≤ 1)
        @objective(model, Max, x_1 - x_2 + x_3)
        JuMP.optimize!(model)
        # Initialise other required structures.
        solution = OrderedDict{VariableRef,Float64}()
        solution[x_1] = 1.0
        solution[x_2] = 0.0
        solution[x_3] = 1.0
        index_map = Dict{Int64,Int64}()
        index_map[1] = 1
        index_map[2] = 2
        index_map[3] = 3
        # Run function and test results. We cannot test function equality so we evaluate the functions in two points and compare.
        f = NearOptimalAlternatives.create_objective(
            model,
            solution,
            0.5,
            Distances.SqEuclidean(),
            index_map,
            Dict{MOI.VariableIndex,Float64}(),
        )
        f0, g0, h0 = f([0.0, 0.0, 0.0])
        f1, g1, h1 = f([1.0, 1.0, 1.0])
        @test f0 == [-2.0] &&         # -1 * ((x_1 - 1)^2 + (x_2 - 0)^2 + (x_3 - 1)^2) = -(1 + 0 + 1) = -2
              f1 == [-1.0] &&         # -1 * ((x_1 - 1)^2 + (x_2 - 0)^2 + (x_3 - 1)^2) = -(0 + 1 + 0) = -1
              length(g0) == 5 &&      # Objective gap constraint + 4 variable bounds
              g0[1] == 1.0 &&         # x_1 - x_2 + x_3 >= 1.0 (1.0 <= 0)
              count(i -> (i == 0.0), g0) == 2 && # Constraints except objective gap constraint can be in arbitrary order, so we count the occurences per value.
              count(i -> (i == -1.0), g0) == 2 && # -1 occurs for x_1 <= 1 and x_3 <= 1, for the others it's 0.0.
              length(g1) == 5 &&
              g1[1] == 0.0 &&
              count(i -> (i == 0.0), g1) == 3 && # Objective gap, x_1 <= 1 and x_3 <= 1
              count(i -> (i == -1.0), g1) == 2 && # x_2 >= 0, x_3 >= 0.
              h0 == [0.0] && # No equality constraints included
              h1 == [0.0]
    end

    @testset "Test simple problem with all types of constraints" begin
        # Initialise model.
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)
        @variable(model, x_1)
        @variable(model, x_2)
        @constraint(model, x_1 + x_2 ≤ 3.0)
        @constraint(model, x_1 - x_2 ≥ 0.0)
        @constraint(model, x_2 == 0.0)
        @objective(model, Max, 2 * x_1 + x_2)
        JuMP.optimize!(model)
        # Initialise other required structures.
        solution = OrderedDict{VariableRef,Float64}()
        solution[x_1] = 3.0
        solution[x_2] = 0.0
        index_map = Dict{Int64,Int64}()
        index_map[1] = 1
        index_map[2] = 2
        # Run function and test results. We cannot test function equality so we evaluate the functions in two points and compare.
        f = NearOptimalAlternatives.create_objective(
            model,
            solution,
            0.5,
            Distances.SqEuclidean(),
            index_map,
            Dict{MOI.VariableIndex,Float64}(),
        )
        f0, g0, h0 = f([0.0, 0.0])
        f1, g1, h1 = f([1.0, 1.0])
        @test f0 == [-9.0] &&         # -1 * ((x_1 - 1)^2 + (x_2 - 0)^2 + (x_3 - 1)^2) = -(1 + 0 + 1) = -2
              f1 == [-5.0] &&         # -1 * ((x_1 - 1)^2 + (x_2 - 0)^2 + (x_3 - 1)^2) = (0 + 1 + 0) = -1
              length(g0) == 3 &&      # Objective gap constraint + 2 inequality constraints
              g0[1] == 3.0 &&         # 2 * x_1 + x_2 >= 3.0 (3.0 <= 0)
              count(i -> (i == -3.0), g0) == 1 && # Constraints except objective gap constraint can be in arbitrary order, so we count the occurences per value.
              count(i -> (i == 0.0), g0) == 1 &&  # -3 occurs for x_1 + x_2 <= 3, 0 for x_1 - x_2 >= 0.
              length(g1) == 3 &&
              g1[1] == 0.0 &&
              count(i -> (i == -1.0), g1) == 1 && # x_1 + x_2 <= 3.
              count(i -> (i == 0.0), g1) == 2 &&  # Objective gap and x_1 - x_2 >= 0.
              h0 == [0.0] && # x_2 == 0.0
              h1 == [1.0]     # x_2 == 0.0
    end
end

@testset "Test creating metaheuristic alternative problem" begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # Initialise simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, x_1 + x_2)
    JuMP.optimize!(model)

    # Initialise other parameters
    solution = OrderedDict{VariableRef,Float64}()
    solution[x_1] = 1.0
    solution[x_2] = 1.0

    algorithm = Metaheuristics.PSO(N = 100, C1 = 2.0, C2 = 2.0, ω = 0.8)
    metric = Distances.SqEuclidean()

    problem = NearOptimalAlternatives.create_alternative_generating_problem(
        model,
        algorithm,
        solution,
        0.5,
        metric,
        Dict{MOI.VariableIndex,Float64}(),
    )
    f0, g0, h0 = problem.objective([0.0, 0.0])
    @test problem.algorithm == algorithm &&
          problem.bounds == [0.0 0.0; 1.0 1.0] &&
          f0 == [-2.0] &&   # -((x_1 - 1)^2 + (x_2 - 1)^2) = -(1 + 1)
          length(g0) == 5 &&
          h0 == [0.0]
end

@testset "Test running metaheuristic" begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # Initialise simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, x_1 + x_2)
    JuMP.optimize!(model)

    # Initialise other parameters
    solution = OrderedDict{VariableRef,Float64}()
    solution[x_1] = 1.0
    solution[x_2] = 1.0

    algorithm = Metaheuristics.PSO(N = 100, C1 = 2.0, C2 = 2.0, ω = 0.8)
    metric = Distances.SqEuclidean()

    problem = NearOptimalAlternatives.create_alternative_generating_problem(
        model,
        algorithm,
        solution,
        0.5,
        metric,
        Dict{MOI.VariableIndex,Float64}(),
    )
    result = NearOptimalAlternatives.run_alternative_generating_problem!(problem)
    solution = minimizer(result)

    @test solution[1] ≥ 0 && solution[1] ≤ 1 && solution[2] ≥ 0 && solution[2] ≤ 1
end

@testset "Test adding solution to metaheuristic problem" begin
    optimizer = Ipopt.Optimizer
    model = JuMP.Model(optimizer)

    # Initialise simple `square` JuMP model
    @variable(model, 0 ≤ x_1 ≤ 1)
    @variable(model, 0 ≤ x_2 ≤ 1)
    @objective(model, Max, x_1 + x_2)
    JuMP.optimize!(model)

    # Initialise other parameters
    solution = OrderedDict{VariableRef,Float64}()
    solution[x_1] = 1.0
    solution[x_2] = 1.0

    algorithm = Metaheuristics.PSO(N = 100, C1 = 2.0, C2 = 2.0, ω = 0.8)
    metric = Distances.SqEuclidean()

    problem = NearOptimalAlternatives.create_alternative_generating_problem(
        model,
        algorithm,
        solution,
        0.5,
        metric,
        Dict{MOI.VariableIndex,Float64}(),
    )
    result = NearOptimalAlternatives.run_alternative_generating_problem!(problem)
    sol = minimizer(result)
    NearOptimalAlternatives.add_solution!(problem, result, metric)
    f0, g0, h0 = problem.objective([0.0, 0.0])

    @test problem.algorithm == algorithm &&
          problem.bounds == [0.0 0.0; 1.0 1.0] &&
          f0 ≤ [-2.0 - sol[1]^2 - sol[2]^2] &&   # -((x_1 - 1)^2 + (x_2 - 1)^2 + (x_1 - res1)^2 + x_2 - res2)^2) = -(1 + 1 + res1^2 + res2^2)
          length(g0) == 5 &&
          h0 == [0.0]
end
