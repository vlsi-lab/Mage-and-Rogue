// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: age_unit.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: Address Generation Engine (AGE) Unit
//              This module contains all Address Generation Engines (AGEs)


module age_unit
  import agu_pkg::*;
(
    input logic clk_i,
    input logic rst_n_i,
    //input logic end_accumulation_i,
    input logic start_i,
    //CSR containing all column sizes neeeded for calculating flat address
    input logic [N_AGE_TOT-1:0][N_IVS-1:0][NBIT_LP_IV-1:0] age_strides_i,
    //from HWLP_ROU
    //oredered ivs for each stream address/bank generation
    input logic [N_AGE_TOT-1:0][N_IVS-1:0][NBIT_LP_IV-1:0] rou_i,
    input logic [N_AGE_TOT-1:0] pea_acc_reset_i,
    //validity of each stream
    input logic [N_AGE_TOT-1:0] stream_valid_i,
    //is age active
    input logic [N_AGE_TOT-1:0] is_age_active_i,
    //end signals
    input logic [N_AGE_TOT-1:0] end_lp_i,
    output logic [N_AGE_TOT-1:0] end_lp_o,
    //FA_GEN
    //constant ivs for each subscript of each stream
    input logic [N_AGE_TOT-1:0][NBIT_LP_IV-1:0] const_iv_i,
    //BA_GEN
    //number of banks for each stream
    input logic [N_AGE_TOT-1:0][NBIT_N_BANKS-1:0] n_banks_i,
    input logic [N_AGE_TOT-1:0][NBIT_START_BANK-1:0] start_banks_i,
    //block size for each stream
    input logic [N_AGE_TOT-1:0][NBIT_BLOCK_SIZE-1:0] block_size_i,
    input logic [N_AGE_TOT-1:0] is_acc_store_i,
    //load_not_store for each stream
    input logic [N_AGE_TOT-1:0] stream_lns_i,
    //Outputs: for each stream group, for each stream, address-bank-validity-lns are generated
    output logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0][NBIT_ADDR-1:0] stream_addr_o,
    output logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0][N_BANKS_PER_STREAM-1:0] stream_bank_o,
    output logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0][LOG_N_BANKS_PER_STREAM-1:0] stream_bank_ls_o,
    output logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0] stream_pea_acc_reset_o,
    output logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0] stream_valid_o,
    output logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0] stream_valid_ls_o,
    output logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0] stream_lns_o
);

  //Generate AGEs
  genvar i;
  generate
    for (i = 0; i < N_STREAMS; i = i + 1) begin : gen_sg
      genvar j;
      for (j = 0; j < N_AGE_PER_STREAM; j = j + 1) begin : gen_spg

        age age_inst (
            .clk_i(clk_i),
            .rst_n_i(rst_n_i),
            .start_i(start_i),
            .end_lp_i(end_lp_i[i*N_AGE_PER_STREAM+j]),
            .end_lp_o(end_lp_o[i*N_AGE_PER_STREAM+j]),
            .valid_i(stream_valid_i[i*N_AGE_PER_STREAM+j]),
            .active_i(is_age_active_i[i*N_AGE_PER_STREAM+j]),
            .iv_i(rou_i[i*N_AGE_PER_STREAM+j]),
            .pea_acc_reset_i(pea_acc_reset_i[i*N_AGE_PER_STREAM+j]),
            .iv_const_i(const_iv_i[i*N_AGE_PER_STREAM+j]),
            .age_strides_i(age_strides_i[i*N_AGE_PER_STREAM+j]),
            .n_banks_i(n_banks_i[i*N_AGE_PER_STREAM+j]),
            .start_bank_i(start_banks_i[i*N_AGE_PER_STREAM+j]),
            .block_size_i(block_size_i[i*N_AGE_PER_STREAM+j]),
            .is_acc_store_i(is_acc_store_i[i*N_AGE_PER_STREAM+j]),
            .lns_i(stream_lns_i[i*N_AGE_PER_STREAM+j]),
            .age_addr_o(stream_addr_o[i][j]),
            .age_bank_o(stream_bank_o[i][j]),
            .age_bank_ls_stream_o(stream_bank_ls_o[i][j]),
            .pea_acc_reset_o(stream_pea_acc_reset_o[i][j]),
            .valid_o(stream_valid_o[i][j]),
            .valid_ls_o(stream_valid_ls_o[i][j]),
            .lns_o(stream_lns_o[i][j])
        );
      end
    end
  endgenerate

endmodule : age_unit
