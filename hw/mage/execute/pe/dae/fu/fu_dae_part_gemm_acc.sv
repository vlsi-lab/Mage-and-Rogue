
// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: fu_dae_part_gemm_acc.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: FU for DAE mode supporting int32-16-8 (packed SIMD) computation of classic gemm-related operations and accumulations

module fu_dae_part_gemm_acc
  import pea_pkg::*;
(
    input  logic                   clk_i,
    input  logic                   rst_n_i,
    input  logic      [N_BITS-1:0] a_i,
    input  logic      [N_BITS-1:0] b_i,
    input  logic      [N_BITS-1:0] pe_res_i,
    input  logic      [       1:0] vec_mode_i,
    input  logic                   acc_match_i,
    input  fu_instr_t              instr_i,
    output logic      [N_BITS-1:0] res_o
);

  logic [N_BITS-1:0] op_a;

  ////////////////////////////////
  //  Part Multiplier Signals   //
  ////////////////////////////////
  logic [       7:0] mul_op_8_a;
  logic [       7:0] mul_op_8_b;
  logic [      15:0] mul_op_16_1_a;
  logic [      15:0] mul_op_16_1_b;
  logic [      15:0] mul_op_16_2_a;
  logic [      15:0] mul_op_16_2_b;
  logic [      15:0] mul_op_16_3_a;
  logic [      15:0] mul_op_16_3_b;
  logic [       7:0] mul_result_8;
  logic [      31:0] mul_result_16_1;
  logic [      15:0] mul_result_16_2;
  logic [      15:0] mul_result_16_3;
  logic [      31:0] mul_result_16_1_d;
  logic [      15:0] mul_result_16_2_d;
  logic [      15:0] mul_result_16_3_d;

  // Vector Mode
  logic              vec_mode_8;
  logic              vec_mode_16;
  logic              no_vec_mode;

  //fu signals
  logic [N_BITS-1:0] tmp_pe_res;

  //Accumulation signals
  logic              acc_match;
  logic [       4:0] output_ready_ff;
  logic              output_ready;
  logic [      17:0] adder_res_16_part;
  logic [      17:0] adder_16_part_in_a;
  logic [      17:0] adder_16_part_in_b;
  logic [       7:0] adder_8_res;


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
    op_a = a_i;
    if (!acc_match_i) begin
      op_a = pe_res_i;
    end
  end

  ////////////////////////////////
  //        Vector Mode         //
  ////////////////////////////////
  always_comb begin
    vec_mode_8  = vec_mode_i == 2'b01;
    vec_mode_16 = vec_mode_i == 2'b10;
    no_vec_mode = vec_mode_i == 2'b00;
  end

  ////////////////////////////////
  //      Part Multiplier       //
  ////////////////////////////////
  always_comb begin

    // default case is mul32
    mul_op_16_1_a = op_a[15:0];  //A_low
    mul_op_16_1_b = b_i[15:0];  //B_low
    mul_op_16_2_a = op_a[15:0];  //A_low
    mul_op_16_2_b = b_i[31:16];  //B_high
    mul_op_16_3_a = op_a[31:16];  //A_high
    mul_op_16_3_b = b_i[15:0];  //B_low
    mul_op_8_a = '0;
    mul_op_8_b = '0;

    if (instr_i == MUL) begin
      if (vec_mode_8) begin
        // mul8
        mul_op_8_a = op_a[7:0];
        mul_op_8_b = b_i[7:0];
        mul_op_16_1_a[7:0] = op_a[15:8];
        mul_op_16_1_b[7:0] = b_i[15:8];
        mul_op_16_2_a[7:0] = op_a[23:16];
        mul_op_16_2_b[7:0] = b_i[23:16];
        mul_op_16_3_a[7:0] = op_a[31:24];
        mul_op_16_3_b[7:0] = b_i[31:24];
      end else if (vec_mode_16) begin
        //mul16
        mul_op_16_1_a = op_a[15:0];
        mul_op_16_1_b = b_i[15:0];
        mul_op_16_2_a = op_a[31:16];
        mul_op_16_2_b = b_i[31:16];
        mul_op_16_3_a = '0;
        mul_op_16_3_b = '0;
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

  logic adder_op_b_negate;
  logic [15:0]
      adder_op_a_low,
      adder_op_b_low,
      adder_op_a_high,
      adder_op_b_high,
      operand_b_neg_low,
      operand_b_neg_high;
  logic [17:0] adder_in_a_low, adder_in_b_low, adder_in_a_high, adder_in_b_high;
  logic [31:0] adder_result;
  logic [18:0] adder_result_expanded_low, adder_result_expanded_high;

  assign adder_op_b_negate = (instr_i == SUB);

  // prepare operand a
  assign adder_op_a_low = op_a[15:0];
  assign adder_op_a_high = op_a[31:16];

  // prepare operand b
  assign adder_op_b_low = adder_op_b_negate ? operand_b_neg_low : b_i[15:0];
  assign adder_op_b_high = adder_op_b_negate ? operand_b_neg_high : b_i[31:16];

  assign operand_b_neg_low = ~b_i[15:0];
  assign operand_b_neg_high = ~b_i[31:16];

  // prepare carry
  always_comb begin
    // default is the 32-bit addition case
    adder_in_a_low[0]      = 1'b1;
    adder_in_a_low[8:1]    = adder_op_a_low[7:0];
    adder_in_a_low[9]      = 1'b1;
    adder_in_a_low[17:10]  = adder_op_a_low[15:8];
    adder_in_a_high[0]     = adder_result_expanded_low[18];
    adder_in_a_high[8:1]   = adder_op_a_high[7:0];
    adder_in_a_high[9]     = 1'b1;
    adder_in_a_high[17:10] = adder_op_a_high[15:8];

    adder_in_b_low[0]      = 1'b0;
    adder_in_b_low[8:1]    = adder_op_b_low[7:0];
    adder_in_b_low[9]      = 1'b0;
    adder_in_b_low[17:10]  = adder_op_b_low[15:8];
    adder_in_b_high[0]     = 1'b0;
    adder_in_b_high[8:1]   = adder_op_b_high[7:0];
    adder_in_b_high[9]     = 1'b0;
    adder_in_b_high[17:10] = adder_op_b_high[15:8];

    if (adder_op_b_negate) begin
      // special case for subtractions and absolute number calculations
      adder_in_b_low[0] = 1'b1;

      if (vec_mode_16) begin
        adder_in_a_high[0] = 1'b0;
        adder_in_b_high[0] = 1'b1;
      end else if (vec_mode_8) begin
        adder_in_a_high[0] = 1'b0;
        adder_in_b_low[9]  = 1'b1;
        adder_in_b_high[0] = 1'b1;
        adder_in_b_high[9] = 1'b1;
      end

    end else if (instr_i == ADD) begin
      // take care of partitioning the adder for the addition case
      if (vec_mode_16) begin
        adder_in_a_high[0] = 1'b0;
      end else if (vec_mode_8) begin
        adder_in_a_low[9]  = 1'b0;
        adder_in_a_high[0] = 1'b0;
        adder_in_a_high[9] = 1'b0;
      end
    end else if (instr_i == MUL && no_vec_mode) begin
      adder_in_a_low[8:1] = mul_result_16_2_d[7:0];
      adder_in_a_low[17:10] = mul_result_16_2_d[15:8];
      adder_in_b_low[8:1] = mul_result_16_3_d[7:0];
      adder_in_b_low[17:10] = mul_result_16_3_d[15:8];

      adder_in_a_high[8:1] = mul_result_16_1_d[23:16];
      adder_in_a_high[17:10] = mul_result_16_1_d[31:24];
      adder_in_b_high[8:1] = adder_result_expanded_low[8:1];
      adder_in_b_high[17:10] = adder_result_expanded_low[17:10];
    end
  end

  // actual adder
  assign adder_result_expanded_low = $signed(adder_in_a_low) + $signed(adder_in_b_low);
  assign adder_result_expanded_high = $signed(adder_in_a_high) + $signed(adder_in_b_high);
  assign adder_result = {
    adder_result_expanded_high[17:10],
    adder_result_expanded_high[8:1],
    adder_result_expanded_low[17:10],
    adder_result_expanded_low[8:1]
  };

  ////////////////////////////////
  //        Part Shifter        //
  ////////////////////////////////

  logic        shift_left;  // should we shift left
  logic        shift_arithmetic;

  logic [31:0] operand_a_rev;
  logic [31:0] operand_a_neg;
  logic [31:0] operand_a_neg_rev;

  logic [31:0] shift_amt_left;  // amount of shift, if to the left
  logic [31:0] shift_amt;  // amount of shift, to the right
  logic [31:0] shift_amt_int;  // amount of shift, used for the actual shifters
  logic [31:0] shift_op_a;  // input of the shifter
  logic [31:0] shift_result;
  logic [31:0] shift_right_result;
  logic [31:0] shift_left_result;

  assign shift_amt = b_i;

  assign operand_a_neg = ~op_a;
  // bit reverse operand_a_neg for left shifts and bit counting
  generate
    genvar m;
    for (m = 0; m < 32; m++) begin : gen_operand_a_neg_rev
      assign operand_a_neg_rev[m] = operand_a_neg[31-m];
    end
  endgenerate

  // bit reverse operand_a for left shifts
  generate
    genvar k;
    for (k = 0; k < 32; k++) begin : gen_operand_a_rev
      assign operand_a_rev[k] = op_a[31-k];
    end
  endgenerate

  // by reversing the bits of the input, we also have to reverse the order of shift amounts
  always_comb begin
    case (vec_mode_i)
      2'b01: begin
        shift_amt_left[15:0]  = shift_amt[31:16];
        shift_amt_left[31:16] = shift_amt[15:0];
      end

      2'b10: begin
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

  assign shift_arithmetic = (instr_i == ARSH)  || (instr_i == LRSH);

  // choose the bit reversed or the normal input for shift operand a
  assign shift_op_a    = shift_left ? operand_a_rev : op_a;
  assign shift_amt_int = shift_left ? shift_amt_left : shift_amt;

  // right shifts, we let the synthesizer optimize this
  logic [63:0] shift_op_a_32;

  assign shift_op_a_32 = $signed({{32{shift_arithmetic & shift_op_a[31]}}, shift_op_a});

  always_comb begin
    case (vec_mode_i)
      2'b01: begin
        shift_right_result[31:16] = $signed({shift_arithmetic & shift_op_a[31],
                                             shift_op_a[31:16]}) >>> shift_amt_int[19:16];
        shift_right_result[15:0] =
            $signed({shift_arithmetic & shift_op_a[15], shift_op_a[15:0]}) >>> shift_amt_int[3:0];
      end

      2'b10: begin
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
          res_o = {adder_result[15:0], mul_result_16_1_d[15:0]};
        end
      end

      ADD: res_o = adder_result;

      ACC: begin
        if (output_ready && vec_mode_8) begin
          res_o = {{24{adder_8_res[7]}}, adder_8_res};
        end else if (output_ready && vec_mode_16) begin
          res_o = {{16{adder_res_16_part[17]}}, adder_res_16_part[17:10], adder_res_16_part[8:1]};
        end else begin
          res_o = adder_result;
        end
      end

      SUB: res_o = adder_result;
      LSH: res_o = shift_result;
      ARSH: res_o = shift_result;
      LRSH: res_o = shift_result;
      ABS: res_o = a_signed[N_BITS-1] ? adder_result[N_BITS:1] : a_signed;
      MAX:
      res_o = (a_signed[N_BITS-1] == 1'b0) ? ((adder_result[N_BITS-1] != a_signed[N_BITS-1]) ? b_signed : a_signed) :
                                                  ((adder_result[N_BITS-1] == a_signed[N_BITS-1]) ? b_signed : a_signed);
      MIN:
      res_o = (a_signed[N_BITS-1] == 1'b0) ? ((adder_result[N_BITS-1] != a_signed[N_BITS-1]) ? a_signed : b_signed) :
                                                  ((adder_result[N_BITS-1] == a_signed[N_BITS-1]) ? a_signed : b_signed);

      default: res_o = 0;
    endcase
  end

  ////////////////////////////////////////////////////////////////
  // 16-bit and 8-bit Adders for Vector Mode Final Accumulation //
  ////////////////////////////////////////////////////////////////

  //PE temporary output register holding the operand to consider for vecmode 8 and 16 accumulation final stage
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      tmp_pe_res <= 0;
    end else begin
      if (acc_match) begin
        tmp_pe_res <= pe_res_i;
      end
    end
  end

  // delay acc_match to create the signal that is asserted when the output is ready
  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (~rst_n_i) begin
      output_ready_ff <= 0;
    end else begin
      output_ready_ff[0] <= acc_match;
      for (int i = 1; i < 5; i++) begin
        output_ready_ff[i] <= output_ready_ff[i-1];
      end
    end
  end

  // Depending on the vector mode, the actual output ready signal differs
  always_comb begin
    if (vec_mode_8) begin
      output_ready = output_ready_ff[2];
    end else if (vec_mode_16) begin
      output_ready = output_ready_ff[1];
    end else begin
      output_ready = acc_match;
    end
  end

  // partitioned 16-bit adder for:
  // vec16 mode final addition in the accumulation process
  // first vec8 addtion in the accumulation process
  always_comb begin
    adder_16_part_in_a[0]     = 1'b1;
    adder_16_part_in_a[8:1]   = tmp_pe_res[7:0];
    adder_16_part_in_a[9]     = 1'b1;
    adder_16_part_in_a[17:10] = tmp_pe_res[15:8];

    adder_16_part_in_b[0]     = 1'b0;
    adder_16_part_in_b[8:1]   = tmp_pe_res[23:16];
    adder_16_part_in_b[9]     = 1'b0;
    adder_16_part_in_b[17:10] = tmp_pe_res[31:24];

    if (vec_mode_8) begin
      adder_16_part_in_a[9] = 1'b0;
    end
  end

  // adder and register
  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (~rst_n_i) begin
      adder_res_16_part <= 0;
    end else begin
      adder_res_16_part <= $signed(adder_16_part_in_a) + $signed(adder_16_part_in_b);
    end
  end

  // 8-bit adder and register (Final vec8 addition)
  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (~rst_n_i) begin
      adder_8_res <= 0;
    end else begin
      adder_8_res <= $signed(adder_res_16_part[8:1]) + $signed(adder_res_16_part[17:10]);
    end
  end

endmodule
