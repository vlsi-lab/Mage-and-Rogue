// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: hwlp.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module is a 4-nested loop Hardware Loop Unit with the II-calculation functionality.

module hwlp
  import agu_pkg::*;
(
    input                                            clk_i,
    input                                            rst_n_i,
    //start signal for hwlp
    input  logic                                     count_en_i,
    //CSR register for II (must be set to II-1)
    input  logic       [NBIT_II-1:0]                 reg_II_i,
    //CSR register for loop variables bounds
    input  loop_vars_t [   N_LP-1:0]                 reg_loop_vars_i,
    //output loop variables
    output logic       [   N_LP-1:0][NBIT_LP_IV-1:0] loop_vars_o,
    //each bit is set to 1 when the related loop variable has to restart from initial value
    output logic       [   N_LP-1:0]                 end_condition_lp_o,
    //1 if all ivs are 0
    //this signal is used to indicate that the loop variables are valid for address calculation
    output logic                                     hwlp_valid_o,
    output logic                                     end_lp_o
);

  logic [   N_LP-1:0][NBIT_LP_IV-1:0] loop_vars;
  logic                               count_en;
  logic [NBIT_II-1:0]                 ii_count;
  logic [   N_LP-1:0]                 end_lp;
  logic [   N_LP-1:0]                 end_condition_lp;

  assign end_condition_lp_o = end_condition_lp;

  //II counter
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      ii_count <= 0;
    end else if (count_en_i == 1'b1) begin
      if (ii_count == reg_II_i) begin
        ii_count <= 0;
      end else begin
        ii_count <= ii_count + 1;
      end
    end else begin
      ii_count <= 0;
    end
  end

  always_comb begin
    hwlp_valid_o = (ii_count == '0 && count_en_i == 1'b1) ? 1'b1 : 1'b0;
    count_en     = (ii_count == reg_II_i && count_en_i == 1'b1) ? 1'b1 : 1'b0;
  end


  //Loop Counters

  assign end_condition_lp[0] = (loop_vars[0] == reg_loop_vars_i[0].fv) ? 1'b1 : 1'b0;
  assign end_condition_lp[1] = (loop_vars[1] == reg_loop_vars_i[1].fv) ? 1'b1 : 1'b0;
  assign end_condition_lp[2] = (loop_vars[2] == reg_loop_vars_i[2].fv) ? 1'b1 : 1'b0;
  assign end_condition_lp[3] = (loop_vars[3] == reg_loop_vars_i[3].fv) ? 1'b1 : 1'b0;

  always_ff @(posedge clk_i, negedge rst_n_i) begin

    if (!rst_n_i) begin
      for (int i = 0; i < N_LP; i = i + 1) begin
        loop_vars[i] <= reg_loop_vars_i[i].iv;
        end_lp[i] <= 1'b0;
      end
    end else if (count_en_i == 1'b1 && end_lp[3] == 1'b0) begin

      if (count_en) begin

        if (end_condition_lp[0]) begin
          loop_vars[0] <= reg_loop_vars_i[0].iv;
          end_lp[0] <= 1'b1;
        end else begin
          loop_vars[0] <= loop_vars[0] + reg_loop_vars_i[0].inc;
          end_lp[0] <= 1'b0;
        end

        if (end_condition_lp[0] & end_condition_lp[1]) begin
          loop_vars[1] <= reg_loop_vars_i[1].iv;
          end_lp[1] <= 1'b1;
        end else if (end_condition_lp[0]) begin
          loop_vars[1] <= loop_vars[1] + reg_loop_vars_i[1].inc;
          end_lp[1] <= 1'b0;
        end else begin
          loop_vars[1] <= loop_vars[1];
          end_lp[1] <= 1'b0;
        end

        if (end_condition_lp[0] & end_condition_lp[1] & end_condition_lp[2]) begin
          loop_vars[2] <= reg_loop_vars_i[2].iv;
          end_lp[2] <= 1'b1;
        end else if (end_condition_lp[0] & end_condition_lp[1]) begin
          loop_vars[2] <= loop_vars[2] + reg_loop_vars_i[2].inc;
          end_lp[2] <= 1'b0;
        end else begin
          loop_vars[2] <= loop_vars[2];
          end_lp[2] <= 1'b0;
        end

        if (end_condition_lp[0] & end_condition_lp[1] & end_condition_lp[2] & end_condition_lp[3]) begin
          loop_vars[3] <= reg_loop_vars_i[3].iv;
          end_lp[3] <= 1'b1;
        end else if (end_condition_lp[0] & end_condition_lp[1] & end_condition_lp[2]) begin
          loop_vars[3] <= loop_vars[3] + reg_loop_vars_i[0].inc;
          end_lp[3] <= 1'b0;
        end else begin
          loop_vars[3] <= loop_vars[3];
          end_lp[3] <= 1'b0;
        end

      end else begin
        for (int i = 0; i < N_LP; i = i + 1) begin
          loop_vars[i] <= loop_vars[i];
          end_lp[i] <= 1'b0;
        end
      end

    end else begin
      for (int i = 0; i < N_LP; i = i + 1) begin
        loop_vars[i] <= reg_loop_vars_i[i].iv;
        end_lp[i] <= 1'b0;
      end
    end

  end

  assign loop_vars_o = loop_vars;
  assign end_lp_o = end_lp[3];

endmodule
