import Metaheuristics: initialize!, update_state!, final_stage!
import Metaheuristics: AbstractParameters, gen_initial_state, Algorithm, get_position
# genetic operators
import Metaheuristics: SBX_crossover, polynomial_mutation!, create_solution, is_better
import Metaheuristics: reset_to_violated_bounds!
import Metaheuristics: velocity

"""
    Structure holding all parameters for PSOGA (Particle Swarm optimization for Generating Alternatives).
"""
mutable struct PSOGA <: AbstractParameters
    N::Int                # Total population size
    N_solutions::Int      # Number of solutions sought. This is the same as the number of subpopulations searching for a solution.
    C1::Float64           # Cognitive parameter. Used to compute velocity based on own best solution.
    C2::Float64           # Social parameter. Used to compute velocity based on best solution in subpopulation.
    ω::Float64            # Inertia parameter. Used to compute velocity to ensure not too large changes.
    v::Array{Float64}     # Array of velocities per individual.
    flock::Array          # Array of all current positions of each of the individuals.
    subBest::Array        # Array of best solutions per subpopulation.
    maximise_total::Bool  # If true, we maximise the sum of distances between a point and all centroids of other subpopulations, else we maximise the minimum distance between a point and the centroids of other subpopulations.
end

"""
    PSOGA(;
        N = 100,
        N_solutions = 1,
        C1 = 2.0,
        C2 = 2.0,
        ω = 0.8,
        v = Float64[],
        flock == Metaheuristics.xf_indiv[],
        subBest = Metaheuristics.xf_indiv[],
        information = Information(),
        options = Options(),
    )

Construct a PSOGA Metaheuristic algorithm.

# Arguments
- `N`: total population size
- `N_solutions::Int`: number of solutions sought. This is the same as the number of subpopulations searching for a solution.
- `C1::Float64`: cognitive parameter. Used to compute velocity based on own best solution.
- `C2::Float64: social parameter. Used to compute velocity based on best solution in subpopulation.
- `ω::Float64`: inertia parameter. Used to compute velocity to ensure not too large changes.
- `v::Array{Float64}`: array of velocities per individual.
- `flock::Array`: array of all current positions of each of the individuals.
- `subBest::Array`: array of best solutions per subpopulation.
- `maximise_total::Bool`: if true, we maximise the sum of distances between a point and all centroids of other subpopulations, else we maximise the minimum distance between a point and the centroids of other subpopulations.
"""
function PSOGA(;
    N::Int = 100,
    N_solutions::Int = 1,
    C1::Float64 = 2.0,
    C2::Float64 = 2.0,
    ω::Float64 = 0.8,
    v::Array{Float64} = Float64[],
    flock::Array = Metaheuristics.xf_indiv[],
    subBest::Array = Metaheuristics.xf_indiv[],
    maximise_total::Bool = true,
    information = Information(),
    options = Options(),
)
    parameters = PSOGA(
        N,
        N_solutions,
        promote(Float64(C1), C2, ω)...,
        v,
        flock,
        subBest,
        maximise_total,
    )

    return Algorithm(parameters, information = information, options = options)
end

"""
  initialize!(
    status,
    parameters::PSOGA,
    problem,
    information,
    options,
    args...;
    kwargs...
  )

initialize all parameters used when solving a problem using PSOGA. Called by main loop of Metaheuristics.
"""
function initialize!(
    status,
    parameters::PSOGA,
    problem,
    information,
    options,
    args...;
    kwargs...,
)
    # Get problem dimensions.
    D = Metaheuristics.getdim(problem)

    # Fix parameters if they don't have sizes that work
    if options.f_calls_limit == 0
        options.f_calls_limit = 10000 * D
        options.debug && @warn("f_calls_limit increased to $(options.f_calls_limit)")
    end
    if options.iterations == 0
        options.iterations = div(options.f_calls_limit, parameters.N) + 1
    end
    if mod(parameters.N, parameters.N_solutions) != 0
        parameters.N += mod(parameters.N, parameters.N_solutions)
        println(parameters.N)
        options.debug && @warn(
            "Population size increased to $(parameters.N) to ensure equal size subpopulations."
        )
    end

    # initialize velocity and population parameters.
    parameters.v = zeros(parameters.N, D)
    status = gen_initial_state(problem, parameters, information, options, status)

    # initialize parameter for best values per subpopulation and populate this array with bests in initial population.
    parameters.subBest = Array{Any}(undef, parameters.N_solutions)
    fill!(parameters.subBest, status.population[1])
    for (i, sol) in enumerate(status.population)
        if Metaheuristics.is_better(
            sol,
            parameters.subBest[Int(
                1 + div(i - 1, (parameters.N / parameters.N_solutions)),
            )],
        )
            parameters.subBest[Int(
                1 + div(i - 1, (parameters.N / parameters.N_solutions)),
            )] = sol
        end
    end

    # initialize flock (set of all previous populations).
    parameters.flock = status.population

    return status
end

"""
  update_state(
    status,
    parameters::PSOGA,
    problem,
    information,
    options,
    args...;
    kwargs...
  )

Perform one iteration of PSOGA. Called by main loop of Metaheuristics.
"""
function update_state!(
    status,
    parameters::PSOGA,
    problem::Metaheuristics.AbstractProblem,
    information::Information,
    options::Options,
    args...;
    kwargs...,
)
    # initialize vector of new generation of individuals.
    X_new = zeros(parameters.N, Metaheuristics.getdim(problem))

    # Update all individuals' position by adding their velocity.
    for i = 1:(parameters.N)
        # Obtain the best position in the individuals subpopulation, its current position and its alltime best position.
        xSPBest = get_position(
            parameters.subBest[Int(
                1 + div(i - 1, (parameters.N / parameters.N_solutions)),
            )],
        )
        x = get_position(parameters.flock[i])
        xPBest = get_position(status.population[i])
        # Generate new velocity.
        parameters.v[i, :] =
            velocity(x, parameters.v[i, :], xPBest, xSPBest, parameters, options.rng)
        # Update position and reset to its bounds if it violates any.
        x += parameters.v[i, :]
        reset_to_violated_bounds!(x, problem.search_space)
        X_new[i, :] = x
    end

    # Compute the centroids of each subpopulation
    centroids = ones(parameters.N_solutions, Metaheuristics.getdim(problem))
    for i = 1:(parameters.N_solutions)
        centroids[i, :] = Statistics.mean(
            X_new[
                ((i-1)*div(parameters.N, parameters.N_solutions)+1):(i*div(
                    parameters.N,
                    parameters.N_solutions,
                )),
                :,
            ],
            dims = 1,
        )
    end

    # Update local bests (in population) and bests per subpopulation (subBest).
    for (i, sol) in
        enumerate(Metaheuristics.create_solutions(X_new, problem; ε = options.h_tol))
        if is_better_psoga(
            sol,
            status.population[i],
            centroids,
            Int(1 + div(i - 1, (parameters.N / parameters.N_solutions))),
            parameters.maximise_total,
        )
            status.population[i] = sol
            if is_better_psoga(
                sol,
                parameters.subBest[Int(
                    1 + div(i - 1, (parameters.N / parameters.N_solutions)),
                )],
                centroids,
                Int(1 + div(i - 1, (parameters.N / parameters.N_solutions))),
                parameters.maximise_total,
            )
                parameters.subBest[Int(
                    1 + div(i - 1, (parameters.N / parameters.N_solutions)),
                )] = sol
            end
        end

        # Update current generation.
        parameters.flock[i] = sol

        # Check if stop criteria are met.
        Metaheuristics.stop_criteria!(status, parameters, problem, information, options)
        status.stop && break
    end
end

"""
  final_stage(
    status,
    parameters::PSOGA,
    problem,
    information,
    options,
    args...;
    kwargs...
  )

Perform concluding operations after solving a problem using PSOGA. Called by main loop of Metaheuristics.
"""
function final_stage!(
    status,
    parameters::PSOGA,
    problem::Metaheuristics.AbstractProblem,
    information::Information,
    options::Options,
    args...;
    kwargs...,
)
    # Set end time of algorithm.
    status.final_time = time()
end
