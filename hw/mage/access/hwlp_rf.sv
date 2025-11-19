// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: hwlp_rf.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module contains all IVs of all iterations of the loop nest.
//              They are stored in a small register file.


module hwlp_rf
  import agu_pkg::*;
(
    input  logic                                                               clk_i,
    input  logic                                                               rst_n_i,
    input  pea_pkg::state_t                                                    state_i,
    input  logic                                                               end_lp_i,
    //Input signal to indicate that the loop variables are valid
    input  logic                                                               hwlp_valid_i,
    input  logic            [        N_LP-1:0]                                 end_condition_lp_i,
    //Input loop variables
    input  logic            [        N_LP-1:0][NBIT_LP_IV-1:0]                 loop_vars_i,
    //each bit of hwlp_valid_o indicates the validity of the corresponding location in hwlp_rf_o
    output logic            [HWLP_RF_SIZE-1:0]                                 hwlp_valid_o,
    //each location of hwlp_rf_o contains loop variables of one iteration of the loop nest
    output logic            [HWLP_RF_SIZE-1:0][      N_LP-1:0][NBIT_LP_IV-1:0] hwlp_rf_o,
    output logic            [HWLP_RF_SIZE-1:0][      N_LP-1:0]                 end_condition_lp_o,
    //end signals
    output logic            [HWLP_RF_SIZE-1:0]                                 end_lp_o
);

  logic [        N_LP-1:0][NBIT_LP_IV-1:0]                 hwlp_rf_first;
  logic [HWLP_RF_SIZE-2:0][      N_LP-1:0][NBIT_LP_IV-1:0] hwlp_rf;

  logic [HWLP_RF_SIZE-2:0]                                 hwlp_valid;
  logic [HWLP_RF_SIZE-2:0][      N_LP-1:0]                 end_condition_lp;
  logic [HWLP_RF_SIZE-2:0]                                 end_lp;
  logic                                                    hwlp_valid_first;
  logic                                                    exec;

  assign exec = state_i == pea_pkg::EXEC;

  //at each clock cycle, each location of hwlp_rf_o is shifted to the right and loop_vars_i is inserted at the first location
  //This mechanism delays the loop variables
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      hwlp_rf <= '0;
      hwlp_valid <= '0;
      end_condition_lp <= '0;
    end else begin
      if (exec) begin
        hwlp_rf[0] <= loop_vars_i;
        hwlp_valid[0] <= hwlp_valid_i;
        end_lp[0] <= end_lp_i;
        end_condition_lp[0] <= end_condition_lp_i;
        for (int i = 1; i < HWLP_RF_SIZE - 1; i = i + 1) begin
          hwlp_rf[i] <= hwlp_rf[i-1];
          hwlp_valid[i] <= hwlp_valid[i-1];
          end_lp[i] <= end_lp[i-1];
          end_condition_lp[i] <= end_condition_lp[i-1];
        end
      end else begin
        hwlp_rf <= '0;
        hwlp_valid <= '0;
        end_lp <= '0;
        end_condition_lp <= '0;
      end
    end
  end

  assign hwlp_valid_first = hwlp_valid_i;
  assign hwlp_rf_first = loop_vars_i;

  assign hwlp_rf_o = {hwlp_rf, hwlp_rf_first};
  assign hwlp_valid_o = {hwlp_valid, hwlp_valid_first};
  assign end_lp_o = {end_lp, end_lp_i};
  assign end_condition_lp_o = {end_condition_lp, end_condition_lp_i};


endmodule : hwlp_rf
