// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: cfg_dispatcher.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module handles the dispatching of configurations to all different Streams.

module cfg_dispatcher
  import agu_pkg::*;
(
% if kernel_len != 1:
    input logic [LOG2_ACC_CFGMEM_SIZE-1:0] cfgmem_addr_i,
% endif
    input logic [ACC_CFGMEM_SIZE-1:0][N_AGE_TOT-1:0][NBIT_CFG_STREAM_WORD-1:0] cfgmem_content_i,
    // ROU
    output logic [N_AGE_TOT-1:0]                        rou_is_age_active_rou_o,
    output logic [N_AGE_TOT-1:0][LOG2_HWLP_RF_SIZE-1:0] rou_hwlp_sel_o,
    output logic [N_AGE_TOT-1:0][LOG2_N_LP-1+1:0]       rou_iv_constraint_sel_o,
    output logic [N_AGE_TOT-1:0][NBIT_LP_IV-1:0]        rou_iv_constraint_o,
    output logic [N_AGE_TOT-1:0]                        rou_is_acc_store_rou_o,
    // AGE,
    output logic [N_AGE_TOT-1:0]                      age_is_age_active_o,
    output logic [N_AGE_TOT-1:0][NBIT_LP_IV-1:0]      age_const_iv_o,
    output logic [N_AGE_TOT-1:0][NBIT_N_BANKS-1:0]    age_n_banks_o,
    output logic [N_AGE_TOT-1:0][NBIT_START_BANK-1:0] age_start_banks_o,
    output logic [N_AGE_TOT-1:0][NBIT_BLOCK_SIZE-1:0] age_block_size_o,
    output logic [N_AGE_TOT-1:0]                      age_stream_lns_o,
    output logic [N_AGE_TOT-1:0]                      age_is_acc_store_o
);

  logic [N_AGE_TOT-1:0][NBIT_CFG_STREAM_WORD-1:0] cfg_word;
  stream_inst_t [N_AGE_TOT-1:0] stream_inst;

  always_comb begin
% if kernel_len != 1:
  cfg_word = cfgmem_content_i[cfgmem_addr_i];
% else:
    cfg_word = cfgmem_content_i[0];
% endif
  end

  //Constructing stream instruction fields
  always_comb begin
    for (int i = 0; i < N_AGE_TOT; i = i + 1) begin

      stream_inst[i].hwlp_rf_sel        = cfg_word[i][HWLP_RF_MSB:HWLP_RF_LSB];
      stream_inst[i].iv_constraint_sel  = cfg_word[i][IV_CONSTR_MSB:IV_CONSTR_LSB];

      stream_inst[i].n_banks            = cfg_word[i][N_BANKS_MSB:N_BANKS_LSB];
      stream_inst[i].bank_start         = cfg_word[i][BANK_START_MSB:BANK_START_LSB];
      stream_inst[i].block_size         = cfg_word[i][BLOCK_SIZE_MSB:BLOCK_SIZE_LSB];
      stream_inst[i].lns                = cfg_word[i][LNS_MSB:LNS_LSB];
      stream_inst[i].is_acc_store       = cfg_word[i][IS_ACC_STORE_MSB:IS_ACC_STORE_LSB];
      
      stream_inst[i].iv_const           = cfg_word[i][IV_CONST_MSB:IV_CONST_LSB];
      stream_inst[i].iv_constraint      = cfg_word[i][IV_CONSTRAINT_MSB:IV_CONSTRAINT_LSB];

      stream_inst[i].valid              = cfg_word[i][VALID_MSB:VALID_LSB];

    end
  end

  // Outputs to ROU exiting the dispatcher without going through registers 
  always_comb begin
    for (int i = 0; i < N_AGE_TOT; i = i + 1) begin
      rou_hwlp_sel_o[i] = stream_inst[i].hwlp_rf_sel;
      rou_iv_constraint_sel_o[i] = stream_inst[i].iv_constraint_sel;
      rou_iv_constraint_o[i] = stream_inst[i].iv_constraint;
      rou_is_acc_store_rou_o[i] = stream_inst[i].is_acc_store;
      rou_is_age_active_rou_o[i] = stream_inst[i].valid;
    end
  end


  // Outputs to AGU exiting the dispatcher without going through registers
  always_comb begin
    for (int i = 0; i < N_AGE_TOT; i = i + 1) begin
      age_is_acc_store_o[i]      = stream_inst[i].is_acc_store;
      age_n_banks_o[i]       = stream_inst[i].n_banks;
      age_start_banks_o[i]   = stream_inst[i].bank_start;
      age_block_size_o[i]    = stream_inst[i].block_size;
      age_stream_lns_o[i]    = stream_inst[i].lns; 
      age_const_iv_o[i]      = stream_inst[i].iv_const;
      age_is_age_active_o[i] = stream_inst[i].valid;
    end
  end
endmodule : cfg_dispatcher
