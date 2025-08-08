using NearOptimalAlternatives
using Test
using Ipopt
using JuMP
using Distances
using MathOptInterface
using Metaheuristics
using DataStructures

for file in readdir(@__DIR__)
  if !startswith("test-")(file)
    continue
  end
  include(file)
end

for file in readdir(joinpath(@__DIR__, "tests-MGA-Methods/"))
  if !startswith("test-")(file)
    continue
  end
  include(joinpath("tests-MGA-Methods", file))
end
