// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: xbar_banks_pea.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: SpM Bank Group <-> PE Group Pipelinable Crossbar
//              This modlule describes a modular crossbar connection between a Bank Group and a PE Group

module xbar_banks_pea
  import pea_pkg::*;
  import agu_pkg::*;
  import xbar_pkg::*;
(
    //Input signals from PE and SpM Group
    input  logic [    N_PE_PER_GROUP-1:0][                N_BITS-1:0] out_pea_i,
    input  logic [N_BANKS_PER_STREAM-1:0][                N_BITS-1:0] out_dmem_i,
    //Selectors
    input  logic [    N_PE_PER_GROUP-1:0][LOG_N_BANKS_PER_STREAM-1:0] sel_dmem_pea_i,
    input  logic [N_BANKS_PER_STREAM-1:0][    LOG_N_PE_PER_GROUP-1:0] sel_pea_dmem_i,
    //Output signals to PE and SpM Group
    output logic [N_BANKS_PER_STREAM-1:0][                N_BITS-1:0] in_pea_o,
    output logic [N_BANKS_PER_STREAM-1:0][                N_BITS-1:0] in_dmem_o
);


  always_comb begin
    for (i = 0; i < N_BANKS_PER_STREAM; i++) begin 
      in_pea_o[i]  = out_dmem_i[sel_dmem_pea_i[i]];
      in_dmem_o[i] = out_pea_i[sel_pea_dmem_i[i]];
    end
  end

endmodule
