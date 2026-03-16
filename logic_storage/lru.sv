//=====================================================
// Module: lru_cache
// Purpose:  Implements a simple parameterized LRU cache
//            - Stores key/data pairs
//            - Replaces least recently used (LRU) entry
//            - Tracks usage order for replacement policy
//=====================================================
module lru_cache #(
    parameter int KEY_WIDTH  = 8,   // size of address or tag
    parameter int DATA_WIDTH = 8,   // payload size per entry
    parameter int DEPTH      = 4    // number of cache lines
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    rd_en,
    input  logic                    wr_en,
    input  logic [KEY_WIDTH-1:0]    key,
    input  logic [DATA_WIDTH-1:0]   data_in,
    output logic [DATA_WIDTH-1:0]   data_out,
    output logic                    hit
);

    // ------------------------------------------------
    // Internal storage arrays
    // key_store     : holds keys (or addresses)
    // data_store    : holds associated data
    // usage_order   : tracks recency (0 = most recent)
    // ------------------------------------------------
    logic [KEY_WIDTH-1:0]  key_store [DEPTH-1:0];
    logic [DATA_WIDTH-1:0] data_store[DEPTH-1:0];
    int                    usage_order [DEPTH-1:0];

    // Temporary variables for logic
    int i, hit_idx, lru_idx;

    // ------------------------------------------------
    // Combinational search logic
    // - Find whether key exists (hit)
    // - Identify least recently used (LRU) entry
    // - Produce read data if hit
    // ------------------------------------------------
    always_comb begin
        hit      = 1'b0;
        hit_idx  = -1;
        lru_idx  = 0;

        // Search through all lines
        for (i = 0; i < DEPTH; i++) begin
            // Track which entry is oldest (largest usage_order)
            if (usage_order[i] > usage_order[lru_idx])
                lru_idx = i;

            // Key match → mark hit
            if (key_store[i] == key && usage_order[i] != -1) begin
                hit     = 1'b1;
                hit_idx = i;
            end
        end

        // Return stored data if hit, else 0
        data_out = (hit_idx != -1) ? data_store[hit_idx] : '0;
    end

    // ------------------------------------------------
    // Sequential logic for updates (synchronous on clk)
    // Handles both cache write and LRU tracking updates
    // ------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all entries and initialize their usage order
            for (i = 0; i < DEPTH; i++) begin
                key_store[i]    <= '0;
                data_store[i]   <= '0;
                usage_order[i]  <= i; // higher index = less recently used
            end
        end else begin
            // Hit case: key exists in cache
            if (hit) begin
                // If write enabled, update data
                if (wr_en) data_store[hit_idx] <= data_in;

                // Increase "age" of more recent than current hit
                for (i = 0; i < DEPTH; i++) begin
                    if (usage_order[i] < usage_order[hit_idx])
                        usage_order[i] <= usage_order[i] + 1;
                end
                // Most recent entry gets usage 0
                usage_order[hit_idx] <= 0;
            end
            // Miss case: replace least recently used entry
            else if (wr_en) begin
                key_store[lru_idx]   <= key;
                data_store[lru_idx]  <= data_in;

                // Increment age for all, and set replaced one to 0 (most recent)
                for (i = 0; i < DEPTH; i++) usage_order[i] <= usage_order[i] + 1;
                usage_order[lru_idx] <= 0;
            end
        end
    end
endmodule



// tb 
//=====================================================
// Module: tb_lru_cache
// Purpose: Basic self-checking stimulus for lru_cache
//          - Drives write/read operations
//          - Verifies replacement happens
//          - Prints out hit/miss and data info
//=====================================================
module tb_lru_cache;

    // ------------------------------------------------
    // Parameter setup for testbench instantiation
    // ------------------------------------------------
    localparam int KEY_WIDTH  = 8;
    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 4;

    // DUT interface signals
    logic clk, rst_n;
    logic rd_en, wr_en;
    logic [KEY_WIDTH-1:0] key;
    logic [DATA_WIDTH-1:0] data_in, data_out;
    logic hit;

    // ------------------------------------------------
    // Instantiate DUT
    // ------------------------------------------------
    lru_cache #(
        .KEY_WIDTH(KEY_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk, .rst_n, .rd_en, .wr_en,
        .key, .data_in, .data_out, .hit
    );

    // ------------------------------------------------
    // Clock generation
    // ------------------------------------------------
    always #5 clk = ~clk;

    // ------------------------------------------------
    // Stimulus block
    // 1. Reset
    // 2. Write a few entries (fills cache)
    // 3. Access entries to refresh LRU order
    // 4. Add new entry to cause replacement
    // 5. Read back new entry to verify replacement worked
    // ------------------------------------------------
    initial begin
        clk = 0;
        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        data_in = '0;
        key = '0;

        // Apply reset
        #20 rst_n = 1;
        $display("=== Starting LRU Cache Test ===");

        // Step 1: Fill cache completely
        repeat (DEPTH) begin
            @(posedge clk);
            wr_en = 1;
            key = $urandom_range(0, 8'hFF);
            data_in = $urandom_range(0, 8'hFF);
            $display("[%0t] Write: key=%0h data=%0h", $time, key, data_in);
        end

        @(posedge clk);
        wr_en = 0;

        // Step 2: Access an existing entry to refresh its LRU ordering
        @(posedge clk);
        rd_en = 1;
        key = dut.key_store[1]; // Known key from DUT memory
        @(posedge clk);
        $display("[%0t] Read: key=%0h data_out=%0h (hit=%0b)", $time, key, data_out, hit);
        rd_en = 0;

        // Step 3: Cause a miss → replacement
        @(posedge clk);
        wr_en = 1;
        key = 8'hAA;
        data_in = 8'h55;
        @(posedge clk);
        wr_en = 0;
        $display("[%0t] Wrote new key=%0h should replace LRU line", $time, key);

        // Step 4: Read back to confirm presence
        @(posedge clk);
        rd_en = 1;
        key = 8'hAA;
        @(posedge clk);
        $display("[%0t] Read new key=%0h data_out=%0h hit=%0b", $time, key, data_out, hit);
        rd_en = 0;

        #20;
        $display("=== Simulation complete ===");
        $finish;
    end
endmodule