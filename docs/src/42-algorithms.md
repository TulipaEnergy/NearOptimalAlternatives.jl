# Algorithms

This page summarizes the algorithms available.

## PSOGA (`:Particle Swarm Optimization for Generating Alternatives`)

- Files: `algorithms/PSOGA/PSOGA.jl` and `algorithms/PSOGA/is_better.jl`
- Goal: maximize distance from provided solution within search space
- Behavior: `initialize!` initializez population and global parameters. `update_state!` performs one loop of he metaheuristic process. `final_stage!` performs final steps after solving the problem.
