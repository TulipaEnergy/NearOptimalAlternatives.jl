"""
  is_better_psoga(
    A::T,
    B::T,
    centroids::Vector{Any},
    subpop_a::Int64,
    subpop_b::Int64,
    maximise_total::Bool
  ) where {T <: Metaheuristics.xFgh_solution}

Compare two solutions of the PSOGA algorithm with respect to their distance to the optimal solution and other alternatives.

# Arguments
- `A`: solution in PSOGA to be compared.
- `B`: solution in PSOGA to be compared.
- `centroids::Vector{Any}`: vector of centroids per subpopulation. A centroid is the average point of all solutions in a subpopulation.
- `subpop::Int64`: index of the subpopulation solution A and B are in. Note that they are always in the same, since we only compare within subpopulations or with themselves.
- `maximise_total::Bool`: if true, we maximise the sum of distances between a point and all centroids of other subpopulations, else we maximise the minimum distance between a point and the centroids of other subpopulations.
"""
function is_better_psoga(
  A::T,
  B::T,
  centroids::Matrix{Float64},
  subpop::Int64,
  maximise_total::Bool,
) where {T <: Metaheuristics.xFgh_solution}
  A_vio = A.sum_violations
  B_vio = B.sum_violations

  # If either A or B violates the constraints, the one with the smaller violation is better.
  if A_vio < B_vio
    return true
  elseif B_vio < A_vio
    return false
  end

  # Set distances for A and B equal to negative objective value, which is equivalent to the distance between the point and the initial optimal solution.
  A_dist = -A.f[1]
  B_dist = -B.f[1]

  # For each subpopulation compute the distance between both points and the centroid of that subpopulation.
  for i in eachindex(centroids[:, 1])
    # Skip the subpopulation A and B are in.
    if i == subpop
      continue
    end
    # Update distance based on whether we aim for maximising the total distance or the minimum distance.
    if maximise_total
      A_dist += sum((A.x[j] - centroids[i, j])^2 for j in eachindex(A.x))
      B_dist += sum((B.x[j] - centroids[i, j])^2 for j in eachindex(A.x))
    else
      A_dist = min(A_dist, sum((A.x[j] - centroids[i, j])^2 for j in eachindex(A.x)))
      B_dist = min(B_dist, sum((B.x[j] - centroids[i, j])^2 for j in eachindex(B.x)))
    end
  end

  # If total or minimum distance of A is bigger than for B, A is better so return true.
  return A_dist > B_dist
end
