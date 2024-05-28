export generate_alternatives!, generate_alternatives

"""
    result = generate_alternatives!(
      model::JuMP.Model,
      optimality_gap::Float64,
      n_alternatives::Int64;
      metric::Distances.Metric = SqEuclidean(),
      selected_variables::Vector{VariableRef} = []
    )

Generate `n_alternatives` solutions to `model` which are as distant from the optimum and each other, but with a maximum `optimality_gap`, using optimisation.

# Arguments
- `model::JuMP.Model`: a solved JuMP model for which alternatives are generated.
- `optimality_gap::Float64`: the maximum percentage deviation (>=0) an alternative may have compared to the optimal solution.
- `n_alternatives`: the number of alternative solutions sought.
- `metric::Distances.Metric=SqEuclidean()`: the metric used to maximise the difference between alternatives and the optimal solution.
- `fixed_variables::Vector{VariableRef}=[]`: a subset of all variables of `model` that are not allowed to be changed when seeking for alternatives.
"""
function generate_alternatives!(
  model::JuMP.Model,
  optimality_gap::Float64,
  n_alternatives::Int64;
  metric::Distances.SemiMetric = SqEuclidean(),
  fixed_variables::Vector{VariableRef} = VariableRef[],
)
  if !is_solved_and_feasible(model)
    throw(ArgumentError("JuMP model has not been solved."))
  elseif optimality_gap < 0
    throw(ArgumentError("Optimality gap (= $optimality_gap) should be at least 0."))
  elseif n_alternatives < 1
    throw(ArgumentError("Number of alternatives (= $n_alternatives) should be at least 1."))
  end

  result = AlternativeSolutions([], [])

  @info "Creating model for generating alternatives."
  create_alternative_generating_problem!(model, optimality_gap, metric, fixed_variables)
  @info "Solving model."
  JuMP.optimize!(model)
  @info "Solution #1/$n_alternatives found." solution_summary(model)
  update_solutions!(result, model)

  # If n_solutions > 1, we repeat the solving process to generate multiple solutions.
  for i = 2:n_alternatives
    @info "Reconfiguring model for generating alternatives."
    add_solution!(model, metric)
    @info "Solving model."
    JuMP.optimize!(model)
    @info "Solution #$i/$n_alternatives found." solution_summary(model)
    update_solutions!(result, model)
  end

  return result
end

"""
    result = generate_alternatives(
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
function generate_alternatives(
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
    throw(ArgumentError("Number of alternatives (= $n_alternatives) should be at least 1."))
  end

  result = AlternativeSolutions([], [])

  @info "Setting up NearOptimalAlternatives problem and solver."
  # Obtain the solution values for all variables, separated in fixed and non-fixed variables.
  initial_solution = OrderedDict{VariableRef, Float64}()
  fixed_variable_solutions = Dict{MOI.VariableIndex, Float64}()
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
  update_solutions!(result, state, initial_solution, fixed_variable_solutions, model)

  for i = 2:n_alternatives
    @info "Reconfiguring NearOptimalAlternatives problem with new solution."
    add_solution!(problem, state, metric)
    @info "Solving NearOptimalAlternatives problem."
    state = run_alternative_generating_problem!(problem)
    @info "Solution #$i/$n_alternatives found." state minimizer(state)
    update_solutions!(result, state, initial_solution, fixed_variable_solutions, model)
  end

  return result
end
