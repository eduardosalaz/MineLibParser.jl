# MineLibParser.jl

A Julia library for parsing [MineLib](http://mansci.uai.cl/minelib) open pit mining optimization problem instances.


[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

MineLib is a library of publicly available test problem instances for three classical types of open pit mining problems:

- **UPIT** (Ultimate Pit Limit Problem): Determines the optimal pit boundary to maximize undiscounted value. This is a maximum-weight closure problem, solvable in polynomial time.

- **CPIT** (Constrained Pit Limit Problem): Extends UPIT with time periods and resource constraints to maximize discounted NPV. This problem is NP-hard.

- **PCPSP** (Precedence Constrained Production Scheduling Problem): Further extends CPIT with variable cutoff grades and multiple destinations (e.g., processing plant vs. waste dump). Also NP-hard.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/eduardosalaz/MineLibParser.jl")
```

Or in the Pkg REPL:
```
pkg> add https://github.com/eduardosalaz/MineLibParser.jl
```

## Quick Start

### Parsing Local Files

```julia
using MineLibParser

# Parse precedence relationships
precedences = parse_precedences("instance.prec")

# Parse UPIT instance
upit_data = parse_upit("instance.upit"; precedences=precedences)
println("UPIT: $(upit_data.num_blocks) blocks")
println("Total positive value: $(total_positive_value(upit_data))")

# Parse CPIT instance
cpit_data = parse_cpit("instance.cpit"; precedences=precedences)
println("CPIT: $(cpit_data.num_periods) periods, $(cpit_data.num_resources) resources")

# Parse PCPSP instance
pcpsp_data = parse_pcpsp("instance.pcpsp"; precedences=precedences)
println("PCPSP: $(pcpsp_data.num_destinations) destinations")
```

### Working with Data

```julia
# Access block values
for (block_id, profit) in upit_data.objective
    println("Block $block_id: \$$profit")
end

# Access precedence relationships
for block_id in 0:(upit_data.num_blocks - 1)
    preds = get_predecessors(upit_data.precedences, block_id)
    if !isempty(preds)
        println("Block $block_id requires blocks $preds")
    end
end

# Calculate discounted profits for CPIT
for period in 0:(cpit_data.num_periods - 1)
    profit = get_discounted_profit(cpit_data, 0, period)
    println("Block 0, Period $period: \$$profit")
end

# Get resource bounds for CPIT
for r in 0:(cpit_data.num_resources - 1)
    for t in 0:(cpit_data.num_periods - 1)
        lb, ub = get_bounds(cpit_data.resource_limits, r, t)
        println("Resource $r, Period $t: [$lb, $ub]")
    end
end
```

## File Formats

### Block-Precedence Descriptor File (`.prec`)

```
% Comment line
<block_id> <num_predecessors> <pred_1> <pred_2> ...
```

Example:
```
0 0
1 1 0
2 1 0
3 2 1 2
```

### UPIT Optimization File (`.upit`)

```
NAME: instance_name
TYPE: UPIT
NBLOCKS: 100
OBJECTIVE_FUNCTION:
0 150.5
1 -25.0
...
EOF
```

### CPIT Optimization File (`.cpit`)

```
NAME: instance_name
TYPE: CPIT
NBLOCKS: 100
NPERIODS: 10
NRESOURCE SIDE CONSTRAINTS: 2
DISCOUNT RATE: 0.10
OBJECTIVE_FUNCTION:
...
RESOURCE CONSTRAINT LIMITS:
...
RESOURCE CONSTRAINT COEFFICIENTS:
...
EOF
```

### PCPSP Optimization File (`.pcpsp`)

```
NAME: instance_name
TYPE: PCPSP
NBLOCKS: 100
NPERIODS: 10
NDESTINATIONS: 2
NRESOURCE SIDE CONSTRAINTS: 2
NGENERAL SIDE CONSTRAINTS: 0
DISCOUNT RATE: 0.10
OBJECTIVE_FUNCTION:
...
RESOURCE CONSTRAINT LIMITS:
...
RESOURCE CONSTRAINT COEFFICIENTS:
...
EOF
```

## Types

### Precedences

```julia
struct Precedences
    num_blocks::Int
    predecessors::Dict{Int,Vector{Int}}
end

# Methods
get_predecessors(prec, block_id) -> Vector{Int}
num_precedence_arcs(prec) -> Int
blocks_with_predecessors(prec) -> Iterator
```

### UPITData

```julia
mutable struct UPITData
    name::String
    num_blocks::Int
    objective::Dict{Int,Float64}
    precedences::Union{Precedences,Nothing}
end

# Methods
total_positive_value(data) -> Float64
total_negative_value(data) -> Float64
```

### CPITData

```julia
mutable struct CPITData
    name::String
    num_blocks::Int
    num_periods::Int
    num_resources::Int
    discount_rate::Float64
    objective::Dict{Int,Float64}
    resource_limits::ResourceLimits
    resource_coefficients::Dict{Int,Dict{Int,Float64}}
    precedences::Union{Precedences,Nothing}
end

# Methods
get_discounted_profit(data, block, period) -> Float64
get_resource_coefficient(data, block, resource) -> Float64
```

### PCPSPData

```julia
mutable struct PCPSPData
    name::String
    num_blocks::Int
    num_periods::Int
    num_destinations::Int
    num_resources::Int
    num_general_constraints::Int
    discount_rate::Float64
    objective::Dict{Int,Dict{Int,Float64}}
    resource_limits::ResourceLimits
    resource_coefficients::Dict{Int,Dict{Int,Dict{Int,Float64}}}
    general_coefficients::Dict{...}
    general_limits::Dict{Int,Tuple{Float64,Float64}}
    precedences::Union{Precedences,Nothing}
end

# Methods
get_discounted_profit(data, block, destination, period) -> Float64
get_resource_coefficient(data, block, destination, resource) -> Float64
```

## Integration with JuMP

MineLibParser.jl works seamlessly with [JuMP](https://jump.dev/) for optimization:

```julia
using MineLibParser
using JuMP
using HiGHS

# Load instance
prec = parse_precedences("instance.prec")
data = parse_upit("instance.upit"; precedences=prec)

# Build model
model = Model(HiGHS.Optimizer)

B = 0:(data.num_blocks - 1)
@variable(model, x[B], Bin)

@objective(model, Max, sum(data.objective[b] * x[b] for b in B))

for b in B
    for p in get_predecessors(data.precedences, b)
        @constraint(model, x[b] <= x[p])
    end
end

optimize!(model)
println("Optimal value: ", objective_value(model))
```

## References

Espinoza, D., Goycoolea, M., Moreno, E., & Newman, A. (2012). MineLib: A Library of Open Pit Mining Problems. *Annals of Operations Research*.

## License

MIT License - see [LICENSE](LICENSE) for details.
