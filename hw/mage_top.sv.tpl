// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: mage_top.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: Top level entity of CGRA

module mage_top
%if dae_cgra == 1:
  import agu_pkg::*;
  import xbar_pkg::*;
%endif
%if streaming_cgra == 1:
  import fifo_pkg::*;
  import stream_intf_pkg::*;
%endif
  import pea_pkg::*;
  import reg_pkg::*;
(
    input  logic                                          clk_i,
    input  logic                                          rst_n_i,
    /* Reg Interface */
    input  reg_req_t                                      reg_req_i,
    output reg_rsp_t                                      reg_rsp_o
%if streaming_cgra == 1:
    ////////////////////////////////////////////////////////////////
    //                Streaming CGRA Configuration                //
    ////////////////////////////////////////////////////////////////
    input fifo_req_t [N_DMA_CH-1:0] fifo_req_i,
    output fifo_resp_t [N_DMA_CH-1:0] fifo_resp_o,
    output logic [N_DMA_CH-1:0] mage_done_o,
  %elif dae_cgra == 1:
    ////////////////////////////////////////////////////////////////
    //                   DAE CGRA Configuration                   //
    ////////////////////////////////////////////////////////////////
    output state_t                                        state_o,
    /* Interface towards internal SpM */
    output logic     [N_BANKS-1:0]                        dmem_req_o,
    output logic     [N_BANKS-1:0]                        dmem_we_o,
    output logic     [N_BANKS-1:0]                        dmem_valid_o,
    output logic     [N_BANKS-1:0][$clog2(BANK_SIZE)-1:0] dmem_addr_o,
    output logic     [N_BANKS-1:0][           N_BITS-1:0] dmem_wdata_o,
    input  logic     [N_BANKS-1:0][           N_BITS-1:0] dmem_rdata_i,
    /* Interrupt */
    output logic                                          mage_intr_o,
%endif
);

%if dae_cgra == 1:
  logic reg_start;
  ////////////////////////////////////////////////////////////////
  //                   General Configuration                    //
  ////////////////////////////////////////////////////////////////
  logic [NBIT_II-1:0] reg_II;
  %if format_part == 1:
  logic [1:0] reg_acc_vec_mode;
  %endif
  % if kernel_len != 1:
  logic reg_static_n_timemux_mage;
  logic reg_static_n_timemux_cgra_pea_out_regs;
  logic reg_static_n_timemux_cgra_xbar;
 % endif
  ////////////////////////////////////////////////////////////////
  //                     AGU Configuration                      //
  ////////////////////////////////////////////////////////////////
  %if kernel_len == 1:
  loop_pipeline_info_t reg_lp_info;
  %endif
  loop_vars_t [N_LP-1:0] reg_loop_vars;
  logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0][NBIT_LP_IV-1:0] reg_iv_contraints;
  logic [N_AGE_TOT-1:0][N_SUBSCRIPTS-1:0][N_IV_PER_SUBSCRIPT-1:0][NBIT_LP_IV-1:0] reg_age_strides;
  logic [ACC_CFGMEM_SIZE-1:0][N_AGE_TOT-1:0][NBIT_CFG_STREAM_WORD-1:0] reg_mage_cfgmem;
  ////////////////////////////////////////////////////////////////
  //                  Crossbars Configuration                   //
  ////////////////////////////////////////////////////////////////
  logic [(N_CFG_REGS_LOAD_STREAM*32)-1:0] reg_cfg_l_stream_sel;
  logic [(N_CFG_REGS_STORE_STREAM*32)-1:0] reg_cfg_s_stream_sel;
  logic [(N_CFG_REGS_SEL_OUT_PEA*32)-1:0] reg_cfg_sel_out_pea;
  ////////////////////////////////////////////////////////////////
  //                     Crossbars Signals                      //
  ////////////////////////////////////////////////////////////////
  logic [N_OUT_PEA-1:0][LOG_M-1:0] cfg_sel_pea_output;
  logic [N_PE_GROUP-1:0][N_PE_PER_GROUP-1:0][LOG_N_BANKS_PER_STREAM-1:0] cfg_sel_dmem_pea;
  logic [N_BANKS_GROUP-1:0][N_BANKS_PER_STREAM-1:0][LOG_N_PE_PER_GROUP-1:0] cfg_sel_pea_dmem;
  logic [N_BANKS_GROUP-1:0][N_BANKS_PER_STREAM-1:0][LOG_N_AGE_PER_STREAM-1:0] l_stream_sel;
  logic [N_BANKS_GROUP-1:0][N_BANKS_PER_STREAM-1:0][LOG_N_PE_PER_GROUP-1:0] s_stream_sel;
  ////////////////////////////////////////////////////////////////
  //             Reconfigurable Controllers and FSM             //
  ////////////////////////////////////////////////////////////////
% if kernel_len != 1:
  logic [N_CFG_ADDR_BITS-1:0] cfg_addr;
  logic [N_CFG_ADDR_BITS-1:0] actual_cfg_addr_pea;
  logic [N_CFG_ADDR_BITS-1:0] actual_cfg_addr_xbar;
  logic [N_CFG_ADDR_BITS-1:0] actual_cfg_addr_regs_out_pea;
% endif
  logic end_pke;
  state_t state;
  ////////////////////////////////////////////////////////////////
  //              Processing Element Array (PEA)                //
  ////////////////////////////////////////////////////////////////
  logic [N_OUT_PEA-1:0][N_BITS-1:0] pea_outputs;
  logic [N_IN_PEA-1:0][N_BITS-1:0] pea_inputs;
  ////////////////////////////////////////////////////////////////
  //                            AGU                             //
  ////////////////////////////////////////////////////////////////
  logic start_d;
  logic end_lp;
  logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0][NBIT_ADDR-1:0] agu_addr;
  logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0][N_BANKS_PER_STREAM-1:0] agu_bank;
  logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0][LOG_N_BANKS_PER_STREAM-1:0] agu_bank_ls;
  logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0] agu_valid;
  logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0] agu_valid_ls;
  logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0] agu_lns;
  logic acc_match;
  ////////////////////////////////////////////////////////////////
  //          Crossbar between AGU and Multi-Bank SpM           //
  ////////////////////////////////////////////////////////////////
  logic [N_STREAMS-1:0][N_BANKS_PER_STREAM-1:0][NBIT_ADDR-1:0] agu_dmem_addr;
  logic [N_STREAMS-1:0][N_BANKS_PER_STREAM-1:0] agu_dmem_bank;
  logic [N_STREAMS-1:0][N_BANKS_PER_STREAM-1:0] agu_dmem_we;
  logic [N_STREAMS-1:0][N_BANKS_PER_STREAM-1:0] agu_dmem_valid;
  logic [N_STREAMS-1:0][N_BANKS_PER_STREAM-1:0] agu_dmem_valid_d;
  ////////////////////////////////////////////////////////////////
  //        Crossbar between Multi-Bank SpM and MAGE PEA        //
  ////////////////////////////////////////////////////////////////
  logic [N_PE_GROUP-1:0][N_PE_PER_GROUP-1:0][N_BITS-1:0] out_pea_in_xbar;
  logic [N_BANKS_GROUP-1:0][N_BANKS_PER_STREAM-1:0][N_BITS-1:0] out_dmem_in_xbar;
  logic [N_BANKS_GROUP-1:0][N_BANKS_PER_STREAM-1:0][N_BITS-1:0] in_pea_out_xbar;
  logic [N_BANKS_GROUP-1:0][N_BANKS_PER_STREAM-1:0][N_BITS-1:0] in_dmem_out_xbar;
  //output of xbar banks-pea
  logic [N_BANKS-1:0][N_BITS-1:0] banks_to_pea_xbar_out;
  //input to xbar banks-pea
  logic [N_BANKS-1:0][N_BITS-1:0] banks_to_pea_xbar_in;
%endif
%if streaming_cgra == 1:
  ////////////////////////////////////////////////////////////////
  //                      Streaming Interface                   //
  ////////////////////////////////////////////////////////////////
  logic [M-1:0]                            stream_pea_out_valid;
  logic [M-1:0][N_BITS-1:0]                stream_pea_data_out;
  logic [M-1:0]                            stream_pea_in_valid;
  logic [M-1:0][N_BITS-1:0]                stream_pea_data_in;
  logic [M-1:0] pea_ready;
  logic mage_done;
  logic [M-1:0] stream_intf_ready;
  ////////////////////////////////////////////////////////////////
  //                 Stream Peripheral Registers                //
  ////////////////////////////////////////////////////////////////
  logic [N_DMA_CH-1:0][1:0] reg_sync_dma_ch_trans;
  logic [N_DMA_CH-1:0][15:0] reg_trans_size_sync_dma_ch;
  logic [N_DMA_CH-1:0][31:0] reg_trans_size_dma_ch;
  logic [1:0] reg_cols_grouping;
  logic [1:0] reg_rf_val;
  logic [N_DMA_CH-1:0] reg_dma_rnw;
  logic [M-1:0][LOG_N:0] reg_stream_sel_out_pea;
  logic [N-1:0][M-1:0][15:0] reg_acc_value_pe;
  %if in_stream_xbar == 1:
  // xbar in signals
  logic [N_IN_STREAM-1:0][N_DMA_CH_PER_IN_STREAM-1:0][LOG_N_DMA_CH_PER_IN_STREAM-1:0] reg_in_stream_sel;
  %endif
  %if out_stream_xbar == 1:
  // xbar out signals
  logic [N_OUT_STREAM-1:0][N_DMA_CH_PER_OUT_STREAM-1:0][LOG_N_PEA_DOUT_PER_OUT_STREAM-1:0] reg_out_stream_sel;
  %endif
%endif
  ////////////////////////////////////////////////////////////////
  //           Processing Element Array Configuration           //
  ////////////////////////////////////////////////////////////////
  logic [N-1:0][M-1:0][KMEM_SIZE-1:0][32-1:0] reg_cfg_pea;
  logic [N-1:0][M-1:0][N_CFG_BITS_PE-1:0] cfg_pea;
  logic [N-1:0][M-1:0][31:0] reg_constant_op_pea;
%if streaming_cgra == 1:
  logic [N-1:0][M-1:0][31:0] reg_rf_in_pea;
  logic [N-1:0][M-1:0][31:0] reg_rf_d_pea;
  logic [N-1:0][M-1:0]       reg_rf_de_pea;
%endif

  ////////////////////////////////////////////////////////////////
  //              CSR and Configuration Registers               //
  ////////////////////////////////////////////////////////////////
  peripheral_regs peripheral_regs_inst (
      .clk_i(clk_i),
      .rst_n_i(rst_n_i),
      /* register interface */
      .reg_req_i(reg_req_i),
      .reg_rsp_o(reg_rsp_o),
%if dae_cgra == 1:
      .state_i(state),
      .reg_start_o(reg_start),
      ////////////////////////////////////////////////////////////////
      //                 General Configuration Bits                 //
      ////////////////////////////////////////////////////////////////
      .reg_II_o(reg_II),
  % if kernel_len != 1:
      .reg_static_n_timemux_mage_o(reg_static_n_timemux_mage),
      .reg_static_n_timemux_cgra_pea_o(reg_static_n_timemux_cgra_pea),
      .reg_static_n_timemux_cgra_pea_out_regs_o(reg_static_n_timemux_cgra_pea_out_regs),
      .reg_static_n_timemux_cgra_xbar_o(reg_static_n_timemux_cgra_xbar),
  % endif
      ////////////////////////////////////////////////////////////////
      //                      AGU Configuration                     //
      ////////////////////////////////////////////////////////////////
  % if kernel_len != 1:
      .reg_lp_info_o(reg_lp_info),
  %endif
  % if format_part != 1:
      .reg_acc_vec_mode_o(reg_acc_vec_mode),
  %endif
      .reg_loop_vars_o(reg_loop_vars),
      .reg_iv_contraints_o(reg_iv_contraints),
      .reg_agu_cfgmem_o(reg_mage_cfgmem),
      ////////////////////////////////////////////////////////////////
      //                  Crossbars Configuration                   //
      ////////////////////////////////////////////////////////////////
      .reg_cfg_sel_out_pea_o(reg_cfg_sel_out_pea),
      .reg_cfg_l_stream_sel_o(reg_cfg_l_stream_sel),
      .reg_cfg_s_stream_sel_o(reg_cfg_s_stream_sel),
%endif
%if streaming_cgra == 1:
      .reg_cols_grouping_o(reg_cols_grouping),
      .reg_rf_value_o(reg_rf_val),
      .reg_dma_rnw_o(reg_dma_rnw),
      .reg_trans_size_dma_ch_o(reg_trans_size_dma_ch),
      .reg_trans_size_sync_dma_ch_o(reg_trans_size_sync_dma_ch),
      .reg_sync_dma_ch_trans_o(reg_sync_dma_ch_trans),
      .reg_sel_out_col_pea_o(reg_stream_sel_out_pea),
      .reg_acc_value_pe_o(reg_acc_value_pe),
      .reg_pea_rf_de_i(reg_rf_de_pea),
      .reg_pea_rf_d_i(reg_rf_d_pea),
      .reg_pea_rf_o(reg_rf_in_pea),
  %if out_stream_xbar == 1:
      .reg_out_stream_sel_o(reg_out_stream_sel),
  %endif
%if in_stream_xbar == 1:
      .reg_in_stream_sel_o(reg_in_stream_sel),
%endif
%endif
      ////////////////////////////////////////////////////////////////
      //           Processing Element Array Configuration           //
      ////////////////////////////////////////////////////////////////
      .reg_pea_constants_o(reg_constant_op_pea),
      .reg_cfg_pea_o(reg_cfg_pea)
  );
%if dae_cgra == 1:
  cfg_regs_out_pea cfg_regs_out_pea_inst (
      .reg_cfg_sel_out_pea_i(reg_cfg_sel_out_pea),
  % if kernel_len != 1:
      .rcfg_ctrl_addr_i(actual_cfg_addr_regs_out_pea),
  % endif
      .sel_output_o(cfg_sel_pea_output)
  );

  cfg_regs_ls_stream_sel cfg_regs_ls_stream_sel_inst (
      .reg_cfg_l_stream_sel_i(reg_cfg_l_stream_sel),
      .reg_cfg_s_stream_sel_i(reg_cfg_s_stream_sel),
  % if kernel_len != 1:
      .rcfg_ctrl_addr_i(actual_cfg_addr_xbar),
  % endif
      .l_stream_sel_o(l_stream_sel),
      .s_stream_sel_o(s_stream_sel)
  );

  ////////////////////////////////////////////////////////////////
  //                           FSM                              //
  ////////////////////////////////////////////////////////////////
  fsm fsm_inst (
      .clk_i(clk_i),
      .rst_n_i(rst_n_i),
      .start_i(reg_start),
      .end_i(end_lp),
      .intr_o(mage_intr_o),
      .state_o(state)
  );
  assign state_o = state;
%endif

  ////////////////////////////////////////////////////////////////
  //              Processing Element Array (PEA)                //
  ////////////////////////////////////////////////////////////////
% if kernel_len != 1:
  cfg_regs_pea cfg_regs_pea_inst (
      .reg_cfg_pea_i(reg_cfg_pea),
      .rcfg_ctrl_addr_i(actual_cfg_addr_pea),
      .ctrl_pea_o(cfg_pea)
  );
% else:
  always_comb begin
    for (int i = 0; i < N; i = i + 1) begin
      for (int j = 0; j < M; j = j + 1) begin
        cfg_pea[i][j] = reg_cfg_pea[i][j][0];
      end
    end
  end
% endif

%if streaming_cgra == 1:
  assign mage_done = &mage_done_o;
%endif

  pea pea_inst (
      .clk_i(clk_i),
      .rst_n_i(rst_n_i),
      .ctrl_pea_i(cfg_pea),
%if streaming_cgra == 1:
      .mage_done_i(mage_done),
      .reg_pea_rf_de_o(reg_rf_de_pea),
      .reg_pea_rf_d_o(reg_rf_d_pea),
      .reg_pea_rf_i(reg_rf_in_pea),
      .reg_cols_grouping_i(reg_cols_grouping),
      .reg_rf_value_i(reg_rf_val),
      .reg_acc_value_i(reg_acc_value_pe),
      .reg_stream_sel_out_pea_i(reg_stream_sel_out_pea),
      .stream_valid_o(stream_pea_out_valid),
      .stream_data_o(stream_pea_data_out),
      .stream_valid_i(stream_pea_in_valid),
      .stream_data_i(stream_pea_data_in),
      .pea_ready_o(pea_ready),
      .stream_intf_ready_i(stream_intf_ready),
%endif
%if dae_cgra == 1:
      .sel_output_i(cfg_sel_pea_output),
      .start_d_i(start_d),
      .pea_data_i(pea_inputs),
      .acc_match_i(acc_match),
      .pea_data_o(pea_outputs),
%endif
      .reg_constant_op_i(reg_constant_op_pea)
  );

%if dae_cgra == 1:
  ////////////////////////////////////////////////////////////////
  //                            AGU                             //
  ////////////////////////////////////////////////////////////////
  agu agu_inst (
      .clk_i(clk_i),
      .rst_n_i(rst_n_i),
      /* Start-End */
      .start_i(reg_start),
      .start_d_o(start_d),
      .end_lp_o(end_lp),
      /* Configuration */
% if kernel_len != 1:
      .reg_loop_vars_i(reg_loop_vars),
      .reg_static_no_timemux_i(reg_static_n_timemux_mage),
      .cfgmem_addr_d_o(cfg_addr),
% endif
      .reg_iv_contraints_i(reg_iv_contraints),
      .reg_II_i(reg_II),
      .reg_lp_info_i(reg_lp_info),
      .cfgmem_content_i(reg_mage_cfgmem),
% if format_part != 1:
      .reg_acc_vec_mode_i(reg_acc_vec_mode),
% endif
      /* Outputs */
      .agu_addr_o(agu_addr),
      .agu_bank_o(agu_bank),
      .agu_bank_ls_o(agu_bank_ls),
      .agu_valid_o(agu_valid),
      .agu_valid_ls_o(agu_valid_ls),
      .agu_lns_o(agu_lns),
      .agu_pea_acc_reset_o(acc_match)
  );

% if kernel_len != 1:
  always_comb begin
    if (reg_static_n_timemux_cgra_xbar) begin
      actual_cfg_addr_xbar = '0;
    end else begin
      actual_cfg_addr_xbar = cfg_addr;
    end
  end

  always_comb begin
    if (reg_static_n_timemux_cgra_pea_out_regs) begin
      actual_cfg_addr_regs_out_pea = '0;
    end else begin
      actual_cfg_addr_regs_out_pea = cfg_addr;
    end
  end

  always_comb begin
    if (reg_static_n_timemux_cgra_pea) begin
      actual_cfg_addr_pea = '0;
    end else begin
      actual_cfg_addr_pea = cfg_addr;
    end
  end
% endif

  ////////////////////////////////////////////////////////////////
  //        Crossbar between Multi-Bank SpM and MAGE PEA        //
  ////////////////////////////////////////////////////////////////

  always_comb begin
    for (int i = 0; i < N_BANKS; i++) begin
      banks_to_pea_xbar_in[i] = dmem_rdata_i[i];
    end
  end

  //constructing inputs to xbar pea-banks
  always_comb begin
    for (int i = 0; i < N_PE_GROUP; i++) begin
      for (int j = 0; j < N_PE_PER_GROUP; j++) begin
        out_pea_in_xbar[i][j] = pea_outputs[i*N_PE_PER_GROUP+j];
      end
    end
    for (int i = 0; i < N_PE_GROUP; i++) begin
      for (int j = 0; j < N_PE_PER_GROUP; j++) begin
        out_dmem_in_xbar[i][j] = banks_to_pea_xbar_in[i*N_PE_PER_GROUP+j];
      end
    end
  end

  //assembling outputs of xbar pea-banks
  always_comb begin
    for (int i = 0; i < N_BANKS_GROUP; i++) begin
      for (int j = 0; j < N_BANKS_PER_STREAM; j++) begin
        pea_inputs[i*N_BANKS_PER_STREAM+j] = in_pea_out_xbar[i][j];
      end
    end
    for (int i = 0; i < N_PE_GROUP; i++) begin
      for (int j = 0; j < N_PE_PER_GROUP; j++) begin
        banks_to_pea_xbar_out[i*N_PE_PER_GROUP+j] = in_dmem_out_xbar[i][j];
      end
    end
  end

  always_comb begin
    for (int i = 0; i < N_BANKS; i++) begin
      dmem_wdata_o[i] = banks_to_pea_xbar_out[i];
    end
  end

  genvar i;
  generate
    for (i = 0; i < N_PE_GROUP; i++) begin : gen_xbar_banks_pea_i
      xbar_banks_pea xbar_banks_pea_i (
          .out_pea_i(out_pea_in_xbar[i]),
          .out_dmem_i(out_dmem_in_xbar[i]),
          .sel_dmem_pea_i(cfg_sel_dmem_pea[i]),
          .sel_pea_dmem_i(cfg_sel_pea_dmem[i]),
          .in_pea_o(in_pea_out_xbar[i]),
          .in_dmem_o(in_dmem_out_xbar[i])
      );
    end
  endgenerate

  genvar m;
  genvar n;
  generate
    for (m = 0; m < N_BANKS_GROUP; m++) begin : gen_ls_stream_o
      for (n = 0; n < N_BANKS_PER_STREAM; n++) begin : gen_ls_stream_i
          load_store_stream load_store_stream_inst (
              .l_stream_sel_i(l_stream_sel[m][n]),
              .s_stream_sel_i(s_stream_sel[m][n]),
              .age_bank_i(agu_bank_ls[m]),
              .valid_i(agu_valid_ls[m]),
              .sel_load_stream_o(cfg_sel_dmem_pea[m][n]),
              .sel_store_stream_o(cfg_sel_pea_dmem[m][n])
          );
      end
    end
  endgenerate

  ////////////////////////////////////////////////////////////////
  //          Crossbar between agu and Multi-Bank SpM          //
  ////////////////////////////////////////////////////////////////
  genvar j;
  generate
    for (j = 0; j < N_STREAMS; j++) begin : gen_stream_xbar

      xbar_age_to_banks xbar_age_to_banks_inst (
          .age_addr_i(agu_addr[j]),
          .age_valid_i(agu_valid[j]),
          .age_we_i(agu_lns[j]),
          .age_bank_i(agu_bank_ls[j]),
          .age_dmem_addr_o(agu_dmem_addr[j]),
          .age_dmem_bank_o(agu_dmem_bank[j]),
          .age_dmem_we_o(agu_dmem_we[j]),
          .age_dmem_valid_o(agu_dmem_valid[j])
      );

    end

  endgenerate

  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (~rst_n_i) begin
      agu_dmem_valid_d <= '0;
    end else begin
      agu_dmem_valid_d <= agu_dmem_valid;
    end
  end

  always_comb begin
    for (int k = 0; k < N_STREAMS; k = k + 1) begin
      for (int l = 0; l < N_BANKS_PER_STREAM; l = l + 1) begin
        dmem_addr_o[k*N_BANKS_PER_STREAM+l] = agu_dmem_addr[k][l];
        dmem_req_o[k*N_BANKS_PER_STREAM+l] = agu_dmem_bank[k][l];
        dmem_we_o[k*N_BANKS_PER_STREAM+l] = agu_dmem_we[k][l];
        dmem_valid_o[k*N_BANKS_PER_STREAM+l] = agu_dmem_valid_d[k][l];
      end
    end
  end
%endif
%if streaming_cgra == 1:

  ////////////////////////////////////////////////////////////////
  //                      Streaming Interface                   //
  ////////////////////////////////////////////////////////////////

  streaming_interface streaming_interface_inst (
      .clk_i(clk_i),
      .rst_n_i(rst_n_i),
      .pea_ready_i(pea_ready),
      .reg_trans_size_dma_ch_i(reg_trans_size_dma_ch),
      .reg_trans_size_sync_dma_ch_i(reg_trans_size_sync_dma_ch),
      .reg_sync_dma_ch_trans_i(reg_sync_dma_ch_trans),
      .stream_intf_ready_o(stream_intf_ready),
      .fifo_req_i(fifo_req_i),
      .fifo_resp_o(fifo_resp_o),
      .reg_cols_grouping_i(reg_cols_grouping),
      .reg_dma_rnw_i(reg_dma_rnw),
%if out_stream_xbar == 1:
      .reg_out_stream_sel_i(reg_out_stream_sel),
%endif
%if in_stream_xbar == 1:
      .reg_in_stream_sel_i(reg_in_stream_sel),
%endif
      .dout_pea_i(stream_pea_data_out),
      .valid_pea_out_i(stream_pea_out_valid),
      .valid_pea_in_o(stream_pea_in_valid),
      .din_pea_o(stream_pea_data_in),
      .mage_done_o(mage_done_o)
  );
%endif

endmodule : mage_top
