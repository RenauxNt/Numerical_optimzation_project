using JuMP, Gurobi, CSV, DataFrames, Statistics

# Create a new JuMP model with Gurobi as the solver
model = Model(Gurobi.Optimizer)
set_optimizer_attribute(model, "Method", 0)  # Primal Simplex
#set_optimizer_attribute(model, "Method", 1) # Dual Simplex

#Read the CSV files
stocks = CSV.read("data.csv", DataFrame)
sectors = CSV.read("sector_mapping.csv", DataFrame, header=false)

#Setting the parameters
num_weeks = nrow(stocks)
num_stocks = nrow(sectors)
num_sectors = unique(sectors[:,2])
capital = 500000
const_obj = 100/(num_weeks-1)

# Variables
@variable(model, parts[1:num_stocks] >= 0)

# Constraints
full_capital_constraint= @constraint(model, sum(parts) <= 1)

sector_constraints = Dict()
for num_sector in num_sectors
    sector_j = findall(sectors[:,2] .== num_sector)
    sector_constraints[num_sector] = @constraint(model, sum(parts[i] for i in sector_j) <= 0.2)      
end

# Objective: maximize historical average weekly return.
@objective(model, Max, sum(((stocks[week, i]-stocks[week-1, i])/stocks[week-1, i]) * parts[i] for i in 1:num_stocks, week in 2:num_weeks)*const_obj)

# Solve the model
optimize!(model)

if termination_status(model) == MOI.OPTIMAL
    optimal_allocation = value.(parts)
    index_parts = findall(optimal_allocation[:] .!= 0)
    println("\nModel Solving Time: ", solve_time(model), " seconds")

    println("Optimal Portfolio Allocation:")
    for i in index_parts
        part = optimal_allocation[i]
        println(names(stocks)[i]," from sector ", sectors[i,2] ," with ", (capital*part/stocks[1, i])," shares while using ", part*100, "% of the capital and ", 
        round(sum(((stocks[week, i]-stocks[week-1, i])/stocks[week-1, i]) for week in 2:num_weeks)*const_obj, digits=4), "% of weekly return")
    end
    println("Total Historical Average Weekly Return:",  objective_value(model),"%")
    println(optimal_allocation[index_parts])

    println("\n DUAL VARIABLES \n")
    println("Constraint on capital p:    ", dual(full_capital_constraint))
    # Dual values for sector allocation constraints
    for (sector, constraint) in sector_constraints
        println("constraint on sector ",sector ," q_", sector, ": ", dual(constraint))
    end
 
    println("\nSensitivity Analysis Report:")
    sensitivity_report = lp_sensitivity_report(model)
    
    function variable_report(xi) #source: https://jump.dev/JuMP.jl/stable/tutorials/linear/lp_sensitivity/
        return (
            name = name(xi),
            lower_bound = has_lower_bound(xi) ? lower_bound(xi) : -Inf,
            value = value(xi),
            upper_bound = has_upper_bound(xi) ? upper_bound(xi) : Inf,
            reduced_cost = reduced_cost(xi),
            obj_coefficient = coefficient(objective_function(model), xi),
            allowed_decrease = sensitivity_report[xi][1],
            allowed_increase = sensitivity_report[xi][2],
        )
        end

    variable_df = DataFrame(variable_report(xi) for xi in all_variables(model))
    basic = filter(row -> iszero(row.reduced_cost), variable_df)
    println(sensitivity_report[sector_constraints[6]])
    println(basic)
else
    println("No optimal solution found")
end