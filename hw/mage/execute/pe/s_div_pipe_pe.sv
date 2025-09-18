// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: s_pe.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module is the main building block of the Processing Element Array (PEA) for Mage in streaming mode.
//              It contains the functional unit (FU) and the input operand multiplexers.

module s_div_pipe_pe
  import pea_pkg::*;
(
    input  logic                                 clk_i,
    input  logic                                 rst_n_i,
    input  logic                                 mage_done_i,
    input  logic [N_CFG_BITS_PE-1:0]             ctrl_pe_i,
    // Streaming Interface
    input  logic [              1:0]             reg_rf_value_i,
    input  logic [             15:0]             reg_acc_value_i,
    input  logic                                 pea_ready_i,
    input  logic [       N_BITS-1:0]             reg_const_i,
    output logic                                 reg_pea_rf_de_o,
    output logic [       N_BITS-1:0]             reg_pea_rf_d_o,
    input  logic [  N_INPUTS_PE-4:0][N_BITS-1:0] neigh_pe_op_i,
    input  logic [  N_INPUTS_PE-4:0]             neigh_pe_op_valid_i,
    input  logic [   N_NEIGH_PE-1:0][  N_BITS:0] neigh_delay_op_i,
    input  logic [   N_NEIGH_PE-1:0]             neigh_delay_op_valid_i,
    output logic                                 valid_o,
    output logic                                 ready_o,
    output logic                                 delay_op_valid_o,
    output logic [         N_BITS:0]             delay_op_o,
    output logic [       N_BITS-1:0]             pe_res_o
    // end Streaming Interface
);

  logic                                               clk_cg;
  // output of operands muxes
  logic                 [     N_BITS-1:0]             op_a;
  logic                 [     N_BITS-1:0]             op_b;
  // mux selectors
  pe_mux_sel_t                                        mux_sel_a;
  pe_mux_sel_t                                        mux_sel_b;
  // output of operands-valid muxes
  logic                                               op_a_valid;
  logic                                               op_b_valid;
  // delay operands signals
  delay_pe_mux_sel_t                                  delay_pe_mux_sel;
  delay_pe_op_mux_sel_t                               delay_pe_op_mux_sel;
  logic                 [       N_BITS:0]             delay_op_fu;
  logic                 [       N_BITS:0]             delay_op_out;
  logic                 [       N_BITS:0]             delay_op_out_d1;
  logic                 [N_DIV_STAGE-1:0]             delay_op_out_d1_1;
  logic                 [       N_BITS:0]             delay_op_out_d2;
  logic                                               delay_op_valid;
  logic                                               delay_op_valid_out;
  logic                                               delay_op_valid_out_d1;
  logic                                               delay_op_valid_out_d2;
  // actual inputs to muxes
  logic                 [N_INPUTS_PE-1:0][N_BITS-1:0] operands;
  logic                 [N_INPUTS_PE-1:0]             operands_valid;
  // fu signals
  logic                                               fu_ops_valid;
  logic                                               fu_valid;
  logic                                               fu_ready;
  logic                                               multi_op_instr;
  logic                                               div_instr;
  // accumulation signals
  logic                                               valid;
  logic                                               acc_loopback;
  //fu signals
  logic                 [     N_BITS-1:0]             fu_out;
  logic                 [     N_BITS-1:0]             rem_q_out;
  fu_instr_t                                          fu_instr;
  // RF
  logic                                               rf_en;
  logic                 [            1:0]             rf_sel;
  logic                 [            1:0]             rf_val;
  logic                 [            1:0]             rf_cnt;
  logic                 [            4:0]             rf_cfg;
  logic                 [     N_BITS-1:0]             loopback_shacc;

  ////////////////////////////////////////////////////////////////
  //                     Clock-gating cell                      //
  ////////////////////////////////////////////////////////////////
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

  ////////////////////////////////////////////////////////////////
  //                      PE Control Word                       //
  ////////////////////////////////////////////////////////////////

  /*
    PE control signals assignment:
      -> selector for source operand 1 of PE is set to SELF if loopback signal is asserted by FU for ACC instruction
        -> it is needed to loopback the output of the PE for accumulation
        -> it is not done if instruction is SHACC, because we cannot waste one source operand for the loopback operand,
            as the operation is s += (s >> a) + b
  */

  always_comb begin
    if (acc_loopback && fu_instr != SHACC) begin
      mux_sel_a = SELF;
    end else begin
      mux_sel_a = pe_mux_sel_t'(ctrl_pe_i[END_CFG_MUX_SEL_0 : 0]);
    end
    mux_sel_b = pe_mux_sel_t'(ctrl_pe_i[END_CFG_MUX_SEL_1 : END_CFG_MUX_SEL_0+1]);
  end

  assign fu_instr = fu_instr_t'(ctrl_pe_i[END_CFG_OP : END_CFG_MUX_SEL_1+1]);
  assign rf_cfg = ctrl_pe_i[END_RF_CFG : END_CFG_OP+1];
  assign delay_pe_mux_sel = delay_pe_mux_sel_t'(ctrl_pe_i[END_DELAY_PE_MUX_SEL : END_RF_CFG+1]);
  assign delay_pe_op_mux_sel  = delay_pe_op_mux_sel_t'(ctrl_pe_i[END_DELAY_PE_OP_MUX_SEL : END_DELAY_PE_MUX_SEL + 1]);

  /*
    The loopback for SHACC is different, since we cannot waste one source operand for the loopback operand,
    we directly assign the output of PE in input to FU
  */
  always_comb begin
    if (acc_loopback) begin
      loopback_shacc = pe_res_o;
    end else begin
      loopback_shacc = '0;
    end
  end

  ////////////////////////////////////////////////////////////////
  //                 Muxes inputs construction                  //
  ////////////////////////////////////////////////////////////////

  always_comb begin

    // Assignments of inputs from neighbouring PEs
    for (int i = 0; i < N_INPUTS_PE - 3; i++) begin
      operands[i] = neigh_pe_op_i[i];
      operands_valid[i] = neigh_pe_op_valid_i[i];
    end

    // SELF
    operands[N_INPUTS_PE-3] = pe_res_o;
    operands_valid[N_INPUTS_PE-3] = valid_o;

    // RF
    operands[N_INPUTS_PE-2] = reg_const_i;
    operands_valid[N_INPUTS_PE-2] = 1'b1;

    // DELAY_OP
    operands[N_INPUTS_PE-1] = delay_op_fu[N_BITS-1:0];
    operands_valid[N_INPUTS_PE-1] = delay_op_valid;

  end

  ////////////////////////////////////////////////////////////////
  //                       Operand Selection                    //
  ////////////////////////////////////////////////////////////////

  // Inputs to FU and related valid signals
  assign op_a = (mux_sel_a == RF && rf_sel == 2'b00 && reg_pea_rf_de_o) ? reg_pea_rf_d_o : operands[mux_sel_a];
  assign op_b = (mux_sel_b == RF && rf_sel == 2'b00 && reg_pea_rf_de_o) ? reg_pea_rf_d_o : operands[mux_sel_b];
  assign op_a_valid = (mux_sel_a == SELF) ? 1'b1 : operands_valid[mux_sel_a];
  assign op_b_valid = (mux_sel_b == SELF) ? 1'b1 : operands_valid[mux_sel_b];
  assign fu_ops_valid = op_a_valid && op_b_valid;

  ////////////////////////////////////////////////////////////////
  //                   1-entry Register File                    //
  ////////////////////////////////////////////////////////////////

  // RF enable
  assign rf_en = rf_cfg[0];

  /*
     RF selector to select which input to latch into RF (reg_cont_i):
      -> 00 for STREAM_IN0, 01 for OP_A (first FU operand), 10 for OP_B (second FU operand)
  */
  assign rf_sel = rf_cfg[2:1];

  //RF value that sets the initial value for the downcounter
  assign rf_val = rf_cfg[4:3];

  /*
    RF control downcounter:
      ? When the input streaming data must be sampled and latched into RF, the user can choose which input to sample
        This is useful in read fifo sync mode, when temp constants must be latched into PE RF
      -> The downcounter is initialized to user-defined rf_val, and decremented each time the streaming input is valid
          and RF is enabled by configurationr register
      -> when it reaches zero, it is re-initialized
  */
  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (~rst_n_i) begin
      rf_cnt <= '0;
    end else begin
      if (rf_en && operands_valid[STREAM_IN0] && pea_ready_i) begin
        if (rf_cnt == reg_rf_value_i) begin
          rf_cnt <= '0;
        end else begin
          rf_cnt <= rf_cnt + 1;
        end
      end
    end
  end

  /*
    RF enable and data_in assignment:
      -> if RF is enabled
        -> if 01 or 10, one fu operand is latched (first and second operand respectively)
        -> if 00, the STREAM_IN0 input is latched, and the enable is asserted when the downcounter is equal to 1
          -> NOTE: It is 1 and not 0 because if we want to latch the first streaming input we would have to set the rf_val to 0.
                    However, this would enable the RF forever. Hence, the downcounter match is set to 1 to avoid this.
  */

  always_comb begin
    reg_pea_rf_de_o = '0;
    reg_pea_rf_d_o  = '0;
    if (rf_en && pea_ready_i) begin
      if (rf_sel == 2'b00) begin
        reg_pea_rf_de_o = operands_valid[STREAM_IN0] && (rf_cnt == rf_val);
        reg_pea_rf_d_o  = operands[STREAM_IN0];
      end else if (rf_sel == 2'b01) begin
        reg_pea_rf_de_o = operands_valid[mux_sel_a];
        reg_pea_rf_d_o  = operands[mux_sel_a];
      end
      if (rf_sel == 2'b10) begin
        reg_pea_rf_de_o = operands_valid[mux_sel_b];
        reg_pea_rf_d_o  = operands[mux_sel_b];
      end
    end
  end

  ////////////////////////////////////////////////////////////////
  //                         Functional Unit                    //
  ////////////////////////////////////////////////////////////////
  fu_wrapper_div_pipe fu_wrapper_div_pipe_i (
      .clk_i(clk_cg),
      .rst_n_i(rst_n_i),
      .mage_done_i,
      .a_i(op_a),
      .b_i(op_b),
      .delay_sign_i(delay_op_fu[N_BITS]),
      .const_i(reg_const_i),
      .pe_res_i(loopback_shacc),
      .reg_acc_value_i,
      .pea_ready_i,
      .ops_valid_i(fu_ops_valid),
      .valid_o(fu_valid),
      .ready_o(fu_ready),
      .rem_q_o(rem_q_out),
      .acc_loopback_o(acc_loopback),
      .instr_i(fu_instr),
      .res_o(fu_out)
  );

  ////////////////////////////////////////////////////////////////
  //                    Delay Operand Selection                 //
  ////////////////////////////////////////////////////////////////

  assign div_instr = (fu_instr == DIV || fu_instr == REM || fu_instr == ABSDIV || fu_instr == ABSREM || fu_instr == CADDDIV);

  // delayed operand selection, it is one among the possible operands of the PE FU 
  assign delay_op_fu = neigh_delay_op_i[delay_pe_mux_sel];
  // delayed operand valid selection
  assign delay_op_valid = neigh_delay_op_valid_i[delay_pe_mux_sel];
  /* output delay data selection
    ->  delay_op_out = fu_out      if delay_pe_mux_sel == D_PE_RES
    ->  delay_op_out = rem_q_out  if delay_pe_mux_sel == D_PE_RES and fu_instr == REM
    ->  delay_op_out = op_a        if delay_pe_mux_sel == D_PE_OP_A
    ->  delay_op_out = op_b        if delay_pe_mux_sel == D_PE_OP_B
    ->  delay_op_out = delay_op_fu if delay_pe_mux_sel == D_PE_DELAY_OP
    in the default case, delay_op_out is set fed with delay_op_fu,
    but it can be decided to forward also the result of the PE FU or one of its operands.
    In case of DIV and REM, the remainder of the division is forwarded.
  */
  always_comb begin
    delay_op_out = (delay_pe_op_mux_sel == D_PE_RES) ? ((fu_instr == DIV || fu_instr == REM || fu_instr == ABSDIV || fu_instr == ABSREM) ? {delay_op_fu[N_BITS], rem_q_out} : {delay_op_fu[N_BITS], fu_out}) : (
                   (delay_pe_op_mux_sel == D_PE_OP_A) ? {delay_op_fu[N_BITS], op_a} : (
                   (delay_pe_op_mux_sel == D_PE_OP_B) ? {delay_op_fu[N_BITS], op_b} : delay_op_fu
                  ));
    delay_op_valid_out = (delay_pe_op_mux_sel == D_PE_RES || div_instr) ? fu_valid : (
                   (delay_pe_op_mux_sel == D_PE_OP_A) ? op_a_valid : (
                   (delay_pe_op_mux_sel == D_PE_OP_B) ? op_b_valid : delay_op_valid
                  ));
  end

  // multi_op_instr is asserted when the instruction is a multi-operand one
  assign multi_op_instr = (fu_instr == ABSDIV || fu_instr == ABSMIN || fu_instr[4] == 1'b1);

  // Delay Operand Reg
  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      delay_op_out_d1 <= '0;
      delay_op_out_d2 <= '0;
    end else begin
      if (!mage_done_i && pea_ready_i) begin
        delay_op_out_d1 <= delay_op_out;
        delay_op_out_d2 <= delay_op_out_d1;
      end
    end
  end

  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      delay_op_out_d1_1 <= '0;
    end else begin
      if (div_instr && !mage_done_i && pea_ready_i) begin
        for (int i = 0; i < N_DIV_STAGE; i++) begin
          if (i == 0) begin
            delay_op_out_d1_1[i] <= delay_op_out_d1[N_BITS];
          end else begin
            delay_op_out_d1_1[i] <= delay_op_out_d1_1[i-1];
          end
        end
      end
    end
  end

  // Delay Operand Valid Reg
  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      delay_op_valid_out_d1 <= 1'b0;
      delay_op_valid_out_d2 <= 1'b0;
    end else begin
      if (!mage_done_i && pea_ready_i) begin
        delay_op_valid_out_d1 <= delay_op_valid_out;
        delay_op_valid_out_d2 <= delay_op_valid_out_d1;
      end
    end
  end

  /* 
  Delay Operand Output Mux
    The output of the delay operand is selected based on the instruction
    If the instruction is a multi-operand one, the output is selected from the second delay register
    Otherwise, the output is selected from the first delay register
  */
  always_comb begin
    if (!div_instr) begin
      if (delay_pe_op_mux_sel == D_PE_RES && multi_op_instr) begin
        delay_op_o = {delay_op_out_d2[N_BITS], delay_op_out_d1[N_BITS-1:0]};
        delay_op_valid_o = delay_op_valid_out_d1;
      end else if (delay_pe_op_mux_sel == D_PE_RES && !multi_op_instr) begin
        delay_op_o = delay_op_out_d1;
        delay_op_valid_o = delay_op_valid_out_d1;
      end else if (delay_pe_op_mux_sel != D_PE_RES && multi_op_instr) begin
        delay_op_o = delay_op_out_d2;
        delay_op_valid_o = delay_op_valid_out_d2;
      end else if (delay_pe_op_mux_sel != D_PE_RES && !multi_op_instr) begin
        delay_op_o = delay_op_out_d1;
        delay_op_valid_o = delay_op_valid_out_d1;
      end else begin
        delay_op_o = delay_op_out_d1;
        delay_op_valid_o = delay_op_valid_out_d1;
      end
    end else begin
      if (delay_pe_op_mux_sel == D_PE_RES && multi_op_instr) begin
        delay_op_o = {delay_op_out_d1_1[N_DIV_STAGE-1], delay_op_out_d1[N_BITS-1:0]};
        delay_op_valid_o = delay_op_valid_out_d1;
      end else if (delay_pe_op_mux_sel == D_PE_RES && !multi_op_instr) begin
        delay_op_o = {delay_op_out_d1_1[N_DIV_STAGE-2], delay_op_out_d1[N_BITS-1:0]};
        delay_op_valid_o = delay_op_valid_out_d1;
      end else if (delay_pe_op_mux_sel != D_PE_RES && !multi_op_instr) begin
        delay_op_o = {delay_op_out_d1_1[N_DIV_STAGE-2], delay_op_out_d1[N_BITS-1:0]};
        delay_op_valid_o = delay_op_valid_out_d1;
      end else begin
        delay_op_o = {delay_op_out_d1_1[N_DIV_STAGE-1], delay_op_out_d1[N_BITS-1:0]};
        delay_op_valid_o = delay_op_valid_out_d1;
      end
    end
  end

  ////////////////////////////////////////////////////////////////
  //                      Output Register                       //
  ////////////////////////////////////////////////////////////////

  /*
    The output register of the PE is set to:
      -> 0 when the instruction is NOP
      -> result of the FU when the instruction is not NOP, the output of the FU is valid and the pea is ready
      -> result of the FU when the instruction is ACC or MAX, the operands are valid and the pea is ready
      -> to itself otherwise, to preserve the current value
  */
  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      pe_res_o <= '0;
    end else begin
      if (!mage_done_i) begin
        if (fu_instr == NOP) begin
          pe_res_o <= '0;
        end else if((pea_ready_i && fu_valid) || ((fu_instr == ACC || fu_instr == MAX) && fu_ops_valid && pea_ready_i)) begin
          pe_res_o <= fu_out;
        end else begin
          pe_res_o <= pe_res_o;
        end
      end else begin
        pe_res_o <= '0;
      end
    end
  end

  ////////////////////////////////////////////////////////////////
  //                       Output Ready/Valid                   //
  ////////////////////////////////////////////////////////////////

  /*
    The output valid signal is set to:
      -> 0 when the instruction is NOP
      -> the FU valid signal when the pea is ready
      -> to itself otherwise, to preserve the current value
  */
  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      valid <= '0;
    end else begin
      if (!mage_done_i) begin
        if (fu_instr == NOP) begin
          valid <= 1'b0;
        end else if (pea_ready_i) begin
          valid <= fu_valid;
        end else begin
          valid <= valid_o;
        end
      end else begin
        valid <= '0;
      end
    end
  end

  assign valid_o = valid;
  assign ready_o = fu_ready;

endmodule
