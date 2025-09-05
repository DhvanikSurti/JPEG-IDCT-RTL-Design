// tb_idct8x8.v
`timescale 1ns/1ps

module tb_idct8x8;
    // Signals for the DUT
    reg clk, rst;
    reg in_we;
    reg [5:0] in_addr;
    reg signed [15:0] in_data;
    reg start;
    wire done;
    reg [5:0] out_addr;
    wire [7:0] out_data;

    // Instantiate the Top-Level IDCT Module
    idct8x8 DUT (
      .clk(clk),
      .rst(rst),
      .in_we(in_we),
      .in_addr(in_addr),
      .in_data(in_data),
      .start(start),
      .done(done),
      .out_addr(out_addr),
      .out_data(out_data)
    );

    // Clock Generation
    initial begin
      clk = 0;
      forever #5 clk = ~clk;
    end

    // VCD Dump
    initial begin
      $dumpfile("idct_dump.vcd");
      $dumpvars(0, tb_idct8x8);
    end

    // Main Test Sequence
    integer i, j;
    reg fail;
    reg signed [15:0] test_input [0:63];
    reg [7:0] test_expected [0:63];
    integer test_case_num;

    initial begin
      // Initialize signals
      rst = 1; in_we = 0; in_addr = 0; in_data = 0; start = 0; out_addr = 0;
      fail = 0;
      test_case_num = 0;

      // Reset the DUT
      repeat(10) @(posedge clk);
      rst = 0;

      // --- TEST 1: DC-only block ---
      $display("--- Starting Test 1: DC-only block ---");
      test_case_num = 1;
      // Define test data
      for (i = 0; i < 64; i = i + 1) begin
        test_input[i] = (i == 0) ? 16'sd1024 : 16'sd0;
        test_expected[i] = 8'd128;
      end
      run_test;

      // --- TEST 2: Simple AC block (Horizontal) ---
      $display("--- Starting Test 2: Simple AC block ---");
      test_case_num = 2;
      // Define test data (pre-calculated coefficients)
      for (i = 0; i < 64; i = i + 1) begin
        test_input[i] = 16'sd0;
      end
      test_input[1] = 16'sd1000; // a single AC coefficient
      
      // Expected output for a single AC coefficient
      // A full IDCT implementation should produce a horizontal stripe pattern.
      // This is for demonstration, replace with your actual pre-calculated values.
      for (i = 0; i < 64; i = i + 1) begin
          // This is a dummy example, replace with your actual values from a
          // verified IDCT calculation.
          // For now, let's just make sure it's not all 128s
          test_expected[i] = (i < 8) ? 8'd160 : 8'd128;
      end
      run_test;

      // End of simulation
      #100;
      $finish;
    end

    // Task to load data, run the IDCT, and verify output
    task run_test;
      begin
        $display("Loading inputs for Test %0d...", test_case_num);
        // Load the input data into the DUT's RAM
        for (i = 0; i < 64; i = i + 1) begin
          in_we = 1;
          in_addr = i;
          in_data = test_input[i];
          @(posedge clk);
        end
        in_we = 0;
        
        // Start the IDCT process
        @(posedge clk);
        $display("Starting IDCT...");
        start = 1;
        @(posedge clk);
        start = 0;

        // Wait for the 'done' signal
        wait(done);
        @(posedge clk);
        $display("IDCT done. Reading outputs...");
        
        // Read and verify the output data
        fail = 0;
        for (i = 0; i < 64; i = i + 1) begin
          out_addr = i;
          @(posedge clk);
          if (out_data !== test_expected[i]) begin
            $display("Test %0d Mismatch at index %0d: got %0d, expected %0d", test_case_num, i, out_data, test_expected[i]);
            fail = 1;
          end
        end

        if (!fail) begin
          $display("--- Test %0d PASSED. ---", test_case_num);
        end else begin
          $display("--- Test %0d FAILED. See mismatches above. ---", test_case_num);
        end

        // Wait a few cycles before next test
        repeat(5) @(posedge clk);
      end
    endtask

endmodule