// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: streaming_interface.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: Streaming interface to let work the execute part of Mage in streaming with the DMA

module streaming_interface
  import stream_intf_pkg::*;
  import fifo_pkg::*;
  import pea_pkg::*;
(
    input logic clk_i,
    input logic rst_n_i,
    input logic [M-1:0] pea_ready_i,

    // HW FIFO Interface
    input fifo_req_t [N_DMA_CH-1:0] fifo_req_i,
    output fifo_resp_t [N_DMA_CH-1:0] fifo_resp_o,

    // Configuration
    input logic [1:0] reg_cols_grouping_i,
    input logic [N_DMA_CH-1:0] reg_dma_rnw_i,

    // Transaction sizes
    %if r_fifo_synch_placement_type == "g4":
    input logic [1:0] reg_r_fifo_synch_groups_i,
    %endif
    input logic [N_DMA_CH-1:0][31:0] reg_trans_size_dma_ch_i,
    input logic [N_DMA_CH-1:0][1:0] reg_sync_dma_ch_trans_i,
    input logic [N_DMA_CH-1:0][15:0] reg_trans_size_sync_dma_ch_i,

    // xbar selectors
    input logic [N_OUT_STREAM-1:0][N_DMA_CH_PER_OUT_STREAM-1:0][LOG_N_PEA_DOUT_PER_OUT_STREAM-1:0] reg_out_stream_sel_i,
    
    // I/O interface with PEA

    // Inputs from PEA (data and valid)
    input logic [M-1:0][N_BITS-1:0] dout_pea_i,
    input logic [M-1:0] valid_pea_out_i,
    // Outputs to PEA (data and valid)
    output logic [N_STREAM_IN_PEA-1:0] valid_pea_in_o,
    output logic [N_STREAM_IN_PEA-1:0][N_BITS-1:0] din_pea_o,
    
    // Ready signals from streaming interface
    output logic [M-1:0] stream_intf_ready_o,

    // Mage done signal
    output logic [N_DMA_CH-1:0] mage_done_o
);

  // Transaction counters
  logic [N_DMA_CH-1:0][31:0] trans_counter;
  logic [N_DMA_CH-1:0][15:0] trans_counter_sync;
  logic [N_DMA_CH-1:0] trans_counter_sync_equal;
  logic [N_DMA_CH-1:0] trans_counter_sync_equal_1;

  logic [N_DMA_CH-1:0] reg_sync_dma_ch_trans_zero;

  // Popping sync signal
  logic [N_DMA_CH-1:0] pop_sync;

  // Pop signals
  logic [N_DMA_CH-1:0] hw_r_fifo_pop;
  logic [N_DMA_CH-1:0] hw_r_fifo_pop_enable;

  // Fifo signals
  logic [N_DMA_CH-1:0] hw_r_fifo_empty;
  logic [N_DMA_CH-1:0] hw_r_fifo_full;
  logic [N_DMA_CH-1:0][$clog2(4)-1:0] hw_r_usage;
  logic [N_DMA_CH-1:0][N_BITS-1:0] hw_r_fifo_dout;
  logic [N_DMA_CH-1:0] hw_w_fifo_push;
  logic [N_DMA_CH-1:0] hw_w_fifo_full;
  logic [N_DMA_CH-1:0] hw_w_fifo_empty;
  logic [N_DMA_CH-1:0][N_BITS-1:0] hw_w_fifo_din;
  logic [N_DMA_CH-1:0][N_BITS-1:0] hw_w_fifo_dout;

  // I/O Valid Signals
  logic [N_IN_STREAM-1:0][N_DMA_CH_PER_IN_STREAM-1:0] stream_in_dma_ch_valid;
  logic [N_IN_STREAM-1:0][N_PEA_DIN_PER_IN_STREAM-1:0] stream_in_pea_valid;
  logic [N_OUT_STREAM-1:0][N_PEA_DOUT_PER_OUT_STREAM-1:0] stream_out_pea_valid;
  logic [N_OUT_STREAM-1:0][N_DMA_CH_PER_OUT_STREAM-1:0] stream_out_dma_ch_valid;

  // input streaming interface
  logic [N_IN_STREAM-1:0][N_DMA_CH_PER_IN_STREAM-1:0][N_BITS-1:0] stream_in_dma_ch_data;
  logic [N_IN_STREAM-1:0][N_PEA_DIN_PER_IN_STREAM-1:0][N_BITS-1:0] stream_in_pea_data;
  // output streaming interface
  logic [N_OUT_STREAM-1:0][N_PEA_DOUT_PER_OUT_STREAM-1:0][N_BITS-1:0] stream_out_pea_data;
  logic [N_OUT_STREAM-1:0][N_DMA_CH_PER_OUT_STREAM-1:0][N_BITS-1:0] stream_out_dma_ch_data;

  // --------------------------------- HW FIFO

  /* Hardware Read Fifo */
  genvar rf;
  generate
    for (rf = 0; rf < N_DMA_CH; rf++) begin : gen_hw_r_fifo
      fifo_v3 #(
          .DEPTH(4),
          .FALL_THROUGH(1'b0),
          .DATA_WIDTH(32)
      ) hw_r_fifo_i (
          .clk_i(clk_i),
          .rst_ni(rst_n_i),
          .flush_i(),
          .testmode_i(1'b0),
          .full_o(hw_r_fifo_full[rf]),
          .empty_o(hw_r_fifo_empty[rf]),
          .usage_o(hw_r_usage[rf]),
          .data_i(fifo_req_i[rf].data),
          .push_i(fifo_req_i[rf].push),
          .data_o(hw_r_fifo_dout[rf]),
          .pop_i(hw_r_fifo_pop[rf])
      );
    end
  endgenerate

  /* Hardware Write Fifo */
  genvar wf;
  generate
    for (wf = 0; wf < N_DMA_CH; wf++) begin : gen_hw_w_fifo
      fifo_v3 #(
          .DEPTH(4),
          .FALL_THROUGH(1'b0),
          .DATA_WIDTH(32)
      ) hw_w_fifo_i (
          .clk_i(clk_i),
          .rst_ni(rst_n_i),
          .testmode_i(1'b0),
          .flush_i(),
          .full_o(hw_w_fifo_full[wf]),
          .empty_o(hw_w_fifo_empty[wf]),
          .usage_o(),
          .data_i(hw_w_fifo_din[wf]),
          .push_i(hw_w_fifo_push[wf]),
          .data_o(hw_w_fifo_dout[wf]),
          .pop_i(fifo_req_i[wf].pop)
      );
    end
  endgenerate

  
  /*
    transaction counters:
      -> they start from a value stored in a configuration register
      -> they are decremented whenever data is written into the related i-th write fifo, if reg_dma_rnw_i is 0,
          or whenever data is pushed into related i-th read fifo by the dma channel, if reg_dma_rnw_i is 1,
  */
  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (~rst_n_i) begin
      for (int i = 0; i < N_DMA_CH; i++) begin
        trans_counter[i] <= '0;
      end
    end else begin
      for (int i = 0; i < N_DMA_CH; i++) begin
        if (fifo_req_i[i].flush) begin
          trans_counter[i] <= reg_trans_size_dma_ch_i[i];
        end else if ((!reg_dma_rnw_i[i] && hw_w_fifo_push[i]) || (reg_dma_rnw_i[i] && fifo_req_i[i].push)) begin
          trans_counter[i] <= trans_counter[i] - 1;
        end
      end
    end
  end

  /*
    synchronization transaction counters:
      -> they start from a value stored in a configuration register
      -> they are decremented whenever data is popped by the related i-th read fifo
      -> they are reset when data is popped by the related i-th read fifo AND the counter arrives to zero
  */
  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (~rst_n_i) begin
      for (int i = 0; i < N_DMA_CH; i++) begin
        trans_counter_sync[i] <= '0;
      end
    end else begin
      for (int i = 0; i < N_DMA_CH; i++) begin
        if (fifo_req_i[i].flush) begin
          trans_counter_sync[i] <= reg_trans_size_sync_dma_ch_i[i];
        end else if (hw_r_fifo_pop[i]) begin
          if (|trans_counter_sync[i] == 1'b0) begin
            trans_counter_sync[i] <= reg_trans_size_sync_dma_ch_i[i];
          end else begin
            trans_counter_sync[i] <= trans_counter_sync[i] - 1;
          end
        end
      end
    end
  end

  /*
    mage done:
      -> asserted when all transaction counters are finished (they are all zero)
  */
  always_comb begin
    for (int i = 0; i < N_DMA_CH; i = i + 1) begin
      mage_done_o[i] = (trans_counter[i] == '0);
    end
  end


%for c in range(n_pea_cols):
  assign trans_counter_sync_equal[${c}] = (trans_counter_sync[${c}] == reg_trans_size_sync_dma_ch_i[${c}]);
  assign trans_counter_sync_equal_1[${c}] = (trans_counter_sync[${c}] == (reg_trans_size_sync_dma_ch_i[${c}] - 1));
  assign reg_sync_dma_ch_trans_zero[${c}] = (|reg_sync_dma_ch_trans_i[${c}]) == 1'b0; 
%endfor

%if r_fifo_synch_placement_type == "g2":
  /*
    read fifos popping synchronization:
      -> if the popping from read fifo i has to be synched with its "mate" j, 2 cases are possible:
        -> reg_sync_dma_ch_trans_i[i] == 2'b01:
          -> the sync signal for the "mate" j is asserted whenever trans_counter_sync[j] == reg_trans_size_sync_dma_ch_i[j]
        -> reg_sync_dma_ch_trans_i[i] == 2'b10:
          -> the sync signal for the "mate" j is asserted whenever trans_counter_sync[j] == reg_trans_size_sync_dma_ch_i[j] OR
              trans_counter_sync[j] == reg_trans_size_sync_dma_ch_i[j] - 1

    NOTE: If i has to be synched with j, i must be marked for synch, and synchronization transaction counters of j must be set accordingly
  */
  always_comb begin
    pop_sync = '0;

%for c in range(n_pea_cols):
  <% a = r_fifo_synch_placement_g2[c][0] %>
  <% b = r_fifo_synch_placement_g2[c][1] %>
    if (reg_sync_dma_ch_trans_i[${a}] == 2'b01) begin
      pop_sync[${b}] = trans_counter_sync_equal[${b}];
    end else if (reg_sync_dma_ch_trans_i[${a}] == 2'b10) begin
      pop_sync[${b}] = (trans_counter_sync_equal[${b}] || trans_counter_sync_equal_1[${b}]);
    end
%endfor

%elif r_fifo_synch_placement_type == "g4":

  /*
    read fifos popping synchronization:
      -> if the popping from read fifo i has to be synched with its "mate" j, 2 cases are possible:
        -> reg_sync_dma_ch_trans_i[i] == 2'b01:
          -> the sync signal for the "mate" j is asserted whenever trans_counter_sync[j] == reg_trans_size_sync_dma_ch_i[j]
        -> reg_sync_dma_ch_trans_i[i] == 2'b10:
          -> the sync signal for the "mate" j is asserted whenever trans_counter_sync[j] == reg_trans_size_sync_dma_ch_i[j] OR
              trans_counter_sync[j] == reg_trans_size_sync_dma_ch_i[j] - 1

    NOTE: If i has to be synched with j, i must be marked for synch, and synchronization transaction counters of j must be set accordingly
  */
  always_comb begin
    pop_sync = '0;

    if(reg_r_fifo_synch_groups_i == 2'b01) begin
%for c in range(n_pea_cols):
  <% a = r_fifo_synch_placement_g2[c][0] %>
  <% b = r_fifo_synch_placement_g2[c][1] %>
      if (reg_sync_dma_ch_trans_i[${a}] == 2'b01) begin
        pop_sync[${b}] = trans_counter_sync_equal[${b}];
      end else if (reg_sync_dma_ch_trans_i[${a}] == 2'b10) begin
        pop_sync[${b}] = (trans_counter_sync_equal[${b}] || trans_counter_sync_equal_1[${b}]);
      end
%endfor
    end else if (reg_r_fifo_synch_groups_i == 2'b10) begin
%for c in range(n_pea_cols):
  <% a = r_fifo_synch_placement_g3[c][0] %>
  <% b = r_fifo_synch_placement_g3[c][1] %>
  <% d = r_fifo_synch_placement_g3[c][2] %>
      if (reg_sync_dma_ch_trans_i[${a}] == 2'b01) begin
        pop_sync[${b}] = trans_counter_sync_equal[${b}];
        pop_sync[${d}] = trans_counter_sync_equal[${d}];
      end else if (reg_sync_dma_ch_trans_i[${a}] == 2'b10) begin
        pop_sync[${b}] = (trans_counter_sync_equal[${b}] || trans_counter_sync_equal_1[${b}]);
        pop_sync[${d}] = (trans_counter_sync_equal[${d}] || trans_counter_sync_equal_1[${d}]);
      end
%endfor
    end else if (reg_r_fifo_synch_groups_i == 2'b11) begin
%for c in range(n_pea_cols):
  <% a = r_fifo_synch_placement_g4[c][0] %>
  <% b = r_fifo_synch_placement_g4[c][1] %>
  <% d = r_fifo_synch_placement_g4[c][2] %>
  <% e = r_fifo_synch_placement_g4[c][3] %>
      if (reg_sync_dma_ch_trans_i[${a}] == 2'b01) begin
        pop_sync[${b}] = trans_counter_sync_equal[${b}];
        pop_sync[${e}] = trans_counter_sync_equal[${e}];
        pop_sync[${d}] = trans_counter_sync_equal[${d}];
      end else if (reg_sync_dma_ch_trans_i[${a}] == 2'b10) begin
        pop_sync[${b}] = (trans_counter_sync_equal[${b}] || trans_counter_sync_equal_1[${b}]);
        pop_sync[${e}] = (trans_counter_sync_equal[${e}] || trans_counter_sync_equal_1[${e}]);
        pop_sync[${d}] = (trans_counter_sync_equal[${d}] || trans_counter_sync_equal_1[${d}]);
      end
%endfor
    end
%endif
  end

  // Response full signals
  always_comb begin
    for (int i = 0; i < N_DMA_CH; i = i + 1) begin
      fifo_resp_o[i].empty = hw_w_fifo_empty[i];
      fifo_resp_o[i].data = hw_w_fifo_dout[i];
      fifo_resp_o[i].full = hw_r_fifo_full[i];
      fifo_resp_o[i].alm_full = hw_r_usage[i] == 2'd3;
    end
  end

  // Pop from Read FIFO
  always_comb begin
    for (int i = 0; i < N_DMA_CH; i = i + 1) begin
      hw_r_fifo_pop_enable[i] = 1'b0;
      if (hw_r_fifo_empty[i] == 1'b0 && pea_ready_i[i] == 1'b1) begin
        hw_r_fifo_pop_enable[i] = 1'b1;
      end
    end
  end


  /*
    Read fifo pop:
      -> the popping from a read fifo is asserted when:
        -> no synch is required, and the related pop enable is asserted
        -> if the pop has to be synched (reg_sync_dma_ch_trans_i[i] != '0):
          -> whenever the pop enable of i and j (the "mates") are asserted along with the synch signal
        -> if the pop has to be synched, but the read fifo is "the mate" (j):
          -> if i (the other "mate") has not reached the end, whenever the pop enable of i and j (the "mates") are asserted
          -> if i (the other "mate") has reached the end, whenever the pop enable of j
  */
%if r_fifo_synch_placement_type == "g2":
  always_comb begin
%for c in range(n_pea_cols):
  <% a = r_fifo_synch_placement_g2[c][0] %>
  <% b = r_fifo_synch_placement_g2[c][1] %>
    if ( reg_sync_dma_ch_trans_zero[${a}] && reg_sync_dma_ch_trans_zero[${b}]) begin
      // no sync required
      hw_r_fifo_pop[${a}] = hw_r_fifo_pop_enable[${a}];
    end else if (!( reg_sync_dma_ch_trans_zero[${a}]) && reg_sync_dma_ch_trans_zero[${b}]) begin
      // 0 is mate i and 1 is mate j
      hw_r_fifo_pop[${a}] = hw_r_fifo_pop_enable[${a}] & hw_r_fifo_pop_enable[${b}] & pop_sync[${b}];
    end else begin
      // 0 is mate j and 1 is mate i
      if (hw_r_fifo_empty[${b}] == 1'b1  && |reg_trans_size_sync_dma_ch_i[${a}] == 1'b1) begin
        hw_r_fifo_pop[${a}] = hw_r_fifo_pop_enable[${a}];
      end else begin
        hw_r_fifo_pop[${a}] = hw_r_fifo_pop_enable[${a}] & hw_r_fifo_pop_enable[${b}];
      end
    end
%endfor
  end

%elif r_fifo_synch_placement_type == "g4":

  always_comb begin

    if(reg_r_fifo_synch_groups_i == 2'b01) begin

%for c in range(n_pea_cols):
  <% a = r_fifo_synch_placement_g2[c][0] %>
  <% b = r_fifo_synch_placement_g2[c][1] %>
      if ( reg_sync_dma_ch_trans_zero[${a}] && reg_sync_dma_ch_trans_zero[${b}]) begin
        // no sync required
        hw_r_fifo_pop[${a}] = hw_r_fifo_pop_enable[${a}];
      end else if (!( reg_sync_dma_ch_trans_zero[${a}]) && reg_sync_dma_ch_trans_zero[${b}]) begin
        // 0 is mate i and 1 is mate j
        hw_r_fifo_pop[${a}] = hw_r_fifo_pop_enable[${a}] & hw_r_fifo_pop_enable[${b}] & pop_sync[${b}];
      end else begin
        // 0 is mate j and 1 is mate i
        if (hw_r_fifo_empty[${b}] == 1'b1  && |reg_trans_size_sync_dma_ch_i[${a}] == 1'b1) begin
          hw_r_fifo_pop[${a}] = hw_r_fifo_pop_enable[${a}];
        end else begin
          hw_r_fifo_pop[${a}] = hw_r_fifo_pop_enable[${a}] & hw_r_fifo_pop_enable[${b}];
        end
      end
%endfor

    end else if(reg_r_fifo_synch_groups_i == 2'b10) begin
%for c in range(n_pea_cols):
  <% a = r_fifo_synch_placement_g3[c][0] %>
  <% b = r_fifo_synch_placement_g3[c][1] %>
  <% d = r_fifo_synch_placement_g3[c][2] %>
      if ( reg_sync_dma_ch_trans_zero[${a}] && reg_sync_dma_ch_trans_zero[${b}] && reg_sync_dma_ch_trans_zero[${d}]) begin
        // no sync required
        hw_r_fifo_pop[${c}] = hw_r_fifo_pop_enable[${c}];
      end else if (!( reg_sync_dma_ch_trans_zero[${a}]) && reg_sync_dma_ch_trans_zero[${b}]  && reg_sync_dma_ch_trans_zero[${d}]) begin
        // 0 is mate i and 1 is mate j
        hw_r_fifo_pop[${a}] = hw_r_fifo_pop_enable[${a}] & (hw_r_fifo_pop_enable[${b}] & pop_sync[${b}]) & (hw_r_fifo_pop_enable[${d}] & pop_sync[${d}]);
      end else begin
        // 0 is mate j and 1 is mate i
        if ((hw_r_fifo_empty[${b}] == 1'b1 && hw_r_fifo_empty[${d}] == 1'b1) && |reg_trans_size_sync_dma_ch_i[${a}] == 1'b1) begin
          hw_r_fifo_pop[${a}] = hw_r_fifo_pop_enable[${a}];
        end else begin
          hw_r_fifo_pop[${a}] = hw_r_fifo_pop_enable[${a}] & hw_r_fifo_pop_enable[${b}] & hw_r_fifo_pop_enable[${d}];
        end
      end
%endfor

    end else if(reg_r_fifo_synch_groups_i == 2'b11) begin
%for c in range(n_pea_cols):
  <% a = r_fifo_synch_placement_g4[c][0] %>
  <% b = r_fifo_synch_placement_g4[c][1] %>
  <% d = r_fifo_synch_placement_g4[c][2] %>
  <% e = r_fifo_synch_placement_g4[c][3] %>
      if ( reg_sync_dma_ch_trans_zero[${a}] && reg_sync_dma_ch_trans_zero[${b}] && reg_sync_dma_ch_trans_zero[${d}] && reg_sync_dma_ch_trans_zero[${e}]) begin
        // no sync required
        hw_r_fifo_pop[${c}] = hw_r_fifo_pop_enable[${c}];
      end else if (!( reg_sync_dma_ch_trans_zero[${a}]) && reg_sync_dma_ch_trans_zero[${b}]  && reg_sync_dma_ch_trans_zero[${d}]  && reg_sync_dma_ch_trans_zero[${e}]) begin
        // 0 is mate i and 1 is mate j
        hw_r_fifo_pop[${a}] = hw_r_fifo_pop_enable[${a}] & (hw_r_fifo_pop_enable[${b}] & pop_sync[${b}]) & (hw_r_fifo_pop_enable[${d}] & pop_sync[${d}]) & (hw_r_fifo_pop_enable[${e}] & pop_sync[${e}]);
      end else begin
        // 0 is mate j and 1 is mate i
        if ((hw_r_fifo_empty[${b}] == 1'b1 && hw_r_fifo_empty[${d}] == 1'b1 && hw_r_fifo_empty[${e}] == 1'b1) && |reg_trans_size_sync_dma_ch_i[${a}] == 1'b1) begin
          hw_r_fifo_pop[${a}] = hw_r_fifo_pop_enable[${a}];
        end else begin
          hw_r_fifo_pop[${a}] = hw_r_fifo_pop_enable[${a}] & hw_r_fifo_pop_enable[${b}] & hw_r_fifo_pop_enable[${d}] & hw_r_fifo_pop_enable[${e}];
        end
      end
%endfor
    end else begin
%for c in range(n_pea_cols):
      hw_r_fifo_pop[${c}] = hw_r_fifo_pop_enable[${c}];
%endfor
    end

  end

%endif

  //--------------------------------- Interface Management and Crossbars

% for nis in range(n_in_stream):
  % for ndc in range(n_dma_ch_per_in_stream):
    % for i in range(len(in_stream_dma_ch_placement)):
      % for j in range(len(in_stream_dma_ch_placement[i])):
        % if i == nis and j == ndc:
          %if in_stream_dma_ch_placement[i][j] != None:
  assign stream_in_dma_ch_data[${nis}][${ndc}] = hw_r_fifo_dout[${in_stream_dma_ch_placement[i][j]}];
  assign stream_in_dma_ch_valid[${nis}][${ndc}] = hw_r_fifo_pop[${in_stream_dma_ch_placement[i][j]}] && pea_ready_i[${in_stream_dma_ch_placement[i][j]}];
          %else:
  assign stream_in_dma_ch_data[${nis}][${ndc}] = '0;
  assign stream_in_dma_ch_valid[${nis}][${ndc}] = 1'b0;
          %endif
        % endif       
      % endfor
    % endfor
  % endfor
% endfor

% for nos in range(n_out_stream):
  % for ndc in range(n_pea_dout_per_out_stream):
    % for i in range(len(out_stream_pea_dout_placement)):
      % for j in range(len(out_stream_pea_dout_placement[i])):
        % if i == nos and j == ndc:
          %if out_stream_pea_dout_placement[i][j] != None:
  assign stream_out_pea_data[${nos}][${ndc}] = dout_pea_i[${out_stream_pea_dout_placement[i][j]}];
  assign stream_out_pea_valid[${nos}][${ndc}] = valid_pea_out_i[${out_stream_pea_dout_placement[i][j]}];
          %else:
  assign stream_out_pea_data[${nos}][${ndc}] = '0;
  assign stream_out_pea_valid[${nos}][${ndc}] = 1'b0;
          %endif
        % endif       
      % endfor
    % endfor
  % endfor
% endfor

% if in_stream_xbar == 1:
  genvar k;
  generate
    for (k = 0; k < N_IN_STREAM; k++) begin : gen_xbar_dma_pea
      dma_pea_xbar dma_pea_xbar_inst (
          .dma_ch_valid_i(stream_in_dma_ch_valid[k]),
          .dma_ch_din_i(stream_in_dma_ch_data[k]),
          .sel_i(reg_in_stream_sel_i[k]),
          .din_pea_o(stream_in_pea_data[k]),
          .valid_pea_o(stream_in_pea_valid[k])
      );
    end
  endgenerate
% else:
  always_comb begin
    for (int i = 0; i < N_IN_STREAM; i = i + 1) begin
      for (int j = 0; j < N_DMA_CH_PER_IN_STREAM; j = j + 1) begin // in this case N_DMA_CH_PER_IN_STREAM = N_PEA_DIN_PER_IN_STREAM
        stream_in_pea_data[i][j] = stream_in_dma_ch_data[i][j];
        stream_in_pea_valid[i][j] = stream_in_dma_ch_valid[i][j];
      end
    end
  end
% endif

  // Outputs to PEA construction
  always_comb begin
    for (int i = 0; i < N_IN_STREAM; i = i + 1) begin
      for (int j = 0; j < N_PEA_DIN_PER_IN_STREAM; j = j + 1) begin
        din_pea_o[i*N_PEA_DIN_PER_IN_STREAM+j] = stream_in_pea_data[i][j];
        valid_pea_in_o[i*N_PEA_DIN_PER_IN_STREAM+j] = stream_in_pea_valid[i][j];
      end
    end
  end

% if out_stream_xbar == 1:
  genvar l;
  generate
    for (l = 0; l < N_OUT_STREAM; l++) begin : gen_xbar_pea_dma
      pea_dma_xbar pea_dma_xbar_inst (
          .dout_pea_i(stream_out_pea_data[l]),
          .valid_pea_i(stream_out_pea_valid[l]),
          .sel_i(reg_out_stream_sel_i[l]),
          .dma_ch_dout_o(stream_out_dma_ch_data[l]),
          .dma_ch_valid_o(stream_out_dma_ch_valid[l])
      );
    end
  endgenerate
% else:
  always_comb begin
    for (int i = 0; i < N_IN_STREAM; i = i + 1) begin
      for (int j = 0; j < N_DMA_CH_PER_IN_STREAM; j = j + 1) begin // in this case N_DMA_CH_PER_OUT_STREAM = N_PEA_DOUT_PER_OUT_STREAM
        stream_out_dma_ch_data[i][j] = stream_out_pea_data[i][j];
        stream_out_dma_ch_valid[i][j] = stream_out_pea_valid[i][j];
      end
    end
  end
% endif

  // Write fifo input construction
  always_comb begin
    for (int i = 0; i < N_OUT_STREAM; i = i + 1) begin
      for (int j = 0; j < N_DMA_CH_PER_OUT_STREAM; j = j + 1) begin
        hw_w_fifo_din[i*N_DMA_CH_PER_OUT_STREAM+j] = stream_out_dma_ch_data[i][j];
        hw_w_fifo_push[i*N_DMA_CH_PER_OUT_STREAM+j] = stream_out_dma_ch_valid[i][j] && pea_ready_i[i*N_DMA_CH_PER_OUT_STREAM+j];
      end
    end
  end

  logic all_ready;

  always_comb begin
    all_ready = hw_w_fifo_full == '0;
    if (reg_cols_grouping_i == 2'b00) begin
%for c in range(n_pea_cols):
      stream_intf_ready_o[${c}] = all_ready;
%endfor
    end else if (reg_cols_grouping_i == 2'b01) begin
%for c in range(n_pea_cols):
      stream_intf_ready_o[${c}] = hw_w_fifo_full[${c}] == 1'b0;
%endfor
    end else begin
%if r_fifo_synch_placement_type == "g2":
%for c in range(n_pea_cols):
  <% a = r_fifo_synch_placement_g2[c][0] %>
  <% b = r_fifo_synch_placement_g2[c][1] %>
      stream_intf_ready_o[${a}] = hw_w_fifo_full[${a}] == 1'b0 && hw_w_fifo_full[${b}] == 1'b0;
%endfor
%elif r_fifo_synch_placement_type == "g4":
%for c in range(n_pea_cols):
  <% a = r_fifo_synch_placement_g4[c][0] %>
  <% b = r_fifo_synch_placement_g4[c][1] %>
  <% d = r_fifo_synch_placement_g4[c][2] %>
  <% e = r_fifo_synch_placement_g4[c][3] %>
      stream_intf_ready_o[${a}] = hw_w_fifo_full[${a}] == 1'b0 && hw_w_fifo_full[${b}] == 1'b0 && hw_w_fifo_full[${d}] == 1'b0 && hw_w_fifo_full[${e}] == 1'b0;
%endfor
%endif
    end
  end

endmodule
