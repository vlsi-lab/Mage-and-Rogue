// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: agu.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: Address Generation Unit top module

module agu
  import agu_pkg::*;
  import pea_pkg::*;
(
    input logic clk_i,
    input logic rst_n_i,
    input logic start_i,
%if format_part == 1:
    input logic [1:0] reg_acc_vec_mode_i,
%endif  
    ////////////////////////////////////////////////////////////////
    //                Hardware Loops Configuration                //
    ////////////////////////////////////////////////////////////////
    input loop_vars_t [N_LP-1:0] reg_loop_vars_i,
    ////////////////////////////////////////////////////////////////
    //                  Controller Configuration                  //
    ////////////////////////////////////////////////////////////////
% if kernel_len != 1:
    input logic reg_static_no_timemux_i,
    input loop_pipeline_info_t reg_lp_info_i,
% endif
    input logic [NBIT_II-1:0] reg_II_i,
    ////////////////////////////////////////////////////////////////
    //                Re-Order Unit Configuration                 //
    ////////////////////////////////////////////////////////////////
    input logic [N_AGE_TOT-1:0][N_IVS-1:0][NBIT_LP_IV-1:0] reg_age_strides_i,
    ////////////////////////////////////////////////////////////////
    //                   Streams Configuration                    //
    ////////////////////////////////////////////////////////////////
    input logic [ACC_CFGMEM_SIZE-1:0][N_AGE_TOT-1:0][NBIT_CFG_STREAM_WORD-1:0] cfgmem_content_i,
    ////////////////////////////////////////////////////////////////
    //                     Start/End Signals                      //
    ////////////////////////////////////////////////////////////////
    output logic start_d_o,
    output logic end_lp_o,
% if kernel_len != 1:
    ////////////////////////////////////////////////////////////////
    //                PC for Configuration Memory                 //
    ////////////////////////////////////////////////////////////////
    output logic [N_CFG_ADDR_BITS-1:0] cfgmem_addr_d_o,
% endif
    ////////////////////////////////////////////////////////////////
    //                Interface to Multi-Bank SpM                 //
    ////////////////////////////////////////////////////////////////
    output logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0][NBIT_ADDR-1:0] agu_addr_o,
    output logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0][N_BANKS_PER_STREAM-1:0] agu_bank_o,
    output logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0][LOG_N_BANKS_PER_STREAM-1:0] agu_bank_ls_o,
    output logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0] agu_valid_o,
    output logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0] agu_valid_ls_o,
    output logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0] agu_lns_o,
    output logic agu_pea_acc_reset_o
);
% if kernel_len != 1:
  ////////////////////////////////////////////////////////////////
  //                Stream Configuration Memory                 //
  ////////////////////////////////////////////////////////////////
  logic [LOG2_ACC_CFGMEM_SIZE-1:0] cfgmem_addr_disp;
  logic [LOG2_ACC_CFGMEM_SIZE-1:0] cfgmem_addr;
% endif
  ////////////////////////////////////////////////////////////////
  //              Configuration Dispatcher Outputs              //
  ////////////////////////////////////////////////////////////////
  logic [N_AGE_TOT-1:0] rou_is_age_active;
  logic [N_AGE_TOT-1:0][LOG2_HWLP_RF_SIZE-1:0] rou_hwlp_sel;
  logic [N_AGE_TOT-1:0][LOG2_N_LP-1+1:0] rou_iv_constraints_sel;
  logic [N_AGE_TOT-1:0][NBIT_LP_IV-1:0] rou_iv_constraints;
  logic [N_AGE_TOT-1:0] rou_is_acc_store;

  logic [N_AGE_TOT-1:0] age_is_age_active;
  logic [N_AGE_TOT-1:0][NBIT_LP_IV-1:0] age_const_iv;
  logic [N_AGE_TOT-1:0][NBIT_N_BANKS-1:0] age_n_banks;
  logic [N_AGE_TOT-1:0][NBIT_START_BANK-1:0] age_start_banks;
  logic [N_AGE_TOT-1:0][NBIT_BLOCK_SIZE-1:0] age_block_size;
  logic [N_AGE_TOT-1:0] age_stream_lns;
  logic [N_AGE_TOT-1:0] age_is_acc_store;
  ////////////////////////////////////////////////////////////////
  //                        HWLP Outputs                        //
  ////////////////////////////////////////////////////////////////
  logic hwlp_valid;
  logic [N_LP-1:0][NBIT_LP_IV-1:0] loop_vars;
  logic [N_LP-1:0] hwlp_end_condition;
  ////////////////////////////////////////////////////////////////
  //                      HWLP RF Outputs                       //
  ////////////////////////////////////////////////////////////////
  logic [HWLP_RF_SIZE-1:0] hwlp_rf_valid;
  logic [HWLP_RF_SIZE-1:0][N_LP-1:0][NBIT_LP_IV-1:0] hwlp_rf;
  logic [HWLP_RF_SIZE-1:0][N_LP-1:0] hwlp_rf_end_condition;
  ////////////////////////////////////////////////////////////////
  //                      HWLP ROU Outputs                      //
  ////////////////////////////////////////////////////////////////
  logic [N_AGE_TOT-1:0][N_IVS-1:0][NBIT_LP_IV-1:0] rou_to_age_hwlp;
  logic [N_AGE_TOT-1:0] rou_to_age_stream_valid;
  logic [N_AGE_TOT-1:0] rou_to_age_pea_acc_reset;
  ////////////////////////////////////////////////////////////////
  //                      AGE Unit Outputs                      //
  ////////////////////////////////////////////////////////////////
  logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0] age_pea_acc_reset;
  ////////////////////////////////////////////////////////////////
  //                     Start/End Signals                      //
  ////////////////////////////////////////////////////////////////
  logic hwlp_end_lp;
  logic [HWLP_RF_SIZE-1:0] hwlp_rf_end_lp;
  logic [N_AGE_TOT-1:0] hwlp_rou_end_lp;
  logic [N_AGE_TOT-1:0] age_end_lp;

  //agu cfgmem controller
  k_controller k_controller_inst (
      .clk_i(clk_i),
      .rst_n_i(rst_n_i),
      .start_i(start_i),
% if kernel_len != 1:
      .reg_lp_info_i(reg_lp_info_i),
      .count_pke_o(cfgmem_addr_disp),
      .count_pke_d_o(cfgmem_addr_d_o),
% endif
      .start_d_o(start_d_o)
  );

  assign end_lp_o = (age_end_lp == age_is_age_active);

  //hwlp module
  hwlp hwlp_inst (
      .clk_i(clk_i),
      .rst_n_i(rst_n_i),
      .count_en_i(start_i),
      .end_condition_lp_o(hwlp_end_condition),
      .reg_II_i(reg_II_i),
      .reg_loop_vars_i(reg_loop_vars_i),
      .loop_vars_o(loop_vars),
      .hwlp_valid_o(hwlp_valid),
      .end_lp_o(hwlp_end_lp)
  );


  //hwlp_rf module
  hwlp_rf hwlp_rf_inst (
      .clk_i(clk_i),
      .rst_n_i(rst_n_i),
      .start_i(start_i),
      .end_lp_i(hwlp_end_lp),
      .end_condition_lp_i(hwlp_end_condition),
      .end_condition_lp_o(hwlp_rf_end_condition),
      .hwlp_valid_i(hwlp_valid),
      .loop_vars_i(loop_vars),
      .hwlp_valid_o(hwlp_rf_valid),
      .hwlp_rf_o(hwlp_rf),
      .end_lp_o(hwlp_rf_end_lp)
  );

  //hwlp_rou module
  hwlp_rou hwlp_rou_inst (
      .clk_i(clk_i),
      .rst_n_i(rst_n_i),
      .hwlp_sel_i(rou_hwlp_sel),
      .hwlp_rf_i(hwlp_rf),
      .end_lp_i(hwlp_rf_end_lp),
      .hwlp_end_condition_i(hwlp_rf_end_condition),
      .is_age_active_i(rou_is_age_active),
      .iv_constraints_i(rou_iv_constraints),
      .iv_constraints_sel_i(rou_iv_constraints_sel),
      .hwlp_valid_i(hwlp_rf_valid),
      .is_acc_store_rou_i(rou_is_acc_store),
%if format_part == 1:
      .reg_acc_vec_mode_i(reg_acc_vec_mode_i),
%endif      
      .stream_valid_o(rou_to_age_stream_valid),
      .pea_acc_reset_o(rou_to_age_pea_acc_reset),
      .hwlp_rou_o(rou_to_age_hwlp),
      .end_lp_o(hwlp_rou_end_lp)
  );

  //age_unit module
  age_unit age_unit_inst (
    .clk_i(clk_i),
    .rst_n_i(rst_n_i),
    .start_i(start_i),
    .end_lp_i(hwlp_rou_end_lp),
    .end_lp_o(age_end_lp),
    .age_strides_i(reg_age_strides_i),
    .rou_i(rou_to_age_hwlp),
    .pea_acc_reset_i(rou_to_age_pea_acc_reset),
    .stream_valid_i(rou_to_age_stream_valid),
    .is_age_active_i(age_is_age_active),
    .const_iv_i(age_const_iv),
    .n_banks_i(age_n_banks),
    .start_banks_i(age_start_banks),
    .block_size_i(age_block_size),
    .is_acc_store_i(age_is_acc_store),
    .stream_lns_i(age_stream_lns),
    .stream_addr_o(agu_addr_o),
    .stream_bank_o(agu_bank_o),
    .stream_bank_ls_o(agu_bank_ls_o),
    .stream_pea_acc_reset_o(age_pea_acc_reset),
    .stream_valid_o(agu_valid_o),
    .stream_valid_ls_o(agu_valid_ls_o),
    .stream_lns_o(agu_lns_o)
);

  assign agu_pea_acc_reset_o = |age_pea_acc_reset;

% if kernel_len != 1:
  // Configuration Memory Address (PC)
  always_comb begin
    if (reg_static_no_timemux_i) begin
      cfgmem_addr = '0;
    end else begin
      cfgmem_addr = cfgmem_addr_disp;
    end
  end
% endif

  //cfg_dispatcher module
  cfg_dispatcher cfg_dispatcher_inst (
% if kernel_len != 1:
      .cfgmem_addr_i(cfgmem_addr),
% endif
      .cfgmem_content_i(cfgmem_content_i),
      // To ROU
      .rou_hwlp_sel_o(rou_hwlp_sel),
      .rou_iv_constraint_sel_o(rou_iv_constraints_sel),
      .rou_iv_constraint_o(rou_iv_constraints),
      .rou_is_acc_store_rou_o(rou_is_acc_store),
      .rou_is_age_active_rou_o(rou_is_age_active),
      // To AGEs
      .age_const_iv_o(age_const_iv),
      .age_is_age_active_o(age_is_age_active),
      .age_n_banks_o(age_n_banks),
      .age_start_banks_o(age_start_banks),
      .age_block_size_o(age_block_size),
      .age_stream_lns_o(age_stream_lns),
      .age_is_acc_store_o(age_is_acc_store)
  );

endmodule : agu
