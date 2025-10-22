// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: accumulation_ctrl.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module generates the "match" signals that tell Mage and Pea when the accumulation is done.
//              When asserted, Mage issues the STORE instruction for the AGE that handles the accumulation.
//              Also, the PE that handles the accumulation restart the accumulation from the initial value.


module accumulation_ctrl
  import agu_pkg::*;
(
    input  logic                                                   clk_i,
    input  logic                                                   rst_n_i,
    // tells if accumulation is required
    input  logic                                                   reg_is_acc_i,
    //hwlp register file
    input  logic [     HWLP_RF_SIZE-1:0][N_LP-1:0][NBIT_LP_IV-1:0] hwlp_rf_i,
    //valid signal for the hwlp register file
    input  logic [     HWLP_RF_SIZE-1:0]                           hwlp_valid_i,
    //select signal for the hwlp register file
    input  logic [LOG2_HWLP_RF_SIZE-1:0]                           reg_acc_hwlp_sel_i,
    //select signal for the IV
    input  logic [        LOG2_N_LP-1:0]                           reg_acc_iv_sel_i,
    //IV constraint
    input  logic [       NBIT_LP_IV-1:0]                           reg_acc_iv_constraint_i,
    //Accumulation vector mode
    input  logic [                  1:0]                           reg_acc_vec_mode_i,
    //output match signal for Mage
    output logic                                                   match_o,
    //output match signal for PEA (delayed by 4 cycles)
    output logic                                                   match_d_o
);

  logic valid;
  logic [N_LP-1:0][NBIT_LP_IV-1:0] hwlp;
  logic [NBIT_LP_IV-1:0] iv;
  logic [4:0] match_pea;
  logic [3:0] match_mage;
  logic acc_match;
  logic act_mage_match;
  logic start_match;
  logic start_match_reached;

  //start_match has to be asserted when the accumulation starts at the beginning of the computation
  //for only one clock cycle, hence when valid is asserted and start_match is not asserted
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      start_match <= 1'b0;
      start_match_reached <= 1'b0;
    end else begin
      if (reg_is_acc_i == 1'b1) begin
        if (valid && start_match == 1'b0 && start_match_reached == 1'b0) begin
          start_match <= 1'b1;
          start_match_reached <= 1'b1;
        end else if (valid && start_match == 1'b1 && start_match_reached == 1'b1) begin
          start_match <= 1'b0;
          start_match_reached <= 1'b1;
        end else if (valid && start_match == 1'b0 && start_match_reached == 1'b1) begin
          start_match <= 1'b0;
          start_match_reached <= 1'b1;
        end else begin
          start_match <= 1'b0;
          start_match_reached <= 1'b0;
        end
      end else begin
        start_match <= 1'b0;
        start_match_reached <= 1'b0;
      end
    end
  end

  //match signal is asserted when the IV constraint is met
  always_comb begin
    if (reg_is_acc_i == 1'b1) begin

      valid = hwlp_valid_i[reg_acc_hwlp_sel_i];
      hwlp = hwlp_rf_i[reg_acc_hwlp_sel_i];
      iv = hwlp[reg_acc_iv_sel_i];

      if (valid == 1'b1) begin
        if (reg_acc_iv_constraint_i == iv) begin
          acc_match = 1'b1;
        end else begin
          acc_match = 1'b0;
        end
      end else begin
        acc_match = 1'b0;
      end

    end else begin

      valid = 1'b0;
      hwlp = 0;
      iv = 0;
      acc_match = 1'b0;

    end
  end

  //match signal to Mage is asserted when the accumulation has finished and the result has to be stored
  //assign match_o = acc_match;

  always_comb begin
    match_o   = act_mage_match;
    match_d_o = match_pea[4];
  end

  always_comb begin
    act_mage_match = acc_match;
    case (reg_acc_vec_mode_i)
      2'b01: begin  //vector mode 8
        act_mage_match = match_mage[0];
      end
      2'b10: begin  //vector mode 16
        act_mage_match = match_mage[0];
      end
      2'b00: begin  //no vector mode
        act_mage_match = match_mage[0];  // takes into account the 2-stages of mul32
      end
    endcase
  end

  //pipeline registers to adjust match for Pea
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      match_pea  <= '0;
      match_mage <= '0;
    end else begin
      if (reg_is_acc_i == 1'b1) begin
        // match pea signal delaying
        match_pea[0]  <= act_mage_match;
        match_pea[1]  <= match_pea[0];
        match_pea[2]  <= match_pea[1] || start_match;
        match_pea[3]  <= match_pea[2];
        match_pea[4]  <= match_pea[3];
        // match mage signal delaying
        match_mage[0] <= acc_match;
        match_mage[1] <= match_mage[0];
        match_mage[2] <= match_mage[1];
        match_mage[3] <= match_mage[2];
      end else begin
        match_pea  <= '0;
        match_mage <= '0;
      end
    end
  end


endmodule : accumulation_ctrl
