// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: age.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module describes the Address Generation Engine (AGE) that generates the address, bank
//              and load_not_store signals

module age
  import agu_pkg::*;
(
    input logic clk_i,
    input logic rst_n_i,
    // start-end signal
    input pea_pkg::state_t state_i,
    input logic end_lp_i,
    ////////////////////////////////
    //      Signals from ROU      //
    ////////////////////////////////
    // AGE valid (comes from HWLP thorugh ROU, indicating that the address generation is valid with current IVs)
    input logic valid_i,
    // IVs used for calculating addresses
    input logic [N_IVS-1:0][NBIT_LP_IV-1:0] iv_i,
    // Reset for accumulation
    input logic pea_acc_reset_i,
    //////////////////////////////////////////////
    //Signals from Dispatcher (Instruction Word)//
    //////////////////////////////////////////////
    // AGE active (comes from instruction word, indicating the AGE is being used)
    input logic active_i,
    // Strides for IVs
    input logic [N_IVS-1:0][NBIT_LP_IV-1:0] age_strides_i,
    // Number of banks in which operand is divided into
    input logic [NBIT_N_BANKS-1:0] n_banks_i,
    // Bank from which data starts to be stored
    input logic [NBIT_START_BANK-1:0] start_bank_i,
    // Block size
    input logic [NBIT_BLOCK_SIZE-1:0] block_size_i,
    // Asserted if AGE handles a store of an accumulation
    input logic is_acc_store_i,
    // asserted for load AGE, otherwise store AGE
    input logic lns_i,
    ////////////////////////////////
    // Signals from Cfg Registers //
    ////////////////////////////////
    // IV constant to be addedd in address calculation
    input logic [NBIT_LP_IV-1:0] iv_const_i,
    ////////////////////////////////
    //          Outputs           //
    ////////////////////////////////
    output logic end_lp_o,
    // Address
    output logic [NBIT_ADDR-1:0] age_addr_o,
    // Bank ID
    output logic [N_BANKS_PER_STREAM-1:0] age_bank_o,
    // Bank ID ls
    output logic [LOG_N_BANKS_PER_STREAM-1:0] age_bank_ls_stream_o,
    // Reset for acc
    output logic pea_acc_reset_o,
    // Valid
    output logic valid_o,
    // Valid ls
    output logic valid_ls_o,
    // load-not-store
    output logic lns_o
);

  logic                                           clk_cg;
  logic                                           exec;

  ////////////////////////////////
  //   Configuration [Static]   //
  ////////////////////////////////

  // Stage 0 cfg from instruction word
  logic [          N_IVS-1:0][    NBIT_LP_IV-1:0] age_strides_0;

  // Stage 1 cfg from instruction word
  logic [     NBIT_LP_IV-1:0]                     iv_const_1;

  // Stage 2 cfg from instruction word
  logic [   NBIT_N_BANKS-1:0]                     n_banks_2;
  logic [NBIT_START_BANK-1:0]                     start_bank_2;
  logic [NBIT_BLOCK_SIZE-1:0]                     block_size_2;
  logic                                           stream_lns_2;
  logic                                           is_acc_store_2;

  ////////////////////////////////
  //   Operands of AGE Stages   //
  ////////////////////////////////

  // Stage 0
  logic [                1:0][NBIT_FLAT_ADDR-1:0] mult_temp_res;
  logic [          N_IVS-1:0][NBIT_FLAT_ADDR-1:0] mult_ivs_in_reg;
  logic [          N_IVS-1:0][NBIT_FLAT_ADDR-1:0] mult_ivs_out_reg;

  // Stage 1
  logic [ NBIT_FLAT_ADDR-1:0]                     flat_address_in_reg;
  logic [ NBIT_FLAT_ADDR-1:0]                     flat_address_out_reg;

  // Stage 2
  logic [ NBIT_FLAT_ADDR-1:0]                     x_div_bs;
  logic [ NBIT_FLAT_ADDR-1:0]                     x_rem_bs;
  logic [   NBIT_N_BANKS-1:0]                     age_bank_ls_stream_in_reg;
  logic [   NBIT_N_BANKS-1:0]                     age_bank_ls_stream_out_reg;

  ////////////////////////////////
  //        ROU signals         //
  ////////////////////////////////

  logic [                2:0]                     valid_2;
  logic [          N_IVS-1:0][    NBIT_LP_IV-1:0] iv_0;
  logic [                2:0]                     pea_acc_reset_2;

  ////////////////////////////////
  //     Start-End Signals      //
  ////////////////////////////////
  logic [                2:0]                     end_lp_2;

  ////////////////////////////////
  //     Clock-gating cell      //
  ////////////////////////////////
`ifndef VERILATOR
`ifndef FPGA
  // PE Clock-gating
  logic clk_cg_en;
  assign clk_cg_en = ~active_i;
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

  assign exec = (state_i == pea_pkg::EXEC) && active_i;

  ////////////////////////////////
  //       Pipe Registers       //
  ////////////////////////////////
  ////////////////////////////////
  //   Configuration [Static]   //
  ////////////////////////////////
  always_comb begin
    n_banks_2 = n_banks_i;
    start_bank_2 = start_bank_i;
    block_size_2 = block_size_i;
    stream_lns_2 = lns_i;
    is_acc_store_2 = is_acc_store_i;
    iv_const_1 = iv_const_i;
    age_strides_0 = age_strides_i;
  end

  ////////////////////////////////
  //   Operands of AGE Stages   //
  ////////////////////////////////
  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      mult_ivs_out_reg     <= '0;
      flat_address_out_reg <= '0;
    end else begin
      if (exec && (!end_lp_2[2])) begin
        // Stage 0 to 1
        mult_ivs_out_reg     <= mult_ivs_in_reg;
        // Stage 1 to 2
        flat_address_out_reg <= flat_address_in_reg;
      end else begin
        mult_ivs_out_reg     <= '0;
        flat_address_out_reg <= '0;
      end
    end
  end

  ////////////////////////////////
  //        ROU Signals         //
  ////////////////////////////////
  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      valid_2         <= '0;
      pea_acc_reset_2 <= '0;
      iv_0            <= '0;
    end else begin
      if (exec && (!end_lp_2[2])) begin
        valid_2[0]         <= valid_i;
        valid_2[1]         <= valid_2[0];
        valid_2[2]         <= valid_2[1];

        pea_acc_reset_2[0] <= pea_acc_reset_i;
        pea_acc_reset_2[1] <= pea_acc_reset_2[0] && is_acc_store_2;
        pea_acc_reset_2[2] <= pea_acc_reset_2[1];

        iv_0               <= iv_i;
      end else begin
        valid_2         <= '0;
        pea_acc_reset_2 <= '0;
        iv_0            <= '0;
      end
    end
  end

  ////////////////////////////////
  //       Output Signals       //
  ////////////////////////////////

  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      valid_o         <= '0;
      pea_acc_reset_o <= '0;
      age_addr_o      <= '0;
      age_bank_o      <= '0;
      lns_o           <= '0;
    end else begin
      if (exec && (!end_lp_2[2])) begin
        valid_o <= valid_2[2];

        pea_acc_reset_o <= pea_acc_reset_2[2];

        age_addr_o <= ((flat_address_out_reg >> (block_size_2 + n_banks_2)) << (block_size_2)) + x_rem_bs;

        age_bank_ls_stream_out_reg <= age_bank_ls_stream_in_reg;

        age_bank_o <= 1 << age_bank_ls_stream_in_reg;

        lns_o <= stream_lns_2;
      end else begin
        valid_o         <= '0;
        pea_acc_reset_o <= '0;
        age_addr_o      <= '0;
        age_bank_o      <= '0;
        lns_o           <= '0;
      end
    end
  end

  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      age_bank_ls_stream_o <= '0;
      valid_ls_o <= '0;
    end else begin
      if (exec) begin
        valid_ls_o <= valid_o;
        age_bank_ls_stream_o <= age_bank_ls_stream_out_reg[0];
      end else begin
        valid_ls_o <= '0;
        age_bank_ls_stream_o <= '0;
      end
    end
  end

  ////////////////////////////////
  //     Start-End Signals      //
  ////////////////////////////////

  always_ff @(posedge clk_cg or negedge rst_n_i) begin
    if (!rst_n_i) begin
      end_lp_2 <= '0;
      end_lp_o <= '0;
    end else begin
      if (exec) begin
        if (end_lp_i) begin
          end_lp_2[0] <= end_lp_i;
        end
        end_lp_2[1] <= end_lp_2[0];
        end_lp_2[2] <= end_lp_2[1];
        end_lp_o    <= end_lp_2[2];
      end else begin
        end_lp_2 <= '0;
        end_lp_o <= '0;
      end
    end
  end

  ////////////////////////////////
  //  Operations of AGE Stages  //
  ////////////////////////////////

  // Stage 0: multiplication of IVs by their strides
  always_comb begin
    for (int i = 0; i < N_IVS; i = i + 1) begin
      mult_ivs_in_reg[i] = iv_0[i] * age_strides_0[i];
    end
  end

  // Stage 1: addition tree for multiplied IVs to generate the "flattened" address
  assign mult_temp_res[0] = mult_ivs_out_reg[0] + mult_ivs_out_reg[1];
  assign mult_temp_res[1] = mult_ivs_out_reg[2] + mult_ivs_out_reg[3];
  always_comb begin
    flat_address_in_reg = mult_temp_res[0] + mult_temp_res[1] + {2'b0, iv_const_1};  // UNSIGNED
  end

  // Stage 2: bank ID and address generation based on number of banks, start bank and block size
  always_comb begin
    x_div_bs = (flat_address_out_reg >> block_size_2);
    case (n_banks_2)
      2'b00:   age_bank_ls_stream_in_reg = start_bank_2;
      2'b01:   age_bank_ls_stream_in_reg = {1'b0, x_div_bs[0]} + start_bank_2;
      default: age_bank_ls_stream_in_reg = '0;
    endcase

    case (block_size_2)
      2'b00:   x_rem_bs = '0;
      2'b01:   x_rem_bs = {{NBIT_FLAT_ADDR - 1{1'b0}}, flat_address_out_reg[0]};
      2'b10:   x_rem_bs = {{NBIT_FLAT_ADDR - 2{1'b0}}, flat_address_out_reg[1:0]};
      default: x_rem_bs = '0;
    endcase
  end

endmodule : age
