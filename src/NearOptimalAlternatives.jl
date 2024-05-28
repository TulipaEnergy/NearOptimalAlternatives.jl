module NearOptimalAlternatives

# Packages

using JuMP
using Distances
using MathOptInterface
using Metaheuristics
using DataStructures

include("results.jl")
include("alternative-optimisation.jl")
include("generate-alternatives.jl")
include("alternative-metaheuristics.jl")

end
