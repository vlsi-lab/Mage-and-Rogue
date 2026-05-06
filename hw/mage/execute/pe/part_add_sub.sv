
// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: part_add_sub.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: packed SIMD partitioned add/sub/acc

module part_add_sub
  import pea_pkg::*;
(
    input  logic [N_BITS-1:0] add_op1_i,
    input  logic [N_BITS-1:0] add_op2_i,
    input  logic [       2:0] vec_mode_i,
    input  logic [       1:0] instr_i,
    output logic [N_BITS-1:0] add_res_o
);


  // Vector Mode
  logic vec_mode_8;
  logic vec_mode_16;
  logic acc_mode;

  ////////////////////////////////
  //        Vector Mode         //
  ////////////////////////////////
  always_comb begin
    vec_mode_8  = (vec_mode_i == 3'b001 || vec_mode_i == 3'b101);
    vec_mode_16 = (vec_mode_i == 3'b010 || vec_mode_i == 3'b110);
    acc_mode    = vec_mode_i[2];
  end

  /////////////////////////////////
  //Part Add/Sub (based on RI5CY)//
  /////////////////////////////////

  logic adder_op_b_negate;
  logic [31:0] adder_op_a, adder_op_b, operand_b_neg;
  logic [35:0] adder_in_a, adder_in_b;
  logic [31:0] adder_result;
  logic [36:0] adder_result_expanded;

  assign adder_op_b_negate = (instr_i == 2'b01);

  // prepare operand a
  assign adder_op_a = add_op1_i;

  // prepare operand b
  assign operand_b_neg = ~add_op2_i;
  assign adder_op_b = adder_op_b_negate ? operand_b_neg : add_op2_i;


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

    end else if (instr_i == 2'b00) begin

      if (vec_mode_16) begin
        // ADD16: adding two lanes of 16-bit data truncating the result to 16-bit
        adder_in_a[18] = 1'b0;
      end else if (vec_mode_8) begin
        // ADD8: adding four lanes of 8-bit data truncating the result to 8-bit
        adder_in_a[9]  = 1'b0;
        adder_in_a[18] = 1'b0;
        adder_in_a[27] = 1'b0;
      end

    end else if (instr_i == 2'b10) begin

      if (vec_mode_16 && !acc_mode) begin
        // ACC16: adding two lanes of 16-bit data and accumulating the result on 16-bit
        adder_in_a[18] = 1'b0;
      end else if (vec_mode_8 && !acc_mode) begin
        // ACC8: adding four lanes of 8-bit data and accumulating the result on 8-bit
        adder_in_a[9]  = 1'b0;
        adder_in_a[18] = 1'b0;
        adder_in_a[27] = 1'b0;
      end else if (vec_mode_8 && acc_mode) begin
        // ACC8-32: adding four lanes of 8-bit data and accumulating the result on 32-bit
        adder_in_a[18] = 1'b0;
      end
      //default is the ACC32 accumulation case and ACC16-32, which requires no special handling as the carry is already set for 32-bit addition

    end

    if (instr_i == 2'b10) begin
      if (vec_mode_16) begin
        // ACC16 and ACC16-32: adding two lanes of 16-bit data and accumulating the result on 16-bit
        // this adder adds together the two 16-bit parts of the first operand,  as the seconds operand add_op2_i contains loopback
        // the result is on 16 bits or 32 bits depending on the accumulation mode 
        adder_in_a[8:1]   = adder_op_b[7:0];
        adder_in_a[17:10] = adder_op_b[15:8];
        if(acc_mode) begin
          adder_in_a[26:19] = {8{adder_op_b[15]}};
          adder_in_a[35:28] = {8{adder_op_b[15]}};
        end else begin
          adder_in_a[26:19] = '0;
          adder_in_a[35:28] = '0;
        end

        adder_in_b[8:1]   = adder_op_b[23:16];
        adder_in_b[17:10] = adder_op_b[31:24];
        if(acc_mode) begin
          adder_in_b[26:19] = {8{adder_op_b[31]}};
          adder_in_b[35:28] = {8{adder_op_b[31]}};
        end else begin
          adder_in_b[26:19] = '0;
          adder_in_b[35:28] = '0;
        end
      end else if (vec_mode_8) begin
        // ACC8 and ACC8-32: adding 2 8-bit fields of the first operand
        // the result is on 8 bits or 16 bits depending on the accumulation mode
        adder_in_a[8:1]   = adder_op_b[7:0];
        adder_in_a[17:10] = acc_mode ? {8{adder_op_b[7]}} : '0;
        adder_in_a[26:19] = adder_op_b[15:8];
        adder_in_a[35:28] = acc_mode ? {8{adder_op_b[15]}} : '0;

        adder_in_b[8:1]   = adder_op_b[23:16];
        adder_in_b[17:10] = acc_mode ? {8{adder_op_b[23]}} : '0;
        adder_in_b[26:19] = adder_op_b[31:24];
        adder_in_b[35:28] = acc_mode ? {8{adder_op_b[31]}} : '0;

      end
    end

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

    add_res_o = '0;

    case (instr_i)

      2'b00: add_res_o = adder_result;

      2'b01: add_res_o = adder_result;

      2'b10: begin
        if (vec_mode_16 && !acc_mode) begin
          // ACC16: result is truncated to 16 bits
          add_res_o = {
            {16{acc_adder_part_16_res[17]}},
            acc_adder_part_16_res[17:10],
            acc_adder_part_16_res[8:1]
          };
        end else if (vec_mode_16 && acc_mode) begin
          add_res_o = {
            acc_adder_part_16_res[35:28],
            acc_adder_part_16_res[26:19],
            acc_adder_part_16_res[17:10],
            acc_adder_part_16_res[8:1]
          };
        end else if (vec_mode_8 && !acc_mode) begin
          // ACC8: result is truncated to 8 bits
          add_res_o = {{24{acc_adder_part_8_res[7]}}, acc_adder_part_8_res[7:0]};
        end else if (vec_mode_8 && acc_mode) begin
          add_res_o = acc_adder_part_8_res;
        end else begin
          add_res_o = adder_result;
        end
      end

      default: begin
        add_res_o = 0;
      end

    endcase
  end

  ////////////////////////////////////////////////////////////////
  // 16-bit and 8-bit Adders for Vector Mode Final Accumulation //
  ////////////////////////////////////////////////////////////////

  //Accumulation signals
  logic [35:0] acc_adder_part_16_res;
  logic [35:0] acc_adder_part_16_a;
  logic [35:0] acc_adder_part_16_b;
  logic [31:0] acc_adder_part_8_res;
  logic [31:0] acc_adder_part_8_a;
  logic [31:0] acc_adder_part_8_b;


  // partitioned 16-bit adder for:
  // vec16 mode final addition in the accumulation process
  // first vec8 addtion in the accumulation process
  always_comb begin
    //default : // add on int16 and acc on int32
    acc_adder_part_16_a = '0;
    acc_adder_part_16_b = '0;

    if (vec_mode_16 && acc_mode) begin
      // ACC16-32: this adder adds together the 16-bit result of the first adder with the 16-bit accumulation result from the previous iteration,
      // which is looped back on add_op2_i.
      // Results is on 32 bits

      acc_adder_part_16_a[0]     = 1'b0;
      acc_adder_part_16_a[8:1]   = adder_result[7:0];
      acc_adder_part_16_a[9]     = 1'b1;
      acc_adder_part_16_a[17:10] = adder_result[15:8];
      acc_adder_part_16_a[18]    = 1'b1;
      acc_adder_part_16_a[26:19] = adder_result[23:16];
      acc_adder_part_16_a[27]    = 1'b1;
      acc_adder_part_16_a[35:28] = adder_result[31:24];

      acc_adder_part_16_b[0]     = 1'b0;
      acc_adder_part_16_b[8:1]   = add_op1_i[7:0];
      acc_adder_part_16_b[9]     = 1'b0;
      acc_adder_part_16_b[17:10] = add_op1_i[15:8];
      acc_adder_part_16_b[18]    = 1'b0;
      acc_adder_part_16_b[26:19] = add_op1_i[23:16];
      acc_adder_part_16_b[27]    = 1'b0;
      acc_adder_part_16_b[35:28] = add_op1_i[31:24];

    end else if (vec_mode_16 && !acc_mode) begin
      // ACC16: this adder adds together the 16-bit result of the first adder with the 16-bit accumulation result from the previous iteration,
      // which is looped back on add_op1_i. Result is truncated to 16 bits

      acc_adder_part_16_a[0]     = 1'b0;
      acc_adder_part_16_a[8:1]   = adder_result[7:0];
      acc_adder_part_16_a[9]     = 1'b1;
      acc_adder_part_16_a[17:10] = adder_result[15:8];
      acc_adder_part_16_a[18]    = 1'b0;
      acc_adder_part_16_a[26:19] = '0;
      acc_adder_part_16_a[27]    = 1'b1;
      acc_adder_part_16_a[35:28] = '0;

      acc_adder_part_16_b[0]     = 1'b0;
      acc_adder_part_16_b[8:1]   = add_op1_i[7:0];
      acc_adder_part_16_b[9]     = 1'b0;
      acc_adder_part_16_b[17:10] = add_op1_i[15:8];
      acc_adder_part_16_b[18]    = 1'b0;
      acc_adder_part_16_b[26:19] = '0;
      acc_adder_part_16_b[27]    = 1'b0;
      acc_adder_part_16_b[35:28] = '0;

    end else if (vec_mode_8 && acc_mode) begin
      // ACC8-32: this adder adds together the two 16-bit results prduced by the first adder on 16 bits

      acc_adder_part_16_a[0]     = 1'b0;
      acc_adder_part_16_a[8:1]   = adder_result[7:0];
      acc_adder_part_16_a[9]     = 1'b1;
      acc_adder_part_16_a[17:10] = adder_result[15:8];
      acc_adder_part_16_a[18]    = 1'b1;
      acc_adder_part_16_a[26:19] = {8{adder_result[15]}};
      acc_adder_part_16_a[27]    = 1'b1;
      acc_adder_part_16_a[35:28] = {8{adder_result[15]}};

      acc_adder_part_16_b[0]     = 1'b0;
      acc_adder_part_16_b[8:1]   = adder_result[23:16];
      acc_adder_part_16_b[9]     = 1'b0;
      acc_adder_part_16_b[17:10] = adder_result[31:24];
      acc_adder_part_16_b[18]    = 1'b0;
      acc_adder_part_16_b[26:19] = {8{adder_result[31]}};
      acc_adder_part_16_b[27]    = 1'b0;
      acc_adder_part_16_b[35:28] = {8{adder_result[31]}};
    end else if (vec_mode_8 && !acc_mode) begin
      // ACC8: this adder adds together the two 16-bit results prduced by the first adder, result is truncated to 16 bits

      acc_adder_part_16_a[0]     = 1'b0;
      acc_adder_part_16_a[8:1]   = adder_result[7:0];
      acc_adder_part_16_a[9]     = 1'b0;
      acc_adder_part_16_a[17:10] = '0;
      acc_adder_part_16_a[18]    = 1'b0;
      acc_adder_part_16_a[26:19] = '0;
      acc_adder_part_16_a[27]    = 1'b1;
      acc_adder_part_16_a[35:28] = '0;

      acc_adder_part_16_b[0]     = 1'b0;
      acc_adder_part_16_b[8:1]   = adder_result[23:16];
      acc_adder_part_16_b[9]     = 1'b0;
      acc_adder_part_16_b[17:10] = '0;
      acc_adder_part_16_b[18]    = 1'b0;
      acc_adder_part_16_b[26:19] = '0;
      acc_adder_part_16_b[27]    = 1'b0;
      acc_adder_part_16_b[35:28] = '0;
    end

  end

  always_comb begin

    acc_adder_part_8_a = '0;
    acc_adder_part_8_b = '0;

    if (vec_mode_8 && acc_mode) begin
      // ACC8-32: this adder adds together the 16-bit result produced by the second adder on 16 bits and the loopback result on 32, result is on 32 bits
      acc_adder_part_8_a = {
        acc_adder_part_16_res[35:28],
        acc_adder_part_16_res[26:19],
        acc_adder_part_16_res[17:10],
        acc_adder_part_16_res[8:1]
      };

      acc_adder_part_8_b = add_op1_i;

    end else if (vec_mode_8 && !acc_mode) begin
      // ACC8: this adder adds together the 8-bit result produced by the second adder and the loopback result on 8, result is truncated to 8 bits

      acc_adder_part_8_a[7:0] = adder_result[8:1];

      acc_adder_part_8_b[7:0] = add_op1_i[7:0];

    end

  end

  always_comb begin
    acc_adder_part_16_res = '0;
    acc_adder_part_8_res  = '0;

    if (vec_mode_16 || vec_mode_8) begin
      acc_adder_part_16_res = $signed(acc_adder_part_16_a) + $signed(acc_adder_part_16_b);
    end
    
    if (vec_mode_8) begin
      acc_adder_part_8_res = $signed(acc_adder_part_8_a) + $signed(acc_adder_part_8_b);
    end
  end

endmodule
