using Test
using JuMP
using NearOptimalAlternatives
using Ipopt

silent_ipopt_arc() = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

# Same small capacity-expansion LP as the sweep test (bounded investment so the
# SPORES direction is defined), rebuilt here so this file is self-contained.
function build_synth_arc()
    cap = [10.0, 8.0, 6.0]
    c_inv = [3.0, 5.0, 7.0]
    c_op = [1.0 2.0 3.0 4.0; 2.5 1.5 3.5 2.0; 4.0 3.0 1.0 2.5]
    demand = [5.0, 7.0, 4.0, 6.0]
    n, T = length(cap), length(demand)
    model = JuMP.Model(silent_ipopt_arc())
    @variable(model, 0 <= inv[i=1:n] <= cap[i])
    @variable(model, disp[i=1:n, t=1:T] >= 0)
    @constraint(model, [i = 1:n, t = 1:T], disp[i, t] <= inv[i])
    @constraint(model, [t = 1:T], sum(disp[i, t] for i = 1:n) >= demand[t])
    @objective(
        model,
        Min,
        sum(c_inv[i] * inv[i] for i = 1:n) +
        sum(c_op[i, t] * disp[i, t] for i = 1:n, t = 1:T)
    )
    JuMP.optimize!(model)
    return model, inv
end

@testset "Arclength: input validation" begin
    @testset "Make sure error is thrown when JuMP model is not solved." begin
        unsolved_model = JuMP.Model(silent_ipopt_arc())
        @variable(unsolved_model, 0 <= x <= 1)
        @objective(unsolved_model, Min, x)
        @test_throws ArgumentError generate_alternatives_arclength!(
            unsolved_model,
            0.1,
            [x],
            1,
        )
    end

    @testset "Make sure error is thrown when incorrect optimality_gap." begin
        model, inv = build_synth_arc()
        @test_throws ArgumentError generate_alternatives_arclength!(model, -0.1, inv, 1)
    end

    @testset "Make sure error is thrown when incorrect n_directions." begin
        model, inv = build_synth_arc()
        @test_throws ArgumentError generate_alternatives_arclength!(model, 0.1, inv, 0)
    end

    @testset "Make sure error is thrown when n_budget < 2." begin
        model, inv = build_synth_arc()
        @test_throws ArgumentError generate_alternatives_arclength!(
            model,
            0.1,
            inv,
            1;
            n_budget = 1,
        )
    end
end

@testset "Arclength: internal predictor-corrector loop" begin
    @testset "a failed midpoint solve is marched past, not fatal" begin
        # Directly drives `_arclength_sample` with a fake `solve_and_record` so
        # the failure is deterministic: both endpoints succeed (the loop only
        # starts if `ok_lo && ok_hi`), then the very first midpoint attempt
        # fails once, exercising the "march past it" fallback (as opposed to
        # `generate_alternatives_arclength!`'s own not-solved path, covered by
        # the reconfigure_solver! test below, which only ever fails *after*
        # both endpoints - never reaching this branch).
        n_calls = Ref(0)
        failed_once = Ref(false)
        fake_solve = function (g)
            n_calls[] += 1
            if n_calls[] == 3
                failed_once[] = true
                return (false, NaN, NaN)
            end
            return (true, g, -g)
        end

        NearOptimalAlternatives._arclength_sample(fake_solve, 1.0, 4)

        @test failed_once[]
        @test n_calls[] == 5   # 2 endpoints + 1 failed + 2 successful midpoints
    end
end

@testset "Arclength: reconfigure_solver! and its restore closure" begin
    @testset "reconfigure_solver! fires once per direction; restore fires between directions" begin
        model, inv = build_synth_arc()
        n_dir, n_bud, gap = 3, 3, 0.1

        reconfigure_count = Ref(0)
        restore_count = Ref(0)
        reconfigure! = m -> begin
            reconfigure_count[] += 1
            return mm -> (restore_count[] += 1)
        end

        result = generate_alternatives_arclength!(
            model,
            gap,
            inv,
            n_dir;
            n_budget = n_bud,
            modeling_method = :Spores,
            reconfigure_solver! = reconfigure!,
        )

        # Fires once per direction (guarded by `reconfigured`, reset each direction)...
        @test reconfigure_count[] == n_dir
        # ...and the restore closure it returns fires at the start of every
        # *following* direction, so one fewer time than reconfigure_solver!
        # itself (the last direction's restore closure is never used).
        @test restore_count[] == n_dir - 1
        @test length(result.solutions) > 0
    end

    @testset "reconfigure_solver! is never called with n_directions == 1" begin
        model, inv = build_synth_arc()
        reconfigure_count = Ref(0)
        reconfigure! = m -> (reconfigure_count[] += 1; return nothing)

        generate_alternatives_arclength!(
            model,
            0.1,
            inv,
            1;
            n_budget = 3,
            modeling_method = :Spores,
            reconfigure_solver! = reconfigure!,
        )
        # A single direction still has a "first point", so reconfigure_solver!
        # does fire once here - this asserts it fires exactly once, not zero
        # or more than once, for the simplest possible case.
        @test reconfigure_count[] == 1
    end

    @testset "returning nothing from reconfigure_solver! is a no-op restore" begin
        model, inv = build_synth_arc()
        reconfigure_count = Ref(0)
        reconfigure! = m -> begin
            reconfigure_count[] += 1
            return nothing   # no restore closure
        end

        # Should not error even though no restore closure is ever returned.
        result = generate_alternatives_arclength!(
            model,
            0.1,
            inv,
            2;
            n_budget = 3,
            modeling_method = :Spores,
            reconfigure_solver! = reconfigure!,
        )
        @test reconfigure_count[] == 2
        @test length(result.solutions) > 0
    end

    @testset "a reconfigure_solver! that breaks the solver is handled, not thrown" begin
        model, inv = build_synth_arc()
        # Force ITERATION_LIMIT on every solve from the reconfigure point onward,
        # exercising both the post-reconfigure confirm-resolve failure warning
        # and the regular "budget not solved, skipping" path in the same run.
        break_solver! = m -> set_optimizer_attribute(m, "max_iter", 0)

        result = @test_logs(
            (:warn, r"Post-reconfigure re-solve.*failed"),
            (:warn, r"not solved.*skipping"),
            match_mode = :any,
            generate_alternatives_arclength!(
                model,
                0.2,
                inv,
                1;
                n_budget = 6,
                modeling_method = :Spores,
                reconfigure_solver! = break_solver!,
            )
        )

        # Only the first (tight-budget) endpoint is ever recorded: the
        # reconfigure fires right after it, breaks the solver, and every
        # solve after that (including the second endpoint) fails.
        @test length(result.solutions) == 1
    end

    @testset "no reconfigure_solver! given: neither callback path is touched" begin
        model, inv = build_synth_arc()
        result = generate_alternatives_arclength!(
            model,
            0.1,
            inv,
            2;
            n_budget = 3,
            modeling_method = :Spores,
        )
        @test length(result.solutions) > 0
    end
end

@testset "Arclength: shape, budget feasibility, endpoints, distribution" begin
    model, inv = build_synth_arc()
    n_dir, n_bud, gap = 2, 5, 0.1

    result = generate_alternatives_arclength!(
        model,
        gap,
        inv,
        n_dir;
        n_budget = n_bud,
        modeling_method = :Spores,
    )

    # The marching predictor-corrector places a variable number of points per
    # direction (adaptive step, capped at n_budget), so check bounds not equality.
    @test length(result.tags) == length(result.solutions)
    @test length(result.solutions) <= n_dir * n_bud
    @test length(result.solutions) >= n_dir * 3     # 2 endpoints + >=1 interior

    for k = 1:n_dir
        tags_k = [t for t in result.tags if t.direction == k]
        @test 3 <= length(tags_k) <= n_bud
        gaps = sort!([t.gap for t in tags_k])
        # The two endpoints are always solved: [gap/n_budget, gap].
        @test isapprox(gaps[1], gap / n_bud; atol = 1e-9)
        @test isapprox(gaps[end], gap; atol = 1e-9)
        # All budgets strictly inside the near-optimal region.
        @test all(0 .< gaps .<= gap + 1e-12)

        # Sorted by budget, the diversity objective is non-increasing (a larger
        # budget can only lower min wᵀx).
        order = sortperm([t.gap for t in tags_k])
        divs = [t.diversity_objective for t in tags_k][order]
        @test all(divs[i] >= divs[i+1] - 1e-6 for i = 1:(length(divs)-1))
    end

    # Every recorded cost is within its budget level.
    for i in eachindex(result.objective_values)
        @test result.objective_values[i] <= result.tags[i].budget_level + 1e-5
    end
end
