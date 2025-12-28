"""
Parsers for MineLib file formats.

This module provides parsers for the three MineLib file types:
- Block-Model Descriptor Files (.blocks)
- Block-Precedence Descriptor Files (.prec)
- Optimization-Model Descriptor Files (.upit, .cpit, .pcpsp)

# Example
```julia
using MineLibParser

prec = parse_precedences("instance.prec")
data = parse_upit("instance.upit"; precedences=prec)
println("Blocks: \$(data.num_blocks), Value: \$(total_positive_value(data))")
```
"""

# ============================================================================
# Block Model Parser
# ============================================================================

"""
    parse_block_model(source; column_names=nothing) -> BlockModel

Parse a MineLib block-model descriptor file.

# Arguments
- `source`: File path (String) or IO stream
- `column_names`: Names for columns beyond x, y, z (e.g., ["tonnage", "grade"]).
  If nothing, columns are named "attr_1", "attr_2", etc.

# File format
```
<id> <x> <y> <z> [<attr1> <attr2> ...]
```

# Example
```julia
model = parse_block_model("mine.blocks"; column_names=["tonnage", "cu_grade"])
block = get_block(model, 0)
println(block["tonnage"], " ", block["cu_grade"])
```
"""
function parse_block_model(source::Union{String,IO}; 
                           column_names::Union{Vector{String},Nothing}=nothing)::BlockModel
    model = BlockModel()
    
    process_io(source) do io
        line_num = 0
        for line in eachline(io)
            line_num += 1
            stripped = strip(line)
            is_comment_or_empty(stripped) && continue
            
            parts = split(stripped)
            if length(parts) < 4
                error("Line $line_num: Block line requires at least 4 fields (id, x, y, z), got $(length(parts))")
            end
            
            block_id = parse(Int, parts[1])
            x, y, z = parse(Int, parts[2]), parse(Int, parts[3]), parse(Int, parts[4])
            
            block_data = Dict{String,Any}(
                "x" => x,
                "y" => y,
                "z" => z
            )
            
            # Parse additional attributes
            for (i, val) in enumerate(parts[5:end])
                col_name = if !isnothing(column_names) && i <= length(column_names)
                    column_names[i]
                else
                    "attr_$i"
                end
                
                # Try to parse as number
                block_data[col_name] = try
                    parse_minelib_float(val)
                catch
                    val
                end
            end
            
            model.blocks[block_id] = block_data
            model.num_blocks = max(model.num_blocks, block_id + 1)
        end
    end
    
    model
end

# ============================================================================
# Precedences Parser
# ============================================================================

"""
    parse_precedences(source) -> Precedences

Parse a MineLib block-precedence descriptor file.

# Arguments
- `source`: File path (String) or IO stream

# File format
```
<block_id> <num_predecessors> <pred_1> <pred_2> ...
```

# Example
```julia
prec = parse_precedences("instance.prec")
println("Block 10 requires: ", get_predecessors(prec, 10))
```
"""
function parse_precedences(source::Union{String,IO})::Precedences
    predecessors = Dict{Int,Vector{Int}}()
    num_blocks = 0
    
    process_io(source) do io
        line_num = 0
        for line in eachline(io)
            line_num += 1
            stripped = strip(line)
            is_comment_or_empty(stripped) && continue
            
            parts = split(stripped)
            if length(parts) < 2
                error("Line $line_num: Precedence line requires at least 2 fields, got $(length(parts))")
            end
            
            block_id = parse(Int, parts[1])
            num_preds = parse(Int, parts[2])
            
            if length(parts) < 2 + num_preds
                error("Line $line_num: Expected $num_preds predecessors but only $(length(parts) - 2) provided")
            end
            
            preds = [parse(Int, parts[i]) for i in 3:(2 + num_preds)]
            predecessors[block_id] = preds
            num_blocks = max(num_blocks, block_id + 1)
        end
    end
    
    Precedences(num_blocks, predecessors)
end

# ============================================================================
# UPIT Parser
# ============================================================================

"""
    parse_upit(source; precedences=nothing) -> UPITData

Parse a UPIT optimization file.

# Arguments
- `source`: File path (String) or IO stream for the .upit file
- `precedences`: Optional Precedences object or file path/IO for precedence data

# Example
```julia
data = parse_upit("newman1.upit"; precedences="newman1.prec")
println("Optimal pit value upper bound: ", total_positive_value(data))
```
"""
function parse_upit(source::Union{String,IO};
                    precedences::Union{String,IO,Precedences,Nothing}=nothing)::UPITData
    data = UPITData()
    
    process_io(source) do io
        while !eof(io)
            line = readline(io)
            stripped = strip(line)
            is_comment_or_empty(stripped) && continue
            
            kv = parse_key_value(stripped)
            isnothing(kv) && continue
            key, value = kv
            
            if key == "NAME"
                data.name = value
            elseif key == "NBLOCKS"
                data.num_blocks = parse(Int, value)
            elseif key == "OBJECTIVE_FUNCTION"
                for _ in 1:data.num_blocks
                    obj_line = read_next_data_line(io)
                    isnothing(obj_line) && error("Unexpected EOF while reading objective function")
                    parts = split(obj_line)
                    block_id = parse(Int, parts[1])
                    data.objective[block_id] = parse_minelib_float(parts[2])
                end
            end
        end
    end
    
    # Handle precedences
    data.precedences = resolve_precedences(precedences)
    
    data
end

# ============================================================================
# CPIT Parser
# ============================================================================

"""
    parse_cpit(source; precedences=nothing) -> CPITData

Parse a CPIT optimization file.

# Arguments
- `source`: File path (String) or IO stream for the .cpit file
- `precedences`: Optional Precedences object or file path/IO for precedence data

# Example
```julia
data = parse_cpit("newman1.cpit"; precedences="newman1.prec")
println("Periods: ", data.num_periods, ", Resources: ", data.num_resources)
```
"""
function parse_cpit(source::Union{String,IO};
                    precedences::Union{String,IO,Precedences,Nothing}=nothing)::CPITData
    data = CPITData()
    
    process_io(source) do io
        while !eof(io)
            line = readline(io)
            stripped = strip(line)
            is_comment_or_empty(stripped) && continue
            
            kv = parse_key_value(stripped)
            isnothing(kv) && continue
            key, value = kv
            
            if key == "NAME"
                data.name = value
            elseif key == "NBLOCKS"
                data.num_blocks = parse(Int, value)
            elseif key == "NPERIODS"
                data.num_periods = parse(Int, value)
            elseif key == "NRESOURCE_SIDE_CONSTRAINTS"
                data.num_resources = parse(Int, value)
            elseif key == "DISCOUNT_RATE"
                data.discount_rate = parse_minelib_float(value)
            elseif key == "OBJECTIVE_FUNCTION"
                for _ in 1:data.num_blocks
                    obj_line = read_next_data_line(io)
                    isnothing(obj_line) && error("Unexpected EOF while reading objective function")
                    parts = split(obj_line)
                    data.objective[parse(Int, parts[1])] = parse_minelib_float(parts[2])
                end
            elseif key == "RESOURCE_CONSTRAINT_LIMITS"
                parse_resource_limits_cpit!(data, io)
            elseif key == "RESOURCE_CONSTRAINT_COEFFICIENTS"
                parse_resource_coefficients_cpit!(data, io)
            end
        end
    end
    
    data.precedences = resolve_precedences(precedences)
    data
end

function parse_resource_limits_cpit!(data::CPITData, io::IO)
    for r in 0:(data.num_resources - 1)
        data.resource_limits.lower_bounds[r] = Dict{Int,Float64}()
        data.resource_limits.upper_bounds[r] = Dict{Int,Float64}()
    end
    
    for _ in 1:(data.num_resources * data.num_periods)
        lim_line = read_next_data_line(io)
        isnothing(lim_line) && error("Unexpected EOF while reading resource limits")
        parts = split(lim_line)
        r, t, ctype = parse(Int, parts[1]), parse(Int, parts[2]), uppercase(parts[3])
        
        if ctype == "L"
            data.resource_limits.lower_bounds[r][t] = -Inf
            data.resource_limits.upper_bounds[r][t] = parse_minelib_float(parts[4])
        elseif ctype == "G"
            data.resource_limits.lower_bounds[r][t] = parse_minelib_float(parts[4])
            data.resource_limits.upper_bounds[r][t] = Inf
        elseif ctype == "I"
            data.resource_limits.lower_bounds[r][t] = parse_minelib_float(parts[4])
            data.resource_limits.upper_bounds[r][t] = parse_minelib_float(parts[5])
        end
    end
end

function parse_resource_coefficients_cpit!(data::CPITData, io::IO)
    while !eof(io)
        coef_line = readline(io)
        stripped = strip(coef_line)
        is_comment_or_empty(stripped) && continue
        uppercase(stripped) == "EOF" && break
        
        parts = split(stripped)
        length(parts) < 3 && break
        
        block_id, resource_id = parse(Int, parts[1]), parse(Int, parts[2])
        coef_value = parse_minelib_float(parts[3])
        
        if !haskey(data.resource_coefficients, block_id)
            data.resource_coefficients[block_id] = Dict{Int,Float64}()
        end
        data.resource_coefficients[block_id][resource_id] = coef_value
    end
end

# ============================================================================
# PCPSP Parser
# ============================================================================

"""
    parse_pcpsp(source; precedences=nothing) -> PCPSPData

Parse a PCPSP optimization file.

# Arguments
- `source`: File path (String) or IO stream for the .pcpsp file
- `precedences`: Optional Precedences object or file path/IO for precedence data

# Example
```julia
data = parse_pcpsp("newman1.pcpsp"; precedences="newman1.prec")
println("Destinations: ", data.num_destinations)
```
"""
function parse_pcpsp(source::Union{String,IO};
                     precedences::Union{String,IO,Precedences,Nothing}=nothing)::PCPSPData
    data = PCPSPData()
    
    process_io(source) do io
        while !eof(io)
            line = readline(io)
            stripped = strip(line)
            is_comment_or_empty(stripped) && continue
            
            kv = parse_key_value(stripped)
            isnothing(kv) && continue
            key, value = kv
            
            if key == "NAME"
                data.name = value
            elseif key == "NBLOCKS"
                data.num_blocks = parse(Int, value)
            elseif key == "NPERIODS"
                data.num_periods = parse(Int, value)
            elseif key == "NDESTINATIONS"
                data.num_destinations = parse(Int, value)
            elseif key == "NRESOURCE_SIDE_CONSTRAINTS"
                data.num_resources = parse(Int, value)
            elseif key == "NGENERAL_SIDE_CONSTRAINTS"
                data.num_general_constraints = parse(Int, value)
            elseif key == "DISCOUNT_RATE"
                data.discount_rate = parse_minelib_float(value)
            elseif key == "OBJECTIVE_FUNCTION"
                parse_objective_pcpsp!(data, io)
            elseif key == "RESOURCE_CONSTRAINT_LIMITS"
                parse_resource_limits_pcpsp!(data, io)
            elseif key == "RESOURCE_CONSTRAINT_COEFFICIENTS"
                parse_resource_coefficients_pcpsp!(data, io)
            elseif key == "GENERAL_CONSTRAINT_COEFFICIENTS"
                parse_general_coefficients_pcpsp!(data, io)
            elseif key == "GENERAL_CONSTRAINT_LIMITS"
                parse_general_limits_pcpsp!(data, io)
            end
        end
    end
    
    data.precedences = resolve_precedences(precedences)
    data
end

function parse_objective_pcpsp!(data::PCPSPData, io::IO)
    for _ in 1:data.num_blocks
        obj_line = read_next_data_line(io)
        isnothing(obj_line) && error("Unexpected EOF while reading objective function")
        parts = split(obj_line)
        block_id = parse(Int, parts[1])
        data.objective[block_id] = Dict{Int,Float64}()
        for d in 0:(data.num_destinations - 1)
            data.objective[block_id][d] = parse_minelib_float(parts[2 + d])
        end
    end
end

function parse_resource_limits_pcpsp!(data::PCPSPData, io::IO)
    for r in 0:(data.num_resources - 1)
        data.resource_limits.lower_bounds[r] = Dict{Int,Float64}()
        data.resource_limits.upper_bounds[r] = Dict{Int,Float64}()
    end
    
    for _ in 1:(data.num_resources * data.num_periods)
        lim_line = read_next_data_line(io)
        isnothing(lim_line) && error("Unexpected EOF while reading resource limits")
        parts = split(lim_line)
        r, t, ctype = parse(Int, parts[1]), parse(Int, parts[2]), uppercase(parts[3])
        
        if ctype == "L"
            data.resource_limits.lower_bounds[r][t] = -Inf
            data.resource_limits.upper_bounds[r][t] = parse_minelib_float(parts[4])
        elseif ctype == "G"
            data.resource_limits.lower_bounds[r][t] = parse_minelib_float(parts[4])
            data.resource_limits.upper_bounds[r][t] = Inf
        elseif ctype == "I"
            data.resource_limits.lower_bounds[r][t] = parse_minelib_float(parts[4])
            data.resource_limits.upper_bounds[r][t] = parse_minelib_float(parts[5])
        end
    end
end

function parse_resource_coefficients_pcpsp!(data::PCPSPData, io::IO)
    while !eof(io)
        coef_line = readline(io)
        stripped = strip(coef_line)
        is_comment_or_empty(stripped) && continue
        uppercase(stripped) == "EOF" && break
        occursin(':', stripped) && break  # New section
        
        parts = split(stripped)
        length(parts) < 4 && break
        
        block_id = parse(Int, parts[1])
        dest_id = parse(Int, parts[2])
        resource_id = parse(Int, parts[3])
        coef_value = parse_minelib_float(parts[4])
        
        if !haskey(data.resource_coefficients, block_id)
            data.resource_coefficients[block_id] = Dict{Int,Dict{Int,Float64}}()
        end
        if !haskey(data.resource_coefficients[block_id], dest_id)
            data.resource_coefficients[block_id][dest_id] = Dict{Int,Float64}()
        end
        data.resource_coefficients[block_id][dest_id][resource_id] = coef_value
    end
end

function parse_general_coefficients_pcpsp!(data::PCPSPData, io::IO)
    while !eof(io)
        coef_line = readline(io)
        stripped = strip(coef_line)
        is_comment_or_empty(stripped) && continue
        uppercase(stripped) == "EOF" && break
        occursin(':', stripped) && break
        
        parts = split(stripped)
        length(parts) < 5 && break
        
        block_id = parse(Int, parts[1])
        dest_id = parse(Int, parts[2])
        period = parse(Int, parts[3])
        row = parse(Int, parts[4])
        coef_value = parse_minelib_float(parts[5])
        
        # Initialize nested dicts as needed
        if !haskey(data.general_coefficients, block_id)
            data.general_coefficients[block_id] = Dict{Int,Dict{Int,Dict{Int,Float64}}}()
        end
        if !haskey(data.general_coefficients[block_id], dest_id)
            data.general_coefficients[block_id][dest_id] = Dict{Int,Dict{Int,Float64}}()
        end
        if !haskey(data.general_coefficients[block_id][dest_id], period)
            data.general_coefficients[block_id][dest_id][period] = Dict{Int,Float64}()
        end
        data.general_coefficients[block_id][dest_id][period][row] = coef_value
    end
end

function parse_general_limits_pcpsp!(data::PCPSPData, io::IO)
    for _ in 1:data.num_general_constraints
        lim_line = read_next_data_line(io)
        isnothing(lim_line) && error("Unexpected EOF while reading general constraint limits")
        parts = split(lim_line)
        row, ctype = parse(Int, parts[1]), uppercase(parts[2])
        
        if ctype == "L"
            data.general_limits[row] = (-Inf, parse_minelib_float(parts[3]))
        elseif ctype == "G"
            data.general_limits[row] = (parse_minelib_float(parts[3]), Inf)
        elseif ctype == "I"
            data.general_limits[row] = (parse_minelib_float(parts[3]), parse_minelib_float(parts[4]))
        end
    end
end

# ============================================================================
# Helper Functions
# ============================================================================

"""
Process a source (file path or IO) with a function.
"""
function process_io(f::Function, source::String)
    open(source, "r") do io
        f(io)
    end
end

function process_io(f::Function, io::IO)
    f(io)
end

"""
Resolve precedences from various input types.
"""
function resolve_precedences(prec::Nothing)::Nothing
    nothing
end

function resolve_precedences(prec::Precedences)::Precedences
    prec
end

function resolve_precedences(prec::Union{String,IO})::Precedences
    parse_precedences(prec)
end

