# MGA methods

This page summarizes the modeling-to-generate-alternatives (MGA) routines available via the `modeling_method` keyword to `generate_alternatives!` and `generate_alternatives`. Each method provides an `*_initial!` and `*_update!` pair that `alternative-optimisation.jl` calls through its dispatch tables.

MGA works on a one-at-a-time approach, where n alternatives are generated sequentially. Each alternative $k, 1 ≤ k ≤ n$ minimizes the sum of the weight vector wk—which indicates the search direction in the near-optimal solution space—and the decision variable vector x, as shown in below. This is subject to the near-optimal solution space. In this section, various methods with different weight vectors are discussed. It is essential to note that this one-at-a-time approach is effective if the model is simple; however, as the model’s size increases, generating even a single alternative becomes computationally expensive.

```math
\text{Minimize}:w^k · x
```

## Max-Distance (`:Max_Distance`)

- Files: `MGA-Methods/Max-Distance.jl`
- Goal: maximize distance between the current solution and the reference solution using a chosen metric (default: squared Euclidean; updates default to Cityblock).
- Behavior: `Dist_initial!` fixes specified variables, captures the current solution, and sets a distance-maximizing objective. `Dist_update!` adds additional distance terms to encourage further diversity across iterations.

## Hop-Skip-Jump (`:HSJ`)

- Files: `MGA-Methods/HSJ.jl`
- Goal: minimize a weighted sum where weights are 1 for nonzero variables and 0 otherwise, biasing the search away from the current support.
- Behavior: `HSJ_initial!` fixes requested variables and sets weights from the current solution; `HSJ_update!` recomputes weights from the latest solution before re-solving.
- Hop-Skip-Jump (HSJ) [^HSJ1982] is a method that tries to find alternatives by minimizing the variables that had a non-zero value in the previous iteration. This is done to find alternatives that invest less in the decision variable, which was already invested in in the previous iteration. More precisely, it minimizes based on the value of the variables in the previous iteration. The weights are defined in:

```math
w_i^{k} = \begin{cases}
0, & \text{if } x_i^{k-1} = 0 \\
1, & \text{otherwise.}
\end{cases}
```

## Spores (`:Spores`)

- Files: `MGA-Methods/Spores.jl`
- Goal: shift emphasis toward variables that could take larger values relative to their upper bounds (upper bounds required for all variables involved).
- Behavior: `Spores_initial!` and `Spores_update!` accumulate weights as `weights[i] += value(v) / upper_bound(v)` and minimize the resulting weighted sum.
- Spores [^SPORES2020] is a modification of HSJ. It does not discard the weights of the previous iteration. Instead, it updates them using the update rule as described below. This equation introduces $x^{max}_i$ , which refers to the maximum possible value that $x_i$ can take. This update rule assigns a high weight to variables whose value is close to the maximum value, while assigning a low weight to variables whose value is close to zero. This is similar to the HSJ method, but with the ability to be more expressive. This weight is the basis of the Spores method.

```math
w_i^k = w_i^{k-1} + \frac{x_i^{k-1}}{x_i^{\text{max}}}, \quad \forall k, 1 \leq k \leq n,
```

```math
w_i^0 = 0.
```

## Min/Max Variables (`:Min_Max_Variables`)

- Files: `MGA-Methods/Min-Max-Variables.jl`
- Goal: randomly push variables to be minimized, maximized, or ignored to explore diverse corners of the feasible region.
- Behavior: both `*_initial!` and `*_update!` draw weights uniformly from `{-1, 0, 1}` and minimize the weighted sum.
- Min/Max Variables [^Evelina2012][^Lukas2019] is an approach that minimizes and/or maximizes a random sample of variables. This is done by randomly sampling the weights as specified below. Contrary to HSJ and Spores, the Min/Max Variables does not consider any previously found alternatives. When applying this approach, all variables with weight 1 get minimized, the variable with weight −1 gets maximized, and the variables with weight 0 are free.

```math
w_i \sim \text{Uniform}(\{−1, 0, 1\}), \forall i
```

## Random Vector (`:Random_Vector`)

- Files: `MGA-Methods/Random-Vector.jl`
- Goal: similar to Min/Max Variables but with continuous random weights in [-1, 1] for smoother perturbations.
- Behavior: each call redraws weights from `Uniform(-1, 1)` and minimizes the weighted sum.
- Random Vector [^RANDV2017] is similar to Min/Max Variables. Where Min/Max Variables samples either −1, 0, or 1, Random Vector samples a predefined distribution for all variables, most of the time this distribution is the uniform distribution between −1 and 1, as described below. However, the distribution can be different for each variable to best fit the model being solved.

```math
w_i \sim \text{Uniform}(−1, 1), \forall i
```

## Directionally Weighted Variables (`:Directionally_Weighted_Variables`)

- Files: `MGA-Methods/Directionally-Weighted-Variables.jl`
- Goal: choose variable directions based on the sign of their coefficients in the original objective to promote directional diversity.
- Behavior: weights depend on objective coefficients (`>0` draws from {0,1}, `<0` from {-1,0}, else {-1,0,1}); `DWV_initial!` fixes requested variables, sets the weighted-sum objective, and `DWV_update!` redraws weights before the next solve.

## How they are selected

- `alternative-optimisation.jl` maps method symbols to the corresponding `*_initial!` and `*_update!` functions through dispatch dictionaries (`METHOD_DISPATCH_INITIAL`, `METHOD_DISPATCH_UPDATE`).
- The `modeling_method` keyword in `generate_alternatives!` determines which method is used for the initial reformulation and each subsequent objective update.
- Metaheuristic runs (`generate_alternatives`) can still use the same method symbol for distance computation when adding solutions iteratively.

## References

[^HSJ1982]: E Downey Brill Jr, Shoou-Yuh Chang, and Lewis D Hopkins. “Modeling to generate alternatives: The HSJ approach and an illustration using a problem in land use planning”. In: Management Science 28.3 (1982), pp. 221–235.
[^SPORES2020]: Francesco Lombardi et al. “Policy decision support for renewables deployment through spatially explicit practically optimal alternatives”. In: Joule 4.10 (2020), pp. 2185–2207.
[^Lukas2019]: Lukas Nacken et al. “Integrated renewable energy systems for Germany–A model-based exploration of the decision space”. In: 2019 16th international conference on the European energy market (EEM). IEEE. 2019, pp. 1–8.
[^Evelina2012]: Evelina Trutnevyte et al. “Context-specific energy strategies: coupling energy system visions with feasible implementation scenarios”. In: Environmental science & technology 46.17 (2012), pp. 9240–9248
[^RANDV2017]: Philip B Berntsen and Evelina Trutnevyte. “Ensuring diversity of national energy scenarios: Bottomup energy system model with Modeling to Generate Alternatives”. In: Energy 126 (2017), pp. 886–898.
