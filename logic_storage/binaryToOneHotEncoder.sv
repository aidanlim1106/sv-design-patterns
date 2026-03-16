/*
Problem Statement

Design a combinational SystemVerilog module that converts an N-bit binary input into a one-hot output vector of size 2^N.

That means exactly one bit in the output is 1, corresponding to the binary input’s value.

Example input: 
WIDTH = 3
in = 3'b101                 decimal 5

Example output:
out = 8'0001_0000
*/

module binaryToOneHot #(
    parameter WIDTH = 3
) (
    input logic [WIDTH-1:0]          in,
    output logic [(1<<WIDTH)-1:0]    out
);

always_comb begin
    out = '0;
    out = 1 << in;
end

endmodule

/*
Follow-up questions interviewers might ask

How would you decode one-hot back into binary?
    So a shift logical right by the same amount shifted left, but this doesn't work because 
How do you register the output (pipelined version)?
    
What happens if the input is wider than 8 bits — does synthesis handle it efficiently?
*/



