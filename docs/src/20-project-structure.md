# Project structure

This page gives a quick orientation of the repository and highlights what each source file does.

## Repository layout

- `Project.toml` / `Manifest.toml`: project environment for the package itself; pin dependencies.
- `docs/Project.toml` / `docs/Manifest.toml`: documentation environment (Documenter + LiveServer).
- `docs/src`: documentation sources (this file, guides, reference pages).
- `src`: package code (module entry point, core APIs, MGA methods, metaheuristic bridge, results container).
- `test`: unit tests exercising the core APIs and MGA methods.

## Source files (src/)

- `NearOptimalAlternatives.jl`: defines the `NearOptimalAlternatives` module and includes all submodules and method implementations.
- `generate-alternatives.jl`: user-facing entry points `generate_alternatives!` (JuMP re-optimisation loop) and `generate_alternatives` (metaheuristics-based) with input validation and iteration logic.
- `alternative-optimisation.jl`: builds and updates the JuMP problem for alternative generation; dispatch tables map method symbols to their initial/update routines; adds the original objective as an optimality-gap constraint.
- `alternative-metaheuristics.jl`: translates a JuMP/MathOptInterface model into a metaheuristics-friendly objective/constraints representation and runs a Metaheuristics.jl algorithm.
- `results.jl`: defines `AlternativeSolutions` and helper functions to collect decision-variable values and objective values from JuMP or Metaheuristics runs.
- `MGA-Methods/`: individual implementations of each modeling-to-generate-alternatives (MGA) strategy used by the dispatch tables (see next page for details).

## Typical control flow

1. Start from a solved JuMP model and call `generate_alternatives!` or `generate_alternatives`.
2. The chosen modeling method (symbol) is looked up in the dispatch tables in `alternative-optimisation.jl`.
3. The selected MGA method file configures the objective and (optionally) fixes variables.
4. Solutions are iteratively generated and accumulated via `AlternativeSolutions` in `results.jl`.
5. Metaheuristic runs follow the same pattern but use the translation layer in `alternative-metaheuristics.jl`.
