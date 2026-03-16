module fifo_sync #(
  parameter WIDTH = 8,         // data width
  parameter DEPTH = 16         // number of entries
)(
  input  logic             clk,
  input  logic             rst_n,

  // write side
  input  logic             wr_en,
  input  logic [WIDTH-1:0] data_in,

  // read side
  input  logic             rd_en,
  output logic [WIDTH-1:0] data_out,

  // status
  output logic             full,
  output logic             empty
);

  localparam ADDR_WIDTH = $clog2(DEPTH); // gives number of bits required for certain depth

  logic [WIDTH-1:0] mem [DEPTH-1:0];     // FIFO storage
  logic [ADDR_WIDTH:0] wr_ptr, rd_ptr;   // one extra bit for wrap
                                         // because wr == rd could be empty or full

// write logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr <= '0;
    end else if (wr_en && !full) begin
      mem[wr_ptr[ADDR_WIDTH-1:0]] <= data_in;
      wr_ptr <= wr_ptr + 1;
    end
  end

// read logic 
  always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        rd_ptr  <= '0;
        data_out <= '0;
      end else if (rd_en && !empty) begin
        data_out <= mem[rd_ptr[ADDR_WIDTH-1:0]];
        rd_ptr   <= rd_ptr + 1;
      end
  end
  // When the address bits are equal but the MSBs differ → the FIFO is full.
  assign full  = ( (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
                  (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]) );

  assign empty = (wr_ptr == rd_ptr);

endmodule

// testbench
`timescale 1ns/1ps

module tb_fifo_sync;

  // Parameters
  localparam WIDTH = 8;
  localparam DEPTH = 8;
  localparam CLK_PERIOD = 10;  // 100 MHz

  // DUT connections
  logic clk;
  logic rst_n;
  logic wr_en, rd_en;
  logic [WIDTH-1:0] data_in, data_out;
  logic full, empty;

  // Instantiate the FIFO
  fifo_sync #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(wr_en),
    .data_in(data_in),
    .rd_en(rd_en),
    .data_out(data_out),
    .full(full),
    .empty(empty)
  );

  // Clock generation
  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  // Simple scoreboard (expected data queue)
  byte queue[$];


  initial begin
    $display("Time(ns) | wr_en rd_en | data_in | data_out | full empty count");
    $monitor("%8t |   %b     %b  |   %3d    |   %3d    |   %b     %b    | qsize=%0d",
              $time, wr_en, rd_en, data_in, data_out, full, empty, queue.size());
  end

  // Task: push random data into FIFO
  task automatic write_word(input byte val);
    if (!full) begin
      data_in = val;
      wr_en = 1;
      @(posedge clk);
      wr_en = 0;
      queue.push_back(val);  // record expected value
    end
  endtask

  // Task: read data from FIFO and compare
  task automatic read_word;
    if (!empty) begin
      rd_en = 1;
      @(posedge clk);
      rd_en = 0;
      assert (data_out === queue.pop_front())
        else $error("Data mismatch at time %t", $time);
    end
  endtask

  // Main stimulus
  initial begin
    // Initialize
    wr_en = 0;
    rd_en = 0;
    data_in = 0;
    rst_n = 0;
    repeat(3) @(posedge clk);
    rst_n = 1;

    // Phase 1: fill FIFO
    for (int i = 0; i < DEPTH; i++) begin
      write_word($urandom_range(0,255));
    end

    // Phase 2: drain FIFO
    repeat(DEPTH) begin
      read_word();
    end

    // Phase 3: random push/pop mix
    repeat(30) begin
      @(posedge clk);
      if ($urandom_range(0,1)) write_word($urandom_range(0,255));
      if ($urandom_range(0,1)) read_word();
    end

    $display("Test completed at time %0t", $time);
    $finish;
  end

endmodule


