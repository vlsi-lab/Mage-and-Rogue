// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: dmem_pea_select.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module is used to select the bank for the load and store streams.
//              Based on the selectors, an AGE in a group is selected to decide which bank to connect to PE in banks-pea xbar.

module dmem_pea_select
  import pea_pkg::*;
#(
    parameter int N_AGE = 2
) (
    //CSRs selectors that determine which AGE in a group decides which bank to connect to PE in banks-pea xbar
    input  logic [$clog2(N_AGE)-1:0]                    reg_load_age_sel_i,
    //signals from AGEs
    input  logic [        N_AGE-1:0][$clog2(N_AGE)-1:0] age_bank_load_i,
    input  logic [        N_AGE-1:0]                    valid_ls_i,
    //selection for load and store streams
    output logic                                        valid_o,
    output logic [$clog2(N_AGE)-1:0]                    sel_load_stream_o
);

  logic [$clog2(N_AGE)-1:0] age_bank_l;
  logic                     valid_l;

  always_comb begin
    age_bank_l = age_bank_load_i[reg_load_age_sel_i];
    valid_l    = valid_ls_i[reg_load_age_sel_i];
  end

  assign valid_o = valid_l;

  always_comb begin
    if (valid_l == 1'b1) begin
      sel_load_stream_o = age_bank_l;
    end else begin
      sel_load_stream_o = '0;
    end
  end

endmodule
