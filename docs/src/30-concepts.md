```@contents
Pages = ["concepts.md"]
Depth = 5
```

# Concepts

Here we explain in more detail the underlying theoretical concepts of NearOptimalAlternatives.jl. We first discuss the traditional approach modelling-to-generate-alternatives and then discuss the evolutionary approaches.

## Modelling-to-Generate-Alternatives (MGA)

Modelling-to-generate-alternatives (MGA) is a technique to find alternative solutions to an optimization problem that are as different as possible from the optimal solution, introduced by Brill Jr et al. [^brill]. Their approach consists of a Hop-Skip-Jump MGA method and works as follows. First, an initial solution is found using any optimization method. Next, an amount of slack specified by the user is added to the objective function. Then, this objective function is encoded as a constraint and a new objective function that minimises the weighted sum of decision variables that appeared in previous solutions. This process is iterated as long as changes in the solutions are visible.

[^brill]: E. D. Brill Jr, S.-Y. Chang, and L. D. Hopkins, “Modeling to generate alternatives: The hsj approach and an illustration using a problem in land use planning,” Management Science, vol. 28, no. 3, pp. 221–235, 1982.

For problems with non-binary variables the corresponding MGA problem can be formulated as follows. Given the optimal solution $x^*$ to an optimization problem with constraints $Ax \leq b, x \geq 0$ and objective $c^{\top}x$, we solve the following problem

```math
\begin{align}
    &max &|| x - x^* ||_d \\
    &s.t. &c^{\top}x \geq (1-\epsilon) c^{\top}x^*\\
        &&Ax \leq b \\
        &&x \geq 0,
\end{align}
```

where $\epsilon$ is the objective gap which specifies the maximum difference between the objective value of a solution and the optimal objective value and $d$ is any distance metric.

## Evolutionary Algorithms for Generating Alternatives

Evolutionary algorithms have been proposed as an alternative method to mathematical programming for generating alternative solutions by Zechman and Ranjithan [^zechman].

[^zechman]: E. M. Zechman and S. R. Ranjithan, “An evolutionary algorithm to generate alternatives (eaga) for engineering optimization problems,” Engineering Optimization, vol. 36, no. 5, pp. 539–553, 2004.

Their method works as follows. Instead of simply initializing an initial population as a regular evolutionary algorithm would do, they divide this population into $P$ subpopulations, where $P$ is equal to the number of alternative solutions to be found. Each subpopulation is dedicated to search for one alternative solution. The first subpopulation can also be used to find the global optimum. After initializing the population, they take the following steps iteratively. First, evaluate all individuals with respect to the objective and feasibility. Also, the distance between this solution and other subpopulations, or there centroids, is taken into account. So, the best individual is a feasible solution which is furthest away from other subpopulations. They used elitism to preserve the best solution in each subpopulation. Afterwards, after checking stopping criteria, they applied binary tournament selection based on the fitness of the solution to select the rest of the individuals.

### Particle Swarm Optimization for Generating Alternatives (PSOGA)

In this package we developed PSOGA, an modification of Evolutionary Algorithms for Generating Alternatives using Particle Swarm Optimization (PSO). It works as follows.

When initializing the algorithm, the population of individuals is divided into $n$ equal-size subpopulations, where $n$ is the number of alternative solutions sought. As with regular PSO, each individual has a position $x$ and a velocity $v$.

The update step of the algorithm works very similar to regular PSO. In every iteration, each individual is updated as follows. First, its velocity is updated and becomes
$$v = \omega \cdot v + \textit{rand}(0,1) \cdot c_1 \cdot (p_{\textit{best}} - x)  + \textit{rand}(0,1) \cdot c_2 \cdot (s_{\textit{best}} - x).$$
In the above equation, $\omega$ represents the inertia, $c_1$ is the cognitive parameter and $c_2$ is the social parameter. These make sure that the old velocity is taken into account, previous information from this individual is used and information from other individuals in the subpopulation is used, respectively. Therefore, the variables $p_\textit{best}$, representing the personal best position of this individual, and $s_\textit{best}$,representing the alltime best of the subpopulation this individual is in, are required. Note that $s_\textit{best}$ replaces $g_\textit{best}$, which is used in regular PSO and represents the global best solution of the full population.

After updating the velocity of each individual, all positions are updated using $x = x + v$. Subsequently, all personal bests and subpopulation bests are updated based on the objective value. For PSOGA the objective is to generate alternatives that are as different as possible from the optimal solution, but also from each other. The aim here is to make sure each subpopulation finds one alternative, and these are spread out over the search space.

When comparing two solutions to decide which is better, we therefore take the following approach. If either of the solutions is infeasible, we take the solution with the smallest constraint violation. If none are infeasible we pick the one with the largest distance, where the distance can be defined in two ways. Either, we calculate the sum of all distances to other subpopulations and to the original optimal solution, or we calculate the minimum of the distances to other subpopulations and the original optimal solution. To compute the distance to other subpopulations, we calculate the centroid (average) of all points in the subpopulation and compute the distance to that centroid.

The algorithm terminates when the subpopulations have converged, or the maximum number of iterations has been met. By then, the subpopulations should be spread out over the feasible space and as far as possible from the initial optimal solution.
