using JuMP, GLPK, CSV, DataFrames

# Create a new JuMP model with Gurobi as the solver
model = Model(GLPK.Optimizer)

# Load the data
stocks = CSV.read("data.csv", DataFrame)
sectors = CSV.read("sector_mapping.csv", DataFrame, header=false)

# Setting the parameters
num_weeks = nrow(stocks)
num_stocks = nrow(sectors)
num_sectors = unique(sectors[:, 2])
capital_initial = 500000

# Variables
@variable(model, 0.2 >= parts[1:num_stocks] >= 0)

# Constraints
full_capital_constraint = @constraint(model, sum(parts[i] for i in 1:num_stocks) == 1)

sector_constraints = Dict()
for num_sector in num_sectors
    sector_i = findall(sectors[:, 2] .== num_sector)
    sector_constraints[num_sector] = @constraint(model, sum(parts[i] for i in sector_i) <= 0.2)
end

# Objective: maximize historical average weekly return
@objective(model, Max, sum(((stocks[week, i] - stocks[week - 1, i]) / stocks[week - 1, i]) * parts[i] for i in 1:num_stocks, week in 2:num_weeks))

# Solve the model
optimize!(model)

if termination_status(model) == MOI.OPTIMAL
    optimal_allocation = value.(parts)
    total_return = objective_value(model)

    println("\nSensitivity Analysis for Sector Limit Change:")

    # Assume we want to analyze Sector 6 limit
    sector_index = 6
    original_limit = 0.2
    sector_constraint = sector_constraints[sector_index]
    current_dual = dual(sector_constraint)

    if current_dual > 0
        println("The current constraint for Sector $sector_index is binding. Calculating the sensitivity interval:")

        # Lower bound: Keep decreasing the limit until dual becomes zero or allocation becomes zero
        local lower_bound = original_limit
        while true
            lower_bound -= 0.01
            set_upper_bound(sector_constraint, lower_bound)
            optimize!(model)
            if termination_status(model) != MOI.OPTIMAL || value(sum(parts[i] for i in sector_i)) == 0
                break
            end
        end
        lower_bound += 0.01

        # Upper bound: Keep increasing the limit until dual becomes zero
        local upper_bound = original_limit
        while true
            upper_bound += 0.01
            set_upper_bound(sector_constraint, upper_bound)
            optimize!(model)
            if termination_status(model) != MOI.OPTIMAL || dual(sector_constraint) == 0
                break
            end
        end
        upper_bound -= 0.01

        println("Sector $sector_index limit sensitivity interval: [$(lower_bound), $(upper_bound)]")
    else
        println("The current constraint for Sector $sector_index is non-binding, changes will have no effect.")
    end
else
    println("No optimal solution found")
end
