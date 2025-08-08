export Dist_update!, Dist_initial!

"""
    Dist_initial!(
        model::JuMP.Model,
        variables::AbstractArray{T,N},
        fixed_variables::Vector{VariableRef};
        weights::Vector{Float64} = zeros(length(variables)),
        metric::Distances.SemiMetric = SqEuclidean(),
    ) where {T<:Union{VariableRef,AffExpr},N}

Initialize a JuMP model's objective to maximize the distance between the current solution and a reference solution, based on a specified metric.

This function is typically used in the context of generating diverse solutions (alternatives) to an optimization problem by first defining a distance-based objective that measures how different a new solution is from an existing (optimal) one.

# Arguments
- `model::JuMP.Model`: a JuMP model that has been previously solved.
- `variables::AbstractArray{T,N}`: the variables of the model to consider in the distance computation.
- `fixed_variables::Vector{VariableRef}`: a subset of all variables of `model` that are not allowed to be changed when seeking for alternatives.
- `weights::Vector{Float64}`: optional weights to influence the distance calculation (currently not used directly but reserved for extensions).
- `metric::Distances.SemiMetric`: the distance metric used to compute dissimilarity (default is squared Euclidean distance).

# Behavior
- Extracts the current solution values of `variables`.
- Sets the model's objective to maximize the distance between the current variable values and the solution.
- Changes the model's objective sense to `Max`.

"""
function Dist_initial!(model::JuMP.Model, variables::AbstractArray{T,N}, fixed_variables::Vector{VariableRef}; weights::Vector{Float64} = zeros(length(variables)), metric::Distances.SemiMetric = SqEuclidean()) where {T<:Union{VariableRef,AffExpr},N}

    vars_vec = [v for v in variables]
    solution = value.(vars_vec)

    # Fix the variables that are fixed
    fix.(fixed_variables, value.(fixed_variables), force = true)

    set_objective_sense(model, FEASIBILITY_SENSE)
    @objective(model, Max, Distances.evaluate(metric, vars_vec, solution))
end


"""
    Dist_update!(
        model::JuMP.Model,
        variables::AbstractArray{T,N};
        weights::Vector{Float64} = zeros(length(variables)),
        metric::Distances.SemiMetric = Cityblock(),
    ) where {T<:Union{VariableRef,AffExpr},N}

Update a JuMP model's objective function to include an additional distance term for generating multiple diverse alternatives (as in Modeling to Generate Alternatives).

This function builds upon a previously defined objective by incrementally adding a distance term between the current solution and a new reference solution. It is typically used after `Dist_initial!` or a prior call to `MGA_Dist_update!`.

# Arguments
- `model::JuMP.Model`: the JuMP model being updated to generate further alternatives.
- `variables::AbstractArray{T,N}`: the variables to consider in the distance computation.
- `weights::Vector{Float64}`: optional weights for the distance metric (currently not directly used).
- `metric::Distances.SemiMetric`: the distance metric used to compute dissimilarity (default is Cityblock distance).

# Behavior
- Evaluates the current objective function to retrieve the cumulative distance so far.
- Computes the distance between the current variable values and their previous optimal values.
- Updates the objective function to maximize the sum of the cumulative and new distances.
- Resets the model's objective sense to `Max`.

"""
function Dist_update!(model::JuMP.Model, variables::AbstractArray{T,N}; weights::Vector{Float64} = zeros(length(variables)), metric::Distances.SemiMetric = Cityblock(),) where {T<:Union{VariableRef,AffExpr},N}
    cumulative_distance = objective_function(model)

    vars_vec = [v for v in variables]
    solution = value.(vars_vec)

    # Reset objective sense to be able to update objective function.
    set_objective_sense(model, FEASIBILITY_SENSE)
    # Update objective by adding the distance between variables and the previous optimal solution.
    @objective(model, Max, cumulative_distance + Distances.evaluate(metric, vars_vec, solution))
end

