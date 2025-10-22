// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: dmem_decoder.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module handles tha access to data memory from both Mage and the external system
//              By configuring the block size, the module can decide which bank to access based on the address (reconfigurable memory mapping)

module dmem_decoder
  import pea_pkg::*;
  import agu_pkg::*;
(
    input                                               clk_i,
    input                                               rst_n_i,
    input  state_t                                      state_i,
    // cfg extenral data transfer
    input          [        3:0]                        reg_block_size_i,
    //Mage to Data Memory
    input  logic   [N_BANKS-1:0]                        agu_dmem_req_i,
    input  logic   [N_BANKS-1:0]                        agu_dmem_we_i,
    input  logic   [N_BANKS-1:0]                        agu_dmem_valid_i,
    input  logic   [N_BANKS-1:0][$clog2(BANK_SIZE)-1:0] agu_dmem_addr_i,
    input  logic   [N_BANKS-1:0][           N_BITS-1:0] agu_dmem_wdata_i,
    //Extern to Data Memory
    input  logic                                        ext_dmem_req_i,
    input  logic                                        ext_dmem_we_i,
    input  logic   [     32-1:0]                        ext_dmem_addr_i,
    input  logic   [     32-1:0]                        ext_dmem_wdata_i,
    //Actual outputs to Data Memory
    output logic   [N_BANKS-1:0]                        dmem_req_o,
    output logic   [N_BANKS-1:0]                        dmem_we_o,
    output logic   [N_BANKS-1:0][$clog2(BANK_SIZE)-1:0] dmem_addr_o,
    output logic   [N_BANKS-1:0][           N_BITS-1:0] dmem_wdata_o,
    output logic   [N_BANKS-1:0][           N_BITS-1:0] agu_dmem_rdata_o,
    input  logic   [N_BANKS-1:0][           N_BITS-1:0] dmem_rdata_i,
    output logic                                        ext_dmem_valid_o,
    output logic                                        ext_dmem_gnt_o,
    output logic   [     32-1:0]                        ext_dmem_rdata_o



);

  localparam logic [31:0] START_ADDRESS = 32'hF0000000 + 32'h00000000;
  localparam logic [31:0] SIZE = 32'h100000;

  logic [          N_BANKS-1:0]         ext_dmem_req;
  logic [          N_BANKS-1:0]         ext_dmem_req_d;
  logic [          N_BANKS-1:0]         ext_dmem_we;
  logic                                 is_dmem_address;  //checks start address peripherals
  logic [               32-1:0]         addr_lrs_2;
  logic [               32-1:0]         ext_dmem_addr;
  logic [          N_BANKS-1:0]         active_banks;
  logic [$clog2(BANK_SIZE)-1:0]         addr_to_bank;
  logic [          N_BANKS-1:0][32-1:0] ext_dmem_rdata;


  assign addr_lrs_2 = ext_dmem_addr_i >> 2;

  always_comb begin

    active_banks = '0;
    addr_to_bank = addr_lrs_2[$clog2(BANK_SIZE)-1:0];

    case (reg_block_size_i)

      4'b0001: begin
        active_banks[0] = (addr_lrs_2[2:0] == 3'b000) ? 1'b1 : 1'b0;
        active_banks[1] = (addr_lrs_2[2:0] == 3'b001) ? 1'b1 : 1'b0;
        active_banks[2] = (addr_lrs_2[2:0] == 3'b010) ? 1'b1 : 1'b0;
        active_banks[3] = (addr_lrs_2[2:0] == 3'b011) ? 1'b1 : 1'b0;
        active_banks[4] = (addr_lrs_2[2:0] == 3'b100) ? 1'b1 : 1'b0;
        active_banks[5] = (addr_lrs_2[2:0] == 3'b101) ? 1'b1 : 1'b0;
        active_banks[6] = (addr_lrs_2[2:0] == 3'b110) ? 1'b1 : 1'b0;
        active_banks[7] = (addr_lrs_2[2:0] == 3'b111) ? 1'b1 : 1'b0;
        addr_to_bank = addr_lrs_2[$clog2(BANK_SIZE)-1:0] >> 3;
      end

      4'b0000: begin
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

    endcase
  end

  always_comb begin
    is_dmem_address = (ext_dmem_addr_i[32-1:32-4] == 4'b1111) ? 1'b1 : 1'b0;

    if (is_dmem_address == 1'b1) begin
      //suppose 8 memory banks for dmem
      if (active_banks[0]) begin
        ext_dmem_req = {7'd0, ext_dmem_req_i};
        ext_dmem_we  = {7'd0, ext_dmem_we_i};
      end else if (active_banks[1]) begin
        ext_dmem_req = {6'd0, ext_dmem_req_i, 1'b0};
        ext_dmem_we  = {6'd0, ext_dmem_we_i, 1'b0};
      end else if (active_banks[2]) begin
        ext_dmem_req = {5'd0, ext_dmem_req_i, 2'b00};
        ext_dmem_we  = {5'd0, ext_dmem_we_i, 2'b00};
      end else if (active_banks[3]) begin
        ext_dmem_req = {4'd0, ext_dmem_req_i, 3'b000};
        ext_dmem_we  = {4'd0, ext_dmem_we_i, 3'b000};
      end else if (active_banks[4]) begin
        ext_dmem_req = {3'd0, ext_dmem_req_i, 4'b0000};
        ext_dmem_we  = {3'd0, ext_dmem_we_i, 4'b0000};
      end else if (active_banks[5]) begin
        ext_dmem_req = {2'd0, ext_dmem_req_i, 5'b00000};
        ext_dmem_we  = {2'd0, ext_dmem_we_i, 5'b00000};
      end else if (active_banks[6]) begin
        ext_dmem_req = {1'd0, ext_dmem_req_i, 6'b000000};
        ext_dmem_we  = {1'd0, ext_dmem_we_i, 6'b000000};
      end else if (active_banks[7]) begin
        ext_dmem_req = {ext_dmem_req_i, 7'b0000000};
        ext_dmem_we  = {ext_dmem_we_i, 7'b0000000};
      end else begin
        ext_dmem_req = '0;
        ext_dmem_we  = '0;
      end
    end else begin
      ext_dmem_req = '0;
      ext_dmem_we  = '0;
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


  //Based on the state, select the right inputs to feed to the Data Memory
  always_comb begin
    case (state_i)

      EXEC: begin

        dmem_req_o = agu_dmem_req_i | ext_dmem_req;
        dmem_we_o  = agu_dmem_we_i | ext_dmem_we;

        for (int i = 0; i < N_BANKS; i++) begin
          dmem_addr_o[i]  = (ext_dmem_req[i] == 1'b1) ? addr_to_bank : agu_dmem_addr_i[i];
          dmem_wdata_o[i] = (ext_dmem_req[i] == 1'b1) ? ext_dmem_wdata_i : agu_dmem_wdata_i[i];
        end

        ext_dmem_rdata_o = '0;

        for (int i = 0; i < N_BANKS; i++) begin
          if (agu_dmem_valid_i[i] == 1'b1) begin
            agu_dmem_rdata_o[i] = dmem_rdata_i[i];
          end else begin
            agu_dmem_rdata_o[i] = '0;
          end
        end

      end

      default: begin
        dmem_req_o = ext_dmem_req;
        dmem_we_o  = ext_dmem_we;

        for (int i = 0; i < N_BANKS; i++) begin
          dmem_addr_o[i]  = (ext_dmem_req[i] == 1'b1) ? addr_to_bank : '0;
          dmem_wdata_o[i] = ext_dmem_wdata_i;
        end

        for (int i = 0; i < N_BANKS; i++) begin
          ext_dmem_rdata[i] = {32{ext_dmem_req_d[i]}} & dmem_rdata_i[i];
        end

        ext_dmem_rdata_o = '0;
        for (int i = 0; i < N_BANKS; i++) begin
          ext_dmem_rdata_o |= ext_dmem_rdata[i];
        end

        agu_dmem_rdata_o = '0;
      end
    endcase
  end


endmodule : dmem_decoder
