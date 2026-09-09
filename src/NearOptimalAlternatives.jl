module NearOptimalAlternatives

using JuMP
using Distances
using MathOptInterface
using Metaheuristics
using DataStructures
using Statistics

# PSOGA Algorithm (metaheuristic)
include("algorithms/PSOGA/PSOGA.jl")
include("algorithms/PSOGA/is_better.jl")

# MGA Methods
include("MGA-Methods/Max-Distance.jl")
include("MGA-Methods/HSJ.jl")
include("MGA-Methods/Spores.jl")
include("MGA-Methods/Min-Max-Variables.jl")
include("MGA-Methods/Random-Vector.jl")
include("MGA-Methods/Directionally-Weighted-Variables.jl")

# Create different problems
include("alternative-optimization.jl")
include("alternative-metaheuristics.jl")

# Main file for generating alternatives
include("generate-alternatives.jl")

# Budget-sweep generator (dense near-optimal front per direction)
include("sweep-alternatives.jl")

# Arclength-distributed front generator (even spacing along the trade-off curve)
include("arclength-alternatives.jl")

# Update solutions
include("results.jl")

end
