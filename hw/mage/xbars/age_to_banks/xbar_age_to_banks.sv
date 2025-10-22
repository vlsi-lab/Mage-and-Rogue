// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: xbar_age_to_banks.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: AGE Group <-> SpM Bank Group Crossbar
//              This module describes a crossbar connection between an AGE Group and a Bank Group

module xbar_age_to_banks
  import pea_pkg::*;
  import agu_pkg::*;
(
    //Input signals from AGE Group
    input  logic [  N_AGE_PER_STREAM-1:0][         NBIT_ADDR-1:0] age_addr_i,
    input  logic [  N_AGE_PER_STREAM-1:0][N_BANKS_PER_STREAM-1:0] age_bank_i,
    input  logic [  N_AGE_PER_STREAM-1:0]                         age_valid_i,
    input  logic [  N_AGE_PER_STREAM-1:0]                         age_we_i,
    //Output signals to Bank Group
    output logic [N_BANKS_PER_STREAM-1:0][         NBIT_ADDR-1:0] age_dmem_addr_o,
    output logic [N_BANKS_PER_STREAM-1:0]                         age_dmem_bank_o,
    output logic [N_BANKS_PER_STREAM-1:0]                         age_dmem_we_o,
    output logic [N_BANKS_PER_STREAM-1:0]                         age_dmem_valid_o
);

  logic [  N_AGE_PER_STREAM-1:0][N_BANKS_PER_STREAM-1:0] age_bank;
  logic [N_BANKS_PER_STREAM-1:0]                         dmem_bank;
  logic [  N_AGE_PER_STREAM-1:0]                         age_we;

  //If the stream is valid, then the bank indicated by age_bank_i is valid
  //Otherwise, the bank selection bit is set to zero
  generate
    for (genvar i = 0; i < N_AGE_PER_STREAM; i++) begin : gen_req
      assign age_bank[i] = (age_valid_i[i] == 1'b1) ? age_bank_i[i] : '0;
    end
  endgenerate

  //If the stream is valid, then the write enable signal indicated by age_we_i is valid
  //Otherwise, the write enable bit is set to zero
  generate
    for (genvar i = 0; i < N_AGE_PER_STREAM; i++) begin : gen_we
      assign age_we[i] = (age_valid_i[i] == 1'b1) ? ~age_we_i[i] : '0;
    end
  endgenerate

  //The actual bank enable signal for the bank group
  //is the OR of the bank enable signals received from the streams
  always_comb begin
    dmem_bank = '0;
    for (int j = 0; j < N_AGE_PER_STREAM; j = j + 1) begin
      dmem_bank = dmem_bank | age_bank[j];
    end
  end

  assign age_dmem_bank_o = dmem_bank;

  always_comb begin
    for (int j = 0; j < N_BANKS_PER_STREAM; j = j + 1) begin
      age_dmem_addr_o[j] = '0;
      age_dmem_we_o[j] = '0;
      age_dmem_valid_o[j] = '0;
      for (int i = 0; i < N_AGE_PER_STREAM; i = i + 1) begin
        if (age_bank[i][j] == 1'b1) begin
          age_dmem_addr_o[j] = age_addr_i[i];
          age_dmem_we_o[j] = age_we[i];
          age_dmem_valid_o[j] = age_valid_i[i];
          break;
        end
      end
    end
  end

endmodule
