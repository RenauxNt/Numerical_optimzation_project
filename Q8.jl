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
const_obj = 100/(num_weeks-1)

model = Model(Gurobi.Optimizer)

# Variables
@variable(model, parts[1:num_stocks] >= 0)

# Covariance matrix
sigma = cov([(stocks[week, i] - stocks[week-1, i]) / stocks[week-1, i] * 100 for week in 2:num_weeks, i in 1:num_stocks])

# Constraints
full_capital_constraint= @constraint(model, sum(parts[i] for i in 1:num_stocks) <= 1)

sector_constraints = Dict()
for num_sector in num_sectors
    sector_i = findall(sectors[:,2] .== num_sector)
    sector_constraints[num_sector] = @constraint(model, sum(parts[i] for i in sector_i) <= 0.2)
end

expected_return = sum(((stocks[week, i]-stocks[week-1, i])/stocks[week-1, i]) * parts[i] for i in 1:num_stocks, week in 2:num_weeks)*const_obj
risk = sum(transpose(parts) * sigma * parts)

risks = []
expected_returns = []

for gamma in Array(gammas)
    # Objective: maximize historical average weekly return.
    # We do not put the normalization factor in the objective function because it does not affect the optimal solution.
    @objective(model, Max, expected_return - gamma * risk)

    # Solve the model
    optimize!(model)

    if termination_status(model) == MOI.OPTIMAL
        optimal_allocation = value.(parts)
        index_parts = findall(optimal_allocation .!= 0)

        return_val = sum(((stocks[week, i]-stocks[week-1, i])/stocks[week-1, i])*optimal_allocation[i] for week in 2:num_weeks, i in index_parts)*const_obj
        println("Total Historical Average Weekly Return:",  return_val, "% for gamma = ", gamma)
        println("Risk: ", value.(risk))
        
        push!(risks, value.(risk))
        push!(expected_returns, value.(return_val))
    else
        println("No optimal solution found")
    end
end

# Plot the efficient frontier
Plots.plot(risks, expected_returns, label="Efficient Frontier", lw=2, size = (800, 600))
Plots.title!("Evolution of the expected return as a function of the risk")
Plots.xlabel!("Risk")
Plots.ylabel!("Expected Return")
Plots.savefig("efficient_frontier.pdf")