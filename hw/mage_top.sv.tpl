// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: mage_top.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: Top level entity of CGRA
<%import math as m%>
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
    output reg_rsp_t                                      reg_rsp_o,
%if streaming_cgra == 1:
    ////////////////////////////////////////////////////////////////
    //                Streaming CGRA Configuration                //
    ////////////////////////////////////////////////////////////////
    input fifo_req_t [N_DMA_CH-1:0] fifo_req_i,
    output fifo_resp_t [N_DMA_CH-1:0] fifo_resp_o,
    output logic [N_DMA_CH-1:0] mage_done_o
  %elif dae_cgra == 1:
    ////////////////////////////////////////////////////////////////
    //                   DAE CGRA Configuration                   //
    ////////////////////////////////////////////////////////////////
    output state_t                                        state_o,
    output logic [1:0]                                    reg_block_size_o,
    /* Interface towards internal SpM */
    output logic     [N_BANKS-1:0]                        dmem_req_o,
    output logic     [N_BANKS-1:0]                        dmem_we_o,
    output logic     [N_BANKS-1:0][$clog2(BANK_SIZE)-1:0] dmem_addr_o,
    output logic     [N_BANKS-1:0][           N_BITS-1:0] dmem_wdata_o,
    input  logic     [N_BANKS-1:0][           N_BITS-1:0] dmem_rdata_i,
    /* Interrupt */
    output logic                                          mage_intr_o
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
  %if kernel_len != 1:
  loop_pipeline_info_t reg_lp_info;
  %endif
  loop_vars_t [N_LP-1:0] reg_loop_vars;
  logic [N_AGE_TOT-1:0][N_IVS-1:0][NBIT_LP_IV-1:0] reg_age_strides;
  logic [N_AGE_TOT-1:0][LOG2_HWLP_RF_SIZE-1:0] reg_age_acc_hwlp_sel;
  logic [ACC_CFGMEM_SIZE-1:0][N_AGE_TOT-1:0][NBIT_CFG_STREAM_WORD-1:0] reg_mage_cfgmem;
  ////////////////////////////////////////////////////////////////
  //                  Crossbars Configuration                   //
  ////////////////////////////////////////////////////////////////
  logic [N_AGE_TOT-1:0][KMEM_SIZE-1:0][${max(m.log(n_age_per_stream), 2)}-1:0] reg_cfg_load_age_sel;
  logic [N_AGE_TOT-1:0][KMEM_SIZE-1:0][${max(m.log(n_age_per_stream), 2)}-1:0] reg_cfg_pea_dmem_sel;
  logic [N_OUT_PEA-1:0][KMEM_SIZE-1:0][${max(m.log(n_pea_cols),2)}-1:0] reg_cfg_sel_out_pea;
  ////////////////////////////////////////////////////////////////
  //                     Crossbars Signals                      //
  ////////////////////////////////////////////////////////////////
  logic [N_OUT_PEA-1:0][${max(m.log(n_pea_cols),2)}-1:0] cfg_sel_pea_output;
  logic [N_AGE_TOT-1:0][${max(m.log(n_age_per_stream), 2)}-1:0] cfg_sel_dmem_pea;
  logic [N_AGE_TOT-1:0][${max(m.log(n_age_per_stream), 2)}-1:0] load_age_sel;
  logic [N_AGE_TOT-1:0][${max(m.log(n_age_per_stream), 2)}-1:0] pea_dmem_sel;
  ////////////////////////////////////////////////////////////////
  //             Reconfigurable Controllers and FSM             //
  ////////////////////////////////////////////////////////////////
% if kernel_len != 1:
  logic [N_CFG_ADDR_BITS-1:0] cfg_addr;
  logic [N_CFG_ADDR_BITS-1:0] actual_cfg_addr_pea;
  logic [N_CFG_ADDR_BITS-1:0] actual_cfg_addr_xbar;
  logic [N_CFG_ADDR_BITS-1:0] actual_cfg_addr_regs_out_pea;
  logic end_pke;
% endif
  state_t state;
  ////////////////////////////////////////////////////////////////
  //              Processing Element Array (PEA)                //
  ////////////////////////////////////////////////////////////////
  logic [N_IN_PEA-1:0][N_BITS-1:0] pea_outputs;
  logic [N_IN_PEA-1:0][N_BITS-1:0] pea_inputs;
  ////////////////////////////////////////////////////////////////
  //                            AGU                             //
  ////////////////////////////////////////////////////////////////
  logic start_d;
  logic end_lp;
  logic [N_AGE_TOT-1:0][NBIT_ADDR-1:0] agu_addr;
  logic [N_AGE_TOT-1:0][N_BANKS_PER_STREAM-1:0] agu_bank;
  logic [N_AGE_TOT-1:0][LOG_N_BANKS_PER_STREAM-1:0] agu_bank_ls;
  logic [N_AGE_TOT-1:0] agu_valid;
  logic [N_AGE_TOT-1:0] agu_valid_ls;
  logic [N_AGE_TOT-1:0] agu_lns;
  logic [N_AGE_TOT/2-1:0] agu_acc_match;
  ////////////////////////////////////////////////////////////////
  //          Crossbar between AGU and Multi-Bank SpM           //
  ////////////////////////////////////////////////////////////////
  logic [N_AGE_TOT-1:0] pea_data_valid;
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
      .reg_block_size_o(reg_block_size_o),
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
  % if format_part == 1:
      .reg_acc_vec_mode_o(reg_acc_vec_mode),
  %endif
      .reg_loop_vars_o(reg_loop_vars),
      .reg_age_strides_o(reg_age_strides),
      .reg_age_acc_hwlp_sel_o(reg_age_acc_hwlp_sel),
      .reg_agu_cfgmem_o(reg_mage_cfgmem),
      ////////////////////////////////////////////////////////////////
      //                  Crossbars Configuration                   //
      ////////////////////////////////////////////////////////////////
      .reg_cfg_sel_out_pea_o(reg_cfg_sel_out_pea),
      .reg_cfg_load_age_sel_o(reg_cfg_load_age_sel),
      .reg_cfg_pea_dmem_sel_o(reg_cfg_pea_dmem_sel),
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
  % if kernel_len != 1:
  cfg_regs_out_pea cfg_regs_out_pea_inst (
      .reg_cfg_sel_out_pea_i(reg_cfg_sel_out_pea),
      .rcfg_ctrl_addr_i(actual_cfg_addr_regs_out_pea),
      .sel_output_o(cfg_sel_pea_output)
  );
  %else:
  always_comb begin
    for (int i = 0; i < N_OUT_PEA; i++) begin
      cfg_sel_pea_output[i] = reg_cfg_sel_out_pea[i][0];
    end
  end
  %endif

% if kernel_len != 1:
  cfg_regs_ls_stream_sel cfg_regs_ls_stream_sel_inst (
      .reg_cfg_load_age_sel_i(reg_cfg_load_age_sel),
      .reg_cfg_pea_dmem_sel_i(reg_cfg_pea_dmem_sel),
      .rcfg_ctrl_addr_i(actual_cfg_addr_xbar),
      .load_age_sel_o(load_age_sel),
      .pea_dmem_sel_o(pea_dmem_sel)
  );
%else:
  always_comb begin
    for (int i = 0; i < N_AGE_TOT; i++) begin
        load_age_sel[i] = reg_cfg_load_age_sel[i][0];
        pea_dmem_sel[i] = reg_cfg_pea_dmem_sel[i][0];
    end
  end
%endif

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
%else:
  always_comb begin
    for (int i = 0; i < N; i++) begin
      for (int j = 0; j < M; j++) begin
        cfg_pea[i][j] = reg_cfg_pea[i][j][0][N_CFG_BITS_PE-1:0];
      end
    end
  end 
%endif

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
      .start_d_i(start_d),
      .in_data_valid_i(pea_data_valid),
      .sel_output_i(cfg_sel_pea_output),
      .pea_data_i(pea_inputs),
      .acc_match_i(agu_acc_match),
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
      .state_i(state),
      .start_d_o(start_d),
      .end_lp_o(end_lp),
      /* Configuration */
      .reg_loop_vars_i(reg_loop_vars),
% if kernel_len != 1:
      .reg_lp_info_i(reg_lp_info),
      .reg_static_no_timemux_i(reg_static_n_timemux_mage),
      .cfgmem_addr_d_o(cfg_addr),
% endif
      .reg_age_strides_i(reg_age_strides),
      .reg_age_acc_hwlp_sel_i(reg_age_acc_hwlp_sel),
      .reg_II_i(reg_II),
      .cfgmem_content_i(reg_mage_cfgmem),
% if format_part == 1:
      .reg_acc_vec_mode_i(reg_acc_vec_mode),
% endif
      /* Outputs */
      .agu_addr_o(agu_addr),
      .agu_bank_o(agu_bank),
      .agu_bank_ls_o(agu_bank_ls),
      .agu_valid_o(agu_valid),
      .agu_valid_ls_o(agu_valid_ls),
      .agu_lns_o(agu_lns),
      .agu_pea_acc_reset_o(agu_acc_match)
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

<% idx = 0%>
%for s in range(n_streams):
  %if n_age_per_stream_ds[s] == 1:

  ////////////////////////////////////////
  //        Stream ${s}: no Xbar        //
  ////////////////////////////////////////

  assign pea_inputs[${idx}] = dmem_rdata_i[${idx}];
  assign dmem_wdata_o[${idx}] = pea_outputs[${idx}];
  assign pea_data_valid[${idx}] = agu_valid_ls[${idx}];
  // assign cfg_sel_dmem_pea[${idx}] = '0;

  <% idx += 1%>
  %elif n_age_per_stream_ds[s] == 2:

  ////////////////////////////////////////
  //        Stream ${s}: Xbar 2x2       //
  ////////////////////////////////////////

  xbar_pea_banks #(
      .XBAR_SIZE(2)
  ) xbar_pea_banks_2x2_stream_${s} (
      .out_pea_i      ({pea_outputs[${idx+1}],          pea_outputs[${idx}]}),
      .out_dmem_i     ({dmem_rdata_i[${idx+1}],         dmem_rdata_i[${idx}]}),
      .sel_dmem_pea_i ({cfg_sel_dmem_pea[${idx+1}][0],  cfg_sel_dmem_pea[${idx}][0]}),
      .sel_pea_dmem_i ({pea_dmem_sel[${idx+1}][0],      pea_dmem_sel[${idx}][0]}),
      .in_pea_o       ({pea_inputs[${idx+1}],           pea_inputs[${idx}]}),
      .in_dmem_o      ({dmem_wdata_o[${idx+1}],         dmem_wdata_o[${idx}]})
  );

  dmem_pea_select #(
    .N_AGE(2)
  ) dmem_pea_select_2x2_n0_stream_${s} (
      .reg_load_age_sel_i(load_age_sel[${idx}][0]),
      .age_bank_load_i   ({agu_bank_ls[${idx+1}][0], agu_bank_ls[${idx}][0]}),
      .valid_ls_i        ({agu_valid_ls[${idx+1}], agu_valid_ls[${idx}]}),
      .sel_load_stream_o (cfg_sel_dmem_pea[${idx}][0]),
        .valid_o(pea_data_valid[${idx}])
  );

  dmem_pea_select #(
    .N_AGE(2)
  ) dmem_pea_select_2x2_n1_stream_${s} (
      .reg_load_age_sel_i(load_age_sel[${idx+1}][0]),
      .age_bank_load_i   ({agu_bank_ls[${idx+1}][0], agu_bank_ls[${idx}][0]}),
      .valid_ls_i        ({agu_valid_ls[${idx+1}], agu_valid_ls[${idx}]}),
      .sel_load_stream_o (cfg_sel_dmem_pea[${idx+1}][0]),
        .valid_o(pea_data_valid[${idx+1}])
  );

  <% idx += 2%>
  %elif n_age_per_stream_ds[s] == 4:

  ////////////////////////////////////////
  //        Stream ${s}: Xbar 4x4       //
  ////////////////////////////////////////

  xbar_pea_banks #(
      .XBAR_SIZE(4)
  )  xbar_pea_banks_4x4_stream_${s} (
      .out_pea_i      ({pea_outputs[${idx+3}],      pea_outputs[${idx+2}],      pea_outputs[${idx+1}],      pea_outputs[${idx}]}),
      .out_dmem_i     ({dmem_rdata_i[${idx+3}],     dmem_rdata_i[${idx+2}],     dmem_rdata_i[${idx+1}],     dmem_rdata_i[${idx}]}),
      .sel_dmem_pea_i ({cfg_sel_dmem_pea[${idx+3}], cfg_sel_dmem_pea[${idx+2}], cfg_sel_dmem_pea[${idx+1}], cfg_sel_dmem_pea[${idx}]}),
      .sel_pea_dmem_i ({pea_dmem_sel[${idx+3}],     pea_dmem_sel[${idx+2}],     pea_dmem_sel[${idx+1}],     pea_dmem_sel[${idx}]}),
      .in_pea_o       ({pea_inputs[${idx+3}],       pea_inputs[${idx+2}],       pea_inputs[${idx+1}],       pea_inputs[${idx}]}),
      .in_dmem_o      ({dmem_wdata_o[${idx+3}],     dmem_wdata_o[${idx+2}],     dmem_wdata_o[${idx+1}],     dmem_wdata_o[${idx}]})
  );

  %for j in range(4):
    dmem_pea_select #(
      .N_AGE(4)
    ) dmem_pea_select_4x4_n${j}_stream_${s} (
        .reg_load_age_sel_i(load_age_sel[${idx+j}]),
        .age_bank_load_i   ({agu_bank_ls[${idx+3}][1:0], agu_bank_ls[${idx+2}][1:0], agu_bank_ls[${idx+1}][1:0], agu_bank_ls[${idx}][1:0]}),
        .valid_ls_i        ({agu_valid_ls[${idx+3}],   agu_valid_ls[${idx+2}],   agu_valid_ls[${idx+1}],   agu_valid_ls[${idx}]}),
        .sel_load_stream_o (cfg_sel_dmem_pea[${idx+j}]),
        .valid_o(pea_data_valid[${idx+j}])
    );
  %endfor
  <% idx += 4%>
  %endif
%endfor

  ////////////////////////////////////////////////////////////////
  //          Crossbar between agu and Multi-Bank SpM          //
  ////////////////////////////////////////////////////////////////

<% idx = 0%>
%for s in range(n_streams):
  %if n_age_per_stream_ds[s] == 1:

  ////////////////////////////////////////
  //        Stream ${s}: no Xbar        //
  ////////////////////////////////////////

  always_comb begin
    if (agu_valid[${idx}]) begin
      dmem_addr_o[${idx}]    = agu_addr[${idx}];
      dmem_we_o[${idx}]      = ~agu_lns[${idx}];
      dmem_req_o[${idx}]     = |agu_bank[${idx}];
    end else begin
      dmem_addr_o[${idx}]    = '0;
      dmem_we_o[${idx}]      = '0;
      dmem_req_o[${idx}]     = '0;
    end
  end

  <% idx += 1%>
  %elif n_age_per_stream_ds[s] == 2:

  ////////////////////////////////////////
  //        Stream ${s}: Xbar 2x2       //
  ////////////////////////////////////////

  xbar_age_to_banks #(
      .N_AGE(2),
      .N_BNKS(2)
    ) xbar_age_to_banks_2x2_stream_${s} (
      .age_addr_i       ({agu_addr[${idx+1}],       agu_addr[${idx}]}),
      .age_valid_i      ({agu_valid[${idx+1}],      agu_valid[${idx}]}),
      .age_we_i         ({agu_lns[${idx+1}],        agu_lns[${idx}]}),
      .age_bank_i       ({agu_bank[${idx+1}][1:0],  agu_bank[${idx}][1:0]}),
      .age_dmem_addr_o  ({dmem_addr_o[${idx+1}],    dmem_addr_o[${idx}]}),
      .age_dmem_bank_o  ({dmem_req_o[${idx+1}],     dmem_req_o[${idx}]}),
      .age_dmem_we_o    ({dmem_we_o[${idx+1}],      dmem_we_o[${idx}]})
  );
  
  <% idx += 2%>
  %elif n_age_per_stream_ds[s] == 4:

  ////////////////////////////////////////
  //        Stream ${s}: Xbar 4x4       //
  ////////////////////////////////////////

  xbar_age_to_banks #(
      .N_AGE(4),
      .N_BNKS(4)
    ) xbar_age_to_banks_4x4_stream_${s} (
      .age_addr_i       ({agu_addr[${idx+3}],       agu_addr[${idx+2}],       agu_addr[${idx+1}],       agu_addr[${idx}]}),
      .age_valid_i      ({agu_valid[${idx+3}],      agu_valid[${idx+2}],      agu_valid[${idx+1}],      agu_valid[${idx}]}),
      .age_we_i         ({agu_lns[${idx+3}],        agu_lns[${idx+2}],        agu_lns[${idx+1}],        agu_lns[${idx}]}),
      .age_bank_i       ({agu_bank[${idx+3}][3:0],  agu_bank[${idx+2}][3:0],  agu_bank[${idx+1}][3:0],  agu_bank[${idx}][3:0]}),
      .age_dmem_addr_o  ({dmem_addr_o[${idx+3}],    dmem_addr_o[${idx+2}],    dmem_addr_o[${idx+1}],    dmem_addr_o[${idx}]}),
      .age_dmem_bank_o  ({dmem_req_o[${idx+3}],     dmem_req_o[${idx+2}],     dmem_req_o[${idx+1}],     dmem_req_o[${idx}]}),
      .age_dmem_we_o    ({dmem_we_o[${idx+3}],      dmem_we_o[${idx+2}],      dmem_we_o[${idx+1}],      dmem_we_o[${idx}]})
  );

  <% idx += 4%>
  %endif
%endfor

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
