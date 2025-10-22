// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: pe_dae.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module is the main building block of the Processing Element Array (PEA) for the CGRA in Decoupled Access-Execute mode

module pe_dae
  import pea_pkg::*;
(
    input  logic                                 clk_i,
    input  logic                                 rst_n_i,
    input  logic [  N_INPUTS_PE-1:0][N_BITS-1:0] pe_op_i,
    input  logic                                 acc_match_i,
    input  logic [N_CFG_BITS_PE-1:0]             ctrl_pe_i,
    output logic [       N_BITS-1:0]             pe_res_o
);
  logic                            clk_cg;

  // inputs/ouputs of FU
  logic      [         N_BITS-1:0] op_a;
  logic      [         N_BITS-1:0] op_b;
  logic      [         N_BITS-1:0] fu_out;

  // configuration signals
  logic      [LOG_N_INPUTS_PE-1:0] mux_a_sel;
  logic      [LOG_N_INPUTS_PE-1:0] mux_b_sel;
  logic      [                1:0] vec_mode;
  fu_instr_t                       fu_instr;

  // fu signals
  logic      [         N_BITS-1:0] fu_out;

  ////////////////////////////////
  //     Clock-gating cell      //
  ////////////////////////////////
`ifndef VERILATOR
`ifndef FPGA
  // PE Clock-gating
  logic clk_cg_en;
  assign clk_cg_en = ~(fu_instr == NOP);
  tc_clk_gating pe_clk_gating_cell (
      .clk_i(clk_i),
      .en_i(clk_cg_en),
      .test_en_i(1'b0),
      .clk_o(clk_cg)
  );
`else
  assign clk_cg = clk_i;
`endif
`else
  assign clk_cg = clk_i;
`endif

  ////////////////////////////////
  //      PE Configuration      //
  ////////////////////////////////
  assign mux_a_sel = pe_mux_sel_t'(ctrl_pe_i[OP_A_SEL_MSB : OP_A_SEL_LSB]);
  assign mux_b_sel = pe_mux_sel_t'(ctrl_pe_i[OP_B_SEL_MSB : OP_V_SEL_LSB]);
  assign fu_instr = fu_instr_t'(ctrl_pe_i[INSTR_SEL_MSB : INSTR_SEL_LSB]);

  ////////////////////////////////
  //        PE Operands         //
  ////////////////////////////////
  assign op_a = pe_op_i[mux_sel_a];
  assign op_b = pe_op_i[mux_sel_b];


  ////////////////////////////////
  //      Functional Unit       //
  ////////////////////////////////
  fu_dae_full_gemm fu_dae_full_gemm_i (
      .clk_i(clk_cg),
      .rst_n_i(rst_n_i),
      .a_i(op_a),
      .b_i(op_b),
      .acc_match_i(acc_match_i),
      .pe_res_i(pe_res_o),
      .instr_i(fu_instr),
      .res_o(fu_out)
  );

  ////////////////////////////////
  //         PE Outputs         //
  ////////////////////////////////
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      pe_res_o <= 0;
    end else begin
      pe_res_o <= fu_out;
    end
  end

endmodule
