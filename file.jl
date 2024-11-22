using JuMP, Gurobi, CSV, DataFrames, Statistics

# Create a new JuMP model with Gurobi as the solver
model = Model(Gurobi.Optimizer)
set_optimizer_attribute(model, "Method", 0)  # Primal Simplex#
#set_optimizer_attribute(model, "Method", 1) # Dual Simplex
#Loadings the CSV files
stocks = CSV.read("data.csv", DataFrame)
sectors = CSV.read("sector_mapping.csv", DataFrame, header=false)

#Setting the parameters
num_weeks = 568
num_stocks = 462
num_sectors = 0:9
const_T = (num_weeks-1)

# Variables
@variable(model, parts[1:num_stocks] >= 0)

# Constraints
full_capital_constraint= @constraint(model, sum(parts) <= 1)

sector_constraints = Dict()
for num_sector in num_sectors
    sector_i = findall(sectors[:,2] .== num_sector)
    sector_constraints[num_sector] =@constraint(model, sum(parts[i] for i in sector_i) <= 0.2)
end

# Objective: maximize historical average weekly return.
# We do not put the normalization factor in the objective function because it does not affect the optimal solution.
@objective(model, Max, sum(((stocks[week, i]-stocks[week-1, i])/stocks[week-1, i]) * parts[i] for i in 1:num_stocks, week in 2:num_weeks)*100/const_T)

# Solve the model
optimize!(model)

if termination_status(model) == MOI.OPTIMAL
    optimal_allocation = value.(parts)
    index_parts = findall(optimal_allocation[:] .!= 0)
    total_return = objective_value(model)
    println("Optimal Portfolio Allocation:")
    for i in index_parts
        println(names(stocks)[i]," from sector ", sectors[i,2] ," with ", (100000/stocks[1, i])," shares while using ", optimal_allocation[i]*100, "% of the capital and ", 
        round(sum(((stocks[week, i]-stocks[week-1, i])/stocks[week-1, i]) for week in 2:num_weeks)*100/(const_T), digits=4), "% of weekly return")
    end
    println("Total Historical Average Weekly Return:",  sum(((stocks[week, i]-stocks[week-1, i])/stocks[week-1, i]) for week in 2:num_weeks, i in index_parts)*100/const_T,"%")
    println(optimal_allocation[index_parts])

    println("\n DUAL VARIABLES \n")
    println("p:   ", dual(full_capital_constraint))

    
    # Dual values for sector allocation constraints
    for (sector, constraint) in sector_constraints
        println("q_", sector, ": ", dual(constraint))
    end

    # Display the sensitivity report
    sensitivity_report = lp_sensitivity_report(model)
    println("\nSensitivity Analysis Report:")
    println(sensitivity_report[sector_constraints[6]])
else
    println("No optimal solution found")
end