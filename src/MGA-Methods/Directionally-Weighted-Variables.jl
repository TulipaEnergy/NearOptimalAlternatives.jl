export DWV_initial!, DWV_update!

"""
    DWV_initial!(
        model::JuMP.Model,
        variables::AbstractArray{T,N},
        fixed_variables::Vector{VariableRef};
        weights::Vector{Float64} = zeros(length(variables)),
        metric::Distances.SemiMetric = SqEuclidean(),
        old_objective::AffExpr = JuMP.objective_function(model),
    ) where {T<:Union{VariableRef,AffExpr},N}
Initialize the objective of a JuMP model using the Directionally Weighted Variables method to generate alternative solutions.
This function sets a new objective that minimizes the weighted sum of the decision variables, where weights are uniformly chosen between -1 and 1, based on the original objective function. Fixed variables are locked at their optimal values.
# Arguments
- `model::JuMP.Model`: a solved JuMP model whose objective is to be redefined for alternative generation.
- `variables::AbstractArray{T,N}`: the variables involved in the objective, typically a vector or matrix of `VariableRef`s or `AffExpr`s.
- `fixed_variables::Vector{VariableRef}`: variables to be fixed at their current values to avoid changes in alternatives.
- `weights::Vector{Float64}`: optional vector of weights for each variable; will be internally overwritten based on variable values.
- `metric::Distances.SemiMetric`: unused in this method (included for consistency with other alternative generation methods).
- `old_objective::AffExpr`: the original objective function of the model, used to determine variable weights.
# Behavior
- Variables are randomly minimized or maximized, based on the original objective function.
- Fixed variables are frozen at their optimal values using `fix(...)`.
- The objective is set to minimize the weighted sum of the variables, encouraging sparsity or deviation from the original.
"""
function DWV_initial!(
  model::JuMP.Model,
  variables::AbstractArray{T, N},
  fixed_variables::Vector{VariableRef};
  weights::Vector{Float64} = zeros(length(variables)),
  metric::Distances.SemiMetric = SqEuclidean(),
  old_objective::AffExpr = JuMP.objective_function(model),
) where {T <: Union{VariableRef, AffExpr}, N}

  # Assign weights depending on coefficient sign
  for (i, v) in enumerate(variables)
    c = get(old_objective.terms, v, 0.0)  # 0.0 if variable not in objective
    if c > 0
      weights[i] = rand([0, 1])
    elseif c < 0
      weights[i] = rand([-1, 0])
    else
      weights[i] = rand([-1, 0, 1])
    end
  end

  # Fix the variables that are fixed
  fix.(fixed_variables, value.(fixed_variables), force = true)

  # update these variables based on their sign
  objective_function = [v * weights[i] for (i, v) in enumerate(variables)]

  # Update objective by adding the distance between variables and the previous optimal solution.
  @objective(model, Min, sum(objective_function))
end

"""
    DWV_update!(
        model::JuMP.Model,
        variables::AbstractArray{T,N},
        weights::Vector{Float64}
    ) where {T<:Union{VariableRef,AffExpr},N}
"""
function DWV_update!(
  model::JuMP.Model,
  variables::AbstractArray{T, N};
  weights::Vector{Float64} = zeros(length(variables)),
  metric::Distances.SemiMetric = SqEuclidean(),
  old_objective::AffExpr = JuMP.objective_function(model), #TODO make sure the old objective is passed correctly
) where {T <: Union{VariableRef, AffExpr}, N}
  # Assign weights depending on coefficient sign
  for (i, v) in enumerate(variables)
    c = get(old_objective.terms, v, 0.0)  # 0.0 if variable not in objective
    if c > 0
      weights[i] = rand([0, 1])
    elseif c < 0
      weights[i] = rand([-1, 0])
    else
      weights[i] = rand([-1, 0, 1])
    end
  end

  # Apply weights to variables
  objective_function = [v * weights[i] for (i, v) in enumerate(variables)]

  # Update model objective
  set_objective_sense(model, FEASIBILITY_SENSE)
  @objective(model, Min, sum(objective_function))
end
