// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: fu_dae_full_act.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: PE for streaming mode supporting int32 computation of classic gemm-related and activation operations

module fu_dae_full_act
  import pea_pkg::*;
(
    input  logic                   clk_i,
    input  logic                   rst_n_i,
    input  logic      [N_BITS-1:0] a_i,
    input  logic      [N_BITS-1:0] b_i,
    input  fu_instr_t              instr_i,
    input  logic                   delay_sign_i,
    input  logic      [N_BITS-1:0] const_i,
    input  logic      [N_BITS-1:0] pe_res_i,
    output logic      [N_BITS-1:0] res_o
);

  // Internal signed versions of the inputs
  logic [N_BITS-1:0] a_signed;
  logic [N_BITS-1:0] b_signed;

  assign b_signed = $signed(b_i);

  ////////////////////////////////////////////////////////////////
  //                    Ready-Valid Handling                    //
  ////////////////////////////////////////////////////////////////

  logic                mo_instr;
  // +1 adder
  logic [  N_BITS-1:0] add_one_op1;
  logic [  N_BITS-1:0] add_one_op2;
  logic [  N_BITS-1:0] add_one_res;

  logic [    N_BITS:0] add_res;
  logic [  N_BITS-1:0] mul_res;
  logic [  N_BITS-1:0] shift_res;
  logic [2*N_BITS-1:0] shift_res_ext;
  logic [  N_BITS-1:0] lsh_res;

  logic [  N_BITS-1:0] mul_op1;
  logic [  N_BITS-1:0] mul_op2;

  logic [  N_BITS-1:0] lsh_op1_rev;
  logic [2*N_BITS-1:0] shift_op1;
  logic [  N_BITS-1:0] shift_op2;

  logic [    N_BITS:0] add_op1;
  logic [    N_BITS:0] add_op2;

  logic [  N_BITS-1:0] op1_neg;
  logic [  N_BITS-1:0] op2_neg;
  logic [  N_BITS-1:0] op2_neg_d1;

  logic                sign_op1;
  logic                sign_op1_d;

  logic [  N_BITS-1:0] temp_res;
  logic [  N_BITS-1:0] temp_res_neg;
  logic [  N_BITS-1:0] temp_op_reg;

  /*
    +1 adder shared between:
      -> the ACC, SHACC, MAX, MAXS counter
      -> the ABS operation in ABSMIN
      -> the ABS operation in SGNCSUB
  */
  always_comb begin
    add_one_op1 = '0;
    add_one_op2 = '0;
    if (instr_i == ACC || instr_i == SHACC || instr_i == MAX || instr_i == MAXS) begin
      add_one_op1 = acc_cnt;
      add_one_op2[0] = 1'b1;
    end else if (instr_i == ABSMIN) begin
      add_one_op1 = sign_op1 ? op1_neg : a_signed;
      add_one_op2[0] = sign_op1 ? 1'b1 : 1'b0;
    end else if (instr_i == SGNCSUB) begin
      add_one_op1 = sign_op1_d ? temp_res_neg : temp_res;
      add_one_op2[0] = sign_op1_d ? 1'b1 : 1'b0;
    end
  end

  // +1 adder
  always_comb begin
    add_one_res = add_one_op1 + add_one_op2;
  end

  ////////////////////////////////
  //      Input Selection       //
  ////////////////////////////////

  /* Accumulation match signal to be asserted if
      1. The PE is in accumulation mode
      2. It is not the first accumulation match signal from accumulation controller
      3. The accumulation match signal is currently asserted from the accumulation controller
  */
  assign acc_match = (fu_instr == ACC || fu_instr == SHACC || fu_instr == MAX) ? acc_match_i : 1'b0;  //&& first_acc_match == 1'b1   

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


  // mo_instr: asserted if PE instruction is multi-operand (2-cycle instruction)
  assign mo_instr = instr_i[4] == 1'b1;

  ////////////////////////////////////////////////////////////////
  //                FU Input/Output Assignments                 //
  ////////////////////////////////////////////////////////////////

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

  /*
    Sign of operand a:
      -> the sign of operand a is taken
      -> it is delayed of one cycle when instruction is SGNCSUB
  */
  assign sign_op1 = a_signed[N_BITS-1];

  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      sign_op1_d <= 1'b0;
    end else begin
      if (instr_i == SGNCSUB) begin
        sign_op1_d <= sign_op1;
      end
    end
  end

  /*
    Temporary result for 2-cycle instructions:
      -> when PE has 2-cycles instruction, the temporary result is stored into a register
  */
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      temp_res <= '0;
    end else begin
      if (instr_i == ADDPOW) begin
        temp_res <= add_res[N_BITS:1];
      end else if (instr_i == CADDMUL) begin
        temp_res <= add_res[N_BITS:1];
      end else if (instr_i == CMULADD) begin
        temp_res <= mul_res;
      end else if (instr_i == ADDCMUL) begin
        temp_res <= add_res[N_BITS:1];
      end else if (instr_i == MULCARSH) begin
        temp_res <= mul_res;
      end else if (instr_i == ABSMIN) begin
        temp_res <= add_one_res;
      end else if (instr_i == SGNCSUB) begin
        temp_res <= add_res[N_BITS:1];
      end else if (instr_i == SUBPOW) begin
        temp_res <= add_res[N_BITS:1];
      end else if (instr_i == CLSHSUB) begin
        temp_res <= lsh_res;
      end
    end
  end

  // negated temp_res
  assign temp_res_neg = ~temp_res;

  /*
    Temporary operand:
      -> for some 2-cycle instructions, one of the input operands must be stored into a register,
          as it will be useful for the operation to be done in the second cycle of the instruction
  */
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      temp_op_reg <= '0;
    end else begin
      if (instr_i == CADDMUL || instr_i == CMULADD || instr_i == ABSMIN || instr_i == CLSHSUB) begin
        temp_op_reg <= b_signed;
      end else if (instr_i == SGNCSUB) begin
        temp_op_reg <= a_signed;
      end
    end
  end

  /*
    FU Instructions
  */
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

      MAXS: begin
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

      ADDPOW: begin
        mul_op1 = temp_res;
        mul_op2 = temp_res;
      end

      SUBPOW: begin
        add_op1 = {a_signed, 1'b1};
        add_op2 = {op2_neg, 1'b1};
        mul_op1 = temp_res;
        mul_op2 = temp_res;
      end

      ADDCMUL: begin
        mul_op1 = temp_res;
        mul_op2 = const_i;
      end

      CADDMUL: begin
        add_op2 = {const_i, 1'b0};
        mul_op1 = temp_res;
        mul_op2 = temp_op_reg;
      end

      CMULADD: begin
        add_op1 = {temp_res, 1'b0};
        add_op2 = {temp_op_reg, 1'b0};
        mul_op2 = const_i;
      end

      SHACC: begin
        shift_op1 = {{32{pe_res_i[N_BITS-1]}}, pe_res_i};
        shift_op2 = a_signed;
        add_op1   = {shift_res, 1'b0};
        add_op2   = {b_signed, 1'b0};
      end

      MULCARSH: begin
        shift_op1 = {{32{temp_res[N_BITS-1]}}, temp_res};
        shift_op2 = const_i;
      end

      CLSHSUB: begin
        shift_op1 = {32'd0, lsh_op1_rev};
        shift_op2 = const_i;
        add_op1   = {temp_res, 1'b1};
        add_op2   = {op2_neg_d1, 1'b1};
      end

      ABSMIN: begin
        add_op1 = {temp_res, 1'b1};
        add_op2 = {op2_neg_d1, 1'b1};
      end

      SGNCSUB: begin
        add_op1 = {const_i, 1'b1};
        add_op2 = {op2_neg, 1'b1};
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
      MAX:
      res_o = (a_signed[N_BITS-1] == 1'b0) ? ((add_res[N_BITS-1] != a_signed[N_BITS-1]) ? b_signed : a_signed) :
                                                  ((add_res[N_BITS-1] == a_signed[N_BITS-1]) ? b_signed : a_signed);
      MAXS:
      res_o = (a_signed[N_BITS-1] == 1'b0) ? ((add_res[N_BITS-1] != a_signed[N_BITS-1]) ? b_signed : a_signed) :
                                                  ((add_res[N_BITS-1] == a_signed[N_BITS-1]) ? b_signed : a_signed);
      MIN:
      res_o = (a_signed[N_BITS-1] == 1'b0) ? ((add_res[N_BITS-1] != a_signed[N_BITS-1]) ? a_signed : b_signed) :
                                                  ((add_res[N_BITS-1] == a_signed[N_BITS-1]) ? a_signed : b_signed);
      ABS: res_o = sign_op1 ? add_res[N_BITS:1] : a_signed;
      ADDPOW: res_o = mul_res;
      SUBPOW: res_o = mul_res;
      CADDMUL: res_o = mul_res;
      ADDCMUL: res_o = mul_res;
      CMULADD: res_o = add_res[N_BITS:1];
      SHACC: res_o = add_res[N_BITS:1];
      CLSHSUB: res_o = add_res[N_BITS:1];
      MULCARSH: res_o = shift_res;
      ABSMIN: res_o = (add_res[N_BITS-1]) ? temp_res : temp_op_reg;
      SGNCSUB: res_o = (|temp_op_reg == 1'b0) ? '0 : add_one_res;
      SGNSEL: res_o = delay_sign_i ? b_i : a_i;
      default: res_o = 0;
    endcase
  end


endmodule
