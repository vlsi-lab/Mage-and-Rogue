
// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: part_mul.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: packed SIMD partitioned mul

module part_mul
  import pea_pkg::*;
(
    input  logic [N_BITS-1:0] mul_op1_i,
    input  logic [N_BITS-1:0] mul_op2_i,
    input  logic [       2:0] vec_mode_i,
    output logic [N_BITS-1:0] mul_res_o
);

  //logic valid;

  ////////////////////////////////
  //  Part Multiplier Signals   //
  ////////////////////////////////
  logic [ 7:0] mul_op_8_a;
  logic [ 7:0] mul_op_8_b;
  logic [15:0] mul_op_16_1_a;
  logic [15:0] mul_op_16_1_b;
  logic [15:0] mul_op_16_2_a;
  logic [15:0] mul_op_16_2_b;
  logic [15:0] mul_op_16_3_a;
  logic [15:0] mul_op_16_3_b;
  logic [ 7:0] mul_result_8;
  logic [31:0] mul_result_16_1;
  logic [15:0] mul_result_16_2;
  logic [15:0] mul_result_16_3;
  logic [31:0] mul_result_16_1_d;
  logic [15:0] mul_result_16_2_d;
  logic [15:0] mul_result_16_3_d;

  // Vector Mode
  logic        vec_mode_8;
  logic        vec_mode_16;
  logic        no_vec_mode;

  //Accumulation signals
  //logic [N_BITS-1:0] feedback_acc;
  //logic              acc_match;
  //logic [17:0] adder_res_16_part;
  //logic [17:0] adder_16_part_in_a;
  //logic [17:0] adder_16_part_in_b;
  //logic [ 7:0] adder_8_res;

  ////////////////////////////////
  //        Vector Mode         //
  ////////////////////////////////
  always_comb begin
    vec_mode_8  = (vec_mode_i == 3'b001 || vec_mode_i == 3'b101);
    vec_mode_16 = (vec_mode_i == 3'b010 || vec_mode_i == 3'b110);
    no_vec_mode = (vec_mode_i == 3'b000 || vec_mode_i == 3'b100);
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

    if (vec_mode_8) begin
      // mul8
      mul_op_8_a = mul_op1_i[7:0];
      mul_op_8_b = mul_op2_i[7:0];
      mul_op_16_1_a[7:0] = mul_op1_i[15:8];
      mul_op_16_1_b[7:0] = mul_op2_i[15:8];
      mul_op_16_2_a[7:0] = mul_op1_i[23:16];
      mul_op_16_2_b[7:0] = mul_op2_i[23:16];
      mul_op_16_3_a[7:0] = mul_op1_i[31:24];
      mul_op_16_3_b[7:0] = mul_op2_i[31:24];
    end else if (vec_mode_16) begin
      //mul16
      mul_op_16_1_a = mul_op1_i[15:0];
      mul_op_16_1_b = mul_op2_i[15:0];
      mul_op_16_2_a = mul_op1_i[31:16];
      mul_op_16_2_b = mul_op2_i[31:16];
      mul_op_16_3_a = '0;
      mul_op_16_3_b = '0;
    end else begin
      // mul32
      mul_op_16_1_a = mul_op1_i[15:0];
      mul_op_16_1_b = mul_op2_i[15:0];
      mul_op_16_2_a = mul_op1_i[15:0];
      mul_op_16_2_b = mul_op2_i[31:16];
      mul_op_16_3_a = mul_op1_i[31:16];
      mul_op_16_3_b = mul_op2_i[15:0];
      mul_op_8_a = '0;
      mul_op_8_b = '0;
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
  /* always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      mul_result_16_1_d <= '0;
      mul_result_16_2_d <= '0;
      mul_result_16_3_d <= '0;
    end else begin
      if (no_vec_mode) begin
        mul_result_16_1_d <= mul_result_16_1;
        mul_result_16_2_d <= mul_result_16_2;
        mul_result_16_3_d <= mul_result_16_3;
      end else begin
        mul_result_16_1_d <= '0;
        mul_result_16_2_d <= '0;
        mul_result_16_3_d <= '0;
      end
    end
  end */

  always_comb begin
    if (no_vec_mode) begin
      mul_result_16_1_d = mul_result_16_1;
      mul_result_16_2_d = mul_result_16_2;
      mul_result_16_3_d = mul_result_16_3;
    end else begin
      mul_result_16_1_d = '0;
      mul_result_16_2_d = '0;
      mul_result_16_3_d = '0;
    end
  end


  /////////////////////////////////
  //Part Add/Sub (based on RI5CY)//
  /////////////////////////////////

  logic [35:0] adder_in_a, adder_in_b;
  logic [31:0] adder_result;
  logic [36:0] adder_result_expanded;

  // prepare carry
  always_comb begin
    // default is the 32-bit addition case
    adder_in_a[0]     = 1'b1;
    adder_in_a[8:1]   = mul_result_16_2_d[7:0];
    adder_in_a[9]     = 1'b1;
    adder_in_a[17:10] = mul_result_16_2_d[15:8];
    adder_in_a[18]    = 1'b0;
    adder_in_a[26:19] = mul_result_16_1_d[23:16];
    adder_in_a[27]    = 1'b1;
    adder_in_a[35:28] = mul_result_16_1_d[31:24];

    adder_in_b[0]     = 1'b0;
    adder_in_b[8:1]   = mul_result_16_3_d[7:0];
    adder_in_b[9]     = 1'b0;
    adder_in_b[17:10] = mul_result_16_3_d[15:8];
    adder_in_b[18]    = 1'b0;
    adder_in_b[26:19] = adder_result_expanded[8:1];
    adder_in_b[27]    = 1'b0;
    adder_in_b[35:28] = adder_result_expanded[17:10];
  end

  // actual adder
  assign adder_result_expanded = $signed(adder_in_a) + $signed(adder_in_b);
  assign adder_result = {
    adder_result_expanded[35:28],
    adder_result_expanded[26:19],
    adder_result_expanded[17:10],
    adder_result_expanded[8:1]
  };

  ////////////////////////////////
  //     Output Assignment      //
  ////////////////////////////////
  always_comb begin
    if (vec_mode_8) begin
      mul_res_o = {mul_result_16_3[7:0], mul_result_16_2[7:0], mul_result_16_1[7:0], mul_result_8};
    end else if (vec_mode_16) begin
      mul_res_o = {mul_result_16_2[15:0], mul_result_16_1[15:0]};
    end else begin
      mul_res_o = {adder_result[31:16], mul_result_16_1_d[15:0]};
    end
  end



  // valid assignment
  /* always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (~rst_n_i) begin
      valid <= 0;
    end else begin
        if (vec_mode_i == 2'b10) begin
            valid <= op_valid_i;
        end
    end
  end */

  /* always_comb begin
    if (vec_mode_i == 2'b10) begin
      valid_o = valid;
    end else begin
      valid_o = op_valid_i;
    end
  end */

endmodule
