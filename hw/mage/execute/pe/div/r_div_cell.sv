// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: r_div_cell.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: Restoring Multicycle Divider Cell

module r_div_cell
  import pea_pkg::*;
(
    input logic [N_BITS-1:0] n_i,
    input logic [N_BITS-1:0] d_i,
    output logic [N_BITS-1:0] r_o,
    output logic q_o
);

  logic [N_BITS-1:0] r;

  assign r   = n_i - d_i;

  assign q_o = ~r[N_BITS-1];
  assign r_o = r[N_BITS-1] ? n_i : r;

endmodule
