```@contents
Pages = ["tutorials.md"]
Depth = 5
```

# Tutorials

Here are three tutorials on how to use NearOptimalAlternatives.jl. The tutorials show how to generate alternatives using optimisation, a metaheuristic algorithm and our metaheuristic PSOGA, respectively.

## Alternatives using optimisation

Given a solved JuMP model called `model`, one should first define the number of alternatives they want to generate and the maximum deviation in objective value compared to the optimal solution. For instance,

```julia
optimality_gap = 0.5 # Objective value may deviate at most 50% from optimal solution.
n_alternatives = 2
```

Now, they can call the following function to generate alternatives

```julia
alternatives = NearOptimalAlternatives.generate_alternatives!(model, optimality_gap, n_alternatives)
```

As a default, this method uses the squared euclidean metric from the [Distances.jl](https://github.com/JuliaStats/Distances.jl) package. If you want to use a different distance metric, you can simply define the metric and supply it as an argument to the function as follows (weighted metrics are also supported).

```julia
metric = Distances.Euclidean() # Use Euclidean instead of SqEuclidean
alternatives = NearOptimalAlternatives.generate_alternatives(model, optimality_gap, n_alternatives, metric=metric)
```

If you only want to change specific variables of a problem when generating alternatives, you can fix the other variables as follows. Suppose you are solving a problem for which the model contains 3 variables ($x_1$, $x_2$, $x_3$) and you want to fix $x_2$. You then simply create a vector of fixed variables and supply this as a parameter to the function.

```julia
fixed_variables = [x_2] # x_2 should be the VariableRef in the JuMP model.
alternatives = NearOptimalAlternatives.generate_alternatives(model, optimality_gap, n_alternatives, fixed_variables=fixed_variables)
```

## Alternatives using a metaheuristic algorithm

Generating alternatives using a metaheuristic algorithm from [Metaheuristics.jl](https://github.com/jmejia8/Metaheuristics.jl) works similarly. We still need a solved `model`, an `optimality_gap` and the amount of alternatives `n_alternatives`. As an extra, we now need to define the algorithm we want to use. For instance:

```julia
metaheuristic_algorithm = Metaheuristics.PSO()
```

Then we call the following function using all parameters to obtain the results.

```julia
alternatives = generate_alternatives(model, optimality_gap, n_alternatives, metaheuristic_algorithm)
```

Again, `metric` and `fixed_variables` can be supplied as optional parameters. The parameters of the `metaheuristic_algorithm` can be defined when initialising it. For more details on this, take a look at the [Metaheuristics.jl documentation](https://jmejia8.github.io/Metaheuristics.jl/stable/).

### Alternatives using PSOGA

To use our concurrent Particle Swarm Optimisation metaheuristic PSOGA, the same steps should be taken as when using another metaheuristic. The only difference is that you have to supply the number of alternatives to the algorithm as well, so it knows how many subpopulations it should keep in its parameters. The following code shows how to do this and obtain the alternatives.

```julia
metaheuristic_algorithm = NearOptimalAlternatives.PSOGA(N_solutions=n_alternatives)
alternatives = generate_alternatives(model, optimality_gap, n_alternatives, metaheuristic_algorithm)
```
