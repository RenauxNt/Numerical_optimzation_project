using JuMP, GLPK, CSV, DataFrames

# Create a new JuMP model with Gurobi as the solver
model = Model(GLPK.Optimizer)

#Loadings the CSV files
stocks = CSV.read("data.csv", DataFrame)
sectors = CSV.read("sector_mapping.csv", DataFrame, header=false)

#Setting the parameters
num_weeks = nrow(stocks)
num_stocks = nrow(sectors)
num_sectors = unique(sectors[:,2])
capital_intial = 500000

# Variables
c1 = @variable(model, parts[1:num_stocks] >= 0)
#@variable(model, returns[1:num_stocks, new_weeks])

# Constraints
full_capital_constraint= @constraint(model, 0 <= sum(parts[i] for i in 1:num_stocks) <= 1)

sector_constraints = Dict()
for num_sector in num_sectors
    sector_i = findall(sectors[:,2] .== num_sector)
    sector_constraints[num_sector] =@constraint(model, sum(parts[i] for i in sector_i) <= 0.2)
end

# Objective: maximize historical average weekly return.
# We do not put the normalization factor in the objective function because it does not affect the optimal solution.
@objective(model, Max, sum(((stocks[week, i]-stocks[week-1, i])/stocks[week-1, i])*parts[i] for i in 1:num_stocks, week in 2:num_weeks)/(num_weeks-1)*100)

# Solve the model
optimize!(model)

if termination_status(model) == MOI.OPTIMAL
    println("\nSensitivity Analysis for Sector Limit Change: \n")
    report = lp_sensitivity_report(model)
    println(report)

    optimal_allocation = value.(parts)
    index_parts = findall(optimal_allocation[:] .!= 0)
    total_return = objective_value(model)
    println("Optimal Portfolio Allocation:")
    for i in index_parts
        println(names(stocks)[i]," from secotr ", sectors[i,2] ," with ", (100000/stocks[1, i]), " shares and ", 
                optimal_allocation[i]*100 ,"% of the capital invest and ", 
                sum(((stocks[week, i]-stocks[week-1, i])/stocks[week-1, i]) for week in 2:num_weeks)/(num_weeks-1)*100, "% of weekly return")
    end
    println("Total Historical Average Weekly Return:",  sum(((stocks[week, i]-stocks[week-1, i])/stocks[week-1, i]) for week in 2:num_weeks, i in index_parts)/(num_weeks-1)*100,"%")
    println(total_return*5)
    println(optimal_allocation[index_parts])
    
    # step = 0.01
    # N = 100
    # local limit_up_bound = 0
    # local limit_low_bound = 0
    # sector_six = findall(sectors[:,2] .== 6)
    # local sector_index = 6

    # println("Positive delta l6")
    # for i in 1:N
    #     if(0.2 + i * step > 1)
    #         break
    #     end

    #     delete(model, sector_constraints[sector_index])
    #     sector_constraints[sector_index] = @constraint(model, sum(parts[i] for i in sector_six) <= 0.2 + i * step) #selecting 6th constraint
    #     optimize!(model)

    #     println("q_5: ", dual(sector_constraints[sector_index])) #when dual becomes 0, the constraint is not binding anymore, it has to be greater than 0 in order to bind
    #     println("Actual upper bound: ", 0.2 + i * step)

    #     if(dual(sector_constraints[sector_index]) == 0)
    #         println("The constraint is not binding anymore, the upper bound is: ", limit_up_bound)
    #         limit_up_bound = 0.2 + i * step
    #     end
    # end

    # println("\n Negative delta l6")
    # for i in 1:N
    #     if(0.2 - i * step < 0)
    #         break
    #     end

    #     delete(model, sector_constraints[sector_index])
    #     sector_constraints[sector_index] = @constraint(model, sum(parts[i] for i in sector_six) <= 0.2 - i * step) #selecting 6th constraint
    #     optimize!(model)

    #     println("q_5: ", dual(sector_constraints[sector_index]))
    #     println("Actual lower bound: ", 0.2 - i * step)

    #     if(dual(sector_constraints[sector_index]) == 0)
    #         println("The constraint is not binding anymore, the lower bound is: ", limit_low_bound)
    #         limit_low_bound = 0.2 - i * step
    #     end
    # end

    # println("The range of the sector limit is: [", limit_low_bound, ", ", limit_up_bound, "]")
    # #if we are out of this range the new optimal solution will be different
    # sector_constraints[sector_index] = @constraint(model, sum(parts[i] for i in sector_six) <= limit_up_bound + 0.01) 
    # optimize!(model)
    # println("q_5: ", dual(sector_constraints[sector_index]))
    # println("The constraint is not binding anymore, the upper bound is: ", limit_up_bound + 0.01)
    # println("The new optimal solution is: ", value.(parts))
    # println("The new total return is: ", objective_value(model))

    # sector_constraints[sector_index] = @constraint(model, sum(parts[i] for i in sector_six) <= limit_low_bound - 0.01)
    # optimize!(model)
    # println("q_5: ", dual(sector_constraints[sector_index]))
    # println("The constraint is not binding anymore, the lower bound is: ", limit_low_bound - 0.01)
    # println("The new optimal solution is: ", value.(parts))
    # println("The new total return is: ", objective_value(model))

else
    println("No optimal solution found")
end