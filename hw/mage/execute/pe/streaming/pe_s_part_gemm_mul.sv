// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: pe_s_part_gemm_mul.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: PE for streaming mode supporting int32 computation of classic gemm-related operations

module pe_s_part_gemm_mul
  import pea_pkg::*;
(
    input  logic                                 clk_i,
    input  logic                                 rst_n_i,
    // overall done signal
    input  logic                                 mage_done_i,
    // instruction word
    input  logic [N_CFG_BITS_PE-1:0]             ctrl_pe_i,
    // RF values
    input  logic [              1:0]             reg_rf_value_i,
    input  logic [             15:0]             reg_acc_value_i,
    input  logic [       N_BITS-1:0]             reg_const_i,
    output logic                                 reg_pea_rf_de_o,
    output logic [       N_BITS-1:0]             reg_pea_rf_d_o,
    // overall PEA ready
    input  logic                                 pea_ready_i,
    // neighbor data, delay operands and valid signals
    input  logic [  N_INPUTS_PE-4:0][N_BITS-1:0] neigh_pe_op_i,
    input  logic [  N_INPUTS_PE-4:0]             neigh_pe_op_valid_i,
    input  logic [   N_NEIGH_PE-1:0][  N_BITS:0] neigh_delay_op_i,
    input  logic [   N_NEIGH_PE-1:0]             neigh_delay_op_valid_i,
    // outputs
    output logic                                 valid_o,
    output logic                                 ready_o,
    output logic                                 delay_op_valid_o,
    output logic [         N_BITS:0]             delay_op_o,
    output logic [       N_BITS-1:0]             pe_res_o
);

  logic                                               clk_cg;
  // inputs to FU
  logic                 [     N_BITS-1:0]             op_a;
  logic                 [     N_BITS-1:0]             op_b;
  // mux selectors
  pe_mux_sel_t                                        mux_sel_a;
  pe_mux_sel_t                                        mux_sel_b;
  // vector mode
  logic                 [            2:0]             part_vec_mode;
  // operands valid
  logic                                               op_a_valid;
  logic                                               op_b_valid;
  // delay operands signals
  delay_pe_mux_sel_t                                  delay_pe_mux_sel;
  delay_pe_op_mux_sel_t                               delay_pe_op_mux_sel;
  logic                 [       N_BITS:0]             delay_op_fu;
  logic                 [       N_BITS:0]             delay_op_out;
  logic                 [       N_BITS:0]             delay_op_out_d1;
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
  // accumulation signals
  logic                                               valid;
  logic                                               acc_loopback;
  // fu signals
  logic                 [     N_BITS-1:0]             fu_out;
  fu_instr_t                                          fu_instr;
  // RF
  logic                                               rf_en;
  logic                 [            1:0]             rf_sel;
  logic                 [            1:0]             rf_cnt;
  logic                 [            1:0]             rf_val;
  logic                 [            4:0]             rf_cfg;
  logic                 [     N_BITS-1:0]             loopback_shacc;

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
      mux_sel_a = pe_mux_sel_t'(ctrl_pe_i[OP_A_SEL_MSB : OP_A_SEL_LSB]);
    end
    mux_sel_b = pe_mux_sel_t'(ctrl_pe_i[OP_B_SEL_MSB : OP_B_SEL_LSB]);
  end

  assign part_vec_mode = ctrl_pe_i[VEC_MODE_SEL_MSB : VEC_MODE_SEL_LSB];
  assign fu_instr = fu_instr_t'(ctrl_pe_i[INSTR_SEL_MSB : INSTR_SEL_LSB]);
  assign rf_cfg = ctrl_pe_i[RF_SEL_MSB : RF_SEL_LSB];
  assign delay_pe_mux_sel = delay_pe_mux_sel_t'(ctrl_pe_i[DELAY_PE_SEL_MSB : DELAY_PE_SEL_LSB]);
  assign delay_pe_op_mux_sel  = delay_pe_op_mux_sel_t'(ctrl_pe_i[DELAY_PE_OP_SEL_MSB : DELAY_PE_OP_SEL_LSB]);

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
  fu_s_part_gemm_mul fu_wrapper_i (
      .clk_i(clk_cg),
      .rst_n_i(rst_n_i),
      .mage_done_i,
      .part_vec_mode_i(part_vec_mode),
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
      .acc_loopback_o(acc_loopback),
      .instr_i(fu_instr),
      .res_o(fu_out)
  );

  ////////////////////////////////////////////////////////////////
  //                    Delay Operand Selection                 //
  ////////////////////////////////////////////////////////////////

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
  // delayed operand valid selection
  assign delay_op_valid = neigh_delay_op_valid_i[delay_pe_mux_sel];


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
    delay_op_valid_out = (delay_pe_op_mux_sel == D_PE_RES) ? fu_valid : (
                         (delay_pe_op_mux_sel == D_PE_OP_A) ? op_a_valid : (
                         (delay_pe_op_mux_sel == D_PE_OP_B) ? op_b_valid : delay_op_valid
                         ));
  end

  // multi_op_instr is asserted when the instruction is a multi-operand one
  assign multi_op_instr = fu_instr[4] == 1'b1;

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
      if (!mage_done_i && pea_ready_i) begin
        delay_op_out_d1 <= delay_op_out;
        delay_op_out_d2 <= delay_op_out_d1;
      end
    end
  end

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
        delay_op_valid_o = delay_op_valid_out_d1;
      end else begin
        delay_op_o = delay_op_out_d1;
        delay_op_valid_o = delay_op_valid_out_d1;
      end
    end else begin
      if (multi_op_instr) begin
        delay_op_o = delay_op_out_d2;
        delay_op_valid_o = delay_op_valid_out_d2;
      end else begin
        delay_op_o = delay_op_out_d1;
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
      -> result of the FU when the instruction is ACC, SHACC or MAX, the operands are valid and the pea is ready
        -> However, the output is not always valid, but we make it available in output to feed it back to FU
      -> to itself otherwise, to preserve the current value
  */
  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      pe_res_o <= '0;
    end else begin
      if (!mage_done_i) begin
        if (fu_instr == NOP) begin
          pe_res_o <= '0;
        end else if((pea_ready_i && fu_valid) || ((fu_instr == ACC || fu_instr == SHACC || fu_instr == MAX) && fu_ops_valid && pea_ready_i)) begin
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
        valid <= 1'b0;
      end
    end
  end

  assign valid_o = valid;
  assign ready_o = fu_ready;

endmodule
