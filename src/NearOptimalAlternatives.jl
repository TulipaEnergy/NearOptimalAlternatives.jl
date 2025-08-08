module NearOptimalAlternatives

# Packages

using JuMP
using Distances
using MathOptInterface
using Metaheuristics
using DataStructures

include("MGA-Methods/Max-distance.jl")
include("MGA-Methods/HSJ.jl")

include("results.jl")
include("alternative-optimisation.jl")
include("generate-alternatives.jl")
include("alternative-metaheuristics.jl")



end
