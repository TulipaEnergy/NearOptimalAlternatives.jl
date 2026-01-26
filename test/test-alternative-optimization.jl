@testset "Test unsupported modeling method" begin
    @testset "Creating alternative generating problem with unsupported method" begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)

        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, x_1 + x_2)
        JuMP.optimize!(model)

        @test_throws ArgumentError NearOptimalAlternatives.create_alternative_generating_problem!(
            model,
            0.1,
            VariableRef[],
            all_variables(model);
            modeling_method = :Unsupported_Method,
            metric = SqEuclidean(),
        )
    end
    @testset "Updating objective function with unsupported method" begin
        optimizer = Ipopt.Optimizer
        model = JuMP.Model(optimizer)
        @variable(model, 0 ≤ x_1 ≤ 1)
        @variable(model, 0 ≤ x_2 ≤ 1)
        @objective(model, Max, x_1 + x_2)
        JuMP.optimize!(model)

        @test_throws ArgumentError NearOptimalAlternatives.update_objective_function!(
            model,
            all_variables(model);
            modeling_method = :Unsupported_Method,
            metric = SqEuclidean(),
        )
    end
end
