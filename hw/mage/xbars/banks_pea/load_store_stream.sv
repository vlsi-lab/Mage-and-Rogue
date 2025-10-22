// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: load_store_stream.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module is used to select the bank for the load and store streams.
//              Based on the selectors, an AGE in a group is selected to decide which bank to connect to PE in banks-pea xbar.

module load_store_stream
  import agu_pkg::*;
  import pea_pkg::*;
(
    //CSRs selectors that determine which AGE in a group decides which bank to connect to PE in banks-pea xbar
    input  logic [  LOG_N_AGE_PER_STREAM-1:0]                             l_stream_sel_i,
    input  logic [    LOG_N_PE_PER_GROUP-1:0]                             s_stream_sel_i,
    //signals from AGEs
    input  logic [      N_AGE_PER_STREAM-1:0][LOG_N_BANKS_PER_STREAM-1:0] age_bank_i,
    input  logic [      N_AGE_PER_STREAM-1:0]                             valid_i,
    //selection for load and store streams
    output logic [LOG_N_BANKS_PER_STREAM-1:0]                             sel_load_stream_o,
    output logic [    LOG_N_PE_PER_GROUP-1:0]                             sel_store_stream_o
);

  logic                              lns;
  logic [LOG_N_BANKS_PER_STREAM-1:0] age_bank;
  logic                              valid;

  always_comb begin
    age_bank = age_bank_i[l_stream_sel_i];
    valid = valid_i[l_stream_sel_i];
  end

  always_comb begin
    if (valid == 1'b1) begin
      sel_load_stream_o  = age_bank;
      sel_store_stream_o = s_stream_sel_i;  //static selection for store stream
    end else begin
      sel_load_stream_o  = '0;
      sel_store_stream_o = s_stream_sel_i;  //static selection for store stream
    end
  end

endmodule
