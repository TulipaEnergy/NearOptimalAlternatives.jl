module NearOptimalAlternatives

# Packages

using JuMP
using Distances
using MathOptInterface
using Metaheuristics
using DataStructures
using Statistics

# Main file for generating alternatives
include("generate-alternatives.jl")

# Create different problems
include("alternative-optimization.jl")
include("alternative-metaheuristics.jl")

# Update solutions
include("results.jl")

# PSOGA Algorithm
include("algorithms/PSOGA/PSOGA.jl")
include("algorithms/PSOGA/is_better.jl")

# MGA Methods
include("MGA-Methods/Max-Distance.jl")
include("MGA-Methods/HSJ.jl")
include("MGA-Methods/Spores.jl")
include("MGA-Methods/Min-Max-Variables.jl")
include("MGA-Methods/Random-Vector.jl")
include("MGA-Methods/Directionally-Weighted-Variables.jl")

end
