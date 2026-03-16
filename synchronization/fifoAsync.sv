module fifo_async #(
  parameter WIDTH = 8,
  parameter DEPTH = 16
)(
  // 🔸 Two independent clock domains
  input  logic wr_clk,     // write domain clock
  input  logic rd_clk,     // read domain clock

  // ✅ Separate resets per domain
  input  logic wr_rst_n,
  input  logic rd_rst_n,

  // ✅ Write side
  input  logic wr_en,
  input  logic [WIDTH-1:0] data_in,
  output logic full,

  // ✅ Read side
  input  logic rd_en,
  output logic [WIDTH-1:0] data_out,
  output logic empty
);

  localparam ADDR_WIDTH = $clog2(DEPTH);

  // ✅ Shared memory
  logic [WIDTH-1:0] mem [DEPTH-1:0];

  // 🔸 Separate pointers per domain
  logic [ADDR_WIDTH:0] wr_ptr_bin, rd_ptr_bin;
  logic [ADDR_WIDTH:0] wr_ptr_gray, rd_ptr_gray;

  // 🔸 Cross-domain synchronized pointers
  logic [ADDR_WIDTH:0] rd_ptr_gray_sync, wr_ptr_gray_sync;


  // ------------------------------------------------------------
  // Why Gray code?
  // ------------------------------------------------------------
  // In an asynchronous FIFO, the write and read pointers live in
  // different clock domains. When we send one pointer to the other
  // domain, the signal may be sampled in the middle of a bit change.
  //
  // If we used normal binary counting, several bits can flip at once.
  // Example: 0111 -> 1000 (four bits change)
  // If sampled halfway, the other domain might see 0000 or 1111,
  // which would cause a false "full" or "empty" condition.
  //
  // Gray code fixes this because only ONE bit changes per increment.
  // Example: 0111 -> 0110 (single bit change)
  //
  // Therefore, we convert the binary pointer to Gray code before
  // synchronizing it across the domain boundary, so that metastability
  // can only affect one bit and never corrupt the entire count.
  // ------------------------------------------------------------
        // How it works:
  //  - The MSB of Gray code = MSB of binary.
  //  - Each lower bit of Gray = XOR of the corresponding binary bit
  //    and the bit to its left (higher index).
  //  - Formula: Gray = Binary XOR (Binary >> 1)

  // 🔸 Functions for conversion
  function automatic [ADDR_WIDTH:0] bin2gray(input [ADDR_WIDTH:0] b);
    return (b >> 1) ^ b;
  endfunction

  //  - Each lower Binary bit = XOR of all higher Gray bits down to that position.
  //  - This cumulative XOR ensures we correctly reconstruct the binary value.
  function automatic [ADDR_WIDTH:0] gray2bin(input [ADDR_WIDTH:0] g);
    automatic [ADDR_WIDTH:0] b;
    for (int i = ADDR_WIDTH; i >= 0; i--)
      b[i] = ^(g >> i);
    return b;
  endfunction


    // 🔸 Write pointer and memory
  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      wr_ptr_bin  <= '0;
      wr_ptr_gray <= '0;
    end else if (wr_en && !full) begin
      mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= data_in;
      wr_ptr_bin  <= wr_ptr_bin + 1;
      wr_ptr_gray <= bin2gray(wr_ptr_bin + 1);
    end
  end


  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      rd_ptr_bin  <= '0;
      rd_ptr_gray <= '0;
      data_out    <= '0;
    end else if (rd_en && !empty) begin
      data_out    <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
      rd_ptr_bin  <= rd_ptr_bin + 1;
      rd_ptr_gray <= bin2gray(rd_ptr_bin + 1);
    end
  end


  // 🔸 Synchronize Gray-coded pointers across domains
  logic [ADDR_WIDTH:0] rd_ptr_gray_wrclk, wr_ptr_gray_rdclk;

  // 🔸 Two-flop synchronizers (CDC safe)
  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n)
      rd_ptr_gray_wrclk <= '0;
    else
      rd_ptr_gray_wrclk <= {rd_ptr_gray_wrclk[ADDR_WIDTH-1:0], rd_ptr_gray};
  end

  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n)
      wr_ptr_gray_rdclk <= '0;
    else
      wr_ptr_gray_rdclk <= {wr_ptr_gray_rdclk[ADDR_WIDTH-1:0], wr_ptr_gray};
  end


 // The FIFO is full when the next Gray-coded write pointer equals
  // the synchronized read pointer but with the two MSBs inverted.
  //
  // Why inverted MSBs?
  // - Because the MSB of each pointer flips every time it wraps around.
  // - If lower bits match but the wrap bit is opposite, it means the
  //   writer has lapped the reader — all slots are filled.
  // 🔸 In write domain: detect full
  assign full = (wr_ptr_gray == {~rd_ptr_gray_wrclk[ADDR_WIDTH:ADDR_WIDTH-1],
                                 rd_ptr_gray_wrclk[ADDR_WIDTH-2:0]});

  // 🔸 In read domain: detect empty
  assign empty = (rd_ptr_gray == wr_ptr_gray_rdclk);

endmodule


// testbench
`timescale 1ns/1ps

module tb_fifo_async;

  localparam WIDTH = 8;
  localparam DEPTH = 8;
  localparam WR_CLK_PERIOD = 10;  // 100 MHz
  localparam RD_CLK_PERIOD = 15;  // ~66 MHz

  // 🔸 Separate clock domains
  logic wr_clk, rd_clk;
  logic wr_rst_n, rd_rst_n;
  logic wr_en, rd_en;
  logic [WIDTH-1:0] data_in, data_out;
  logic full, empty;

  // Instantiate DUT
  fifo_async #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
    .wr_clk(wr_clk), .rd_clk(rd_clk),
    .wr_rst_n(wr_rst_n), .rd_rst_n(rd_rst_n),
    .wr_en(wr_en), .data_in(data_in),
    .rd_en(rd_en), .data_out(data_out),
    .full(full), .empty(empty)
  );

  // 🔸 Dual-clock generation
  initial wr_clk = 0;
  always #(WR_CLK_PERIOD/2) wr_clk = ~wr_clk;

  initial rd_clk = 0;
  always #(RD_CLK_PERIOD/2) rd_clk = ~rd_clk;

  // Simple scoreboard
  byte queue[$];

  // Tasks
  task automatic write_word(input byte val);
    if (!full) begin
      data_in = val;
      wr_en = 1;
      @(posedge wr_clk);
      wr_en = 0;
      queue.push_back(val);
    end
  endtask

  task automatic read_word;
    if (!empty) begin
      rd_en = 1;
      @(posedge rd_clk);
      rd_en = 0;
      assert (data_out === queue.pop_front())
        else $error("Data mismatch at time %0t", $time);
    end
  endtask

  // 🔸 Reset both domains
  initial begin
    wr_rst_n = 0;
    rd_rst_n = 0;
    repeat(3) @(posedge wr_clk);
    wr_rst_n = 1;
    repeat(3) @(posedge rd_clk);
    rd_rst_n = 1;
  end

  // 🔸 Randomized producer/consumer simulation
  initial begin
    wr_en = 0; rd_en = 0; data_in = 0;
    wait (wr_rst_n && rd_rst_n);

    repeat (100) begin
      if ($urandom_range(0,1)) write_word($urandom_range(0,255));
      if ($urandom_range(0,1)) read_word();
      #(WR_CLK_PERIOD);  // let clocks drift
    end

    $display("Async FIFO test completed at %0t", $time);
    $finish;
  end

endmodule

