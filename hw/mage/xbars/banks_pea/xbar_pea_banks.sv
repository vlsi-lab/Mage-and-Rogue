// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: xbar_pea_banks.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: SpM Bank Group <-> PE Group Pipelinable Crossbar
//              This module describes a modular crossbar connection between a Bank Group and a PE Group

module xbar_pea_banks
  import pea_pkg::*;
#(
    parameter int XBAR_SIZE = 2  // Parameter to set the size of the crossbar
) (
    // Input signals from PE and SpM Group
    input  logic [XBAR_SIZE-1:0][           N_BITS-1:0] out_pea_i,
    input  logic [XBAR_SIZE-1:0][           N_BITS-1:0] out_dmem_i,
    // Selectors
    input  logic [XBAR_SIZE-1:0][$clog2(XBAR_SIZE)-1:0] sel_dmem_pea_i,
    input  logic [XBAR_SIZE-1:0][$clog2(XBAR_SIZE)-1:0] sel_pea_dmem_i,
    // Output signals to PE and SpM Group
    output logic [XBAR_SIZE-1:0][           N_BITS-1:0] in_pea_o,
    output logic [XBAR_SIZE-1:0][           N_BITS-1:0] in_dmem_o
);

  always_comb begin
    for (int i = 0; i < XBAR_SIZE; i++) begin
      in_pea_o[i]  = out_dmem_i[sel_dmem_pea_i[i]];
      in_dmem_o[i] = out_pea_i[sel_pea_dmem_i[i]];
    end
  end

endmodule
