// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: k_controller.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module implements the PKE-based controller of the cgra. However, P and E are not used.
//              Only K and the number of repetitions of the kernel are used. It also handles the delivery of the start signal
//              to Pea. Moreover, the count signal of the counter is used to the address to select the current configuration both in
//              Agu and Pea.

module k_controller
  import pea_pkg::*;
(
    input  logic                                      clk_i,
    input  logic                                      rst_n_i,
    input  state_t                                    state_i,
% if kernel_len != 1:
    input  loop_pipeline_info_t                       reg_lp_info_i,
    output logic                [N_CFG_ADDR_BITS-1:0] count_pke_o,
    output logic                [N_CFG_ADDR_BITS-1:0] count_pke_d_o,
% endif
    output logic                                      start_d_o
);

  logic [3:0] start;
  logic exec;

  assign exec = state_i == EXEC;

% if kernel_len != 1:
  logic [N_CFG_ADDR_BITS-1:0] count_pke;
  logic [4:0][N_CFG_ADDR_BITS-1:0] count_pke_d;

  always_ff @(posedge clk_i, negedge rst_n_i) begin : pke_controller_proc
    if (!rst_n_i) begin
      count_pke <= '0;
    end else if (exec) begin
      if (count_pke == reg_lp_info_i.len_k) begin
        count_pke <= 0;
      end else begin
        count_pke <= count_pke + 1;
      end
    end else begin
      count_pke <= reg_lp_info_i.len_p;
    end
  end

  assign count_pke_o = count_pke;
% endif

  always_ff @(posedge clk_i, negedge rst_n_i) begin : pke_controller_d_proc
    if (!rst_n_i) begin
% if kernel_len != 1:
      count_pke_d <= '0;
      count_pke_d_o <= '0;
% endif
      start <= '0;
      start_d_o <= '0;
    end else begin
% if kernel_len != 1:
      count_pke_d[0] <= count_pke;
      count_pke_d[1] <= count_pke_d[0];
      count_pke_d[2] <= count_pke_d[1];
      count_pke_d[3] <= count_pke_d[2];
      count_pke_d_o  <= count_pke_d[3];
% endif
      start[0] <= exec;
      start[1] <= start[0];
      start[2] <= start[1];
      start[3] <= start[2];
      start_d_o <= start[3];
    end
  end

endmodule
