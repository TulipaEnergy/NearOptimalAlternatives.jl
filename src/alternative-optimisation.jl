export create_alternative_generating_problem!, update_objective_function!

"""
const METHOD_DISPATCH shows the mapping of method symbols to their corresponding update functions for the modelling-for-generating-alternatives problem.
It is used to dynamically select the appropriate function based on the method specified in the `create_alternative_generating_problem!` function.
"""
const METHOD_DISPATCH_UPDATE = Dict{Symbol, Function}(
  # :HSJ => HSJ_update!,
  # :Spores => SPORES_update!,
  # :Min_Max_Variables => MM_update!,
  # :Random_Vector => RV_update!,
  # :Directionally_Weighted_Variables => DW_update!,
  :Max_Distance => Dist_update!,
)

const METHOD_DISPATCH_INITIAL = Dict{Symbol, Function}(
  # :HSJ => HSJ_update!,
  # :Spores => SPORES_update!,
  # :Min_Max_Variables => MM_update!,
  # :Random_Vector => RV_update!,
  # :Directionally_Weighted_Variables => DW_update!,
  :Max_Distance => Dist_initial!,
)

"""
    create_alternative_generating_problem!(
      model::JuMP.Model,
      optimality_gap::Float64,
      fixed_variables::Vector{VariableRef},
      variables::AbstractArray{T,N},
      weights::Vector{Float64};
      method::Symbol = :HSJ,
      metric::Distances.SemiMetric = SqEuclidean(),
    ) where {T<:Union{VariableRef,AffExpr},N}

Transform a JuMP model into a model solving its corresponding modelling-for-generating-alternatives problem.

# Arguments
- `model::JuMP.Model`: a solved JuMP model for which alternatives are generated.
- `optimality_gap::Float64`: the maximum percentage deviation (>= 0) an alternative may have compared to the optimal solution.
- `fixed_variables::Vector{VariableRef}=[]`: a subset of all variables of `model` that are not allowed to be changed when seeking for alternatives.
- `variables::AbstractArray{T,N}`: the variables of `model` for which are considered when generating alternatives.
- `weights::Vector{Float64}`: a vector of weights used to update the objective function.
- `method::Symbol = :HSJ`: the method used to model the problem for generating alternatives.
- `metric::Distances.SemiMetric = SqEuclidean()`: the metric used to maximise the difference between alternatives and the optimal solution.
"""
function create_alternative_generating_problem!(
  model::JuMP.Model,
  optimality_gap::Float64,
  fixed_variables::Vector{VariableRef},
  variables::AbstractArray{T, N};
  weights::Vector{Float64} = zeros(length(variables)),
  modeling_method::Symbol = :Max_Distance,
  metric::Distances.SemiMetric = SqEuclidean(),
) where {T <: Union{VariableRef, AffExpr}, N}
  optimal_value = objective_value(model)
  old_objective = objective_function(model)
  old_objective_sense = objective_sense(model)

  # get random variables to minimize and maximize where there is no overlap between minimizing and maximizing
  @info "Creating the new objective function"

  f = get(METHOD_DISPATCH_INITIAL, modeling_method) do
    throw(ArgumentError("Method $modeling_method is not supported."))
  end

  f(model, variables, fixed_variables; weights = weights, metric = metric)

  @info "Adding the old objective function as a constraint to the model"
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
    update_objective_function!(
        model::JuMP.Model,
        variables::AbstractArray{T,N};
        weights::Vector{Float64} = zeros(length(variables)),
        method::Symbol = :HSJ,
        metric::Distances.SemiMetric = SqEuclidean()) where {T<:Union{VariableRef,AffExpr},N}
    )

Add a previously found solution to a modelling-for-generating-alternatives problem. Used for iteratively finding multiple alternative solutions.

# Arguments
- `model::JuMP.Model`: a solved JuMP model for which alternatives are generated.
- `variables::AbstractArray{T,N}`: the variables of `model` for which are considered when generating alternatives.
- `weights::Vector{Float64}`: a vector of weights used to update the objective function.
- `method::Symbol = :HSJ`: the method used to model the problem for generating alternatives.
- `metric::Distances.SemiMetric = SqEuclidean()`: the metric used to maximise the difference between alternatives and the optimal solution.

"""
function update_objective_function!(
  model::JuMP.Model,
  variables::AbstractArray{T, N};
  weights::Vector{Float64} = zeros(length(variables)),
  modeling_method::Symbol = :Max_Distance,
  metric::Distances.SemiMetric = SqEuclidean(),
) where {T <: Union{VariableRef, AffExpr}, N}
  f = get(METHOD_DISPATCH_UPDATE, modeling_method) do
    throw(ArgumentError("Method $modeling_method is not supported."))
  end
  f(model, variables; weights = weights, metric = metric)
end
