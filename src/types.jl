"""
Type definitions for MineLib data structures.

This module defines structs for representing the three main problem types
in the MineLib library: UPIT, CPIT, and PCPSP.
"""

# ============================================================================
# Enums
# ============================================================================

"""
    ProblemType

MineLib problem types.
"""
@enum ProblemType begin
    UPIT
    CPIT
    PCPSP
end

"""
    BoundType

Constraint bound types used in MineLib files.
"""
@enum BoundType begin
    LESS_THAN     # L: <= upper bound only
    GREATER_THAN  # G: >= lower bound only  
    INTERVAL      # I: lower <= x <= upper
end

# ============================================================================
# Precedences
# ============================================================================

"""
    Precedences

Block precedence relationships.

Represents the directed acyclic graph of precedence constraints where
each block may have multiple predecessor blocks that must be extracted
before it.

# Fields
- `num_blocks::Int`: Total number of blocks in the model
- `predecessors::Dict{Int,Vector{Int}}`: Mapping from block ID to predecessor block IDs

# Example
```julia
prec = Precedences(100, Dict(10 => [1, 2, 3]))
get_predecessors(prec, 10)  # Returns [1, 2, 3]
```
"""
struct Precedences
    num_blocks::Int
    predecessors::Dict{Int,Vector{Int}}
end

# Constructor with default empty predecessors
Precedences(num_blocks::Int) = Precedences(num_blocks, Dict{Int,Vector{Int}}())

"""
    get_predecessors(prec::Precedences, block_id::Int) -> Vector{Int}

Get predecessor blocks for a given block.
Returns empty vector if no predecessors exist.
"""
function get_predecessors(prec::Precedences, block_id::Int)::Vector{Int}
    get(prec.predecessors, block_id, Int[])
end

"""
    num_precedence_arcs(prec::Precedences) -> Int

Count total number of precedence arcs.
"""
function num_precedence_arcs(prec::Precedences)::Int
    sum(length(preds) for preds in values(prec.predecessors); init=0)
end

"""
    blocks_with_predecessors(prec::Precedences)

Iterator over blocks that have predecessors.
"""
function blocks_with_predecessors(prec::Precedences)
    (block_id for (block_id, preds) in prec.predecessors if !isempty(preds))
end

# ============================================================================
# Resource Limits
# ============================================================================

"""
    ResourceLimits

Resource constraint bounds by resource and time period.

# Fields
- `lower_bounds::Dict{Int,Dict{Int,Float64}}`: resource -> period -> lower bound
- `upper_bounds::Dict{Int,Dict{Int,Float64}}`: resource -> period -> upper bound

Use `-Inf` for no lower bound and `Inf` for no upper bound.
"""
struct ResourceLimits
    lower_bounds::Dict{Int,Dict{Int,Float64}}
    upper_bounds::Dict{Int,Dict{Int,Float64}}
end

ResourceLimits() = ResourceLimits(
    Dict{Int,Dict{Int,Float64}}(),
    Dict{Int,Dict{Int,Float64}}()
)

"""
    get_bounds(limits::ResourceLimits, resource::Int, period::Int) -> Tuple{Float64,Float64}

Get (lower, upper) bounds for a specific resource and period.
"""
function get_bounds(limits::ResourceLimits, resource::Int, period::Int)::Tuple{Float64,Float64}
    lower = get(get(limits.lower_bounds, resource, Dict{Int,Float64}()), period, -Inf)
    upper = get(get(limits.upper_bounds, resource, Dict{Int,Float64}()), period, Inf)
    (lower, upper)
end

"""
    set_bounds!(limits::ResourceLimits, resource::Int, period::Int; lower=-Inf, upper=Inf)

Set bounds for a specific resource and period.
"""
function set_bounds!(limits::ResourceLimits, resource::Int, period::Int;
                     lower::Float64=-Inf, upper::Float64=Inf)
    if !haskey(limits.lower_bounds, resource)
        limits.lower_bounds[resource] = Dict{Int,Float64}()
        limits.upper_bounds[resource] = Dict{Int,Float64}()
    end
    limits.lower_bounds[resource][period] = lower
    limits.upper_bounds[resource][period] = upper
    nothing
end

# ============================================================================
# Block Model
# ============================================================================

"""
    BlockModel

Geological block model data.

# Fields
- `num_blocks::Int`: Total number of blocks
- `blocks::Dict{Int,Dict{String,Any}}`: Block ID -> block data dict
"""
mutable struct BlockModel
    num_blocks::Int
    blocks::Dict{Int,Dict{String,Any}}
end

BlockModel() = BlockModel(0, Dict{Int,Dict{String,Any}}())

"""
    get_block(model::BlockModel, block_id::Int) -> Union{Dict{String,Any}, Nothing}

Get data for a specific block.
"""
function get_block(model::BlockModel, block_id::Int)::Union{Dict{String,Any},Nothing}
    get(model.blocks, block_id, nothing)
end

"""
    get_coordinates(model::BlockModel, block_id::Int) -> Union{Tuple{Int,Int,Int}, Nothing}

Get (x, y, z) coordinates for a block.
"""
function get_coordinates(model::BlockModel, block_id::Int)::Union{Tuple{Int,Int,Int},Nothing}
    block = get_block(model, block_id)
    isnothing(block) && return nothing
    (Int(block["x"]), Int(block["y"]), Int(block["z"]))
end

# ============================================================================
# UPIT Data
# ============================================================================

"""
    UPITData

Data for Ultimate Pit Limit Problem.

The UPIT problem determines the set of blocks to extract to maximize
value subject to precedence constraints. It is a maximum-weight closure
problem solvable in polynomial time.

# Fields
- `name::String`: Instance name
- `num_blocks::Int`: Number of blocks
- `objective::Dict{Int,Float64}`: Block ID -> profit value
- `precedences::Union{Precedences,Nothing}`: Block precedence relationships

# Mathematical formulation
```
max  Σ_b p_b * x_b
s.t. x_b ≤ x_{b'} for all b' ∈ predecessors(b)
     x_b ∈ {0, 1}
```
"""
mutable struct UPITData
    name::String
    num_blocks::Int
    objective::Dict{Int,Float64}
    precedences::Union{Precedences,Nothing}
end

UPITData() = UPITData("", 0, Dict{Int,Float64}(), nothing)

"""
    total_positive_value(data::UPITData) -> Float64

Sum of all positive block values.
"""
function total_positive_value(data::UPITData)::Float64
    sum(v for v in values(data.objective) if v > 0; init=0.0)
end

"""
    total_negative_value(data::UPITData) -> Float64

Sum of all negative block values (waste cost).
"""
function total_negative_value(data::UPITData)::Float64
    sum(v for v in values(data.objective) if v < 0; init=0.0)
end

# ============================================================================
# CPIT Data
# ============================================================================

"""
    CPITData

Data for Constrained Pit Limit Problem.

The CPIT problem extends UPIT by introducing time periods and resource
constraints. It maximizes discounted NPV subject to precedence and
operational resource constraints. This problem is NP-hard.

# Fields
- `name::String`: Instance name
- `num_blocks::Int`: Number of blocks
- `num_periods::Int`: Number of time periods
- `num_resources::Int`: Number of resource constraint types
- `discount_rate::Float64`: Rate for NPV calculation
- `objective::Dict{Int,Float64}`: Block ID -> undiscounted profit
- `resource_limits::ResourceLimits`: Resource bounds by period
- `resource_coefficients::Dict{Int,Dict{Int,Float64}}`: [block][resource] -> coefficient
- `precedences::Union{Precedences,Nothing}`: Block precedence relationships

# Note
The discounted profit for block b at time t is: p_bt = p_b / (1 + discount_rate)^t
"""
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

CPITData() = CPITData(
    "", 0, 0, 0, 0.0,
    Dict{Int,Float64}(),
    ResourceLimits(),
    Dict{Int,Dict{Int,Float64}}(),
    nothing
)

"""
    get_discounted_profit(data::CPITData, block::Int, period::Int) -> Float64

Calculate discounted profit for a block at a given period (0-indexed).
"""
function get_discounted_profit(data::CPITData, block::Int, period::Int)::Float64
    base_profit = get(data.objective, block, 0.0)
    base_profit / (1 + data.discount_rate)^period
end

"""
    get_resource_coefficient(data::CPITData, block::Int, resource::Int) -> Float64

Get resource consumption coefficient for a block. Returns 0.0 if not defined.
"""
function get_resource_coefficient(data::CPITData, block::Int, resource::Int)::Float64
    get(get(data.resource_coefficients, block, Dict{Int,Float64}()), resource, 0.0)
end

# ============================================================================
# PCPSP Data
# ============================================================================

"""
    PCPSPData

Data for Precedence Constrained Production Scheduling Problem.

PCPSP extends CPIT by allowing variable cutoff grades through multiple
destinations (e.g., processing plant vs waste dump). It determines both
when to extract each block and where to send it.

# Fields
- `name::String`: Instance name
- `num_blocks::Int`: Number of blocks
- `num_periods::Int`: Number of time periods
- `num_destinations::Int`: Number of processing destinations
- `num_resources::Int`: Number of resource constraint types
- `num_general_constraints::Int`: Number of general side constraints
- `discount_rate::Float64`: Rate for NPV calculation
- `objective::Dict{Int,Dict{Int,Float64}}`: [block][destination] -> profit
- `resource_limits::ResourceLimits`: Resource bounds by period
- `resource_coefficients::Dict{Int,Dict{Int,Dict{Int,Float64}}}`: [block][dest][resource]
- `general_coefficients::Dict{Int,Dict{Int,Dict{Int,Dict{Int,Float64}}}}`: General constraint coefficients
- `general_limits::Dict{Int,Tuple{Float64,Float64}}`: General constraint bounds by row
- `precedences::Union{Precedences,Nothing}`: Block precedence relationships
"""
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
    general_coefficients::Dict{Int,Dict{Int,Dict{Int,Dict{Int,Float64}}}}
    general_limits::Dict{Int,Tuple{Float64,Float64}}
    precedences::Union{Precedences,Nothing}
end

PCPSPData() = PCPSPData(
    "", 0, 0, 0, 0, 0, 0.0,
    Dict{Int,Dict{Int,Float64}}(),
    ResourceLimits(),
    Dict{Int,Dict{Int,Dict{Int,Float64}}}(),
    Dict{Int,Dict{Int,Dict{Int,Dict{Int,Float64}}}}(),
    Dict{Int,Tuple{Float64,Float64}}(),
    nothing
)

"""
    get_discounted_profit(data::PCPSPData, block::Int, destination::Int, period::Int) -> Float64

Calculate discounted profit for a block-destination-period combination.
"""
function get_discounted_profit(data::PCPSPData, block::Int, destination::Int, period::Int)::Float64
    base_profit = get(get(data.objective, block, Dict{Int,Float64}()), destination, 0.0)
    base_profit / (1 + data.discount_rate)^period
end

"""
    get_resource_coefficient(data::PCPSPData, block::Int, destination::Int, resource::Int) -> Float64

Get resource consumption coefficient. Returns 0.0 if not defined.
"""
function get_resource_coefficient(data::PCPSPData, block::Int, destination::Int, resource::Int)::Float64
    block_dict = get(data.resource_coefficients, block, nothing)
    isnothing(block_dict) && return 0.0
    dest_dict = get(block_dict, destination, nothing)
    isnothing(dest_dict) && return 0.0
    get(dest_dict, resource, 0.0)
end
