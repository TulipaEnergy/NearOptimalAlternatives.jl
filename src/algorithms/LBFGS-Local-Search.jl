module GradientMGA

using JuMP
using LinearAlgebra
using SparseArrays
using Optim

export run_lbfgs_mga, extract_all_constraints, operational_recovery!

"""
    extract_all_constraints(model, vars)
Extracts both Inequalities (A_in * x <= b_in) and Equalities (A_eq * x == b_eq).
"""
function extract_all_constraints(model::Model, vars::Vector{VariableRef})
    var_to_idx = Dict(v => i for (i, v) in enumerate(vars))
    n_vars = length(vars)

    # --- Inequalities ---
    I_in = Int[]
    J_in = Int[]
    V_in = Float64[]
    b_in = Float64[]
    row_in = 1

    for (i, v) in enumerate(vars)
        if has_lower_bound(v)
            push!(I_in, row_in)
            push!(J_in, i)
            push!(V_in, -1.0)
            push!(b_in, -lower_bound(v))
            row_in += 1
        end
        if has_upper_bound(v)
            push!(I_in, row_in)
            push!(J_in, i)
            push!(V_in, 1.0)
            push!(b_in, upper_bound(v))
            row_in += 1
        end
    end

    for cref in
        all_constraints(model, GenericAffExpr{Float64,VariableRef}, MOI.LessThan{Float64})
        obj = constraint_object(cref)
        push!(b_in, obj.set.upper - obj.func.constant)
        for (v, coeff) in obj.func.terms
            push!(I_in, row_in)
            push!(J_in, var_to_idx[v])
            push!(V_in, coeff)
        end
        row_in += 1
    end

    A_in = sparse(I_in, J_in, V_in, row_in - 1, n_vars)

    # --- Equalities ---
    I_eq = Int[]
    J_eq = Int[]
    V_eq = Float64[]
    b_eq = Float64[]
    row_eq = 1

    for cref in
        all_constraints(model, GenericAffExpr{Float64,VariableRef}, MOI.EqualTo{Float64})
        obj = constraint_object(cref)
        push!(b_eq, obj.set.value - obj.func.constant)
        for (v, coeff) in obj.func.terms
            push!(I_eq, row_eq)
            push!(J_eq, var_to_idx[v])
            push!(V_eq, coeff)
        end
        row_eq += 1
    end

    A_eq = sparse(I_eq, J_eq, V_eq, row_eq - 1, n_vars)

    return A_in, b_in, A_eq, b_eq
end

"""
    operational_recovery!(model, lazy_solution, vars, is_structural_mask)
Locks the capacities found by L-BFGS and runs the LP to fix the dispatch physics.
"""
function operational_recovery!(
    model::Model,
    lazy_solution::Vector{Float64},
    vars::Vector{VariableRef},
    is_structural_mask::BitVector,
)
    for i = 1:length(vars)
        if is_structural_mask[i]
            fix(vars[i], lazy_solution[i]; force = true)
        end
    end

    set_silent(model)
    optimize!(model)
    recovered_solution = value.(vars)

    for i = 1:length(vars)
        if is_structural_mask[i]
            unfix(vars[i])
        end
    end
    return recovered_solution
end

"""
    run_lbfgs_mga(...)
Uses L-BFGS to maximize distance from a known point subject to soft constraint penalties.
"""
function run_lbfgs_mga(model::Model, x_known::Vector{Float64})
    vars = all_variables(model)

    # Feature Space Mask (Identify Structural Variables)
    is_structural = BitVector(
        occursin("investment", string(name(v))) || occursin("capacity", string(name(v))) for v in vars
    )
    mask_float = Float64.(is_structural) # Used for fast gradient math

    A_in, b_in, A_eq, b_eq = extract_all_constraints(model, vars)

    # Penalty hyper-parameters (You may need to tune these! If the final recovered cost
    # is too high, increase rho. If L-BFGS fails to move, decrease rho.)
    rho = 1e4  # Inequality penalty weight
    mu = 1e4   # Equality penalty weight

    # Optim.jl requires a combined function for performance (calculates Loss and Grad together)
    function fg!(F, G, x)
        # 1. Inequality Violations
        viol_in = (A_in * x) .- b_in
        viol_in_pos = max.(0.0, viol_in)

        # 2. Equality Violations
        viol_eq = (A_eq * x) .- b_eq

        # 3. Objective (Distance)
        struct_diff = (x .- x_known) .* mask_float

        if G !== nothing
            # Gradient: -2*Distance + rho*(A_in^T * viol_in_pos) + mu*(A_eq^T * viol_eq)
            grad_dist = -2.0 .* struct_diff
            grad_in = rho .* (A_in' * viol_in_pos)
            grad_eq = mu .* (A_eq' * viol_eq)

            G .= grad_dist .+ grad_in .+ grad_eq
        end

        if F !== nothing
            # Loss: -Distance^2 + (rho/2)*viol_in_pos^2 + (mu/2)*viol_eq^2
            loss_dist = -sum(struct_diff .^ 2)
            loss_in = (rho / 2.0) * sum(viol_in_pos .^ 2)
            loss_eq = (mu / 2.0) * sum(viol_eq .^ 2)

            return loss_dist + loss_in + loss_eq
        end
    end

    println("Starting L-BFGS search...")
    # Start L-BFGS slightly perturbed from x_known so the gradient isn't perfectly zero
    x_start = x_known .+ (randn(length(x_known)) .* 0.01 .* mask_float)

    # Run the optimizer
    res = optimize(
        Optim.only_fg!(fg!),
        x_start,
        LBFGS(),
        Optim.Options(iterations = 500, show_trace = true),
    )
    x_lbfgs = Optim.minimizer(res)

    println("L-BFGS converged. Running Operational Recovery (Snap to Grid)...")
    final_point = operational_recovery!(model, x_lbfgs, vars, is_structural)

    return final_point
end

end # module
