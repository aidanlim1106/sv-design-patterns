/*

PROBLEM STATEMENT

You need to design a combinational module that takes three 
input buses of the same width and outputs a vector where each 
bit represents the majority value among the three inputs at that bit position.

Example test: 
WIDTH = 4
in0 = 4'b1100
in1 = 4'b1010
in2 = 4'b0110
out = 4'b1110
*/

module majority_voter #(
    parameter WIDTH = 8
)(
    input logic [WIDTH-1:0]      in0,
    input logic [WIDTH-1:0]      in1,
    input logic [WIDTH-1:0]      in2,
    output logic [WIDTH-1:0]     out
);

always_comb begin
    out = '0;
    for (int i = 0; i < WIDTH; i++) begin
        if ((in0[i] && in1[i])
        || (in0[i] && in2[i])
        || (in1[i] && in2[i])) begin
            out[i] = 1'b1;
        end
    end

    // assign out = (in0 & in1) | (in0 & in2) | (in1 & in2);
end

endmodule