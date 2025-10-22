// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: div_wrapper.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: Wrapper for Mage divider

module div_wrapper
  import pea_pkg::*;
(
    input logic rst_n_i,
    input logic clk_i,
    input logic signed [N_BITS-1:0] a_i,
    input logic signed [N_BITS-1:0] b_i,
    input logic in_valid_i,
    output logic signed [N_BITS-1:0] q_o,
    output logic signed [N_BITS-1:0] r_o,
    output logic valid_o
);

  r_div r_div_inst (
      .rst_n_i(rst_n_i),
      .clk_i(clk_i),
      .en_i(in_valid_i),
      .n_i(a_i),
      .d_i(b_i),
      .r_o(r_o),
      .q_o(q_o),
      .valid_o(valid_o)
  );

endmodule
