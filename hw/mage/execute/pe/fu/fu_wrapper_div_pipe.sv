// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: fu_wrapper.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: wrapper for functional unit

module fu_wrapper_div_pipe
  import pea_pkg::*;
(
    input  logic                   clk_i,
    input  logic                   rst_n_i,
    input  logic                   mage_done_i,
    input  logic      [N_BITS-1:0] a_i,
    input  logic      [N_BITS-1:0] b_i,
    input  fu_instr_t              instr_i,
    input  logic                   delay_sign_i,
    input  logic      [N_BITS-1:0] const_i,
    input  logic      [N_BITS-1:0] pe_res_i,
    input  logic                   ops_valid_i,
    input  logic                   pea_ready_i,
    input  logic      [      15:0] reg_acc_value_i,
    output logic                   acc_loopback_o,
    output logic                   valid_o,
    output logic                   ready_o,
    output logic      [N_BITS-1:0] rem_q_o,
    output logic      [N_BITS-1:0] res_o
);

  // gated clock
  logic              clk_cg;

  // Internal signed versions of the inputs
  logic [N_BITS-1:0] a_signed;
  logic [N_BITS-1:0] b_signed;

  assign a_signed = $signed(a_i);
  assign b_signed = $signed(b_i);
  ////////////////////////////////////////////////////////////////
  //                    Ready-Valid Handling                    //
  ////////////////////////////////////////////////////////////////

  // division ready-valid
  logic                out_div_valid;
  logic                div_input_valid;
  logic                div_instr;
  // accumulation ready-valid
  logic [  N_BITS-1:0] acc_cnt;
  logic                acc_valid;
  // ready-valid
  logic                valid;
  logic                valid_mo_instr;
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

  logic [  N_BITS-1:0] quotient_div;
  logic [  N_BITS-1:0] remainder_div;
  logic [  N_BITS-1:0] div_op1;
  logic [  N_BITS-1:0] div_op2;


  // div_instr is asserted when the instruction contains a division (it is used to clock gate divider)
  assign div_instr = (instr_i == DIV || instr_i == REM || instr_i == ABSDIV || instr_i == ABSREM || instr_i == CADDDIV);

`ifndef VERILATOR
`ifndef FPGA
  // Div Clock-gating
  logic clk_cg_en;
  assign clk_cg_en = div_instr;
  tc_clk_gating div_clk_gating_cell (
      .clk_i(clk_i),
      .en_i(clk_cg_en),
      .test_en_i(1'b0),
      .clk_o(clk_cg)
  );
`else
  assign clk_cg = clk_i;
`endif
`else
  assign clk_cg = clk_i;
`endif

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
    end else if (instr_i == ABSMIN || instr_i == ABSDIV || instr_i == ABSREM) begin
      add_one_op1 = sign_op1 ? op1_neg : a_signed;
      add_one_op2[0] = sign_op1 ? 1'b1 : 1'b0;
    end else if (instr_i == SGNCSUB) begin
      add_one_op1 = sign_op1_d ? temp_res_neg : temp_res;
      add_one_op2[0] = sign_op1_d ? 1'b1 : 1'b0;
    end
  end

  always_comb begin
    add_one_res = add_one_op1 + add_one_op2;
  end

  ////////////////////////////////////////////////////////////////
  //                        Accumulation                        //
  ////////////////////////////////////////////////////////////////

  /*
    ACC counter: 
      -> counts up to reg_acc_value_i, it is used to know how many elements to accumulate
          in the ACC instruction
      -> it is also used to know when to stop the max search in the MAX instruction
      -> acc_loopback_o is used to loop back the result of the operation to the input of the PE
  */
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      acc_cnt <= '0;
      acc_loopback_o <= 1'b0;
    end else begin
      if (instr_i == ACC || instr_i == SHACC || instr_i == MAX || instr_i == MAXS) begin
        if ((acc_cnt[15:0] == reg_acc_value_i && ops_valid_i && pea_ready_i) || mage_done_i) begin
          acc_cnt <= '0;
          acc_loopback_o <= 1'b0;
        end else if (ops_valid_i && pea_ready_i) begin
          acc_cnt <= add_one_res;
          acc_loopback_o <= 1'b1;
        end
      end else begin
        acc_cnt <= '0;
        acc_loopback_o <= 1'b0;
      end
    end
  end

  /*
    valid signal for accumulation:
      -> the acc_valid signal is asserted when (in AND):
        -> the coutner reaches the final value
        -> the inputs of the FU are valid
  */
  //assign acc_valid = (acc_cnt[15:0] == reg_acc_value_i && acc_cnt != '0 && ops_valid_i);
  assign acc_valid = (acc_cnt[15:0] == reg_acc_value_i && ops_valid_i);


  ////////////////////////////////////////////////////////////////
  //                           Division                         //
  ////////////////////////////////////////////////////////////////

  // div_input_valid is asserted when the inputs to divider are valid and the instruction has division
  assign div_input_valid = (ops_valid_i && (instr_i == DIV || instr_i == REM)) || (valid_mo_instr && (instr_i == ABSDIV || instr_i == ABSREM || instr_i == CADDDIV));

  ////////////////////////////////////////////////////////////////
  //                   Ready-Valid Assignment                   //
  ////////////////////////////////////////////////////////////////

  // mo_instr: asserted if PE instruction is multi-operand (2-cycle instruction)
  assign mo_instr = instr_i[4] == 1'b1;

  /*
    Valid:
      -> standard case: it is asserted when both inputs are valid
      -> ACC, SHACC, MAX case: it is asserted when acc_valid is asserted
        -> NOTE: MAXS has the loopback logic, but its valid is asserted for all the outputs
      -> 2-cycle instruction case: it is assigned to valid_mo_instr (i.e. ops_valid delayed by one cycle)
      -> division instruction case: it is asserted when the output of the divider

    Ready:
      -> the FU is always ready, as also division is pipelined
  */
  always_comb begin
    valid = ops_valid_i;
    if (div_instr) begin
      valid = out_div_valid;
    end else if (mo_instr) begin
      valid = valid_mo_instr;
    end else begin
      if (instr_i == ACC || instr_i == SHACC || instr_i == MAX) begin
        valid = acc_valid;
      end
    end
  end

  // valid_mo_instr is ops_valid_i delayed by one cycle, as it is useful for 2-cycle instructions
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      valid_mo_instr <= 1'b0;
    end else begin
      if (mo_instr && pea_ready_i) begin
        valid_mo_instr <= ops_valid_i;
      end
    end
  end

  assign valid_o = valid;
  assign ready_o = 1'b1;


  ////////////////////////////////////////////////////////////////
  //                Radix-cfg Pipelined Divider                 //
  ////////////////////////////////////////////////////////////////

  div_wrapper_pipe div_wrapper_pipe_i (
      .clk_i(clk_cg),
      .rst_n_i(rst_n_i),
      .pea_ready_i(pea_ready_i),
      .a_i(div_op1),
      .b_i(div_op2),
      .in_valid_i(div_input_valid),
      .q_o(quotient_div),
      .r_o(remainder_div),
      .valid_o(out_div_valid)
  );

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
      if (pea_ready_i && instr_i == SGNCSUB) begin
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
      if (pea_ready_i) begin
        if (ops_valid_i) begin
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
          end else if (instr_i == ABSDIV) begin
            temp_res <= add_one_res;
          end else if (instr_i == CADDDIV) begin
            temp_res <= add_res[N_BITS:1];
          end else if (instr_i == ABSREM) begin
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
      if (pea_ready_i) begin
        if (instr_i == CADDMUL || instr_i == CMULADD || instr_i == ABSMIN || instr_i == CLSHSUB || instr_i == ABSDIV || instr_i == ABSREM || instr_i == CADDDIV) begin
          temp_op_reg <= b_signed;
        end else if (instr_i == SGNCSUB) begin
          temp_op_reg <= a_signed;
        end
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
    div_op1   = a_signed;
    div_op2   = b_signed;
    shift_op1 = {{32{a_signed[N_BITS-1]}}, a_signed};
    shift_op2 = b_signed;

    case (instr_i)
      NOP: begin
        add_op1   = '0;
        add_op2   = '0;
        mul_op1   = '0;
        mul_op2   = '0;
        div_op1   = '0;
        div_op2   = '0;
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

      ABSDIV: begin
        div_op1 = temp_res;
        div_op2 = temp_op_reg;
      end

      SHACC: begin
        shift_op1 = {{32{pe_res_i[N_BITS-1]}}, pe_res_i};
        shift_op2 = a_signed;
        add_op1   = {shift_res, 1'b0};
        add_op2   = {b_signed, 1'b0};
      end

      CADDDIV: begin
        add_op1 = {a_signed, 1'b0};
        add_op2 = {const_i, 1'b0};
        div_op1 = temp_op_reg;
        div_op2 = temp_res;
      end

      ABSREM: begin
        div_op1 = temp_res;
        div_op2 = temp_op_reg;
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
      DIV: res_o = quotient_div;
      REM: res_o = remainder_div;
      ADDPOW: res_o = mul_res;
      SUBPOW: res_o = mul_res;
      ABSDIV: res_o = quotient_div;
      SHACC: res_o = add_res[N_BITS:1];
      ABSREM: res_o = remainder_div;
      CADDDIV: res_o = quotient_div;
      CADDMUL: res_o = mul_res;
      ADDCMUL: res_o = mul_res;
      CMULADD: res_o = add_res[N_BITS:1];
      CLSHSUB: res_o = add_res[N_BITS:1];
      MULCARSH: res_o = shift_res;
      ABSMIN: res_o = (add_res[N_BITS-1]) ? temp_res : temp_op_reg;
      SGNCSUB: res_o = (|temp_op_reg == 1'b0) ? '0 : add_one_res;
      SGNSEL: res_o = delay_sign_i ? b_i : a_i;
      default: res_o = 0;
    endcase
  end

  /*
    rem_q_o:
      -> assigned to REMAINDER if the main result is the quotient
      -> assigned to QUOTIENT if the main result is the remainder
  */
  assign rem_q_o = (instr_i == DIV || instr_i == ABSDIV || instr_i == CADDDIV) ? remainder_div : ((instr_i == REM || instr_i == ABSREM) ? quotient_div : 0);


endmodule
