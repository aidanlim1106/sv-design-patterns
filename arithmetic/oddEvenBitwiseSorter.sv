/*

Problem Statement

You are tasked with designing a simple RTL module that sorts the bits of an input vector. Specifically:
All 1s should be shifted to the odd positions (1, 3, 5, …) of the output.
All 0s should be shifted to the even positions (0, 2, 4, …).
The relative order of 1s and 0s must be preserved as they appear in the input.
Indexing is 0-based from the LSB.

*/

module odd_even_sorter #(
    parameter WIDTH = 8
)(
    input logic [WIDTH-1:0]     in,
    output logic [WIDTH-1:0]    out
);

always_comb begin
    out = '0;
    int next_even = 0;
    int next_odd = 1;

    for (int i = 0; i < WIDTH; i++) begin
        if (in[i]) begin
            if (next_odd < WIDTH) begin
                out[next_odd] = 1'b1;
                next_odd += 2;
            end
        end else begin
            if (next_even < WIDTH) begin
                out[next_even] = 1'b0;
                next_even += 2;
            end
        end
    end
end

endmodule




