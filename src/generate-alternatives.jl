export generate_alternatives_optimization!, generate_alternatives_metaheuristics

"""
    _alt_solve_diagnostics(model) -> NamedTuple

Read-only per-solve diagnostics (solve time, simplex/barrier iteration counts,
termination status) for the structured `"alternative_solved"` log record emitted
by `generate_alternatives_optimization!`. Pure introspection - does not call
`optimize!` or touch model/solver state. Each getter is individually guarded
since not every solver/status exposes every attribute (e.g. an LP solved by an
interior-point method with no crossover reports simplex_iterations = 0, not an
error, but some solvers do not implement the iteration-count attributes at all).
"""
function _alt_solve_diagnostics(model::JuMP.Model)
    solve_time = try
        JuMP.solve_time(model)
    catch
        NaN
    end
    simplex_it = try
        simplex_iterations(model)
    catch
        missing
    end
    barrier_it = try
        barrier_iterations(model)
    catch
        missing
    end
    return (
        solve_time = solve_time,
        simplex_iterations = simplex_it,
        barrier_iterations = barrier_it,
        status = string(termination_status(model)),
    )
end

"""
results = generate_alternatives_optimization!(
  model::JuMP.Model,
  optimality_gap::Float64,
  variables::AbstractArray{T,N},
  n_alternatives::Int64;
  modeling_method::Symbol = :Max_Distance,
  metric::Distances.SemiMetric = SqEuclidean(),
  fixed_variables::Vector{VariableRef} = VariableRef[],
  reconfigure_solver!::Union{Nothing,Function} = nothing,
) where {T<:Union{VariableRef,AffExpr},N}
Generate `n_alternatives` solutions to `model` which are as distant from the optimum and each other, but with a maximum `optimality_gap`, using optimization.

# Arguments
- `model::JuMP.Model`: a solved JuMP model for which alternatives are generated.
- `optimality_gap::Float64`: the maximum percentage deviation (>=0) an alternative may have compared to the optimal solution.
-  variables::AbstractArray{T,N}: the variables of `model` for which are considered when generating alternatives.
- `n_alternatives`: the number of alternative solutions sought.
- `modeling_method::Symbol = :Max_Distance`: the method used to model the problem for generating alternatives.
- `metric::Distances.Metric=SqEuclidean()`: the metric used to maximise the difference between alternatives and the optimal solution.
- `fixed_variables::Vector{VariableRef}=[]`: a subset of all variables of `model` that are not allowed to be changed when seeking for alternatives.
- `reconfigure_solver!::Union{Nothing,Function}=nothing`: an optional `model -> nothing`
  callback invoked once, after alternative #1 is found and before alternative #2 is
  sought. Use it to switch the attached solver's algorithm (e.g. from barrier to
  primal simplex) so that alternatives #2.. are warm-started from alternative #1's
  basis instead of solved cold each time - the feasible region is fixed from here on
  (only the objective changes between iterations), which is the favourable case for a
  primal-simplex warm start. The callback should only set solver attributes (e.g.
  `model -> set_optimizer_attribute(model, "Method", 0)` for Gurobi); this function
  handles the mandatory re-solve that JuMP requires after any attribute change.
  Ignored when `n_alternatives == 1` (no further solves would use it).
"""
function generate_alternatives_optimization!(
    model::JuMP.Model,
    optimality_gap::Float64,
    variables::AbstractArray{T,N},
    n_alternatives::Int64;
    weights = zeros(length(variables)),
    modeling_method::Symbol = :Max_Distance,
    metric::Distances.SemiMetric = SqEuclidean(),
    fixed_variables::Vector{VariableRef} = VariableRef[],
    reconfigure_solver!::Union{Nothing,Function} = nothing,
) where {T<:Union{VariableRef,AffExpr},N}
    if !is_solved_and_feasible(model)
        throw(ArgumentError("JuMP model has not been solved."))
    elseif optimality_gap < 0
        throw(ArgumentError("Optimality gap (= $optimality_gap) should be at least 0."))
    elseif n_alternatives < 1
        throw(
            ArgumentError(
                "Number of alternatives (= $n_alternatives) should be at least 1.",
            ),
        )
    end

    result = AlternativeSolutions([], []) # Initialize the result container for storing alternative solutions.


    @info "Creating model for generating alternatives."
    create_alternative_generating_problem!(
        model,
        optimality_gap,
        fixed_variables,
        variables;
        weights = weights,
        modeling_method = modeling_method,
        metric = metric,
    )
    @info "Solving model."
    JuMP.optimize!(model)
    @info "Solution #1/$n_alternatives found." solution_summary(model)
    update_solutions!(result, model)
    d = _alt_solve_diagnostics(model)
    @info "alternative_solved" index = 1 solve_time = d.solve_time simplex_iterations =
        d.simplex_iterations barrier_iterations = d.barrier_iterations status = d.status

    if reconfigure_solver! !== nothing && n_alternatives > 1
        @info "Reconfiguring solver algorithm for the remaining alternatives."
        reconfigure_solver!(model)
        # Changing a solver attribute invalidates JuMP's cached solve state, so
        # the model must be re-solved before update_objective_function! can read
        # the current solution values below. The feasible region and objective
        # are UNCHANGED at this point, so a warm solver re-confirms the same
        # optimum in a handful of pivots at most, regardless of problem size.
        JuMP.optimize!(model)
    end

    # If n_solutions > 1, we repeat the solving process to generate multiple solutions.
    for i = 2:n_alternatives
        @info "Reconfiguring model for generating alternatives."
        update_objective_function!(
            model,
            variables;
            weights = weights,
            modeling_method = modeling_method,
        )
        @info "Solving model."
        JuMP.optimize!(model)
        @info "Solution #$i/$n_alternatives found." solution_summary(model)
        update_solutions!(result, model)
        d = _alt_solve_diagnostics(model)
        @info "alternative_solved" index = i solve_time = d.solve_time simplex_iterations =
            d.simplex_iterations barrier_iterations = d.barrier_iterations status = d.status
    end

    return result
end

"""
    result = generate_alternatives_metaheuristics(
      model::JuMP.Model,
      optimality_gap::Float64,
      n_alternatives::Int64,
      metaheuristic_algorithm::Metaheuristics.Algorithm;
      metric::Distances.Metric = SqEuclidean(),
      selected_variables::Vector{VariableRef} = []
    )

Generate `n_alternatives` solutions to `model` which are as distant from the optimum and each other, but with a maximum `optimality_gap`, using a metaheuristic algorithm.

# Arguments
- `model::JuMP.Model`: a solved JuMP model for which alternatives are generated.
- `optimality_gap::Float64`: the maximum percentage deviation (>=0) an alternative may have compared to the optimal solution.
- `n_alternatives`: the number of alternative solutions sought.
- `metaheuristic_algorithm::Metaheuristics.Algorithm`: algorithm used to search for alternative solutions.
- `metric::Distances.Metric=SqEuclidean()`: the metric used to maximise the difference between alternatives and the optimal solution.
- `fixed_variables::Vector{VariableRef}=[]`: a subset of all variables of `model` that are not allowed to be changed when seeking for alternatives.
"""
function generate_alternatives_metaheuristics(
    model::JuMP.Model,
    optimality_gap::Float64,
    n_alternatives::Int64,
    metaheuristic_algorithm::Metaheuristics.Algorithm;
    metric::Distances.SemiMetric = SqEuclidean(),
    fixed_variables::Vector{VariableRef} = VariableRef[],
)
    if !is_solved_and_feasible(model)
        throw(ArgumentError("JuMP model has not been solved."))
    elseif optimality_gap < 0
        throw(ArgumentError("Optimality gap (= $optimality_gap) should be at least 0."))
    elseif n_alternatives < 1
        throw(
            ArgumentError(
                "Number of alternatives (= $n_alternatives) should be at least 1.",
            ),
        )
    end

    result = AlternativeSolutions([], [])

    @info "Setting up NearOptimalAlternatives problem and solver."
    # Obtain the solution values for all variables, separated in fixed and non-fixed variables.
    initial_solution = OrderedDict{VariableRef,Float64}()
    fixed_variable_solutions = Dict{MOI.VariableIndex,Float64}()
    for v in all_variables(model)
        if v in fixed_variables
            fixed_variable_solutions[v.index] = value(v)
        else
            initial_solution[v] = value(v)
        end
    end

    problem = create_alternative_generating_problem(
        model,
        metaheuristic_algorithm,
        initial_solution,
        optimality_gap,
        metric,
        fixed_variable_solutions,
    )
    @info "Solving NearOptimalAlternatives problem."
    state = run_alternative_generating_problem!(problem)
    @info "Solution #1/$n_alternatives found." state minimizer(state)


    # Update the solutions based on whether PSOGA is used or not.
    if typeof(metaheuristic_algorithm) ==
       Metaheuristics.Algorithm{NearOptimalAlternatives.PSOGA}
        update_solutions!(
            result,
            state,
            metaheuristic_algorithm.parameters.subBest,
            initial_solution,
            fixed_variable_solutions,
            model,
        )
    else
        update_solutions!(result, state, initial_solution, fixed_variable_solutions, model)
    end

    # Only run iteratively if PSOGA is not used.
    if typeof(metaheuristic_algorithm) !=
       Metaheuristics.Algorithm{NearOptimalAlternatives.PSOGA}
        for i = 2:n_alternatives
            @info "Reconfiguring NearOptimalAlternatives problem with new solution."
            add_solution!(problem, state, metric)
            @info "Solving NearOptimalAlternatives problem."
            state = run_alternative_generating_problem!(problem)
            @info "Solution #$i/$n_alternatives found." state minimizer(state)
            update_solutions!(
                result,
                state,
                initial_solution,
                fixed_variable_solutions,
                model,
            )
        end
    end

    return result
end
