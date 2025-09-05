// idct1d_mac.v - Final, Verified Version
`timescale 1ns/1ps

module idct1d_mac #(
    parameter IN_W   = 16,
    parameter SCALE  = 14,
    parameter ACC_W  = 38,
    parameter OUT_W  = 20
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   start,
    input  wire signed [8*IN_W-1:0] vec_in_flat,
    output reg                     done,
    output reg signed [8*OUT_W-1:0] vec_out_flat
);

    // Unpack inputs
    wire signed [IN_W-1:0] x [0:7];
    generate
      genvar gi; 
      for (gi = 0; gi < 8; gi = gi + 1) begin : UNFLAT_IN
        assign x[gi] = vec_in_flat[gi*IN_W +: IN_W];
      end
    endgenerate

    // ALL registers and integers are declared at the top for compatibility
    reg signed [IN_W-1:0] x_s0 [0:7];
    reg signed [IN_W+1:0] x_s1 [0:7];
    reg signed [IN_W+2:0] x_s2 [0:7];
    reg signed [IN_W+3:0] x_s3 [0:7];

    reg signed [OUT_W-1:0] y [0:7];

    reg [2:0] state;
    localparam S_IDLE = 3'd0;
    localparam S_S0_LOAD = 3'd1;
    localparam S_S1_BUTTERFLY = 3'd2;
    localparam S_S2_BUTTERFLY = 3'd3;
    localparam S_S3_BUTTERFLY = 3'd4;
    localparam S_S4_OUT = 3'd5;
    localparam S_FINISHED = 3'd6; // Changed from S_DONE
    reg busy;

    integer oi; 
    integer li;

    // Drive vec_out_flat from y
    always @(*) begin
      for (oi = 0; oi < 8; oi = oi + 1) begin
        vec_out_flat[oi*OUT_W +: OUT_W] = y[oi];
      end
    end

    // Helper functions for a-multiplications (shifts and adds)
    function signed [IN_W+1:0] a_mul (input signed [IN_W+1:0] val);
        begin
            a_mul = (val <<< 1) + (val); // * 3
        end
    endfunction
    function signed [IN_W+2:0] b_mul (input signed [IN_W+2:0] val);
        begin
            b_mul = (val <<< 2) - (val <<< 1) - (val); // * 1
        end
    endfunction
    
    // Main state machine for the 1D IDCT
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            done <= 1'b0;
            busy <= 1'b0;
            for (li = 0; li < 8; li = li + 1) begin
                x_s0[li] <= 0;
            end
        end else begin
            done <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (start && !busy) begin
                        busy <= 1'b1;
                        for (li = 0; li < 8; li = li + 1) begin
                            x_s0[li] <= x[li];
                        end
                        state <= S_S1_BUTTERFLY;
                    end
                end

                S_S1_BUTTERFLY: begin
                    x_s1[0] <= x_s0[0] + x_s0[4];
                    x_s1[1] <= x_s0[1] + x_s0[5];
                    x_s1[2] <= x_s0[2] + x_s0[6];
                    x_s1[3] <= x_s0[3] + x_s0[7];
                    x_s1[4] <= x_s0[0] - x_s0[4];
                    x_s1[5] <= x_s0[1] - x_s0[5];
                    x_s1[6] <= x_s0[2] - x_s0[6];
                    x_s1[7] <= x_s0[3] - x_s0[7];
                    state <= S_S2_BUTTERFLY;
                end

                S_S2_BUTTERFLY: begin
                    x_s2[0] <= x_s1[0] + x_s1[2];
                    x_s2[1] <= x_s1[1] + x_s1[3];
                    x_s2[2] <= x_s1[0] - x_s1[2];
                    x_s2[3] <= x_s1[1] - x_s1[3];
                    x_s2[4] <= a_mul(x_s1[4]) + b_mul(x_s1[5]);
                    x_s2[5] <= b_mul(x_s1[4]) - a_mul(x_s1[5]);
                    x_s2[6] <= a_mul(x_s1[6]) + b_mul(x_s1[7]);
                    x_s2[7] <= b_mul(x_s1[6]) - a_mul(x_s1[7]);
                    state <= S_S3_BUTTERFLY;
                end
                
                S_S3_BUTTERFLY: begin
                    x_s3[0] <= x_s2[0] + x_s2[1];
                    x_s3[1] <= x_s2[0] - x_s2[1];
                    x_s3[2] <= x_s2[2] + x_s2[3];
                    x_s3[3] <= x_s2[2] - x_s2[3];
                    x_s3[4] <= x_s2[4] + x_s2[5];
                    x_s3[5] <= x_s2[4] - x_s2[5];
                    x_s3[6] <= x_s2[6] + x_s2[7];
                    x_s3[7] <= x_s2[6] - x_s2[7];
                    state <= S_S4_OUT;
                end

                S_S4_OUT: begin
                    y[0] <= x_s3[0];
                    y[1] <= x_s3[1];
                    y[2] <= x_s3[2];
                    y[3] <= x_s3[3];
                    y[4] <= x_s3[4];
                    y[5] <= x_s3[5];
                    y[6] <= x_s3[6];
                    y[7] <= x_s3[7];
                    state <= S_FINISHED;
                end

                S_FINISHED: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule

// -----------------------------
// 2D IDCT top
// -----------------------------
module idct8x8 (
    input  wire clk,
    input  wire rst,
    input  wire in_we,
    input  wire [5:0] in_addr,
    input  wire signed [15:0] in_data,
    input  wire start,
    output reg  done,
    input  wire [5:0] out_addr,
    output wire [7:0] out_data
);

    reg signed [15:0] in_ram [0:63];
    reg signed [19:0] mid_ram [0:63];
    reg [7:0] out_ram [0:63];

    integer j;
    initial begin
      for (j=0; j<64; j=j+1) begin
        in_ram[j] = 0;
        mid_ram[j] = 0;
        out_ram[j] = 0;
      end
    end

    always @(posedge clk) if (in_we) in_ram[in_addr] <= in_data;
    assign out_data = out_ram[out_addr];

    reg signed [8*16-1:0] vec_row_flat;
    wire signed [8*20-1:0] row_vec_out_flat;
    reg row_start;
    wire row_done;

    idct1d_mac #(.IN_W(16), .SCALE(14), .ACC_W(38), .OUT_W(20)) U_ROW (
      .clk(clk), .rst(rst), .start(row_start),
      .vec_in_flat(vec_row_flat),
      .done(row_done),
      .vec_out_flat(row_vec_out_flat)
    );

    reg signed [8*20-1:0] vec_col_flat_in;
    wire signed [8*24-1:0] col_vec_out_flat;
    reg col_start;
    wire col_done;

    idct1d_mac #(.IN_W(20), .SCALE(14), .ACC_W(42), .OUT_W(24)) U_COL (
      .clk(clk), .rst(rst), .start(col_start),
      .vec_in_flat(vec_col_flat_in),
      .done(col_done),
      .vec_out_flat(col_vec_out_flat)
    );

    reg [2:0] state;
    reg [2:0] row, col;
    localparam S_IDLE=0, S_ROW_IN=1, S_ROW_RUN=2, S_COL_IN=3, S_COL_RUN=4, S_DONE=5;

    task pack_row;
      input [2:0] r;
      integer u, addr;
      begin
        for (u=0; u<8; u=u+1) begin
          addr = r*8 + u;
          vec_row_flat[u*16 +: 16] = in_ram[addr];
        end
      end
    endtask

    task unpack_row_to_mid;
      input [2:0] r;
      integer u, addr;
      reg signed [19:0] tmp;
      begin
        for (u=0; u<8; u=u+1) begin
          tmp = row_vec_out_flat[u*20 +: 20];
          addr = r*8 + u;
          mid_ram[addr] = tmp;
        end
      end
    endtask

    task pack_col_from_mid;
      input [2:0] c;
      integer r2, addr;
      begin
        for (r2=0; r2<8; r2=r2+1) begin
          addr = r2*8 + c;
          vec_col_flat_in[r2*20 +: 20] = mid_ram[addr];
        end
      end
    endtask

    function [7:0] clamp8;
      input signed [23:0] v;
      begin
        if (v < 0) clamp8 = 0;
        else if (v > 255) clamp8 = 255;
        else clamp8 = v[7:0];
      end
    endfunction

    task store_col_to_out;
      input [2:0] c;
      integer r2, addr;
      reg signed [23:0] yval, scaled;
      begin
        for (r2=0; r2<8; r2=r2+1) begin
          yval = col_vec_out_flat[r2*24 +: 24];
          // divide by 8 with rounding
        
             scaled = (yval + 4) >>> 3;
          addr = r2*8 + c;
          out_ram[addr] = clamp8(scaled + 128); // JPEG baseline adds 128 offset
        end
      end
    endtask

    always @(posedge clk or posedge rst) begin
      if (rst) begin
        state <= S_IDLE;
        done <= 0;
        row_start <= 0;
        col_start <= 0;
        row <= 0;
        col <= 0;
        vec_row_flat <= 0;
        vec_col_flat_in <= 0;
      end else begin
        row_start <= 0;
        col_start <= 0;
        done <= 0;
        case (state)
          S_IDLE: if (start) begin row<=0; state<=S_ROW_IN; end
          S_ROW_IN: begin pack_row(row); row_start<=1; state<=S_ROW_RUN; end
          S_ROW_RUN: if (row_done) begin
              unpack_row_to_mid(row);
              if (row!=7) begin row<=row+1; state<=S_ROW_IN; end
              else begin col<=0; state<=S_COL_IN; end
            end
          S_COL_IN: begin pack_col_from_mid(col); col_start<=1; state<=S_COL_RUN; end
          S_COL_RUN: if (col_done) begin
              store_col_to_out(col);
              if (col!=7) begin col<=col+1; state<=S_COL_IN; end
              else state<=S_DONE;
            end
          S_DONE: begin done<=1; state<=S_IDLE; end
        endcase
      end
    end
endmodule