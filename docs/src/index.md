```@meta
CurrentModule = NearOptimalAlternatives
```

# NearOptimalAlternatives.jl Documentation

[NearOptimalAlternatives.jl](https://github.com/TulipaEnergy/NearOptimalAlternatives.jl) is a package for generating near optimal alternative solutions to a solved [JuMP.jl](https://github.com/jump-dev/JuMP.jl) optimisation problem. The alternative solutions are within a maximum specified percentage of the optimum and are as different from the optimal solution (and other alternatives) as possible. Alternatives can either be generated using mathematical optimisation or using a metaheuristic algorithm. For the latter, this package depends on [Metaheuristics.jl](https://github.com/jmejia8/Metaheuristics.jl).

## License

This content is released under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) license.

## Contents

```@contents
Pages = ["index.md", "how-to-use.md", "tutorials.md", "concepts.md", "contributing.md", "developer.md", reference.md"]
```
