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
%if activation_computation == 1:
    // delay operands
    input  logic [   N_NEIGH_PE-1:0][  N_BITS:0] neigh_delay_op_i,
    output logic [         N_BITS:0]             delay_op_o,
%endif
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
%if activation_computation == 1:
  delay_pe_mux_sel_t                          delay_pe_mux_sel;
  delay_pe_op_mux_sel_t                       delay_pe_op_mux_sel;
  // delay operands signals
  logic                 [           N_BITS:0] delay_op_fu;
  logic                 [           N_BITS:0] delay_op_out;
  logic                 [           N_BITS:0] delay_op_out_d1;
  logic                 [           N_BITS:0] delay_op_out_d2;
%endif

    // fu signals
%if activation_computation == 1:
    logic                                       multi_op_instr;
%endif
    logic                 [         N_BITS-1:0] fu_out;

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
  assign fu_instr  = fu_instr_t'(ctrl_pe_i[INSTR_SEL_MSB : INSTR_SEL_LSB]);
%if format_part == 1:
  assign vec_mode  = ctrl_pe_i[VEC_MODE_MSB : VEC_MODE_LSB];
%endif
%if activation_computation == 1:
  assign delay_pe_mux_sel = delay_pe_mux_sel_t'(ctrl_pe_i[DELAY_PE_SEL_MSB : DELAY_PE_SEL_LSB]);
  assign delay_pe_op_mux_sel  = delay_pe_op_mux_sel_t'(ctrl_pe_i[DELAY_PE_OP_SEL_MSB : DELAY_PE_OP_SEL_LSB]);
%endif

  ////////////////////////////////
  //        PE Operands         //
  ////////////////////////////////
  assign op_a = pe_op_i[mux_sel_a];
  assign op_b = pe_op_i[mux_sel_b];

%if activation_computation == 1:
  ////////////////////////////////
  //  Delay Operand Selection   //
  ////////////////////////////////

  // multi_op_instr is asserted when the instruction is a multi-operand one
  assign multi_op_instr = fu_instr[4] == 1'b1;

  /*
    Selection of delay-operand to be fed to FU:
      -> it can be chosen among four input delay-operands
        -> D_UP
        -> D_LEFT
        -> D_RIGHT
        -> D_DOWN

      -> The chosen delay-operand is fed to FU
  */

  // delayed operand selection, it is one among the possible operands of the PE FU 
  assign delay_op_fu    = neigh_delay_op_i[delay_pe_mux_sel];


  /* Output delay data selection:
    ->  delay_op_out = fu_out      if delay_pe_op_mux_sel == D_PE_RES
    ->  delay_op_out = op_a        if delay_pe_op_mux_sel == D_PE_OP_A
    ->  delay_op_out = op_b        if delay_pe_op_mux_sel == D_PE_OP_B
    ->  delay_op_out = delay_op_fu else

    -> The MSB of the delayed operand is always taken from the delay-operand sent to FU (This delays the sign of input delay operand)
  */
  always_comb begin
    delay_op_out = (delay_pe_op_mux_sel == D_PE_RES) ?  {delay_op_fu[N_BITS], fu_out} : (
                   (delay_pe_op_mux_sel == D_PE_OP_A) ? {delay_op_fu[N_BITS], op_a} : (
                   (delay_pe_op_mux_sel == D_PE_OP_B) ? {delay_op_fu[N_BITS], op_b} : delay_op_fu
                  ));
  end


  /*
    Delay-operand register (also for related valid signal):
      -> double register to delay operand by the right amount
        -> 1 cycle for 1-cycle instructions
        -> 2 cycle for 2-cycle instructions
  */
  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      delay_op_out_d1 <= '0;
      delay_op_out_d2 <= '0;
    end else begin
      delay_op_out_d1 <= delay_op_out;
      delay_op_out_d2 <= delay_op_out_d1;
    end
  end

  /* 
    Delay Operand Output Mux:

      -> if delay_pe_op_mux_sel is D_PE_RES:
        -> in case of multi-operand (2-cycle) instructions:
          -> delay_op_o is made up of the MSB of "_d2" operand (one of the input delay-operands) and the rest is taken from "_d1" operand
              This because we want to forward the output of the FU directly and not an input
        -> else:
            ->the "_d1" signals are selected

      
      -> if delay_pe_op_mux_sel is NOT D_PE_RES:
        -> in case of multi-operand (2-cycle) instructions:
            ->the "_d2" signals are selected
        -> else:
            ->the "_d1" signals are selected
  */
  always_comb begin
    if (delay_pe_op_mux_sel == D_PE_RES) begin
      if (multi_op_instr) begin
        delay_op_o = {delay_op_out_d2[N_BITS], delay_op_out_d1[N_BITS-1:0]};
      end else begin
        delay_op_o = delay_op_out_d1;
      end
    end else begin
      if (multi_op_instr) begin
        delay_op_o = delay_op_out_d2;
      end else begin
        delay_op_o = delay_op_out_d1;
      end
    end
  end
%endif

  ////////////////////////////////
  //      Functional Unit       //
  ////////////////////////////////
%if gemm_computation == 1:
  %if format_full == 1:
    fu_dae_full_gemm fu_dae_full_gemm_i  (
        .clk_i(clk_cg),
        .rst_n_i(rst_n_i),
        .a_i(op_a),
        .b_i(op_b),
        .acc_match_i(acc_match_i),
        .pe_res_i(pe_res_o),
        .instr_i(fu_instr),
        .res_o(fu_out)
    );
  %elif format_part == 1:
    fu_dae_part_gemm fu_dae_part_gemm_i (
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .a_i(op_a),
        .b_i(op_b),
        .pe_res_i(pe_res_o),
        .instr_i(fu_instr),
        .vec_mode_i(vec_mode),
        .acc_match_i(acc_match_i),
        .res_o(fu_out)
    );
  %endif
%elif activation_computation == 1:
    fu_dae_full_act fu_dae_full_act (
        .clk_i(clk_cg),
        .rst_n_i(rst_n_i),
        .a_i(op_a),
        .b_i(op_b),
        .delay_sign_i(delay_op_fu[N_BITS]),
        .const_i(neigh_pe_op_i[CONSTANT]),
        .pe_res_i(pe_res_o),
        .acc_match_i(acc_match_i),
        .instr_i(fu_instr),
        .res_o(fu_out)
    );
%endif

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
