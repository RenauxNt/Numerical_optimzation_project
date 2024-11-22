using JuMP, Gurobi, CSV, DataFrames, Statistics, Plots

# Create a new JuMP model with Gurobi as the solver

#Loadings the CSV files
stocks = CSV.read("data.csv", DataFrame)
sectors = CSV.read("sector_mapping.csv", DataFrame, header=false)
gammas = CSV.read("gamma_vals.csv", DataFrame, header=false)

#Setting the parameters
num_weeks = nrow(stocks)
num_stocks = nrow(sectors)
num_sectors = unique(sectors[:,2])
capital_intial = 500000

# Covariance matrix
sigma = cov( Matrix(stocks[:,1:end]) )

model = Model(Gurobi.Optimizer)
set_optimizer_attribute(model, "Method", 0) # Primal Simplex
#set_optimizer_attribute(model, "Method", 1) # Dual Simplex

# Variables
@variable(model, parts[1:num_stocks] >= 0)

# Constraints
full_capital_constraint= @constraint(model, 0 <= sum(parts[i] for i in 1:num_stocks) <= 1)

sector_constraints = Dict()
for num_sector in num_sectors
    sector_i = findall(sectors[:,2] .== num_sector)
    sector_constraints[num_sector] = @constraint(model, sum(parts[i] for i in sector_i) <= 0.2)
end

expected_return = sum(((stocks[week, i]-stocks[week-1, i])/stocks[week-1, i]) * parts[i] for i in 1:num_stocks, week in 2:num_weeks)*100/(num_weeks-1)
risk = sum(transpose(parts)*sigma*parts)
#risk = sum(parts[i] * sigma[i, j] * parts[j] for i in 1:num_stocks, j in 1:num_stocks)

risks = []
expected_returns = []

for gamma in Array(gammas)
    println("Gamma: ", gamma)
    # Objective: maximize historical average weekly return.
    # We do not put the normalization factor in the objective function because it does not affect the optimal solution.
    @objective(model, Max, expected_return - gamma * risk)

    # Solve the model
    optimize!(model)

    if termination_status(model) == MOI.OPTIMAL
        optimal_allocation = value.(parts)
        index_parts = findall(optimal_allocation[:] .!= 0)
        total_return = objective_value(model)
        println("Optimal Portfolio Allocation for gamma = ", gamma," :")

        println("Total Historical Average Weekly Return:",  sum(((stocks[week, i]-stocks[week-1, i])/stocks[week-1, i])*optimal_allocation[i] for week in 2:num_weeks, i in index_parts)*100/(num_weeks-1),"%")

        println("Risk: ", value.(risk))
        println("Expected Return: ", value.(expected_return))

        push!(risks, value.(risk))
        push!(expected_returns, value.(expected_return - gamma * risk))

        # optimal_allocation = value.(parts)
        # index_parts = findall(optimal_allocation[:] .!= 0)
        # total_return = objective_value(model)
        # println("Optimal Portfolio Allocation for gamma = ", gamma," :")
        # for i in index_parts
        #     println(names(stocks)[i]," from sector ", sectors[i,2] ," with ", (100000/stocks[1, i]), " shares and ", 
        #     sum(((stocks[week, i]-stocks[week-1, i])/stocks[week-1, i]) for week in 2:num_weeks)*100/(num_weeks-1), "% of weekly return")
        # end
        # println("Total Historical Average Weekly Return:",  sum(((stocks[week, i]-stocks[week-1, i])/stocks[week-1, i]) for week in 2:num_weeks, i in index_parts)*100/(num_weeks-1),"%")
        # println(optimal_allocation[index_parts])
        # println("\n DUAL VARIABLES \n")
        # println("p:  ", dual(full_capital_constraint))

        # Dual values for sector allocation constraints
        # for (sector, constraint) in sector_constraints
        #     println("q_", sector, " ", dual(constraint))
        # end
    else
        println("No optimal solution found")
    end
end

Plots.plot(risks, expected_returns)