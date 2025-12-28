"""
Utility functions for MineLib parsing.
"""

"""
    parse_minelib_float(value::AbstractString) -> Float64

Parse a float value, handling infinity representations.

# Examples
```julia
parse_minelib_float("3.14")      # 3.14
parse_minelib_float("infinity")  # Inf
parse_minelib_float("-inf")      # -Inf
```
"""
function parse_minelib_float(value::AbstractString)::Float64
    v = lowercase(strip(value))
    if v in ("infinity", "inf", "+infinity", "+inf")
        return Inf
    elseif v in ("-infinity", "-inf")
        return -Inf
    else
        return parse(Float64, v)
    end
end

"""
    is_comment_or_empty(line::AbstractString) -> Bool

Check if a line is a comment or empty.
"""
function is_comment_or_empty(line::AbstractString)::Bool
    stripped = strip(line)
    isempty(stripped) || startswith(stripped, '%')
end

"""
    parse_key_value(line::AbstractString) -> Union{Tuple{String,String}, Nothing}

Parse a "key: value" line. Returns nothing if not a key-value line.
"""
function parse_key_value(line::AbstractString)::Union{Tuple{String,String},Nothing}
    !occursin(':', line) && return nothing
    parts = split(line, ':', limit=2)
    key = uppercase(replace(strip(parts[1]), ' ' => '_'))
    value = strip(parts[2])
    (key, value)
end

"""
    read_next_data_line(io::IO) -> Union{String, Nothing}

Read the next non-comment, non-empty line from a stream.
Returns nothing if EOF reached.
"""
function read_next_data_line(io::IO)::Union{String,Nothing}
    while !eof(io)
        line = readline(io)
        stripped = strip(line)
        if !is_comment_or_empty(stripped)
            return stripped
        end
    end
    nothing
end
