// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: dmem_decoder.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module handles tha access to internal SpM from both the CGRA and the external system

module dmem_decoder
  import pea_pkg::*;
  import agu_pkg::*;
(
    input                                               clk_i,
    input                                               rst_n_i,
    input  state_t                                      state_i,
    /* CGRA to internal SpM */
    input  logic   [N_BANKS-1:0]                        agu_dmem_req_i,
    input  logic   [N_BANKS-1:0]                        agu_dmem_we_i,
    input  logic   [N_BANKS-1:0]                        agu_dmem_valid_i,
    input  logic   [N_BANKS-1:0][$clog2(BANK_SIZE)-1:0] agu_dmem_addr_i,
    input  logic   [N_BANKS-1:0][           N_BITS-1:0] agu_dmem_wdata_i,
    /* External system to internal SpM */
    input  logic                                        ext_dmem_req_i,
    input  logic                                        ext_dmem_we_i,
    input  logic   [        3:0]                        ext_dmem_be_i,
    input  logic   [     32-1:0]                        ext_dmem_addr_i,
    input  logic   [     32-1:0]                        ext_dmem_wdata_i,
    /* Selected outputs to internal SpM */
    output logic   [N_BANKS-1:0]                        dmem_req_o,
    output logic   [N_BANKS-1:0]                        dmem_we_o,
    output logic   [N_BANKS-1:0][                  3:0] dmem_be_o,
    output logic   [N_BANKS-1:0][$clog2(BANK_SIZE)-1:0] dmem_addr_o,
    output logic   [N_BANKS-1:0][           N_BITS-1:0] dmem_wdata_o,
    output logic   [N_BANKS-1:0][           N_BITS-1:0] agu_dmem_rdata_o,
    input  logic   [N_BANKS-1:0][           N_BITS-1:0] dmem_rdata_i,
    output logic                                        ext_dmem_valid_o,
    output logic                                        ext_dmem_gnt_o,
    output logic   [     32-1:0]                        ext_dmem_rdata_o



);

  logic                                 is_dmem_address;
  logic [                 12:0]         addr_lrs_2;
  logic [          N_BANKS-1:0]         active_banks;

  logic [          N_BANKS-1:0]         ext_dmem_req;
  logic [          N_BANKS-1:0][   3:0] ext_dmem_be;
  logic [          N_BANKS-1:0]         ext_dmem_req_d;
  logic [          N_BANKS-1:0]         ext_dmem_we;
  logic [          N_BANKS-1:0][32-1:0] ext_dmem_rdata;

  logic [$clog2(BANK_SIZE)-1:0]         addr_to_bank;


  assign addr_lrs_2 = ext_dmem_addr_i[14:2];

  always_comb begin

    active_banks = '0;
    addr_to_bank = addr_lrs_2[$clog2(BANK_SIZE)-1:0];

    active_banks[0] = (addr_lrs_2[12:10] == 3'b000) ? 1'b1 : 1'b0;
    active_banks[1] = (addr_lrs_2[12:10] == 3'b001) ? 1'b1 : 1'b0;
    active_banks[2] = (addr_lrs_2[12:10] == 3'b010) ? 1'b1 : 1'b0;
    active_banks[3] = (addr_lrs_2[12:10] == 3'b011) ? 1'b1 : 1'b0;
    active_banks[4] = (addr_lrs_2[12:10] == 3'b100) ? 1'b1 : 1'b0;
    active_banks[5] = (addr_lrs_2[12:10] == 3'b101) ? 1'b1 : 1'b0;
    active_banks[6] = (addr_lrs_2[12:10] == 3'b110) ? 1'b1 : 1'b0;
    active_banks[7] = (addr_lrs_2[12:10] == 3'b111) ? 1'b1 : 1'b0;

    addr_to_bank = addr_lrs_2[$clog2(BANK_SIZE)-1:0];

  end

  always_comb begin
    is_dmem_address = (ext_dmem_addr_i[32-1:32-4] == 4'b1111) ? 1'b1 : 1'b0;

    if (is_dmem_address == 1'b1) begin
      //suppose 8 memory banks for dmem
      if (active_banks[0]) begin
        ext_dmem_req = {7'd0, ext_dmem_req_i};
      end else if (active_banks[1]) begin
        ext_dmem_req = {6'd0, ext_dmem_req_i, 1'b0};
      end else if (active_banks[2]) begin
        ext_dmem_req = {5'd0, ext_dmem_req_i, 2'b00};
      end else if (active_banks[3]) begin
        ext_dmem_req = {4'd0, ext_dmem_req_i, 3'b000};
      end else if (active_banks[4]) begin
        ext_dmem_req = {3'd0, ext_dmem_req_i, 4'b0000};
      end else if (active_banks[5]) begin
        ext_dmem_req = {2'd0, ext_dmem_req_i, 5'b00000};
      end else if (active_banks[6]) begin
        ext_dmem_req = {1'd0, ext_dmem_req_i, 6'b000000};
      end else if (active_banks[7]) begin
        ext_dmem_req = {ext_dmem_req_i, 7'b0000000};
      end else begin
        ext_dmem_req = '0;
      end

      for (int i = 0; i < N_BANKS; i++) begin
        ext_dmem_we[i] = ext_dmem_we_i;
        ext_dmem_be[i] = ext_dmem_be_i;
      end

    end else begin
      ext_dmem_req = '0;
      ext_dmem_we  = '0;
      ext_dmem_be  = '0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (~rst_n_i) begin
      ext_dmem_req_d   <= '0;
      ext_dmem_valid_o <= '0;
      ext_dmem_gnt_o   <= '0;
    end else begin
      ext_dmem_valid_o <= |ext_dmem_req;
      ext_dmem_gnt_o   <= |ext_dmem_req;
      ext_dmem_req_d   <= ext_dmem_req;
    end
  end


  //Based on the state, select the right inputs to feed to the internal SpM
  always_comb begin
    case (state_i)

      /*
        In the EXEC state:
          > The CGRA can read/write to banks
          > The external system can read/write to banks
        However:
          ! The CGRA and the external systems MUST interact with different sets of banks
      */

      EXEC: begin

        // SpM accepts requests from AGU and external system
        dmem_req_o = agu_dmem_req_i | ext_dmem_req;

        // SpM accepts WE from AGU and external system
        dmem_we_o  = agu_dmem_we_i | ext_dmem_we;

        for (int i = 0; i < N_BANKS; i++) begin

          // SpM BE chosen based on external request bit
          dmem_be_o[i] = (ext_dmem_req[i] == 1'b1) ? ext_dmem_be[i] : 4'b1111;

          // SpM address chosen based on external request bit
          dmem_addr_o[i] = (ext_dmem_req[i] == 1'b1) ? addr_to_bank : agu_dmem_addr_i[i];

          // SpM write data chosen based on external request bit
          dmem_wdata_o[i] = (ext_dmem_req[i] == 1'b1) ? ext_dmem_wdata_i : agu_dmem_wdata_i[i];
        end

        // SpM read data towards external system based on external request bit
        for (int i = 0; i < N_BANKS; i++) begin
          ext_dmem_rdata[i] = {32{ext_dmem_req_d[i]}} & dmem_rdata_i[i];
        end

        ext_dmem_rdata_o = '0;
        for (int i = 0; i < N_BANKS; i++) begin
          ext_dmem_rdata_o |= ext_dmem_rdata[i];
        end

        // SpM read data towards PEA based on AGEs valid bits
        for (int i = 0; i < N_BANKS; i++) begin
          if (agu_dmem_valid_i[i] == 1'b1) begin
            agu_dmem_rdata_o[i] = dmem_rdata_i[i];
          end else begin
            agu_dmem_rdata_o[i] = '0;
          end
        end

      end

      /*
        In the IDLE state:
          > The CGRA CANNOT read/write to banks
          > The external system can read/write to banks
      */

      default: begin
        // SpM accepts requests from external system
        dmem_req_o = ext_dmem_req;

        // SpM accepts WE from external system
        dmem_we_o  = ext_dmem_we;

        // SpM accepts BE from external system
        dmem_be_o  = ext_dmem_be;

        for (int i = 0; i < N_BANKS; i++) begin

          // SpM address chosen based on external request bit
          dmem_addr_o[i]  = (ext_dmem_req[i] == 1'b1) ? addr_to_bank : '0;

          // SpM write data is taken from external system
          dmem_wdata_o[i] = ext_dmem_wdata_i;
        end

        // SpM read data towards external system based on external request bit
        for (int i = 0; i < N_BANKS; i++) begin
          ext_dmem_rdata[i] = {32{ext_dmem_req_d[i]}} & dmem_rdata_i[i];
        end

        ext_dmem_rdata_o = '0;
        for (int i = 0; i < N_BANKS; i++) begin
          ext_dmem_rdata_o |= ext_dmem_rdata[i];
        end

        // SpM read data towards PEA is alaways 0
        agu_dmem_rdata_o = '0;
      end
    endcase
  end


endmodule : dmem_decoder
