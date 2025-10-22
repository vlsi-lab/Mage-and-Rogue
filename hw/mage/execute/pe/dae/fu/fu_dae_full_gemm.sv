// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: fu_dae_full_gemm.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: Functional Unit for DAE mode supporting int32 computation of classic gemm-related operations

module fu_dae_full_gemm
  import pea_pkg::*;
(
    input  logic                   clk_i,
    input  logic                   rst_n_i,
    input  logic      [N_BITS-1:0] a_i,
    input  logic      [N_BITS-1:0] b_i,
    input  logic                   acc_match_i,
    input  logic      [N_BITS-1:0] pe_res_i,
    input  fu_instr_t              instr_i,
    output logic      [N_BITS-1:0] res_o
);

  logic              acc_match;

  // Internal signed versions of the inputs
  logic [N_BITS-1:0] a_signed;
  logic [N_BITS-1:0] b_signed;
  assign b_signed  = $signed(b_i);

  ////////////////////////////////
  //      Input Selection       //
  ////////////////////////////////

  /* Accumulation match signal to be asserted if
      1. The PE is in accumulation mode
      2. It is not the first accumulation match signal from accumulation controller
      3. The accumulation match signal is currently asserted from the accumulation controller
  */
  assign acc_match = (instr_i == ACC) ? acc_match_i : 1'b0;  //&& first_acc_match == 1'b1   

  //ATTENTION: The feedback operand for the accumulation is ALWAYS on the first operands input to the FU
  /*
      Management of PE actual inputs
      They are always equal to the output of the input muxes,
      except when the PE is in accumulation mode. In this case, as long as the accumulation match signal is not asserted
      the output of the FU is fed back to the input of the FU. When asserted, the output of the muxa is fed to the input of the FU
  */
  always_comb begin
    a_signed = $signed(a_i);
    if (!acc_match_i) begin
      a_signed = $signed(pe_res_i);
    end
  end

  ////////////////////////////////
  //      int32 Operators       //
  ////////////////////////////////

  // Negated versione of a, b and temp_op_reg
  assign op1_neg = ~a_signed;
  assign op2_neg = ~b_signed;
  assign op2_neg_d1 = ~temp_op_reg;

  // 32-bit adder
  assign add_res = add_op1 + add_op2;

  // 32-bit mul
  assign mul_res = mul_op1 * mul_op2;

  // 32-bit shifter
  assign shift_res_ext = shift_op1 >>> shift_op2;
  assign shift_res = shift_res_ext[31:0];

  // LHS logic
  generate
    genvar m;
    for (m = 0; m < 32; m++) begin
      assign lsh_res[31-m] = shift_res[m];
    end
  endgenerate

  generate
    genvar n;
    for (n = 0; n < 32; n++) begin
      assign lsh_op1_rev[n] = a_signed[31-n];
    end
  endgenerate

  ////////////////////////////////
  //      FU Instrucitons       //
  ////////////////////////////////
  always_comb begin

    add_op1   = {a_signed, 1'b0};
    add_op2   = {b_signed, 1'b0};
    mul_op1   = a_signed;
    mul_op2   = b_signed;
    shift_op1 = {{32{a_signed[N_BITS-1]}}, a_signed};
    shift_op2 = b_signed;

    case (instr_i)
      NOP: begin
        add_op1   = '0;
        add_op2   = '0;
        mul_op1   = '0;
        mul_op2   = '0;
        shift_op1 = '0;
        shift_op2 = '0;
      end

      ABS: begin
        add_op1 = {op1_neg, 1'b0};
        add_op2 = {32'd1, 1'b0};
      end

      SUB: begin
        add_op1 = {a_signed, 1'b1};
        add_op2 = {op2_neg, 1'b1};
      end

      MIN: begin
        add_op1 = {a_signed, 1'b1};
        add_op2 = {op2_neg, 1'b1};
      end

      MAX: begin
        add_op1 = {a_signed, 1'b1};
        add_op2 = {op2_neg, 1'b1};
      end

      ARSH: begin
        shift_op1 = {{32{a_signed[N_BITS-1]}}, a_signed};
        shift_op2 = b_signed;
      end

      LRSH: begin
        shift_op1 = {32'd0, a_signed};
      end

      LSH: begin
        shift_op1 = {32'd0, lsh_op1_rev};
      end

      default: begin
        add_op1   = {a_signed, 1'b0};
        add_op2   = {b_signed, 1'b0};
        mul_op1   = a_signed;
        mul_op2   = b_signed;
        shift_op1 = {{32{a_signed[N_BITS-1]}}, a_signed};
        shift_op2 = b_signed;
      end

    endcase
  end

  ////////////////////////////////
  //     Output Assignment      //
  ////////////////////////////////
  always_comb begin
    case (instr_i)
      NOP: res_o = 0;
      ADD: res_o = add_res[N_BITS:1];
      ACC: res_o = add_res[N_BITS:1];
      MUL: res_o = mul_res;
      SUB: res_o = add_res[N_BITS:1];
      LSH: res_o = lsh_res;
      ARSH: res_o = shift_res;
      LRSH: res_o = shift_res;
      ABS: res_o = a_signed[N_BITS-1] ? add_res[N_BITS:1] : a_signed;
      MAX:
      res_o = (a_signed[N_BITS-1] == 1'b0) ? ((add_res[N_BITS-1] != a_signed[N_BITS-1]) ? b_signed : a_signed) :
                                                  ((add_res[N_BITS-1] == a_signed[N_BITS-1]) ? b_signed : a_signed);
      MIN:
      res_o = (a_signed[N_BITS-1] == 1'b0) ? ((add_res[N_BITS-1] != a_signed[N_BITS-1]) ? a_signed : b_signed) :
                                                  ((add_res[N_BITS-1] == a_signed[N_BITS-1]) ? a_signed : b_signed);
      default: res_o = 0;
    endcase
  end


endmodule
