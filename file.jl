using JuMP, Gurobi, CSV, DataFrames

# Create a new JuMP model with Gurobi as the solver
model = Model(Gurobi.Optimizer)

#Loadings the CSV files
stocks = CSV.read("data.csv", DataFrame)
sectors = CSV.read("sector_mapping.csv", DataFrame, header=false)

#Setting the parameters
num_weeks = nrow(stocks)
num_stocks = nrow(sectors)
num_sectors = unique(sectors[:,2])
capital_intial = 500000

# Variables
@variable(model, 0.2 >= parts[1:num_stocks] >= 0)
#@variable(model, returns[1:num_stocks, new_weeks])

# Constraints
@constraint(model, 0 <= sum(parts[i] for i in 1:num_stocks) <= 1)

for num_sector in num_sectors
    sector_i = findall(sectors[:,2] .== num_sector)
    @constraint(model, sum(parts[i] for i in sector_i) <= 0.2)
end

# Objective: maximize historical average weekly return.
# We do not put the normalization factor in the objective function because it does not affect the optimal solution.
@objective(model, Max, sum(((stocks[week, i]-stocks[week-1, i])/stocks[week-1, i]) * parts[i] for i in 1:num_stocks, week in 2:num_weeks))

# Solve the model
optimize!(model)

if termination_status(model) == MOI.OPTIMAL
    optimal_allocation = value.(parts)
    index = findall(optimal_allocation[:] .!= 0)
    total_return = objective_value(model)
    println("Optimal Portfolio Allocation:")
    println(names(stocks[:,index]), " with ", optimal_allocation[index], (100000/stocks[1, i] for i in index))
    println("Total Historical Average Weekly Return:", total_return)
else
    println("No optimal solution found")
end