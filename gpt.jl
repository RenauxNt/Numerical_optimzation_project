using JuMP, GLPK, CSV, DataFrames

# Create a function to extract key information and put it into a DataFrame
function extract_sensitivity_report(report)
    # Create an empty DataFrame with suitable column names
    df = DataFrame(Constraint = String[], RHS = Float64[], Shadow_Price = Float64[], Allowable_Increase = Float64[], Allowable_Decrease = Float64[])
    
    for constraint_report in report
        # Extract relevant information
        constraint_name = constraint_report.name
        rhs = constraint_report.rhs
        shadow_price = constraint_report.shadow_price
        allowable_increase = constraint_report.allowable_increase
        allowable_decrease = constraint_report.allowable_decrease
        
        # Append row to DataFrame
        push!(df, (constraint_name, rhs, shadow_price, allowable_increase, allowable_decrease))
    end
    
    return df
end

# Create a new JuMP model with Gurobi as the solver
model = Model(GLPK.Optimizer)

# Load the CSV files
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

# Check if the solution is optimal
if termination_status(model) == MOI.OPTIMAL
    # Generate the sensitivity report
    sensitivity_report = lp_sensitivity_report(model)
    test = sensitivity_report[sector_constraints[6]]

    # Display the sensitivity report
    println("\nSensitivity Analysis Report:")
    println(test)

else
    println("No optimal solution found.")
end
