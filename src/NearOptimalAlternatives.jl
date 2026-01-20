module NearOptimalAlternatives

# Packages

using JuMP
using Distances
using MathOptInterface
using Metaheuristics
using DataStructures
using Statistics

include("MGA-Methods/Max-Distance.jl")
include("MGA-Methods/HSJ.jl")
include("MGA-Methods/Spores.jl")
include("MGA-Methods/Min-Max-Variables.jl")
include("MGA-Methods/Random-Vector.jl")
include("MGA-Methods/Directionally-Weighted-Variables.jl")

include("results.jl")
include("alternative-optimization.jl")
include("generate-alternatives.jl")
include("alternative-metaheuristics.jl")
include("algorithms/PSOGA/PSOGA.jl")
include("algorithms/PSOGA/is_better.jl")


end
