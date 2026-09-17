export generate_alternatives_arclength!

"""
    result = generate_alternatives_arclength!(
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

Like [`generate_alternatives_sweep!`](@ref), but distributes the `n_budget`
points along each direction's near-optimal front by **arclength** rather than by
uniform budget steps. Uniform-budget sampling clusters points where the front is
flat (extra budget stops buying diversity — redundant) and under-samples the
steep "knee"; arclength spacing places points evenly *along the trade-off curve*,
which is the MGA-relevant notion of a well-distributed front.

Arclength control follows the pseudo-arclength predictor–corrector scheme
(Keller 1977; Allgower & Georg 1990), specialised to the parametric-LP front:
the two budget endpoints are solved to anchor and normalise the (cost, diversity)
metric, then the curve is **marched** monotonically from the tight budget to the
full budget. At each step a **finite-difference tangent** (normalised arclength
travelled per unit budget over the last successful step) is used as the
*predictor* to choose the next budget so the step advances a fixed target
arclength `Δs`; the *corrector* is the exact LP solve at that budget (its optimum
lies on the front). The step is reduced/marched past a budget that fails to solve
(the standard continuation step-control), so a pathological budget is stepped over
rather than aborting the run. This equidistributes points along the trade-off
curve — sparse on the flat plateau (tangent flattens ⇒ larger budget steps), dense
at the knee — instead of clustering by uniform budget.

(A finite-difference tangent is used because the only solver viable at this scale,
barrier, exposes no basis sensitivity; with a simplex corrector the tangent could
come from exact LP sensitivity `dx/dB`.)

# Arguments
Same as [`generate_alternatives_sweep!`](@ref); `n_budget >= 2` (the two endpoints
are always solved first). By default no warm starting is used — arclength solves
budgets out of order, so there is no monotone previous iterate to seed from.
- `reconfigure_solver!::Union{Nothing,Function}=nothing`: an optional
  `model -> restore!` callback, applied once per direction, immediately after
  that direction's first point succeeds — the same one-shot idea as
  [`generate_alternatives_optimization!`](@ref)'s `reconfigure_solver!`, but
  fired per direction instead of once for the whole call. Use it to switch the
  solver's algorithm (e.g. barrier to dual simplex) so the rest of that
  direction's (out-of-order) points warm-start off the resulting basis. It
  should return either `nothing`, or a `model -> nothing` closure that restores
  the original config; that closure is applied at the start of the *next*
  direction, right after `update_objective_function!`.

# Result
An [`AlternativeSolutions`](@ref); each `tags` entry records
`(direction, budget_idx, budget_level, gap, diversity_objective, solve_time)`,
where `budget_idx` is the placement order within the direction. Plot
`diversity_objective` against `objective_values` to see the arclength-distributed
front.
"""
function generate_alternatives_arclength!(
    model::JuMP.Model,
    optimality_gap::Float64,
    variables::AbstractArray{T,N},
    n_directions::Int64;
    n_budget::Int64 = 6,
    weights = zeros(length(variables)),
    modeling_method::Symbol = :Spores,
    metric::Distances.SemiMetric = SqEuclidean(),
    fixed_variables::Vector{VariableRef} = VariableRef[],
    reconfigure_solver!::Union{Nothing,Function} = nothing,
) where {T<:Union{VariableRef,AffExpr},N}
    if !is_solved_and_feasible(model)
        throw(ArgumentError("JuMP model has not been solved."))
    elseif optimality_gap < 0
        throw(ArgumentError("Optimality gap (= $optimality_gap) should be at least 0."))
    elseif n_directions < 1
        throw(ArgumentError("Number of directions (= $n_directions) should be at least 1."))
    elseif n_budget < 2
        throw(ArgumentError("Arclength needs n_budget >= 2 (got $n_budget)."))
    end

    optimal_value = objective_value(model)
    s = sign(optimal_value)
    is_max = objective_sense(model) == MAX_SENSE

    result = AlternativeSolutions([], [])

    @info "Creating model for arclength alternatives ($modeling_method)."
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
    full_level =
        is_max ? optimal_value * (1 - optimality_gap * s) :
        optimal_value * (1 + optimality_gap * s)
    offset = full_level - normalized_rhs(bud)
    levelof(g) = is_max ? optimal_value * (1 - g * s) : optimal_value * (1 + g * s)

    restore_next_direction = nothing   # restore closure from the previous direction's reconfigure_solver!
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
            # Restore after reading value() above: it invalidates the cached
            # solve, but this direction's first point (below) re-solves anyway.
            if restore_next_direction !== nothing
                @info "Restoring solver algorithm for the start of direction $k."
                restore_next_direction(model)
                restore_next_direction = nothing
            end
        end

        placed = Ref(0)
        reconfigured = Ref(false)   # reconfigure_solver! fires once, at the direction's first point
        # Solve at relative gap `g`; on success record the point and return its
        # (cost, diversity) for arclength bookkeeping, else signal failure.
        function solve_and_record(g)
            set_normalized_rhs(bud, levelof(g) - offset)
            JuMP.optimize!(model)
            if !is_solved_and_feasible(model)
                @warn "Direction $k, gap $(round(g, digits = 4)) not solved ($(termination_status(model))); skipping."
                return (false, NaN, NaN)
            end
            div = objective_value(model)
            cost = value(bud)
            update_solutions!(result, model)
            placed[] += 1
            st = _safe_solve_time(model)
            push!(
                result.tags,
                (
                    direction = k,
                    budget_idx = placed[],
                    budget_level = levelof(g),
                    gap = g,
                    diversity_objective = div,
                    solve_time = st,
                ),
            )
            d = _alt_solve_diagnostics(model)
            @info "alternative_solved" direction = k budget_idx = placed[] solve_time =
                d.solve_time simplex_iterations = d.simplex_iterations barrier_iterations =
                d.barrier_iterations status = d.status
            @info "Direction $k/$n_directions: placed point $(placed[])/$n_budget at gap $(round(g, digits = 4)) (diversity $(round(div, sigdigits = 5)))."

            if reconfigure_solver! !== nothing && !reconfigured[]
                @info "Reconfiguring solver algorithm after the first arclength point."
                reconfigured[] = true
                restore_next_direction = reconfigure_solver!(model)
                # Re-solve to confirm the new algorithm at this same budget -
                # not a new point, so it isn't recorded.
                JuMP.optimize!(model)
                if !is_solved_and_feasible(model)
                    @warn "Post-reconfigure re-solve at the first arclength point failed ($(termination_status(model)))."
                end
            end

            return (true, cost, div)
        end

        _arclength_sample(solve_and_record, optimality_gap, n_budget)

        if k < n_directions
            # Arclength may finish a direction on a failed midpoint. Re-solve at
            # the full budget so the next direction's SPORES accumulation sees a
            # valid solution, same as the sweep and the classic generator.
            set_normalized_rhs(bud, levelof(optimality_gap) - offset)
            JuMP.optimize!(model)
        end
    end

    return result
end

"""
    _arclength_sample(solve_and_record, gap, n_budget)

Marching pseudo-arclength predictor–corrector over the budget parameter.
`solve_and_record(g) -> (ok, cost, diversity)` solves at relative gap `g` and
records the point on success. Solves the two endpoints `[gap/n_budget, gap]` to
anchor and normalise the (cost, diversity) metric, then marches from the tight
end: a finite-difference tangent predicts the next budget so each step advances a
fixed target arclength `Δs`, and the exact LP solve is the corrector. A budget
that fails to solve is stepped over (monotone step-size control), so the march
always advances toward the full budget and terminates.
"""
function _arclength_sample(solve_and_record, gap::Float64, n_budget::Int)
    g_lo = gap / n_budget
    g_hi = gap

    # Endpoints: anchor the march and normalise the arclength metric.
    ok_lo, cost_lo, div_lo = solve_and_record(g_lo)
    ok_hi, cost_hi, div_hi = solve_and_record(g_hi)
    (ok_lo && ok_hi) || return
    n_budget <= 2 && return

    crange = max(abs(cost_hi - cost_lo), 1e-12)
    drange = max(abs(div_lo - div_hi), 1e-12)
    nrm(cost, div) = ((cost - cost_lo) / crange, (div - div_hi) / drange)
    p_lo = nrm(cost_lo, div_lo)
    p_hi = nrm(cost_hi, div_hi)

    # Target arclength per step: the endpoint distance split into n_budget-1
    # pieces (the convex curve is a little longer, so we cap the point count).
    Ltot = hypot(p_hi[1] - p_lo[1], p_hi[2] - p_lo[2])
    Δs = Ltot / (n_budget - 1)
    Δg_nom = (g_hi - g_lo) / (n_budget - 1)
    min_step = 0.15 * Δg_nom

    g_prev, p_prev = g_lo, p_lo
    g_cur = clamp(g_lo + Δg_nom, g_lo + min_step, g_hi)   # bootstrap first predictor step
    placed = 0
    attempts = 0
    maxattempts = 8 * n_budget
    while placed < n_budget - 2 && g_cur < g_hi - 1e-9 && attempts < maxattempts
        attempts += 1
        ok, cost, div = solve_and_record(g_cur)
        if ok
            p_cur = nrm(cost, div)
            placed += 1
            # Finite-difference tangent: arclength per unit gap over the last
            # successful step. Predictor advances ~Δs of arclength.
            r = max(
                hypot(p_cur[1] - p_prev[1], p_cur[2] - p_prev[2]) / (g_cur - g_prev),
                1e-9,
            )
            g_prev, p_prev = g_cur, p_cur
            g_cur = clamp(g_cur + Δs / r, g_cur + min_step, g_hi)
        else
            # Pathological budget: march past it, staying monotone.
            g_cur =
                clamp(g_cur + max(min_step, 0.3 * (g_cur - g_prev)), g_cur + min_step, g_hi)
        end
    end
    return
end
