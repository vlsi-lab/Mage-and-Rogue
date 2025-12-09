// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: peripheral_registers.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module contains the configuration registers for the CGRA
<%import math as m%>
module peripheral_regs
%if streaming_cgra == 1:
  import stream_intf_pkg::*;
%endif
%if dae_cgra == 1:
  import agu_pkg::*;
  import xbar_pkg::*;
%endif
  import pea_pkg::*;
  import reg_pkg::*;
  import mage_reg_pkg::*;
(
    input logic clk_i,
    input logic rst_n_i,
    input reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,
%if dae_cgra == 1:
    ////////////////////////////////
    //     DAE Configuration      //
    ////////////////////////////////
    input state_t state_i,
    ////////////////////////////////
    //   General Configuration    //
    ////////////////////////////////
    // Start
    output logic reg_start_o,
    // Iteration Interval
    output logic [NBIT_II-1:0] reg_II_o,
  %if kernel_len != 1:
    output logic [N-1:0][M-1:0] reg_static_n_timemux_cgra_pea_o,
    output logic reg_static_n_timemux_mage_o,
    output logic reg_static_n_timemux_cgra_pea_out_regs_o,
    output logic reg_static_n_timemux_cgra_xbar_o,
  %endif
  %if format_part == 1:
    // vector mode for packet SIMD
    output logic [1:0] reg_acc_vec_mode_o,
  %endif
    ////////////////////////////////
    //     AGU Configuration      //
    ////////////////////////////////
  %if kernel_len != 1:
    output loop_pipeline_info_t reg_lp_info_o,
  %endif
    output loop_vars_t [N_LP-1:0] reg_loop_vars_o,
    output logic [N_AGE_TOT-1:0][N_IVS-1:0][NBIT_LP_IV-1:0] reg_age_strides_o,
    output logic [N_AGE_TOT-1:0][LOG2_HWLP_RF_SIZE-1:0] reg_age_acc_hwlp_sel_o,
    output logic [ACC_CFGMEM_SIZE-1:0][N_AGE_TOT-1:0][NBIT_CFG_STREAM_WORD-1:0] reg_agu_cfgmem_o,
    ////////////////////////////////
    //    XBars Configuration     //
    ////////////////////////////////
    output logic [N_OUT_PEA-1:0][KMEM_SIZE-1:0][${max(m.log(n_pea_cols),2)}-1:0] reg_cfg_sel_out_pea_o,
    output logic [N_AGE_TOT-1:0][KMEM_SIZE-1:0][${max(m.log(n_age_per_stream), 2)}-1:0] reg_cfg_load_age_sel_o,
    output logic [N_BANKS-1:0][KMEM_SIZE-1:0][${max(m.log(n_age_per_stream), 2)}-1:0] reg_cfg_pea_dmem_sel_o,
    output logic [1:0] reg_block_size_o,
%endif
%if streaming_cgra == 1:
    ////////////////////////////////
    //  Streaming Configuration   //
    ////////////////////////////////
    output logic [1:0] reg_rf_value_o,
    output logic [1:0] reg_cols_grouping_o,
    output logic [N_DMA_CH-1:0][1:0] reg_sync_dma_ch_trans_o,
    output logic [N_DMA_CH-1:0] reg_dma_rnw_o,
    output logic [N_DMA_CH-1:0][31:0] reg_trans_size_dma_ch_o,
    output logic [N_DMA_CH-1:0][15:0] reg_trans_size_sync_dma_ch_o,
    output logic [M-1:0][LOG_N:0] reg_sel_out_col_pea_o,
    output logic [N-1:0][M-1:0][15:0] reg_acc_value_pe_o,
    input logic [N-1:0][M-1:0] reg_pea_rf_de_i,
    input logic [N-1:0][M-1:0][31:0] reg_pea_rf_d_i,
    output logic [N-1:0][M-1:0][31:0] reg_pea_rf_o,
  %if out_stream_xbar == 1:
    output logic [N_OUT_STREAM-1:0][N_DMA_CH_PER_OUT_STREAM-1:0][LOG_N_PEA_DOUT_PER_OUT_STREAM-1:0] reg_out_stream_sel_o,
  %endif
  %if in_stream_xbar == 1:
    output logic [N_IN_STREAM-1:0][N_DMA_CH_PER_IN_STREAM-1:0][LOG_N_DMA_CH_PER_IN_STREAM-1:0] reg_in_stream_sel_o,
  %endif
%endif
    ////////////////////////////////
    //     PEA Configuration      //
    ////////////////////////////////
    output logic [N-1:0][M-1:0][31:0] reg_pea_constants_o,
    output logic [N-1:0][M-1:0][KMEM_SIZE-1:0][32-1:0] reg_cfg_pea_o
);
  mage_hw2reg_t hw2reg;
  mage_reg2hw_t reg2hw;

  mage_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) mage_reg_top_i (
      .clk_i(clk_i),
      .rst_ni(rst_n_i),
      .reg_req_i(reg_req_i),
      .reg_rsp_o(reg_rsp_o),
      .reg2hw(reg2hw),
      .hw2reg(hw2reg),
      .devmode_i(1'b1)
  );

  always_comb begin
%if dae_cgra == 1:
    ////////////////////////////////
    //     DAE Configuration      //
    ////////////////////////////////

    ////////////////////////////////
    //           Status           //
    ////////////////////////////////
    hw2reg.status.done.de = (state_i == DONE || state_i == EXEC) ? 1'b1 : 1'b0;
    hw2reg.status.done.d = (state_i == DONE) ? 1'b1 : 1'b0;
    hw2reg.status.start.de = (state_i == DONE) ? 1'b1 : 1'b0;
    hw2reg.status.start.d = 1'b0;
    reg_start_o = reg2hw.status.start.q;
    reg_block_size_o = reg2hw.block_size.q;

    ////////////////////////////////
    //   General Configuration    //
    ////////////////////////////////
    reg_II_o = reg2hw.gen_cfg.ii.q;
%if format_part == 1:
    reg_acc_vec_mode_o = reg2hw.gen_cfg.acc_vec_mode.q[1:0];
%endif
%if kernel_len != 1:
    for(int i = 0; i < N; i++) begin
        for(int j = 0; j < M; j++) begin
            reg_static_n_timemux_cgra_pea_o[i][j] = reg2hw.pea_control_snt.q[i * M + j];
        end
    end
    //reg_static_n_timemux_cgra_pea_o = reg2hw.gen_cfg.s_n_t_mage_pea.q;
    reg_static_n_timemux_cgra_pea_out_regs_o = reg2hw.gen_cfg.s_n_t_mage_pea_out_regs.q;
    reg_static_n_timemux_cgra_xbar_o = reg2hw.gen_cfg.s_n_t_mage_xbar.q;
    reg_static_n_timemux_mage_o = reg2hw.gen_cfg.s_n_t_mage.q;
%endif

    ////////////////////////////////
    //        AGE Strides         //
    ////////////////////////////////
%for s in range(n_age_tot):
  %for i in range(4):
    reg_age_strides_o[${s}][${i}] = reg2hw.strides[${s}].s${i}.q;
  %endfor
%endfor

    ////////////////////////////////
    //    Acc HWLP RF Selectors   //
    ////////////////////////////////
  %for i in range(n_age_tot):
    reg_age_acc_hwlp_sel_o[${i}] = reg2hw.acc_hwlp_sel_${int(i/8)}.s${int(i%8)}.q;
  %endfor

    ////////////////////////////////
    //            HWLP            //
    ////////////////////////////////
    reg_loop_vars_o[0].iv = reg2hw.ilb_hwl.ilb_0.q;
    reg_loop_vars_o[1].iv = reg2hw.ilb_hwl.ilb_1.q;
    reg_loop_vars_o[2].iv = reg2hw.ilb_hwl.ilb_2.q;
    reg_loop_vars_o[3].iv = reg2hw.ilb_hwl.ilb_3.q;
    reg_loop_vars_o[0].fv = reg2hw.flb_hwl.flb_0.q;
    reg_loop_vars_o[1].fv = reg2hw.flb_hwl.flb_1.q;
    reg_loop_vars_o[2].fv = reg2hw.flb_hwl.flb_2.q;
    reg_loop_vars_o[3].fv = reg2hw.flb_hwl.flb_3.q;
    reg_loop_vars_o[0].inc = reg2hw.inc_hwl.inc_0.q;
    reg_loop_vars_o[1].inc = reg2hw.inc_hwl.inc_1.q;
    reg_loop_vars_o[2].inc = reg2hw.inc_hwl.inc_2.q;
    reg_loop_vars_o[3].inc = reg2hw.inc_hwl.inc_3.q;

    ////////////////////////////////
    //            AGU             //
    ////////////////////////////////
    for(int i = 0; i < ACC_CFGMEM_SIZE; i++) begin
%for i in range(n_age_tot):
      reg_agu_cfgmem_o[i][${i}] = reg2hw.cfg_mage_age_${i}[i].q[NBIT_CFG_STREAM_WORD-1:0];
%endfor

    end
%if kernel_len != 1:
    ////////////////////////////////
    //            PKE             //
    ////////////////////////////////
    reg_lp_info_o.len_e = reg2hw.pke.len_e.q[N_CFG_ADDR_BITS-1:0];
    reg_lp_info_o.len_k = reg2hw.pke.len_k.q[N_CFG_ADDR_BITS-1:0];
    reg_lp_info_o.len_p = reg2hw.pke.len_p.q[N_CFG_ADDR_BITS-1:0];
    reg_lp_info_o.len_dfg = reg2hw.pke.len_dfg.q;
%endif

    ////////////////////////////////
    //           XBars            //
    ////////////////////////////////
<%prev_idx = 0%>
<%idx = m.ceil(max(m.log(n_age_per_stream), 2))%>
%for s in range(n_age_tot):
    %for k in range(kernel_len):
      reg_cfg_load_age_sel_o[${s}][${k}] = reg2hw.load_age_sel[0].q[${idx-1}:${prev_idx}]; <%prev_idx = idx%> <%idx = idx + m.ceil(max(m.log(n_age_per_stream),2))%>
    %endfor
%endfor

<%prev_idx = 0%>
<%idx = m.ceil(max(m.log(n_age_per_stream),2))%>
%for s in range(n_age_tot):
    %for k in range(kernel_len):
      reg_cfg_pea_dmem_sel_o[${s}][${k}] = reg2hw.pea_dmem_sel[0].q[${idx-1}:${prev_idx}]; <%prev_idx = idx%> <%idx = idx + m.ceil(max(m.log(n_age_per_stream),2))%>
    %endfor
%endfor

<%prev_idx = 0%>
<%idx = m.ceil(max(m.log(n_pea_cols),2))%>
%for r in range(n_pea_rows*2):
    %for k in range(kernel_len):
      reg_cfg_sel_out_pea_o[${r}][${k}] = reg2hw.out_pea_sel[0].q[${idx-1}:${prev_idx}]; <%prev_idx = idx%> <%idx = idx + m.ceil(max(m.log(n_pea_cols),2))%>
    %endfor
%endfor

%endif

%if streaming_cgra == 1:
    ////////////////////////////////
    //  Streaming Configuration   //
    ////////////////////////////////
    reg_cols_grouping_o = reg2hw.cols_grouping.q;
    reg_rf_value_o = reg2hw.rf_val.q;
  %for i in range(n_dma_ch):
    reg_dma_rnw_o[${i}] = reg2hw.dma_rnw.q[${i}];
    reg_sync_dma_ch_trans_o[${i}] = reg2hw.sync_dma_ch_trans.q[${2*i+1}:${2*i}];
    reg_trans_size_dma_ch_o[${i}] = reg2hw.trans_size_dma_ch_${i}.q;
    reg_trans_size_sync_dma_ch_o[${i}] = reg2hw.trans_size_sync_dma_ch_${i}.q;
  %endfor
  %for c in range(n_pea_cols):
    reg_sel_out_col_pea_o[${c}] = reg2hw.sel_out_col_pea[0].sel_col_${c}.q[LOG_N:0];
  %endfor
  %for r in range(n_pea_rows):
    %for c in range(n_pea_cols):
    reg_acc_value_pe_o[${r}][${c}] = reg2hw.acc_value[${r*n_pea_cols+c}].q;
    %endfor 
  %endfor
  %if out_stream_xbar == 1:
    %for i in range(n_out_stream):
      %for j in range(n_dma_ch_per_out_stream):
    reg_out_stream_sel_o[${i}][${j}] = reg2hw.stream_out_xbar_sel.sel_out_xbar_${i*n_dma_ch_per_out_stream+j}.q[LOG_N_PEA_DOUT_PER_OUT_STREAM-1:0];  
      %endfor
    %endfor
  %endif
  %if in_stream_xbar == 1:
    %for i in range(n_in_stream):
      %for j in range(n_dma_ch_per_out_stream):
    reg_in_stream_sel_o[${i}][${j}] = reg2hw.stream_in_xbar_sel.sel_in_xbar_${i*n_dma_ch_per_out_stream+j}.q[LOG_N_DMA_CH_PER_IN_STREAM-1:0];  
      %endfor
    %endfor
  %endif
%endif

    ////////////////////////////////
    //            PEA             //
    ////////////////////////////////
%for r in range(n_pea_rows):
  %for c in range(n_pea_cols):
    reg_pea_constants_o[${r}][${c}] = reg2hw.pea_constants[${r*n_pea_cols+c}].q; 
  %endfor
%endfor
%if streaming_cgra == 1:
  %for r in range(n_pea_rows):
    %for c in range(n_pea_cols):
    reg_pea_rf_o[${r}][${c}] = reg2hw.pea_rf[${r*n_pea_cols+c}].q;
    hw2reg.pea_rf[${r*n_pea_cols+c}].de = reg_pea_rf_de_i[${r}][${c}];
    hw2reg.pea_rf[${r*n_pea_cols+c}].d = reg_pea_rf_d_i[${r}][${c}]; 
    %endfor
  %endfor
%endif
    for (int i = 0; i < KMEM_SIZE; i++) begin
%for r in range(n_pea_rows):
  %for c in range(n_pea_cols):
      reg_cfg_pea_o[${r}][${c}][i] = reg2hw.cfg_pe_${r}${c}[i].q; 
  %endfor
%endfor
    end
  end

endmodule : peripheral_regs
