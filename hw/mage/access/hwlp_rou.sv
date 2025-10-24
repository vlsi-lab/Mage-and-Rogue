// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: hwlp_rou.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module is named HWLP Reorder Unit as it reorders the loop variables in order to feed each stream with the right IVs.

module hwlp_rou
  import agu_pkg::*;
(
    input logic clk_i,
    input logic rst_n_i,
    input logic [N_AGE_TOT-1:0] is_age_active_i,
    //end signals
    input logic [HWLP_RF_SIZE-1:0] end_lp_i,
    //for each stream, hwlp_sel_i indicates the location in hwlp_rf_i that contains the loop variables needed for the stream
    input logic [N_AGE_TOT-1:0][LOG2_HWLP_RF_SIZE-1:0] hwlp_sel_i,
    //each bit is set to 1 when the related loop variable has to restart from initial value
    input logic [HWLP_RF_SIZE-1:0][N_LP-1:0] hwlp_end_condition_i,
    //IVs constraints for each stream
    input logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0][NBIT_LP_IV-1:0] iv_constraints_i,
    //selection signals for ivs constraints
    input logic [N_AGE_TOT-1:0][LOG2_N_LP-1+1:0] iv_constraints_sel_i,
    //input from hwlp_rf
    input logic [HWLP_RF_SIZE-1:0][N_LP-1:0][NBIT_LP_IV-1:0] hwlp_rf_i,
    //input from hwlp_rf for the validity of locations of hwlp_rf_i
    input logic [HWLP_RF_SIZE-1:0] hwlp_valid_i,
    //input from dispather that indicates if the stream handles the store operation for an accumulation
    input logic [N_AGE_TOT-1:0] is_acc_store_rou_i,
    //accumulation vector mode
    input logic [1:0] reg_acc_vec_mode_i,
    //output for the validity of the stream
    output logic [N_AGE_TOT-1:0] stream_valid_o,
    output logic [N_AGE_TOT-1:0] pea_acc_reset_o,
    //reordered end signals
    output logic [N_AGE_TOT-1:0] end_lp_o,
    //for each stream,   contains the ordered ivs needed for the calculation of the address/bank for the stream
    output logic [N_AGE_TOT-1:0][N_IVS-1:0][NBIT_LP_IV-1:0] hwlp_rou_o
);

  logic [N_AGE_TOT-1:0][N_LP-1+1:0][NBIT_LP_IV-1:0] stream_hwlp;
  logic [N_AGE_TOT-1:0] is_constraint_iv_valid;
  logic [N_AGE_TOT-1:0] is_pea_acc_constraint_valid;
  logic [N_AGE_TOT-1:0][N_IVS-1:0][NBIT_LP_IV-1:0] hwlp_rou;
  logic init_acc_done;

  logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0][N_LP-1:0] condition_mask;
  logic [N_STREAMS-1:0][N_AGE_PER_STREAM-1:0][N_LP-1:0] zero_condition;

  ////////////////////////////////////////////////////////////////
  //   Reordering outputs of HWLP RF for the correct Streams    //
  ////////////////////////////////////////////////////////////////
  always_comb begin
    for (int i = 0; i < N_AGE_TOT; i = i + 1) begin
      stream_hwlp[i][N_LP-1:0] = hwlp_rf_i[hwlp_sel_i[i]];
      stream_hwlp[i][N_LP] = '0;
    end
  end

  always_comb begin
    for (int i = 0; i < N_AGE_TOT; i = i + 1) begin
      if (is_age_active_i[i] == 1'b0) begin
        end_lp_o[i] = 1'b0;
      end else begin
        end_lp_o[i] = end_lp_i[hwlp_sel_i[i]];
      end
    end
  end

  ////////////////////////////////////////////////////////////////
  //         Reordering the correct IVs for each Stream         //
  ////////////////////////////////////////////////////////////////
  always_comb begin
    for (int i = 0; i < N_AGE_TOT; i = i + 1) begin
      for (int j = 0; j < N_IVS; j = j + 1) begin
        if (is_age_active_i[i] == 1'b0) begin
          hwlp_rou[i][j] = 0;
        end else begin
          hwlp_rou[i][j] = stream_hwlp[i][j];
        end
      end
    end
    hwlp_rou_o = hwlp_rou;
  end

  always_comb begin
    for (int i = 0; i < N_STREAMS; i = i + 1) begin
      for (int j = 0; j < N_AGE_PER_STREAM; j = j + 1) begin
        for (int k = 0; k < N_LP; k = k + 1) begin
          zero_condition[i][j][k] = |(stream_hwlp[i*N_AGE_PER_STREAM+j][k]);
        end
      end
    end
  end

  ////////////////////////////////////////////////////////////////
  //               Streams IVs Constraints Check                //
  ////////////////////////////////////////////////////////////////
  always_comb begin
    for (int i = 0; i < N_STREAMS; i = i + 1) begin
      for (int j = 0; j < N_AGE_PER_STREAM; j = j + 1) begin
        if (iv_constraints_sel_i[i*N_AGE_PER_STREAM+j] == 3'b100 || is_age_active_i[i*N_AGE_PER_STREAM+j] == 1'b0) begin
          // Unconstrained IVs for the stream:
          // If the iv constraint selector is 4, it means that the ivs for the stream are unconstrained
          // If the age is not active, the ivs for the stream are unconstrained (CHECK)
          is_constraint_iv_valid[i*N_AGE_PER_STREAM+j] = 1'b1;
          is_pea_acc_constraint_valid[i*N_AGE_PER_STREAM+j] = 1'b0;
          condition_mask = '0;
        end else begin
          condition_mask[i][j] = (1 << (iv_constraints_sel_i[i*N_AGE_PER_STREAM+j])) - 1;
          // Constrained IVs for the stream:
          // If the iv constraint selector is not 4, it indicates the iv to be constrained (at the value kept in reg) for the respective stream
          is_constraint_iv_valid[i*N_AGE_PER_STREAM+j] = (stream_hwlp[i*N_AGE_PER_STREAM+j][iv_constraints_sel_i[i*N_AGE_PER_STREAM+j]] == iv_constraints_i[i][j]) &&
                                                         ((zero_condition[i][j] & condition_mask[i][j]) == '0);
          // If the stream handles the store of an accumulation, the PEA has to be informed on when the accumulation ends too
          // This is done by checking if the constrained IV is equal to its constraint but considering an entry of the RF active before the one of the acc store stream
          // The one to chose depends on the accumulation vector mode
          if (is_acc_store_rou_i[i*N_AGE_PER_STREAM+j]) begin
            case (reg_acc_vec_mode_i)
              2'b00: begin
                is_pea_acc_constraint_valid[i*N_AGE_PER_STREAM+j] = (hwlp_rf_i[hwlp_sel_i[i*N_AGE_PER_STREAM+j]-2][iv_constraints_sel_i[i*N_AGE_PER_STREAM+j]] == 0) &&
                                                                 ((condition_mask[i][j] && hwlp_end_condition_i[hwlp_sel_i[i*N_AGE_PER_STREAM+j]-2]) == condition_mask[i][j]);
              end
              2'b01: begin
                is_pea_acc_constraint_valid[i*N_AGE_PER_STREAM+j] = (hwlp_rf_i[hwlp_sel_i[i*N_AGE_PER_STREAM+j]-5][iv_constraints_sel_i[i*N_AGE_PER_STREAM+j]] == 0) &&
                                                                 ((condition_mask[i][j] && hwlp_end_condition_i[hwlp_sel_i[i*N_AGE_PER_STREAM+j]-5]) == condition_mask[i][j]);
              end
              2'b10: begin
                is_pea_acc_constraint_valid[i*N_AGE_PER_STREAM+j] = (hwlp_rf_i[hwlp_sel_i[i*N_AGE_PER_STREAM+j]-4][iv_constraints_sel_i[i*N_AGE_PER_STREAM+j]] == 0) &&
                                                                 ((condition_mask[i][j] && hwlp_end_condition_i[hwlp_sel_i[i*N_AGE_PER_STREAM+j]-4]) == condition_mask[i][j]);
              end
              default: begin
                is_pea_acc_constraint_valid[i*N_AGE_PER_STREAM+j] = (hwlp_rf_i[hwlp_sel_i[i*N_AGE_PER_STREAM+j]-2][iv_constraints_sel_i[i*N_AGE_PER_STREAM+j]] == 0) &&
                                                                 ((condition_mask[i][j] && hwlp_end_condition_i[hwlp_sel_i[i*N_AGE_PER_STREAM+j]-2]) == condition_mask[i][j]);
              end
            endcase
          end else begin
            is_pea_acc_constraint_valid[i*N_AGE_PER_STREAM+j] = 1'b0;
          end
        end
      end
    end
  end

  ////////////////////////////////////////////////////////////////
  //                   Streams Validity Check                   //
  ////////////////////////////////////////////////////////////////
  always_comb begin
    for (int i = 0; i < N_AGE_TOT; i = i + 1) begin
      /* If the stream does not handle the store of an accumulation, the stream is valid if:
        - The location in the HWLP RF is valid
        - The IVs constraints are valid
      */
      stream_valid_o[i] = hwlp_valid_i[hwlp_sel_i[i]] & is_constraint_iv_valid[i];
      if (is_acc_store_rou_i[i]) begin
        /* If the stream handles the store of an accumulation, PEA's PE handling the accumulation must reset its result value.
           Reset means that the PE must stop accumulate and it must initiate the successive accumulation stage.
           The reset signal to the PE is given:
           -> by the repective entry of the HWLP RF until the first reset 
           -> by the respective is_pea_acc_constraint_valid signal, that is asserted when the constraint is valid for the PE reset
        */
        case (reg_acc_vec_mode_i)
          2'b00: begin
            pea_acc_reset_o[i] = (init_acc_done == 1'b0) ? hwlp_valid_i[hwlp_sel_i[i]-2] : is_pea_acc_constraint_valid[i];
          end
          2'b01: begin
            pea_acc_reset_o[i] = (init_acc_done == 1'b0) ? hwlp_valid_i[hwlp_sel_i[i]-5] : is_pea_acc_constraint_valid[i];
          end
          2'b10: begin
            pea_acc_reset_o[i] = (init_acc_done == 1'b0) ? hwlp_valid_i[hwlp_sel_i[i]-4] : is_pea_acc_constraint_valid[i];
          end
          default: begin
            pea_acc_reset_o[i] = (init_acc_done == 1'b0) ? hwlp_valid_i[hwlp_sel_i[i]-2] : is_pea_acc_constraint_valid[i];
          end
        endcase
      end else begin
        pea_acc_reset_o[i] = '0;
      end
    end
  end

  // Handles the detection of when the initial value of first accumulation set has been loaded into the PE
  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (~rst_n_i) begin
      init_acc_done <= 1'b0;
    end else begin
      if (|pea_acc_reset_o == 1'b1) begin
        init_acc_done <= 1'b1;
      end
    end
  end

endmodule : hwlp_rou
