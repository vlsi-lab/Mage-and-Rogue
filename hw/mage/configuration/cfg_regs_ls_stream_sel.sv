// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: cfg_regs_ls_stream_sel.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module reorganizes configuration bits to properly assign them to the crossbars mux

module cfg_regs_ls_stream_sel
  import pea_pkg::*;
  import agu_pkg::*;
  import xbar_pkg::*;
(
    input logic [N_BANKS_GROUP-1:0][N_BANKS_PER_STREAM-1:0][KMEM_SIZE-1:0][LOG_N_AGE_PER_STREAM-1:0] reg_cfg_l_stream_sel_i,
    input logic [N_BANKS_GROUP-1:0][N_BANKS_PER_STREAM-1:0][KMEM_SIZE-1:0][LOG_N_PE_PER_GROUP-1:0] reg_cfg_s_stream_sel_i,
    input logic [N_CFG_ADDR_BITS-1:0] rcfg_ctrl_addr_i,
    output logic [N_BANKS_GROUP-1:0][N_BANKS_PER_STREAM-1:0][LOG_N_AGE_PER_STREAM-1:0] l_stream_sel_o,
    output logic [N_BANKS_GROUP-1:0][N_BANKS_PER_STREAM-1:0][LOG_N_PE_PER_GROUP-1:0] s_stream_sel_o
);


  always_comb begin
    for (int i = 0; i < N_BANKS_GROUP; i = i + 1) begin
      for (int j = 0; j < N_BANKS_PER_STREAM; j = j + 1) begin
        l_stream_sel_o[i][j] = reg_cfg_l_stream_sel_i[i][j][rcfg_ctrl_addr_i];
      end
    end
  end

  always_comb begin
    for (int i = 0; i < N_BANKS_GROUP; i = i + 1) begin
      for (int j = 0; j < N_BANKS_PER_STREAM; j = j + 1) begin
        s_stream_sel_o[i][j] = reg_cfg_s_stream_sel_i[i][j][rcfg_ctrl_addr_i];
      end
    end
  end


endmodule : cfg_regs_ls_stream_sel
