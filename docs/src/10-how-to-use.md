```@contents
Pages = ["how-to-use.md"]
Depth = 5
```

# How to use

This section gives an introduction to the package installation, main functions, and their inputs and outputs.

## Install

In Julia:

- Enter package mode (press "]")

```pkg
pkg> add NearOptimalAlternatives
```

- Return to Julia mode (backspace)

```julia
julia> using NearOptimalAlternatives
```

## Main functions

To generate alternative solutions to a solved JuMP model, use either of the functions:

- [`generate_alternatives_optimization!(model, optimality_gap, n_alternatives)`](@ref)
- [`generate_alternatives_metaheuristics(model, optimality_gap, n_alternatives, metaheuristic_algorithm)`](@ref)

The `model` should be a solved JuMP model. The `optimality_gap` is the maximum percentage of deviation from the optimal solution. `n_alternatives` specifies the desired number of alternative solutions. If you want to generate alternatives with a metaheuristic instead of mathematical optimization, use `generate_alternatives_metaheuristics` instead of `generate_alternatives_optimization!` and specify the `metaheuristic_algorithm` to use. Other optional input parameters are specified in the Input section below.

## Input

The following parameters can be supplied to either of the alternative generating functions (unless otherwise specified). The ones alreay mentioned in the previous section are required, the rest is optional.

- `model`: The solved JuMP model for which we want to find alternative solutions. When using optimization to find alternatives, the solver specified to solve this model will also perform the optimization for finding alternatives.
- `optimality_gap`: The maximum objective value deviation each of the alternative solutions may have from the original solution. An optimality gap of `0.5` means that the objective value of an alternative solution must be at least `50%` of the optimal objective value found by solving `model` (in case of a maximization problem).
- `n_alternatives`: The number of alternative solutions to be found by this package.
- `metaheuristic_algorithm` (only for `generate_alternatives_metaheuristics`): The algorithm used to find alternative solutions. Can be an algorithm from [Metaheuristics.jl](https://jmejia8.github.io/Metaheuristics.jl/stable/algorithms/) or the algorithm we developed: `PSOGA`. The former are repeated iteratively to find multiple alternatives, the latter generates multiple alternatives concurrently.
- `metric`: The distance metric used to compute the difference between solutions (between different alternatives and between alternatives and the optimal solution). This metric should be a `SemiMetric` from the [Distances.jl](https://github.com/JuliaStats/Distances.jl) package. Note that, depending on the solver used, several metrics might not be usable when finding alternatives using optimization. When using a metaheuristic, any metric is usable.
- `fixed_variables`: A vector of variables that should remain fixed when finding alternative solutions. One can use this to find near optimal alternative solutions that only modify a subset of all variables and leave the rest unchanged.

## Output

Both methods for generating alternative solutions return the results in the same form: a structure `AlternativeSolutions` containing a vector `solutions` and `objective_values`.

- `solutions` holds a dictionary containing the solution value for every JuMP variables (based on its `VariableRef`), per alternative solution.
- `objective_values` is a vector of floats representing the objective value of each of the alternative solutions.
