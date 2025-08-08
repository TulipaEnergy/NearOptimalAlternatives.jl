export Min_Max_Variables_update!, Min_Max_Variables_initial!


"""
    Min_Max_Variables_initial!(
        model::JuMP.Model,
        variables::AbstractArray{T,N},
        fixed_variables::Vector{VariableRef};
        weights::Vector{Float64} = zeros(length(variables)),
        metric::Distances.SemiMetric = SqEuclidean(),
    ) where {T<:Union{VariableRef,AffExpr}, N}
Initialize the objective of a JuMP model using the Min/Max Variables method to generate alternative solutions.
This function sets a new objective that minimizes the weighted sum of the decision variables, where weights are randomized between -1, 0 and 1. Fixed variables are locked at their optimal values.
# Arguments
- `model::JuMP.Model`: a solved JuMP model whose objective is to be redefined for alternative generation.
- `variables::AbstractArray{T,N}`: the variables involved in the objective, typically a vector or matrix of `VariableRef`s or `AffExpr`s.
- `fixed_variables::Vector{VariableRef}`: variables to be fixed at their current values to avoid changes in alternatives.
- `weights::Vector{Float64}`: optional vector of weights for each variable; will be internally overwritten based on variable values.
- `metric::Distances.SemiMetric`: unused in this method (included for consistency with other alternative generation methods).
# Behavior
- Variables are randomly minimized or maximized.
- Fixed variables are frozen at their optimal values using `fix(...)`.
- The objective is set to minimize the weighted sum of the variables, encouraging sparsity or deviation from the original.
"""
function Min_Max_Variables_initial!(model::JuMP.Model, variables::AbstractArray{T,N}, fixed_variables::Vector{VariableRef}; weights::Vector{Float64} = zeros(length(variables)), metric::Distances.SemiMetric = SqEuclidean()) where {T<:Union{VariableRef,AffExpr},N}
  # new objective function consist of the n variables in variables
  for (i, v) in enumerate(variables)
    weights[i] = rand([-1, 0, 1])
  end
  # Fix the variables that are fixed
  fix.(fixed_variables, value.(fixed_variables), force = true)

  # update these variables based on their sign
  objective_function = [v * weights[i] for (i, v) in enumerate(variables)]

  # Update objective by adding the distance between variables and the previous optimal solution.
  @objective(model, Min, sum(objective_function))
end

"""
    Min_Max_Variables_update!(
        model::JuMP.Model,
        variables::AbstractArray{T,N};
        weights::Vector{Float64} = zeros(length(variables)),
        metric::Distances.SemiMetric = SqEuclidean(),
    ) where {T<:Union{VariableRef,AffExpr}, N}
Update the objective of a JuMP model using the Min/Max Variables method to generate the next alternative solution.
Update the weights randomly between -1, 0 and 1.
# Arguments
- `model::JuMP.Model`: the JuMP model to be updated.
- `variables::AbstractArray{T,N}`: the decision variables involved in the updated objective.
- `weights::Vector{Float64}`: optional vector of weights; will be overwritten based on current variable values.
- `metric::Distances.SemiMetric`: unused in this method (included for interface consistency).
# Behavior
- Variables are randomly minimized or maximized.
- A new objective is set: minimize the weighted sum of the variables.
- This function does not re-fix any variables; it is typically called iteratively after `Min_Max_Variables_initial!`.
"""
function Min_Max_Variables_update!(model::JuMP.Model, variables::AbstractArray{T,N}; weights::Vector{Float64} = zeros(length(variables)), metric::Distances.SemiMetric = SqEuclidean()) where {T<:Union{VariableRef,AffExpr},N}
  # new objective function consist of the n variables in variables
  for (i, v) in enumerate(variables)
    weights[i] = rand([-1, 0, 1])
  end

  # update these variables based on their sign
  objective_function = [v * weights[i] for (i, v) in enumerate(variables)]

  # Update objective by adding the distance between variables and the previous optimal solution.
  @objective(model, Min, sum(objective_function))
end