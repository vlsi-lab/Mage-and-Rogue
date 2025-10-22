// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: r_div.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: Restoring Multicycle Divider

module r_div_pipe
  import pea_pkg::*;
(
    input  logic                     rst_n_i,
    input  logic                     clk_i,
    input  logic                     pea_ready_i,
    input  logic                     en_i,
    input  logic signed [N_BITS-1:0] n_i,
    input  logic signed [N_BITS-1:0] d_i,
    output logic signed [N_BITS-1:0] r_o,
    output logic signed [N_BITS-1:0] q_o,
    output logic                     valid_o
);

  // i/o div signals
  logic signed [N_DIV_STAGE-2:0] valid;

  logic signed [N_DIV_STAGE-1:0][N_BITS-1:0] n_in_stage;
  logic signed [N_DIV_STAGE-2:0][N_BITS-1:0] n_in_pipe_reg;
  logic signed [N_DIV_STAGE-2:0][N_BITS-1:0] n_out_pipe_reg;

  logic [N_DIV_STAGE-1:0][N_BITS-1:0] r_in_stage;
  logic [N_DIV_STAGE-1:0][N_BITS-1:0] r_out_stage;
  logic [N_DIV_STAGE-2:0][N_BITS-1:0] r_in_pipe_reg;
  logic [N_DIV_STAGE-2:0][N_BITS-1:0] r_out_pipe_reg;

  logic signed [N_DIV_STAGE-1:0][N_BITS-1:0] d_in_stage;
  logic signed [N_DIV_STAGE-2:0][N_BITS-1:0] d_in_pipe_reg;
  logic signed [N_DIV_STAGE-2:0][N_BITS-1:0] d_out_pipe_reg;

  logic [N_DIV_STAGE-1:0][$clog2(N_RADIX)-1:0] q_out_stage;

  logic [N_DIV_STAGE-2:0][$clog2(N_RADIX)-1:0] q_stage_0;
  logic [N_DIV_STAGE-3:0][$clog2(N_RADIX)-1:0] q_stage_1;
  logic [N_DIV_STAGE-4:0][$clog2(N_RADIX)-1:0] q_stage_2;
  logic [N_DIV_STAGE-5:0][$clog2(N_RADIX)-1:0] q_stage_3;
  logic [N_DIV_STAGE-6:0][$clog2(N_RADIX)-1:0] q_stage_4;
  logic [N_DIV_STAGE-7:0][$clog2(N_RADIX)-1:0] q_stage_5;
  logic [N_DIV_STAGE-8:0][$clog2(N_RADIX)-1:0] q_stage_6;

  logic signed [N_BITS-1:0] n_in_signed;
  logic signed [N_BITS-1:0] d_in_signed;
  logic [N_BITS-1:0] n_in;
  logic [N_BITS-1:0] d_in;

  logic [N_BITS-1:0] q_final;
  logic [N_BITS-1:0] r_final;
  logic [N_BITS-1:0] q_final_inv;
  logic [N_BITS-1:0] r_final_inv;
  logic [N_BITS-1:0] q_out;

  // sign signals
  logic [N_DIV_STAGE-2:0] n_is_neg;
  logic [N_DIV_STAGE-2:0] d_is_neg;
  logic [N_DIV_STAGE-2:0] n_is_zero;
  logic [N_DIV_STAGE-2:0] d_is_zero;

  // valid
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    integer i;
    if (~rst_n_i) begin
      for (i = 0; i < N_DIV_STAGE - 1; i++) begin
        valid[i] <= '0;
      end
    end else begin
      for (i = 0; i < N_DIV_STAGE - 1; i++) begin
        if (pea_ready_i) begin
          if (i == 0) begin
            valid[i] <= en_i;
          end else begin
            valid[i] <= valid[i-1];
          end
        end
      end
    end
  end

  assign valid_o = valid[N_DIV_STAGE-2];

  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (~rst_n_i) begin
      for (int i = 0; i < N_DIV_STAGE - 1; i++) begin
        n_is_neg[i]  <= '0;
        d_is_neg[i]  <= '0;
        n_is_zero[i] <= '0;
        d_is_zero[i] <= '0;
      end
    end else begin
      for (int i = 0; i < N_DIV_STAGE - 1; i++) begin
        if (pea_ready_i) begin
          if (i == 0) begin
            n_is_neg[i]  <= n_i[N_BITS-1];
            d_is_neg[i]  <= d_i[N_BITS-1];
            n_is_zero[i] <= (n_i == '0);
            d_is_zero[i] <= (d_i == '0);
          end else begin
            n_is_neg[i]  <= n_is_neg[i-1];
            d_is_neg[i]  <= d_is_neg[i-1];
            n_is_zero[i] <= n_is_zero[i-1];
            d_is_zero[i] <= d_is_zero[i-1];
          end
        end
      end
    end
  end

  // dividend assignments
  assign n_in_signed = (n_i[N_BITS-1] == 1'b0) ? n_i : (~n_i + 1);
  assign n_in = $unsigned(n_in_signed);

  always_comb begin
    for (int i = 0; i < N_DIV_STAGE; i++) begin
      if (i == 0) begin
        n_in_stage[i] = n_in;
      end else begin
        n_in_stage[i] = n_out_pipe_reg[i-1] << $clog2(N_RADIX);
      end
    end
  end

  always_comb begin
    for (int i = 0; i < N_DIV_STAGE - 1; i++) begin
      n_in_pipe_reg[i] = n_in_stage[i];
    end
  end

  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (~rst_n_i) begin
      for (int i = 0; i < N_DIV_STAGE - 1; i++) begin
        n_out_pipe_reg[i] <= '0;
      end
    end else begin
      for (int i = 0; i < N_DIV_STAGE - 1; i++) begin
        if (pea_ready_i) begin
          n_out_pipe_reg[i] <= n_in_pipe_reg[i];
        end
      end
    end
  end

  // divider assignments
  assign d_in_signed = (d_i[N_BITS-1] == 1'b0) ? d_i : (~d_i + 1);
  assign d_in = $unsigned(d_in_signed);

  always_comb begin
    for (int i = 0; i < N_DIV_STAGE; i++) begin
      if (i == 0) begin
        d_in_stage[i] = d_in;
      end else begin
        d_in_stage[i] = d_out_pipe_reg[i-1];
      end
    end
  end

  always_comb begin
    for (int i = 0; i < N_DIV_STAGE - 1; i++) begin
      d_in_pipe_reg[i] = d_in_stage[i];
    end
  end

  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (~rst_n_i) begin
      for (int i = 0; i < N_DIV_STAGE - 1; i++) begin
        d_out_pipe_reg[i] <= '0;
      end
    end else begin
      for (int i = 0; i < N_DIV_STAGE - 1; i++) begin
        if (pea_ready_i) begin
          d_out_pipe_reg[i] <= d_in_pipe_reg[i];
        end
      end
    end
  end

  // remainder assignments  
  always_comb begin
    for (int i = 0; i < N_DIV_STAGE; i++) begin
      if (i == 0) begin
        r_in_stage[i] = '0;
      end else begin
        r_in_stage[i] = r_out_pipe_reg[i-1];
      end
    end
  end

  always_comb begin
    for (int i = 0; i < N_DIV_STAGE - 1; i++) begin
      r_in_pipe_reg[i] = r_out_stage[i];
    end
  end

  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (~rst_n_i) begin
      for (int i = 0; i < N_DIV_STAGE - 1; i++) begin
        r_out_pipe_reg[i] <= '0;
      end
    end else begin
      for (int i = 0; i < N_DIV_STAGE - 1; i++) begin
        if (pea_ready_i) begin
          r_out_pipe_reg[i] <= r_in_pipe_reg[i];
        end
      end
    end
  end

  // quotient assignment
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (~rst_n_i) begin
      q_stage_0[0] <= '0;
      q_stage_0[1] <= '0;
      q_stage_0[2] <= '0;
      q_stage_0[3] <= '0;
      q_stage_0[4] <= '0;
      q_stage_0[5] <= '0;
      q_stage_0[6] <= '0;
      q_stage_1[0] <= '0;
      q_stage_1[1] <= '0;
      q_stage_1[2] <= '0;
      q_stage_1[3] <= '0;
      q_stage_1[4] <= '0;
      q_stage_1[5] <= '0;
      q_stage_2[0] <= '0;
      q_stage_2[1] <= '0;
      q_stage_2[2] <= '0;
      q_stage_2[3] <= '0;
      q_stage_2[4] <= '0;
      q_stage_3[0] <= '0;
      q_stage_3[1] <= '0;
      q_stage_3[2] <= '0;
      q_stage_3[3] <= '0;
      q_stage_4[0] <= '0;
      q_stage_4[1] <= '0;
      q_stage_4[2] <= '0;
      q_stage_5[0] <= '0;
      q_stage_5[1] <= '0;
      q_stage_6[0] <= '0;
    end else begin
      if (pea_ready_i) begin
        q_stage_0[0] <= q_out_stage[0];
        q_stage_0[1] <= q_stage_0[0];
        q_stage_0[2] <= q_stage_0[1];
        q_stage_0[3] <= q_stage_0[2];
        q_stage_0[4] <= q_stage_0[3];
        q_stage_0[5] <= q_stage_0[4];
        q_stage_0[6] <= q_stage_0[5];

        q_stage_1[0] <= q_out_stage[1];
        q_stage_1[1] <= q_stage_1[0];
        q_stage_1[2] <= q_stage_1[1];
        q_stage_1[3] <= q_stage_1[2];
        q_stage_1[4] <= q_stage_1[3];
        q_stage_1[5] <= q_stage_1[4];

        q_stage_2[0] <= q_out_stage[2];
        q_stage_2[1] <= q_stage_2[0];
        q_stage_2[2] <= q_stage_2[1];
        q_stage_2[3] <= q_stage_2[2];
        q_stage_2[4] <= q_stage_2[3];

        q_stage_3[0] <= q_out_stage[3];
        q_stage_3[1] <= q_stage_3[0];
        q_stage_3[2] <= q_stage_3[1];
        q_stage_3[3] <= q_stage_3[2];

        q_stage_4[0] <= q_out_stage[4];
        q_stage_4[1] <= q_stage_4[0];
        q_stage_4[2] <= q_stage_4[1];

        q_stage_5[0] <= q_out_stage[5];
        q_stage_5[1] <= q_stage_5[0];

        q_stage_6[0] <= q_out_stage[6];
      end
    end
  end

  genvar i;
  generate
    for (i = 0; i < N_DIV_STAGE; i++) begin
      // radix-configurable divider core
      r_div_stage r_div_stage_inst (
          .n_i(n_in_stage[i][N_BITS-1:N_BITS-$clog2(N_RADIX)]),
          .d_i(d_in_stage[i]),
          .r_i(r_in_stage[i]),
          .r_o(r_out_stage[i]),
          .q_o(q_out_stage[i])
      );
    end
  endgenerate

  assign q_out = {
    q_stage_0[6],
    q_stage_1[5],
    q_stage_2[4],
    q_stage_3[3],
    q_stage_4[2],
    q_stage_5[1],
    q_stage_6[0],
    q_out_stage[7]
  };

  assign q_final = q_out;
  assign r_final = r_out_stage[N_DIV_STAGE-1];
  assign q_final_inv = ~q_final + 1;
  assign r_final_inv = ~r_final + 1;

  always_comb begin
    if (n_is_zero[N_DIV_STAGE-2] || d_is_zero[N_DIV_STAGE-2]) begin
      r_o = '0;
      q_o = '0;
    end else begin
      if (n_is_neg[N_DIV_STAGE-2] && !d_is_neg[N_DIV_STAGE-2]) begin
        q_o = q_final_inv;
        r_o = r_final_inv;
      end else if (!n_is_neg[N_DIV_STAGE-2] && d_is_neg[N_DIV_STAGE-2]) begin
        q_o = q_final_inv;
        r_o = r_final;
      end else if (n_is_neg[N_DIV_STAGE-2] && d_is_neg[N_DIV_STAGE-2]) begin
        q_o = q_final;
        r_o = r_final_inv;
      end else begin
        q_o = q_final;
        r_o = r_final;
      end
    end
  end

endmodule
