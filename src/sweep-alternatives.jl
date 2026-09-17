export generate_alternatives_sweep!

"""
    result = generate_alternatives_sweep!(
        model::JuMP.Model,
        optimality_gap::Float64,
        variables::AbstractArray{T,N},
        n_directions::Int64;
        n_budget::Int64 = 6,
        weights = zeros(length(variables)),
        modeling_method::Symbol = :Spores,
        metric::Distances.SemiMetric = SqEuclidean(),
        fixed_variables::Vector{VariableRef} = VariableRef[],
    ) where {T<:Union{VariableRef,AffExpr},N}

Generate near-optimal alternatives by *sweeping the cost budget* along each
search direction, rather than returning a single point per direction.

This reuses the existing modelling-for-generating-alternatives machinery
([`create_alternative_generating_problem!`](@ref) /
[`update_objective_function!`](@ref)): any `modeling_method` that discovers a
direction (`:Spores`, `:HSJ`, `:Max_Distance`, ...) is supported unchanged. For
each of the `n_directions` discovered directions, the objective (the direction)
is held fixed while the `original_objective` budget constraint is re-solved at
`n_budget` cost levels spanning `[C*, (1 + optimality_gap)·C*]`, collecting every
intermediate optimum. The result is a dense near-optimal front per direction
instead of just its boundary endpoint.

Each direction's sweep ends at the *full* budget, so the model is left exactly
where the classic single-budget generator would leave it — direction-discovery
methods that accumulate from the previous solution (e.g. SPORES, HSJ) advance
identically to [`generate_alternatives_optimization!`](@ref).

# Arguments
- `model::JuMP.Model`: a solved JuMP model for which alternatives are generated.
- `optimality_gap::Float64`: the maximum relative deviation (>= 0) defining the
  near-optimal cost budget, i.e. the top of the sweep range.
- `variables::AbstractArray{T,N}`: the variables carrying the MGA direction.
- `n_directions::Int64`: the number of search directions to discover and sweep.
- `n_budget::Int64 = 6`: the number of cost levels per direction (>= 1). The
  levels are `C*(1 + g_i)` for `g_i = optimality_gap · i / n_budget`,
  `i = 1…n_budget`: evenly spaced *strictly inside* the near-optimal region, with
  the last level at the full budget. The cost-optimal face `C*` itself is never
  sampled — at `C*` the only near-optimal point is `x*` (zero diversity, which
  MGA never seeks), and that face also has empty interior and breaks
  interior-point solvers run without crossover.
- `weights`: optional initial direction weights (accumulated in place).
- `modeling_method::Symbol = :Spores`: the direction-discovery method, any key of
  [`METHOD_DISPATCH_INITIAL`](@ref) / [`METHOD_DISPATCH_UPDATE`](@ref).
- `metric::Distances.SemiMetric = SqEuclidean()`: metric forwarded to the method.
- `fixed_variables::Vector{VariableRef} = []`: variables frozen at their optimum.
- `warm_start::Bool = false`: when `true`, seed each solve from the previous
  optimum (variable primal starts + constraint dual starts, via MOI). Successive
  budget levels differ only in the budget RHS, so the previous solution is an
  excellent start for solvers that exploit it (SCS and other first-order/ADMM
  methods, simplex). Leave it `false` for interior-point solvers that ignore or
  dislike start values (e.g. Gurobi/HiGHS barrier) — the default keeps their
  behaviour unchanged.

As a failsafe, any budget whose solve does not reach a feasible optimum (e.g. an
interior-point numerical error on a tight budget) is logged and skipped, so one
bad solve cannot abort the whole sweep — the result simply contains fewer points.

# Result
An [`AlternativeSolutions`](@ref) holding `n_directions * n_budget` points. Each
point's `tags` entry records
`(direction = k, budget_idx = b, budget_level = L, diversity_objective = d,
solve_time = t)`, where `d` is the optimal diversity-objective value at that
budget and `t` is the solver-reported solve time for that single solve; and
`objective_values[i]` is the realised original-objective cost of point `i`.
Plotting `diversity_objective` against `objective_values` traces the
near-optimal front for each direction.
"""
function generate_alternatives_sweep!(
    model::JuMP.Model,
    optimality_gap::Float64,
    variables::AbstractArray{T,N},
    n_directions::Int64;
    n_budget::Int64 = 6,
    weights = zeros(length(variables)),
    modeling_method::Symbol = :Spores,
    metric::Distances.SemiMetric = SqEuclidean(),
    fixed_variables::Vector{VariableRef} = VariableRef[],
    warm_start::Bool = false,
) where {T<:Union{VariableRef,AffExpr},N}
    if !is_solved_and_feasible(model)
        throw(ArgumentError("JuMP model has not been solved."))
    elseif optimality_gap < 0
        throw(ArgumentError("Optimality gap (= $optimality_gap) should be at least 0."))
    elseif n_directions < 1
        throw(ArgumentError("Number of directions (= $n_directions) should be at least 1."))
    elseif n_budget < 1
        throw(ArgumentError("Number of budget levels (= $n_budget) should be at least 1."))
    end

    # Capture C* before the objective is rewritten into the first direction.
    optimal_value = objective_value(model)
    s = sign(optimal_value)
    is_max = objective_sense(model) == MAX_SENSE

    result = AlternativeSolutions([], [])

    # Capture the incoming optimum (x*) *before* rewriting the model: the call
    # below adds the budget constraint and changes the objective, which
    # invalidates the cached solution.
    all_vars = warm_start ? all_variables(model) : VariableRef[]
    prev_primal = warm_start ? value.(all_vars) : Float64[]

    @info "Creating model for sweeping alternatives ($modeling_method)."
    create_alternative_generating_problem!(
        model,
        optimality_gap,
        fixed_variables,
        variables;
        weights = weights,
        modeling_method = modeling_method,
        metric = metric,
    )

    bud = constraint_by_name(model, "original_objective")
    if isnothing(bud)
        throw(ErrorException("Expected an `original_objective` budget constraint."))
    end
    # The constraint is `old_objective {<=,>=} optimal_value*(1 +/- gap)`. JuMP's
    # normalised RHS moves the objective's constant out, so recover that constant
    # offset once and reuse it to set any intermediate level L exactly.
    full_level =
        is_max ? optimal_value * (1 - optimality_gap * s) :
        optimal_value * (1 + optimality_gap * s)
    offset = full_level - normalized_rhs(bud)

    # Budget gaps evenly spaced strictly inside the near-optimal region:
    # g_i = gap·i/n_budget for i = 1…n_budget. Ascending so the final solve per
    # direction lands on the full budget (correct accumulation), and the cost-
    # optimal face g=0 (= x*, zero diversity, empty interior) is never sampled.
    gaps = [optimality_gap * i / n_budget for i = 1:n_budget]

    # Warm-start bookkeeping. Writing MOI start attributes invalidates the cached
    # solution (subsequent `value(v)` would throw), so we *capture* the solution
    # after each solve (a pure read) and *apply* it as a start only immediately
    # before the next `optimize!`. `prev_primal` was captured above from x*; the
    # first solve is seeded primal-only (the budget constraint has no dual yet).
    cons =
        warm_start ? all_constraints(model; include_variable_in_set_constraints = false) :
        JuMP.ConstraintRef[]
    prev_dual = Float64[]

    for k = 1:n_directions
        if k > 1
            @info "Advancing to direction $k/$n_directions."
            update_objective_function!(
                model,
                variables;
                weights = weights,
                modeling_method = modeling_method,
                metric = metric,
            )
        end
        for (bi, g) in enumerate(gaps)
            level = is_max ? optimal_value * (1 - g * s) : optimal_value * (1 + g * s)
            set_normalized_rhs(bud, level - offset)
            warm_start && _apply_warm_start!(all_vars, prev_primal, cons, prev_dual)
            JuMP.optimize!(model)
            @info "Direction $k/$n_directions, budget $bi/$n_budget solved." solution_summary(
                model,
            )
            # Failsafe: a budget can fail (e.g. an interior-point numerical error
            # on a tight, near-degenerate budget). Always log and move on rather
            # than abort the whole sweep and discard the points already found.
            if !is_solved_and_feasible(model)
                @warn "Direction $k, budget $bi/$n_budget not solved ($(termination_status(model))); skipping."
                continue
            end
            update_solutions!(result, model)
            # The model objective is the diversity objective (the direction), so
            # `objective_value` here is the optimal diversity value at this budget
            # -- the natural y-axis of the near-optimal front, alongside the cost
            # stored in `objective_values`. `solve_time` is the solver-reported
            # time for this single solve (the API-call time, not wall clock).
            push!(
                result.tags,
                (
                    direction = k,
                    budget_idx = bi,
                    budget_level = level,
                    diversity_objective = objective_value(model),
                    solve_time = _safe_solve_time(model),
                ),
            )
            if warm_start
                prev_primal = value.(all_vars)         # capture (read-only, safe)
                prev_dual = _safe_duals(cons)
            end
        end
    end

    return result
end

"Solver-reported solve time of the last `optimize!` (`MOI.SolveTimeSec`),
returning `NaN` if the solver does not expose it."
function _safe_solve_time(model::JuMP.Model)
    try
        return JuMP.solve_time(model)
    catch
        return NaN
    end
end

"Read constraint duals, returning an empty vector if no dual solution is available."
function _safe_duals(cons)
    try
        return [dual(c) for c in cons]
    catch
        return Float64[]
    end
end

"""
    _apply_warm_start!(all_vars, primal, cons, dual_vals)

Load a previously captured solution into the model's MOI warm-start attributes:
variable primal starts and constraint dual starts. Applied only right before an
`optimize!`. Solvers that warm start (SCS and other first-order/ADMM methods,
simplex) use these as the initial iterate; interior-point solvers ignore them.
Each block is guarded so a solver that rejects a start attribute does not abort
the sweep.
"""
function _apply_warm_start!(all_vars, primal, cons, dual_vals)
    if length(primal) == length(all_vars)
        try
            for (v, val) in zip(all_vars, primal)
                set_start_value(v, val)
            end
        catch
        end
    end
    if length(dual_vals) == length(cons)
        try
            for (c, val) in zip(cons, dual_vals)
                set_dual_start_value(c, val)
            end
        catch
        end
    end
    return nothing
end
