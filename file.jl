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
@variable(model, returns[1:num_stocks, new_weeks])

# Constraints
@constraint(model, 0 <= sum(parts[stock] for stock in 1:num_stocks) <= 1)

for num_sector in num_sectors
    sector_i = findall(sectors[:,2] .== num_sector)
    @constraints(sum(parts[stock] for stock in sector_i) <= 0.2)
end

# Objective: maximize historical average weekly return.
# We do not put the normalization factor in the objective function because it does not affect the optimal solution.
@objective(model, Max, sum(returns[stock, week] * parts[stock] for stock in 1:num_stocks, week in 1:num_weeks))