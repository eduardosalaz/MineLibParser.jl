"""
    MineLibParser

A Julia library for parsing MineLib open pit mining optimization problem instances.

MineLib is a library of publicly available test problem instances for three
classical types of open pit mining problems:

- **UPIT** (Ultimate Pit Limit Problem): Maximum-weight closure problem,
  polynomial time solvable.
- **CPIT** (Constrained Pit Limit Problem): NPV maximization with resource
  constraints, NP-hard.
- **PCPSP** (Precedence Constrained Production Scheduling Problem): Variable
  cutoff grades with multiple destinations, NP-hard.

# Basic Usage
```julia
using MineLibParser

prec = parse_precedences("instance.prec")
data = parse_upit("instance.upit"; precedences=prec)
println("Blocks: ", data.num_blocks)
```

For more information on the MineLib library, see:
http://mansci.uai.cl/minelib

# References
Espinoza, D., Goycoolea, M., Moreno, E., & Newman, A. (2012).
MineLib: A Library of Open Pit Mining Problems.
Annals of Operations Research.
"""
module MineLibParser

# Include source files
include("types.jl")
include("utils.jl")
include("parsers.jl")

# Export types
export ProblemType, UPIT, CPIT, PCPSP
export BoundType, LESS_THAN, GREATER_THAN, INTERVAL
export Precedences
export ResourceLimits
export BlockModel
export UPITData
export CPITData
export PCPSPData

# Export type methods
export get_predecessors, num_precedence_arcs, blocks_with_predecessors
export get_bounds, set_bounds!
export get_block, get_coordinates
export total_positive_value, total_negative_value
export get_discounted_profit, get_resource_coefficient

# Export parsers
export parse_block_model
export parse_precedences
export parse_upit
export parse_cpit
export parse_pcpsp

end # module MineLibParser
