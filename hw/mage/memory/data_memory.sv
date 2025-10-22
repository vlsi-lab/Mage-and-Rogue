// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: data_memory.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module describes the multi-bank Mage data memory

module data_memory
  import pea_pkg::*;
  import agu_pkg::*;
(
    input logic clk_i,
    input logic rst_n_i,

    input  logic                                      dmem_set_retentive_i,
    input  logic [N_BANKS-1:0]                        dmem_req_i,
    input  logic [N_BANKS-1:0]                        dmem_be_i,
    input  logic [N_BANKS-1:0]                        dmem_we_i,
    input  logic [N_BANKS-1:0][$clog2(BANK_SIZE)-1:0] dmem_addr_i,
    input  logic [N_BANKS-1:0][               32-1:0] dmem_wdata_i,
    output logic [N_BANKS-1:0][           N_BITS-1:0] dmem_rdata_o
);

  generate
    for (genvar j = 0; j < N_BANKS; j++) begin : gen_data_sram_macro
`ifndef FPGA_SYNTHESIS
      sram_wrapper #(
          .NumWords (BANK_SIZE),
          .DataWidth(32'd32)
      ) cgra_ram0_i (
          .clk_i  (clk_i),
          .rst_ni (rst_n_i),
          .req_i  (dmem_req_i[j]),
          .we_i   (dmem_we_i[j]),
          .addr_i (dmem_addr_i[j]),
          .wdata_i(dmem_wdata_i[j]),
          .be_i   (4'b1111),
          .set_retentive_ni (dmem_set_retentive_i),
          .pwrgate_ni(1'b0),
          .pwrgate_ack_no(),
          .rdata_o(dmem_rdata_o[j])
      );
`else
      fpga_sram_wrapper #(
          .NumWords (BANK_SIZE),
          .DataWidth(32'd32)
      ) cgra_ram0_i (
          .clk_i  (clk_i),
          .rst_ni (rst_n_i),
          .req_i  (dmem_req_i[j]),
          .we_i   (dmem_we_i[j]),
          .addr_i (dmem_addr_i[j]),
          .wdata_i(dmem_wdata_i[j]),
          .be_i   (4'b1111),
          .set_retentive_ni (dmem_set_retentive_i),
          .pwrgate_ni(1'b0),
          .pwrgate_ack_no(),
          .rdata_o(dmem_rdata_o[j])
      );
`endif
    end
  endgenerate

endmodule
