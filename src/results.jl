"""
Structure holding the solutions for the near-optimal alternatives.
"""
mutable struct AlternativeSolutions
  solutions::Vector{Dict{VariableRef, Float64}}
  objective_values::Vector{Float64}
end

"""
    update_solutions!(results::AlternativeSolutions, model::JuMP.Model)

Update the set of results `AlternativeSolutions` with the variable values obtained when solving the JuMP model `model`.
"""
function update_solutions!(results::AlternativeSolutions, model::JuMP.Model)
  if !is_solved_and_feasible(model)
    throw(ErrorException("JuMP model $model not solved when trying to read results."))
  end

  # Retrieve all variable values from JuMP model.
  solution = Dict{VariableRef, Float64}()
  for v in all_variables(model)
    solution[v] = value(v)
  end
  push!(results.solutions, solution)

  # Retrieve constraint for maximum difference to original objective and compute original objective value.
  original_objective = constraint_by_name(model, "original_objective")
  if isnothing(original_objective)
    throw(ErrorException("JuMP model $model has no constraint named `original_objective`"))
  end
  push!(results.objective_values, value(original_objective))
end

"""
    update_solutions!(results::AlternativeSolutions, model::JuMP.Model)

Update the set of results `AlternativeSolutions` with the variable values obtained when solving using Metaheuristics.

# Arguments
- `results::AlternativeSolutions`: set of solutions to add a new solution to.
- `state::Metaheuristics.State`: contains results to metaheuristic solve.
- `initial:solution::OrderedDict{VariableRef, Float64}`: used to identify the indices of the metaheuristic solution in the JuMP model.
- `fixed_variables::Dict{MOI.VariableIndex, Float64}`: set of fixed variables and their solution values.
- `model::JuMP.Model`: original model for which alternative solutions are found.
"""
function update_solutions!(
  results::AlternativeSolutions,
  state::Metaheuristics.State,
  initial_solution::OrderedDict{VariableRef, Float64},
  fixed_variables::Dict{MOI.VariableIndex, Float64},
  model::JuMP.Model,
)
  if !state.stop
    throw(ErrorException("Metaheuristic state `state` not terminated when trying to read results."))
  end

  best_solution = minimizer(state)
  solution = Dict{VariableRef, Float64}()
  index_map = Dict{Int64, Int64}()
  # Add all new results
  for (i, (k, _)) in enumerate(initial_solution)
    solution[k] = best_solution[i]
    index_map[k.index.value] = i
  end
  # Add values of fixed variables.
  for (k, v) in fixed_variables
    solution[JuMP.VariableRef(model, k)] = v
  end

  push!(results.solutions, solution)

  # Retrieve objective value to original problem.
  objective_value =
    extract_objective(JuMP.objective_function(model), best_solution, index_map, fixed_variables)
  push!(results.objective_values, objective_value)
end
