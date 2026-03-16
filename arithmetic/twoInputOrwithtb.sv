module twoInputOr #(
    parameter WIDTH = 4
)(
    input logic [WIDTH-1:0]  in1,
    input logic [WIDTH-1:0]  in2,
    output logic [WIDTH-1:0] out
);

always_comb begin
    out = in1 | in2;
end

endmodule

// testbench below

module tb_twoInputOr;
    // 1. Signal declaration
    logic [WIDTH-1:0] in1, in2;
    logic [WIDTH-1:0] out;
    // 2. DUT instantiation
    twoInputOr dut (
        .in1(in1),
        .in2(in2),
        .out(out)
    );
    // 3. Stimulus generation
    initial begin
        $display("Time\t in1 in2 | out");
        $monitor("%4t\t%b     %b | %b", $time, in1, in2, out);
        in1 = 0; in2 = 0;
        #10 in1 = 0; in2 = 1;
        #10 in1 = 1; in2 = 0;
        #10 in1 = 1; in2 = 1;
        #10 $finish;
    end
    // 4. Optimal checking and monitoring 
    // 5. Self checking
    always @(*) begin
        logic [WIDTH-1:0] expected;
        expected = in1 | in2;
        if (out !== expected) begin
            $error("Mismatch at %0t: in1=%b, in2=%b, expected=%b, got=%b",
                $time, in1, in2, expected, out);
        end
    end
endmodule

