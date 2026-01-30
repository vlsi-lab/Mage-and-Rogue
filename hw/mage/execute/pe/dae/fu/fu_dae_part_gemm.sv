
// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: fu_dae_part_gemm.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: FU for DAE mode supporting int32-16-8 (packed SIMD) computation of classic gemm-related operations

module fu_dae_part_gemm
  import pea_pkg::*;
(
    input  logic                   clk_i,
    input  logic                   rst_n_i,
    input  logic      [N_BITS-1:0] a_i,
    input  logic      [N_BITS-1:0] b_i,
    input  logic      [       1:0] vec_mode_i,
    input  fu_instr_t              instr_i,
    output logic      [N_BITS-1:0] res_o
);

  ////////////////////////////////
  //  Part Multiplier Signals   //
  ////////////////////////////////
  logic [7:0] mul_op_8_a;
  logic [7:0] mul_op_8_b;
  logic [15:0] mul_op_16_1_a;
  logic [15:0] mul_op_16_1_b;
  logic [15:0] mul_op_16_2_a;
  logic [15:0] mul_op_16_2_b;
  logic [15:0] mul_op_16_3_a;
  logic [15:0] mul_op_16_3_b;
  logic [7:0] mul_result_8;
  logic [31:0] mul_result_16_1;
  logic [15:0] mul_result_16_2;
  logic [15:0] mul_result_16_3;
  logic [31:0] mul_result_16_1_d;
  logic [15:0] mul_result_16_2_d;
  logic [15:0] mul_result_16_3_d;

  // Vector Mode
  logic vec_mode_8;
  logic vec_mode_16;
  logic no_vec_mode;

  always_comb begin
    vec_mode_8  = vec_mode_i == 2'b01;
    vec_mode_16 = vec_mode_i == 2'b10;
    no_vec_mode = vec_mode_i == 2'b00;
  end

  ////////////////////////////////
  //      Part Multiplier       //
  ////////////////////////////////
  always_comb begin

    mul_op_16_1_a = '0;
    mul_op_16_1_b = '0;
    mul_op_16_2_a = '0;
    mul_op_16_2_b = '0;
    mul_op_16_3_a = '0;
    mul_op_16_3_b = '0;
    mul_op_8_a = '0;
    mul_op_8_b = '0;

    if (instr_i == MUL) begin
      if (vec_mode_8) begin
        // mul8
        mul_op_8_a = a_i[7:0];
        mul_op_8_b = b_i[7:0];
        mul_op_16_1_a[7:0] = a_i[15:8];
        mul_op_16_1_b[7:0] = b_i[15:8];
        mul_op_16_2_a[7:0] = a_i[23:16];
        mul_op_16_2_b[7:0] = b_i[23:16];
        mul_op_16_3_a[7:0] = a_i[31:24];
        mul_op_16_3_b[7:0] = b_i[31:24];
      end else if (vec_mode_16) begin
        //mul16
        mul_op_16_1_a = a_i[15:0];
        mul_op_16_1_b = b_i[15:0];
        mul_op_16_2_a = a_i[31:16];
        mul_op_16_2_b = b_i[31:16];
        mul_op_16_3_a = '0;
        mul_op_16_3_b = '0;
      end else begin
        // mul32
        mul_op_16_1_a = a_i[15:0];
        mul_op_16_1_b = b_i[15:0];
        mul_op_16_2_a = a_i[15:0];
        mul_op_16_2_b = b_i[31:16];
        mul_op_16_3_a = a_i[31:16];
        mul_op_16_3_b = b_i[15:0];
        mul_op_8_a = '0;
        mul_op_8_b = '0;
      end
    end
  end

  // Multipliers outputs
  always_comb begin
    mul_result_8 = mul_op_8_a * mul_op_8_b;
    mul_result_16_1 = mul_op_16_1_a * mul_op_16_1_b;
    mul_result_16_2 = mul_op_16_2_a * mul_op_16_2_b;
    mul_result_16_3 = mul_op_16_3_a * mul_op_16_3_b;
  end

  // delaying results for 32-bit multiplication
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      mul_result_16_1_d <= '0;
      mul_result_16_2_d <= '0;
      mul_result_16_3_d <= '0;
    end else begin
      if (instr_i == MUL && no_vec_mode) begin
        mul_result_16_1_d <= mul_result_16_1;
        mul_result_16_2_d <= mul_result_16_2;
        mul_result_16_3_d <= mul_result_16_3;
      end else begin
        mul_result_16_1_d <= '0;
        mul_result_16_2_d <= '0;
        mul_result_16_3_d <= '0;
      end
    end
  end


  /////////////////////////////////
  //Part Add/Sub (based on RI5CY)//
  /////////////////////////////////
  logic is_add_instr;

  logic adder_op_b_negate;
  logic [31:0] adder_op_a, adder_op_b, operand_b_neg;
  logic [35:0] adder_in_a, adder_in_b;
  logic [31:0] adder_result;
  logic [36:0] adder_result_expanded;

  assign is_add_instr = (instr_i == SUB || instr_i == ADD);

  assign adder_op_b_negate = (instr_i == SUB);

  // prepare operand a
  assign adder_op_a = is_add_instr ? a_i : '0;

  // prepare operand b
  assign adder_op_b = is_add_instr ? (adder_op_b_negate ? operand_b_neg : b_i) : '0;

  assign operand_b_neg = is_add_instr ? ~b_i : '0;

  // prepare carry
  always_comb begin
    // default is the 32-bit addition case
    adder_in_a[0]     = 1'b1;
    adder_in_a[8:1]   = adder_op_a[7:0];
    adder_in_a[9]     = 1'b1;
    adder_in_a[17:10] = adder_op_a[15:8];
    adder_in_a[18]    = 1'b1;
    adder_in_a[26:19] = adder_op_a[23:16];
    adder_in_a[27]    = 1'b1;
    adder_in_a[35:28] = adder_op_a[31:24];

    adder_in_b[0]     = 1'b0;
    adder_in_b[8:1]   = adder_op_b[7:0];
    adder_in_b[9]     = 1'b0;
    adder_in_b[17:10] = adder_op_b[15:8];
    adder_in_b[18]    = 1'b0;
    adder_in_b[26:19] = adder_op_b[23:16];
    adder_in_b[27]    = 1'b0;
    adder_in_b[35:28] = adder_op_b[31:24];

    if (adder_op_b_negate) begin
      // special case for subtractions
      adder_in_b[0] = 1'b1;

      if (vec_mode_16) begin
        adder_in_a[18] = 1'b1;
        adder_in_b[18] = 1'b1;
      end else if (vec_mode_8) begin
        adder_in_a[18] = 1'b1;
        adder_in_b[9]  = 1'b1;
        adder_in_b[18] = 1'b1;
        adder_in_b[27] = 1'b1;
      end

    end else if (instr_i == ADD) begin
      // take care of partitioning the adder for the addition case
      if (vec_mode_16) begin
        adder_in_a[18] = 1'b0;
      end else if (vec_mode_8) begin
        adder_in_a[9]  = 1'b0;
        adder_in_a[18] = 1'b0;
        adder_in_a[27] = 1'b0;
      end
    end else if (instr_i == MUL && no_vec_mode) begin
      adder_in_a[8:1] = mul_result_16_2_d[7:0];
      adder_in_a[17:10] = mul_result_16_2_d[15:8];
      adder_in_b[8:1] = mul_result_16_3_d[7:0];
      adder_in_b[17:10] = mul_result_16_3_d[15:8];

      adder_in_a[18] = 1'b0;

      adder_in_a[26:19] = mul_result_16_1_d[23:16];
      adder_in_a[35:28] = mul_result_16_1_d[31:24];
      adder_in_b[26:19] = adder_result_expanded[8:1];
      adder_in_b[35:28] = adder_result_expanded[17:10];
    end
  end

  // actual adder
  assign adder_result_expanded  = (instr_i == ADD || instr_i == SUB || (instr_i == MUL && no_vec_mode)) ? ($signed(
      adder_in_a
  ) + $signed(
      adder_in_b
  )) : '0;
  assign adder_result = {
    adder_result_expanded[35:28],
    adder_result_expanded[26:19],
    adder_result_expanded[17:10],
    adder_result_expanded[8:1]
  };

  ////////////////////////////////
  //        Part Shifter        //
  ////////////////////////////////

  logic        shift_left;  // should we shift left
  logic        shift_arithmetic;
  logic        is_shift_instr;

  logic [31:0] operand_a_rev;

  logic [31:0] shift_amt_left;  // amount of shift, if to the left
  logic [31:0] shift_amt;  // amount of shift, to the right
  logic [31:0] shift_amt_int;  // amount of shift, used for the actual shifters
  logic [31:0] shift_op_a;  // input of the shifter
  logic [31:0] shift_result;
  logic [31:0] shift_right_result;
  logic [31:0] shift_left_result;

  assign is_shift_instr = (instr_i == LSH || instr_i == ARSH || instr_i == LRSH);

  assign shift_amt = is_shift_instr ? b_i : '0;

  // bit reverse operand_a for left shifts
  generate
    genvar k;
    for (k = 0; k < 32; k++) begin : gen_operand_a_rev
      assign operand_a_rev[k] = a_i[31-k];
    end
  endgenerate

  // by reversing the bits of the input, we also have to reverse the order of shift amounts
  always_comb begin
    case (vec_mode_i)
      2'b10: begin
        shift_amt_left[15:0]  = shift_amt[31:16];
        shift_amt_left[31:16] = shift_amt[15:0];
      end

      2'b01: begin
        shift_amt_left[7:0]   = shift_amt[31:24];
        shift_amt_left[15:8]  = shift_amt[23:16];
        shift_amt_left[23:16] = shift_amt[15:8];
        shift_amt_left[31:24] = shift_amt[7:0];
      end

      default: // VEC_MODE32
      begin
        shift_amt_left[31:0] = shift_amt[31:0];
      end
    endcase
  end

  // ALU_FL1 and ALU_CBL are used for the bit counting ops later
  assign shift_left = (instr_i == LSH);

  assign shift_arithmetic = instr_i == ARSH;

  // choose the bit reversed or the normal input for shift operand a
  assign shift_op_a    = is_shift_instr ? (shift_left ? operand_a_rev : a_i) : '0;
  assign shift_amt_int = is_shift_instr ? (shift_left ? shift_amt_left : shift_amt) : '0;

  // right shifts, we let the synthesizer optimize this
  logic [63:0] shift_op_a_32;

  assign shift_op_a_32 = $signed({{32{shift_arithmetic & shift_op_a[31]}}, shift_op_a});

  always_comb begin
    case (vec_mode_i)
      2'b10: begin
        shift_right_result[31:16] = $signed({shift_arithmetic & shift_op_a[31],
                                             shift_op_a[31:16]}) >>> shift_amt_int[19:16];
        shift_right_result[15:0] =
            $signed({shift_arithmetic & shift_op_a[15], shift_op_a[15:0]}) >>> shift_amt_int[3:0];
      end

      2'b01: begin
        shift_right_result[31:24] = $signed({shift_arithmetic & shift_op_a[31],
                                             shift_op_a[31:24]}) >>> shift_amt_int[26:24];
        shift_right_result[23:16] = $signed({shift_arithmetic & shift_op_a[23],
                                             shift_op_a[23:16]}) >>> shift_amt_int[18:16];
        shift_right_result[15:8] =
            $signed({shift_arithmetic & shift_op_a[15], shift_op_a[15:8]}) >>> shift_amt_int[10:8];
        shift_right_result[7:0] = $signed({shift_arithmetic & shift_op_a[7], shift_op_a[7:0]}) >>>
            shift_amt_int[2:0];
      end

      default: // VEC_MODE32
      begin
        shift_right_result = shift_op_a_32 >> shift_amt_int[4:0];
      end
    endcase
    ;  // case (vec_mode_i)
  end

  // bit reverse the shift_right_result for left shifts
  genvar j;
  generate
    for (j = 0; j < 32; j++) begin : gen_shift_left_result
      assign shift_left_result[j] = shift_right_result[31-j];
    end
  endgenerate

  assign shift_result = shift_left ? shift_left_result : shift_right_result;

  ////////////////////////////////
  //     Output Assignment      //
  ////////////////////////////////
  always_comb begin
    case (instr_i)
      NOP: res_o = '0;
      MUL: begin
        if (vec_mode_8) begin
          res_o = {mul_result_16_3[7:0], mul_result_16_2[7:0], mul_result_16_1[7:0], mul_result_8};
        end else if (vec_mode_16) begin
          res_o = {mul_result_16_2[15:0], mul_result_16_1[15:0]};
        end else begin
          res_o = {adder_result[31:16], mul_result_16_1_d[15:0]};
        end
      end

      ADD:  res_o = adder_result;
      SUB:  res_o = adder_result;
      LSH:  res_o = shift_result;
      ARSH: res_o = shift_result;
      LRSH: res_o = shift_result;
      FW_A: res_o = a_i;
      FW_B: res_o = b_i;

      default: res_o = 0;
    endcase
  end

endmodule
