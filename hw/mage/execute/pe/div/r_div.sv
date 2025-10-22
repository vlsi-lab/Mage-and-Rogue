// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: r_div.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: Restoring Multicycle Divider

module r_div
  import pea_pkg::*;
(
    input  logic                     rst_n_i,
    input  logic                     clk_i,
    input  logic                     en_i,
    input  logic signed [N_BITS-1:0] n_i,
    input  logic signed [N_BITS-1:0] d_i,
    output logic signed [N_BITS-1:0] r_o,
    output logic signed [N_BITS-1:0] q_o,
    output logic                     valid_o
);

  // divider state
  typedef enum logic [1:0] {
    IDLE,
    EXEC,
    FINISH
  } div_fsm_t;

  // i/o div signals
  logic [N_BITS-1:0] r_out_stage_in_reg;
  logic [N_BITS-1:0] r_out_stage_out_reg;
  logic [N_BITS-1:0] r_in_stage;
  logic [$clog2(N_RADIX)-1:0] q_out_stage;
  logic [N_BITS-1:0] q_final;
  logic [N_BITS-1:0] r_final;
  logic [N_BITS-1:0] q_final_inv;
  logic [N_BITS-1:0] r_final_inv;
  logic [N_BITS-1:0] q_out;
  logic signed [N_BITS-1:0] n_in_stage;
  logic signed [N_BITS-1:0] n_in_signed;
  logic signed [N_BITS-1:0] d_in_signed;
  logic [N_BITS-1:0] n_in;
  logic [N_BITS-1:0] d_in;

  // fsm-realted signals
  logic [$clog2(N_RADIX)-1:0] cnt;
  div_fsm_t div_state_n;
  div_fsm_t div_state_c;

  // sign signals
  logic n_is_neg;
  logic d_is_neg;
  logic n_is_zero;
  logic d_is_zero;

  // dividend and divisor sign
  assign n_is_neg = n_i[N_BITS-1];
  assign d_is_neg = d_i[N_BITS-1];

  // zero check
  assign n_is_zero = (n_i == '0);
  assign d_is_zero = (d_i == '0);

  assign d_in_signed = (d_i[N_BITS-1] == 1'b0) ? d_i : (~d_i + 1);
  assign d_in = $unsigned(d_in_signed);

  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      n_in_stage <= '0;
    end else begin
      if (en_i) begin
        n_in_stage <= (n_in_signed << $clog2(N_RADIX));
      end else begin
        n_in_stage <= '0;
      end
    end
  end

  assign n_in_signed = (cnt == 0) ? ((n_i[N_BITS-1] == 1'b0) ? n_i : (~n_i + 1)) : n_in_stage;
  assign n_in = $unsigned(n_in_signed);

  // radix-configurable divider core
  r_div_stage r_div_stage_inst (
      .n_i(n_in[N_BITS-1:N_BITS-$clog2(N_RADIX)]),
      .d_i(d_in),
      .r_i(r_in_stage),
      .r_o(r_out_stage_in_reg),
      .q_o(q_out_stage)
  );

  // state transition
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      div_state_c <= IDLE;
    end else begin
      div_state_c <= div_state_n;
    end
  end

  // counter with enable
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      cnt <= '0;
    end else begin
      if (en_i) begin
        if (div_state_c == FINISH) begin
          cnt <= '0;
        end else begin
          cnt <= cnt + 1;
        end
      end
    end
  end

  always_comb begin
    case (div_state_c)
      IDLE: begin
        if (en_i) begin
          div_state_n = EXEC;
        end else begin
          div_state_n = IDLE;
        end
      end
      EXEC: begin
        if (cnt == N_DIV_STAGE - 2) begin
          div_state_n = FINISH;
        end else begin
          div_state_n = EXEC;
        end
      end
      FINISH: begin
        if (en_i) begin
          div_state_n = EXEC;
        end else begin
          div_state_n = IDLE;
        end
      end
      default: begin
        div_state_n = IDLE;
      end
    endcase
  end

  always_comb begin
    case (cnt)
      0: begin
        r_in_stage = '0;
      end
      default: begin
        r_in_stage = r_out_stage_out_reg;
      end
    endcase
  end

  // output register for divider core
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      r_out_stage_out_reg <= '0;
    end else begin
      r_out_stage_out_reg <= r_out_stage_in_reg;
    end
  end

  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      q_out <= '0;
    end else begin
      if (div_state_c == EXEC || div_state_c == IDLE) begin
        q_out <= (q_out << $clog2(N_RADIX)) | {{N_BITS - $clog2(N_RADIX) {1'b0}}, q_out_stage};
      end else begin
        q_out <= '0;
      end
    end
  end

  assign q_final = {q_out[N_BITS-1-$clog2(N_RADIX):0], q_out_stage[$clog2(N_RADIX)-1:0]};
  assign r_final = r_out_stage_in_reg;
  assign q_final_inv = ~q_final + 1;
  assign r_final_inv = ~r_final + 1;

  always_comb begin
    valid_o = (div_state_c == FINISH);

    if (n_is_zero || d_is_zero) begin
      r_o = '0;
      q_o = '0;
    end else begin
      if (n_is_neg && !d_is_neg) begin
        q_o = q_final_inv;
        r_o = r_final_inv;
      end else if (!n_is_neg && d_is_neg) begin
        q_o = q_final_inv;
        r_o = r_final;
      end else if (n_is_neg && d_is_neg) begin
        q_o = q_final;
        r_o = r_final_inv;
      end else begin
        q_o = q_final;
        r_o = r_final;
      end
    end
  end

endmodule
