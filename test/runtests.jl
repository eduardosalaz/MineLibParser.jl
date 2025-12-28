using MineLibParser
using Test

# Sample test data
const SAMPLE_PRECEDENCE_DATA = """
% Sample precedence file
0 0
1 1 0
2 1 0
3 2 1 2
4 3 1 2 3
"""

const SAMPLE_UPIT_DATA = """
% Sample UPIT file
NAME: test_instance
TYPE: UPIT
NBLOCKS: 5
OBJECTIVE_FUNCTION:
0 -100.0
1 50.0
2 75.0
3 200.0
4 -25.0
EOF
"""

const SAMPLE_CPIT_DATA = """
% Sample CPIT file
NAME: test_cpit
TYPE: CPIT
NBLOCKS: 5
NPERIODS: 3
NRESOURCE SIDE CONSTRAINTS: 2
DISCOUNT RATE: 0.1
OBJECTIVE_FUNCTION:
0 -100.0
1 50.0
2 75.0
3 200.0
4 -25.0
RESOURCE CONSTRAINT LIMITS:
0 0 L 1000.0
0 1 L 1000.0
0 2 L 1000.0
1 0 I 0.0 500.0
1 1 I 0.0 500.0
1 2 I 0.0 500.0
RESOURCE CONSTRAINT COEFFICIENTS:
0 0 10.0
0 1 5.0
1 0 8.0
1 1 4.0
2 0 12.0
2 1 6.0
3 0 15.0
3 1 7.0
4 0 9.0
4 1 3.0
EOF
"""

const SAMPLE_PCPSP_DATA = """
% Sample PCPSP file
NAME: test_pcpsp
TYPE: PCPSP
NBLOCKS: 3
NPERIODS: 2
NDESTINATIONS: 2
NRESOURCE SIDE CONSTRAINTS: 1
NGENERAL SIDE CONSTRAINTS: 0
DISCOUNT RATE: 0.1
OBJECTIVE_FUNCTION:
0 -50.0 -100.0
1 100.0 25.0
2 150.0 50.0
RESOURCE CONSTRAINT LIMITS:
0 0 L 500.0
0 1 L 500.0
RESOURCE CONSTRAINT COEFFICIENTS:
0 0 0 10.0
0 1 0 10.0
1 0 0 15.0
1 1 0 15.0
2 0 0 20.0
2 1 0 20.0
EOF
"""

const SAMPLE_BLOCK_MODEL_DATA = """
% Sample block model
0 0 0 0 1000.0 0.5
1 1 0 0 1200.0 0.8
2 0 1 0 950.0 0.3
3 1 1 0 1100.0 1.2
4 0 0 1 1050.0 0.6
"""

@testset "MineLibParser.jl" begin
    
    @testset "Parse Precedences" begin
        prec = parse_precedences(IOBuffer(SAMPLE_PRECEDENCE_DATA))
        
        @test prec.num_blocks == 5
        @test get_predecessors(prec, 0) == Int[]
        @test get_predecessors(prec, 1) == [0]
        @test get_predecessors(prec, 2) == [0]
        @test get_predecessors(prec, 3) == [1, 2]
        @test get_predecessors(prec, 4) == [1, 2, 3]
        
        # Test arc counting: 0 + 1 + 1 + 2 + 3 = 7
        @test num_precedence_arcs(prec) == 7
        
        # Test nonexistent block returns empty
        @test get_predecessors(prec, 999) == Int[]
    end
    
    @testset "Parse UPIT" begin
        data = parse_upit(IOBuffer(SAMPLE_UPIT_DATA))
        
        @test data.name == "test_instance"
        @test data.num_blocks == 5
        @test data.objective[0] == -100.0
        @test data.objective[1] == 50.0
        @test data.objective[3] == 200.0
        
        # Test value calculations
        # Positive: 50 + 75 + 200 = 325
        @test total_positive_value(data) == 325.0
        # Negative: -100 + -25 = -125
        @test total_negative_value(data) == -125.0
    end
    
    @testset "Parse UPIT with Precedences" begin
        prec = parse_precedences(IOBuffer(SAMPLE_PRECEDENCE_DATA))
        data = parse_upit(IOBuffer(SAMPLE_UPIT_DATA); precedences=prec)
        
        @test !isnothing(data.precedences)
        @test data.precedences.num_blocks == 5
        @test get_predecessors(data.precedences, 4) == [1, 2, 3]
    end
    
    @testset "Parse CPIT" begin
        data = parse_cpit(IOBuffer(SAMPLE_CPIT_DATA))
        
        @test data.name == "test_cpit"
        @test data.num_blocks == 5
        @test data.num_periods == 3
        @test data.num_resources == 2
        @test data.discount_rate == 0.1
        
        # Test objective
        @test data.objective[0] == -100.0
        @test data.objective[3] == 200.0
        
        # Test resource limits
        # Resource 0 has upper bound only (L type)
        @test data.resource_limits.lower_bounds[0][0] == -Inf
        @test data.resource_limits.upper_bounds[0][0] == 1000.0
        
        # Resource 1 has interval (I type)
        @test data.resource_limits.lower_bounds[1][0] == 0.0
        @test data.resource_limits.upper_bounds[1][0] == 500.0
        
        # Test resource coefficients
        @test data.resource_coefficients[0][0] == 10.0
        @test data.resource_coefficients[0][1] == 5.0
        @test data.resource_coefficients[3][0] == 15.0
        
        # Test getter method
        @test get_resource_coefficient(data, 0, 0) == 10.0
        @test get_resource_coefficient(data, 999, 0) == 0.0  # Nonexistent
        
        # Test discounted profit
        # Block 3 has profit 200.0, discount rate 0.1
        @test get_discounted_profit(data, 3, 0) ≈ 200.0
        @test get_discounted_profit(data, 3, 1) ≈ 200.0 / 1.1
        @test get_discounted_profit(data, 3, 2) ≈ 200.0 / 1.21
    end
    
    @testset "Parse PCPSP" begin
        data = parse_pcpsp(IOBuffer(SAMPLE_PCPSP_DATA))
        
        @test data.name == "test_pcpsp"
        @test data.num_blocks == 3
        @test data.num_periods == 2
        @test data.num_destinations == 2
        @test data.num_resources == 1
        @test data.num_general_constraints == 0
        @test data.discount_rate == 0.1
        
        # Test objective by destination
        # Block 1: destination 0 = 100, destination 1 = 25
        @test data.objective[1][0] == 100.0
        @test data.objective[1][1] == 25.0
        
        # Test 3D resource coefficients [block][dest][resource]
        @test data.resource_coefficients[0][0][0] == 10.0
        @test data.resource_coefficients[1][0][0] == 15.0
        @test data.resource_coefficients[2][1][0] == 20.0
        
        # Test discounted profit by destination
        # Block 2, destination 0, period 1: 150 / 1.1
        @test get_discounted_profit(data, 2, 0, 1) ≈ 150.0 / 1.1
    end
    
    @testset "Parse Block Model" begin
        model = parse_block_model(
            IOBuffer(SAMPLE_BLOCK_MODEL_DATA);
            column_names=["tonnage", "grade"]
        )
        
        @test model.num_blocks == 5
        @test length(model.blocks) == 5
        
        # Test coordinates
        coords = get_coordinates(model, 0)
        @test coords == (0, 0, 0)
        
        coords = get_coordinates(model, 4)
        @test coords == (0, 0, 1)
        
        # Test attributes
        block = get_block(model, 1)
        @test !isnothing(block)
        @test block["tonnage"] == 1200.0
        @test block["grade"] == 0.8
        
        # Test nonexistent block
        @test isnothing(get_block(model, 999))
        @test isnothing(get_coordinates(model, 999))
    end
    
    @testset "ResourceLimits" begin
        limits = ResourceLimits()
        
        set_bounds!(limits, 0, 0; lower=0.0, upper=100.0)
        lb, ub = get_bounds(limits, 0, 0)
        @test lb == 0.0
        @test ub == 100.0
        
        # Test nonexistent returns infinities
        lb, ub = get_bounds(limits, 99, 99)
        @test lb == -Inf
        @test ub == Inf
    end
    
    @testset "Utility Functions" begin
        # Test parse_minelib_float
        @test MineLibParser.parse_minelib_float("3.14") == 3.14
        @test MineLibParser.parse_minelib_float("infinity") == Inf
        @test MineLibParser.parse_minelib_float("-inf") == -Inf
        @test MineLibParser.parse_minelib_float("  Infinity  ") == Inf
        
        # Test is_comment_or_empty
        @test MineLibParser.is_comment_or_empty("")
        @test MineLibParser.is_comment_or_empty("  ")
        @test MineLibParser.is_comment_or_empty("% comment")
        @test !MineLibParser.is_comment_or_empty("data")
        
        # Test parse_key_value
        kv = MineLibParser.parse_key_value("NAME: test")
        @test kv == ("NAME", "test")
        
        kv = MineLibParser.parse_key_value("DISCOUNT RATE: 0.1")
        @test kv == ("DISCOUNT_RATE", "0.1")
        
        @test isnothing(MineLibParser.parse_key_value("no colon here"))
    end
    
end
