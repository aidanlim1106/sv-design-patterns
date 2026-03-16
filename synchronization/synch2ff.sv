module synch_2ff #(
  parameter INIT = 1'b0
)(
    input logic clk_dst,
    input logic rst_dst_n,
    input logic asynch_in,
    output logic synch_out
 );
 
  logic meta;
  
  always_ff @(posedge clk_dst or negedge rst_dst_n) begin
    if (!rst_dst_n)
    {meta, synch_out} <= {2{INIT}};
    else
    {meta, synch_out} <= {asynch_in, meta};
  end
endmodule



// tb
`timescale 1ns/1ps
module tb_synch_2ff;
  logic clk_dst, rst_dst_n;
  logic asynch_in, synch_out;
  
  synch_2ff #(.INIT(1'b0)) dut1 (
    .clk_dst 	(clk_dst),
    .rst_dst_n	(rst_dst_n),
    .asynch_in 	(asynch_in),
    .synch_out	(synch_out)
  );
  
  initial clk_dst = 1'b0;
  always #5 clk_dst = ~clk_dst;
  
  initial begin
    rst_dst_n = 0;
    repeat (2) @(posedge clk_dst);
    rst_dst_n = 1;
  end
  
  initial begin
    asynch_in = 1'b0;
    @(posedge rst_dst_n);
    #15 asynch_in = 1'b1;
    #3 asynch_in = 1'b0;
    #2 $finish;
  end
  
  initial begin
    $display("Time | rst_dst_n asynch_in | synch_out");
    $monitor("%t,   |    %b        %b        %b",
             $time, rst_dst_n, asynch_in, synch_out);
  end
endmodule