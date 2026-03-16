module bx_threeInputXor #(
    parameter WIDTH = 8
) (
    input logic [WIDTH-1:0]     in1,
    input logic [WIDTH-1:0]     in2,
    input logic [WIDTH-1:0]     in3,
    output logic [WIDTH-1:0]    out
);

always_comb begin
    out = in1 ^ in2 ^ in3;
end

endmodule

module cont_threeInputXor #(
    parameter WIDTH = 8
) (
    input logic [WIDTH-1:0]     in1,
    input logic [WIDTH-1:0]     in2,
    input logic [WIDTH-1:0]     in3,
    output logic [WIDTH-1:0]    out
);

    assign out = in1 ^ in2 ^ in3;
endmodule



module tb_threeInputXor;
    // Signal declaration
    logic [WIDTH-1:0] a, b, c,
    logic [WIDTH-1:0] y_cont, y_bx;

    // dut instantiations
    bx_threeInputXor dut1 (.in1(a), .in2(b), .in3(c) .out(y_bx));
    cont_threeInputXor dut2 (.in1(a), in2(b), .in3(c), .out(y_cont));

    //
    initial begin
        $display("Time a b c | y_cont y_bx");
        $monitor("$4t %b %b %b | %b    %B", $time, a, b, c, y_cont, y_bx);

        for (int i = 0; i < 8; i++) begin
            {a,b,c} = i[2:0]
            #10
            expected = a^b^c;
            if (y_bx !== expected) begin
                $error("dut1 mismatch at %0t: inputs%b%b%b expected:%b got %b",
                    $time, a, b, c, expected, y_bx);
            end
            if (y_cont !== expected) begin
                $error("dut2 mismatch at %0t: inputs %b%b%b expected:%b got%b",
                    $time, a, b, c, expected, y_cont);
            end
        end
        #10 $finish;
    end
    endmodule