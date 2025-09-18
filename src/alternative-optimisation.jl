"""
    create_alternative_problem(
        model::JuMP.Model,
        optimality_gap::Float64,
        metric::Distances.Metric,
        [selected_variables::Vector{VariableRef}]
    )

Transform a JuMP model into a model solving its corresponding modelling-for-generating-alternatives problem.

# Arguments
- `model::JuMP.Model`: a solved JuMP model for which alternatives are generated.
- `optimality_gap::Float64`: the maximum percentage deviation (>= 0) an alternative may have compared to the optimal solution.
- `metric::Distances.Metric=SqEuclidean()`: the metric used to maximise the difference between alternatives and the optimal solution.
- `fixed_variables::Vector{VariableRef}=[]`: a subset of all variables of `model` that are not allowed to be changed when seeking for alternatives.
"""
function create_alternative_generating_problem!(
    model::JuMP.Model,
    optimality_gap::Float64,
    metric::Distances.SemiMetric,
    fixed_variables::Vector{VariableRef},
)
    optimal_value = objective_value(model)
    old_objective = objective_function(model)
    old_objective_sense = objective_sense(model)

    # Store all variables and solution values.
    variables, solution = extract_variables(model)

    # Fix the variables that are not to be changed.
    fix.(fixed_variables, value.(fixed_variables), force = true)

    # Objective maximising the distance between variables and the previous optimal solution.
    @objective(model, Max, Distances.evaluate(metric, variables, solution))

    # Constraint ensuring maximum difference in objective value to optimal solution. The sign of `optimal_value` is used to ensure that a negative `optimal_value` does not lead to an infeasible bound requiring a better than optimal solution.
    if old_objective_sense == MAX_SENSE
        @constraint(
            model,
            original_objective,
            old_objective ≥ optimal_value * (1 - optimality_gap * sign(optimal_value))
        )
    else
        @constraint(
            model,
            original_objective,
            old_objective ≤ optimal_value * (1 + optimality_gap * sign(optimal_value))
        )
    end
end

"""
    add_solution!(
        model::JuMP.Model,
        metric::Distances.Metric
    )

Add a previously found solution to a modelling-for-generating-alternatives problem. Used for iteratively finding multiple alternative solutions.
"""
function add_solution!(model::JuMP.Model, metric::Distances.SemiMetric)
    cumulative_distance = objective_function(model)

    # Store all variables and solution values.
    variables, solution = extract_variables(model)

    # Reset objective sense to be able to update objective function.
    set_objective_sense(model, FEASIBILITY_SENSE)
    # Update objective by adding the distance between variables and the previous optimal solution.
    @objective(
        model,
        Max,
        cumulative_distance + Distances.evaluate(metric, variables, solution)
    )
end

"""
    extract_variables(model::JuMP.Model)

Retrieve the variables and their solution values from a JuMP `model`.
"""
function extract_variables(model::JuMP.Model)
    variables = all_variables(model)
    solution = value.(variables)
    return variables, solution
end
