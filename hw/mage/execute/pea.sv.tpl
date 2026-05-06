// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: pea.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: Processing Element Array
<%import math as m%>
module pea
  import pea_pkg::*;
%if streaming_cgra == 1:
  import stream_intf_pkg::*;
%endif
(
    input  logic                                                    clk_i,
    input  logic                                                    rst_n_i,
%if dae_cgra == 1:
    ////////////////////////////////
    //   DAE Interface for PEA    //
    ////////////////////////////////
    input logic                                                     start_d_i,
    // Accumulation end signal from AGU
    input  logic [N_IN_PEA/2-1:0]                                   acc_match_i,
    // input data valid
    input logic [N_IN_PEA-1:0]                                      in_data_valid_i,
    // Input data from internal SpM
    input  logic   [N_IN_PEA-1:0][N_BITS-1:0]                       pea_data_i,
    // Selection of PEA outputs for each row
    input  logic   [N_OUT_PEA-1:0][ ${max(m.log(n_pea_cols), 2)}-1:0]                      sel_output_i,
    // PEA output data
    output logic   [N_OUT_PEA-1:0][N_BITS-1:0]                      pea_data_o,
%endif
%if streaming_cgra == 1:
    ////////////////////////////////
    //Streaming Interface for PEA //
    ////////////////////////////////
    input  logic   [        N-1:0][     M-1:0][             31:0]  reg_pea_rf_i,
    input  logic [1:0]                                             reg_cols_grouping_i,
    input  logic [M-1:0][ LOG_N:0]                                 reg_stream_sel_out_pea_i,
    input  logic [N-1:0][M-1:0][15:0]                              reg_acc_value_i,
    input  logic [1:0]                                             reg_rf_value_i,
    input  logic [M-1:0]                                           stream_valid_i,
    input  logic [M-1:0][N_BITS-1:0]                               stream_data_i,
    output logic [M-1:0]                                           pea_ready_o,
    output logic [M-1:0]                                           stream_valid_o,
    output logic [M-1:0][N_BITS-1:0]                               stream_data_o,
    output  logic   [        N-1:0][     M-1:0][             31:0] reg_pea_rf_d_o,
    output  logic   [        N-1:0][     M-1:0]                    reg_pea_rf_de_o,
    input logic                                                    mage_done_i,
    input logic [M-1:0]                                            stream_intf_ready_i,
%endif
    // Instruction word
    input  logic   [        N-1:0][     M-1:0][N_CFG_BITS_PE-1:0]   ctrl_pea_i,
    // Constant from configuration registers
    input  logic   [        N-1:0][     M-1:0][             31:0]   reg_constant_op_i
);

%if dae_cgra == 1:

  ////////////////////////////////
  //     I/O Values of PEs      //
  ////////////////////////////////
  %for r in range(n_pea_rows):
      %for c in range(n_pea_cols):
  logic [     N_BITS-1:0]             out_data_pe${r}${c};  
      %endfor
  %endfor
  
  %for r in range(n_pea_rows):
      %for c in range(n_pea_cols):
  logic [N_INPUTS_PE-1:0][N_BITS-1:0] in_data_pe${r}${c};  
      %endfor
  %endfor

  ////////////////////////////////
  //    DAE: I/O of PEA Rows    //
  ////////////////////////////////
  logic   [ N_IN_PEA-1:0][N_BITS-1:0] in_data_pea;
  %for r in range(n_pea_rows):
  logic [          M-1:0][N_BITS-1:0] out_data_row${r};  
  %endfor
%endif

%if streaming_cgra == 1:
  ////////////////////////////////
  //     I/O Values of PEs      //
  ////////////////////////////////
  %for r in range(n_pea_rows):
      %for c in range(n_pea_cols):
  logic [     N_BITS-1:0]             out_data_pe${r}${c};  
      %endfor
  %endfor
  
  %for r in range(n_pea_rows):
      %for c in range(n_pea_cols):
  logic [N_INPUTS_PE-4:0][N_BITS-1:0] in_data_pe${r}${c};  
      %endfor
  %endfor

  /////////////////////////////////
  //Streaming: I/O of PEA Columns//
  /////////////////////////////////
  logic [M-1:0][N_BITS-1:0]   stream_data_in_reg;
  logic [M-1:0]               stream_valid_in_reg;

  %for c in range(n_pea_cols):
    logic [          N:0][N_BITS-1:0] out_data_col${c};   
  %endfor
  %for c in range(n_pea_cols): 
    logic [          N:0]             out_valid_col${c};  
  %endfor

  // accumulation counter register
  logic [N-1:0][M-1:0][15:0]  reg_acc_value_pe;

  //////////////////////////////////
  //Streaming: Ready/Valid Signals//
  //////////////////////////////////
%for r in range(n_pea_rows):
    %for c in range(n_pea_cols):
  logic [N_INPUTS_PE-4:0] stream_valid_pe_in${r}${c};   
    %endfor
%endfor

%for r in range(n_pea_rows):
    %for c in range(n_pea_cols):
  logic  stream_valid_pe_out${r}${c};   
    %endfor
%endfor

%for r in range(n_pea_rows):
    %for c in range(n_pea_cols):
  logic  stream_ready_pe_out${r}${c};   
    %endfor
%endfor

  logic [M-1:0] ready_in_pe;
  logic pea_ready_all_cols;
  logic [M-1:0] pea_ready_single_cols;
  logic [M/2-1:0] pea_ready_twin_cols;
%endif

%if activation_computation == 1:
  ////////////////////////////////
  //  Streaming: Delay Signals  //
  ////////////////////////////////
%for r in range(n_pea_rows):
    %for c in range(n_pea_cols):
logic [N_NEIGH_PE-1:0][N_BITS:0] in_delay_op${r}${c};  
    %endfor
%endfor

%for r in range(n_pea_rows):
    %for c in range(n_pea_cols):
logic [N_BITS:0] out_delay_op${r}${c};  
    %endfor
%endfor

%for r in range(n_pea_rows):
    %for c in range(n_pea_cols):
logic [N_NEIGH_PE-1:0] in_delay_op_valid${r}${c};  
    %endfor
%endfor

%for r in range(n_pea_rows):
    %for c in range(n_pea_cols):
logic out_delay_op_valid${r}${c};  
    %endfor
%endfor
%endif

  ////////////////////////////////
  // Streaming: Input Registers //
  ////////////////////////////////
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
%if dae_cgra == 1:
      in_data_pea <= '0;
%endif
%if streaming_cgra == 1:
      stream_data_in_reg <= '0;
      stream_valid_in_reg <= '0;
%endif
    end else begin
%if streaming_cgra == 1:
  %for i in range(n_pea_cols):
      if(ready_in_pe[${i}]) begin
        stream_data_in_reg[${i}]  <= stream_data_i[${i}];
        stream_valid_in_reg[${i}] <= stream_valid_i[${i}];
      end else begin
        stream_data_in_reg[${i}]  <= stream_data_in_reg[${i}];
        stream_valid_in_reg[${i}] <= stream_valid_in_reg[${i}];
      end
  %endfor
%endif
%if dae_cgra == 1:
      for (int i = 0; i < N_IN_PEA; i++) begin
        if (start_d_i && in_data_valid_i[i]) begin
            in_data_pea[i] <= pea_data_i[i];
        end
      end
%endif
    end
  end

%if dae_cgra == 1:
  ////////////////////////////////
  //  DAE: Output Construction  //
  ////////////////////////////////
  %for r in range(n_pea_rows):
      %for c in range(n_pea_cols):
  assign out_data_row${r}[${c}] = out_data_pe${r}${c}; 
      %endfor
  %endfor
%endif

%if streaming_cgra == 1:
  //////////////////////////////////
  //Streaming: Output Construction//
  //////////////////////////////////
  %for c in range(n_pea_cols):
      %for r in range(n_pea_rows):
  assign out_data_col${c}[${r}] = out_data_pe${r}${c};  
      %endfor
  assign out_data_col${c}[${n_pea_rows}] = '0;
  %endfor
  %for c in range(n_pea_cols):
      %for r in range(n_pea_rows): 
  assign out_valid_col${c}[${r}] = stream_valid_pe_out${r}${c}; 
      %endfor
  assign out_valid_col${c}[${n_pea_rows}] = 1'b0;
  %endfor
%endif

%if dae_cgra == 1:
%for s in range(n_age_tot):
    assign pea_data_o[${(s)}] = out_data_row${(s)%n_pea_rows}[sel_output_i[${(s)}]]; 
%endfor
%endif
%if streaming_cgra == 1:
  %for c in range(n_pea_cols):
  assign stream_data_o[${c}] = out_data_col${c}[reg_stream_sel_out_pea_i[${c}]];
  assign stream_valid_o[${c}] = out_valid_col${c}[reg_stream_sel_out_pea_i[${c}]]; 
  %endfor
%endif

%if streaming_cgra == 1:
  //////////////////////////////////
  //Streaming: PE I/Os assignments//
  //////////////////////////////////
  %for r in range(n_pea_rows):
    %for c in range(n_pea_cols):
  assign in_data_pe${r}${c}[CONSTANT] = reg_constant_op_i[${r}][${c}]; <% k = 1 %> <% pe = 0 %>
      %for i in range(len(pea_in_stream_placement[c])):
        %if pea_in_stream_placement[c][i] != None:
  assign in_data_pe${r}${c}[STREAM_IN${k-1}] = stream_data_in_reg[${pea_in_stream_placement[c][i]}]; <% k = k + 1 %> 
        %else:
  assign in_data_pe${r}${c}[${k}] = '0; <% k = k + 1 %> 
        %endif  
      %endfor 
      %for r1 in range(r-1,r+2,1):
        %for c1 in range(c-1,c+2,1):
          %if (r1 == r or c1 == c) and (not(r1 == r and c1 == c)): #this defines noc
            %if r1 < 0 or c1 < 0 or r1 >= n_pea_rows or c1 >= n_pea_cols:
  assign in_data_pe${r}${c}[${pattern_neigh_pe[pe]}] = '0; <% k = k + 1 %> <% pe = pe + 1 %>
            %else:
  assign in_data_pe${r}${c}[${pattern_neigh_pe[pe]}] = out_data_pe${r1}${c1}; <% k = k + 1 %> <% pe = pe + 1 %>                 
            %endif
          %endif
        %endfor
      %endfor

    %endfor
  %endfor

%endif

%if dae_cgra == 1:
  ////////////////////////////////
  //  DAE: PE I/Os assignments  //
  ////////////////////////////////
  %for r in range(n_pea_rows):
    %for c in range(n_pea_cols):
  assign in_data_pe${r}${c}[CONSTANT] = reg_constant_op_i[${r}][${c}]; <% k = 1 %> <% pe = 0 %>
        %for i in range(len(pea_in_mem_placement[r])):
          %if pea_in_mem_placement[r][i] == "None":
  assign in_data_pe${r}${c}[MEM_IN_${i}] = '0; <% k = k + 1 %>
          %else:
  assign in_data_pe${r}${c}[MEM_IN_${i}] = in_data_pea[${pea_in_mem_placement[r][i]}]; <% k = k + 1 %>      
          %endif
        %endfor    
      %for r1 in range(r-1,r+2,1):
        %for c1 in range(c-1,c+2,1):
          %if (r1 == r or c1 == c) and (not(r1 == r and c1 == c)): #this defines noc
            %if r1 < 0 or c1 < 0 or r1 >= n_pea_rows or c1 >= n_pea_cols:
  assign in_data_pe${r}${c}[${pattern_neigh_pe[pe]}] = '0; <% k = k + 1 %> <% pe = pe + 1 %>
            %else:
  assign in_data_pe${r}${c}[${pattern_neigh_pe[pe]}] = out_data_pe${r1}${c1}; <% k = k + 1 %> <% pe = pe + 1 %>                
            %endif
          %endif
        %endfor
      %endfor

    %endfor
  %endfor

%endif

%if streaming_cgra == 1:
  ////////////////////////////////////
  //Streaming: Delay Ops assignments//
  ////////////////////////////////////
  <% k = 0 %>
  %for r in range(n_pea_rows):
    %for c in range(n_pea_cols): 
      %for r1 in range(r-1,r+2,1):
        %for c1 in range(c-1,c+2,1):
          %if (r1 == r or c1 == c) and (not(r1 == r and c1 == c)): #this defines noc
            %if r1 < 0 or c1 < 0 or r1 >= n_pea_rows or c1 >= n_pea_cols:
              %if r1 == -1 and c1 == c:
                %if pea_in_stream_placement[c][0] != None:
  assign in_delay_op${r}${c}[${k}] = {stream_data_in_reg[${pea_in_stream_placement[c][0]}][N_BITS-1], stream_data_in_reg[${pea_in_stream_placement[c][0]}]}; <% k = k + 1 %>
                %else:
  assign in_delay_op${r}${c}[${k}] = '0; <% k = k + 1 %>
                %endif
              %else:
  assign in_delay_op${r}${c}[${k}] = '0; <% k = k + 1 %>
              %endif
            %else:
  assign in_delay_op${r}${c}[${k}] = out_delay_op${r1}${c1}; <% k = k + 1 %>                  
            %endif
          %endif
        %endfor
      %endfor
    <% k = 0 %>
    %endfor
  %endfor
  <% k = 0 %>
  %for r in range(n_pea_rows):
    %for c in range(n_pea_cols): 
      %for r1 in range(r-1,r+2,1):
        %for c1 in range(c-1,c+2,1):
          %if (r1 == r or c1 == c) and (not(r1 == r and c1 == c)): #this defines noc
            %if r1 < 0 or c1 < 0 or r1 >= n_pea_rows or c1 >= n_pea_cols:
              %if r1 == -1 and c1 == c:
                %if pea_in_stream_placement[c][0] != None:
  assign in_delay_op_valid${r}${c}[${k}] = stream_valid_in_reg[${pea_in_stream_placement[c][0]}]; <% k = k + 1 %>
                %else:
  assign in_delay_op_valid${r}${c}[${k}] = '0; <% k = k + 1 %>
                %endif
              %else:
  assign in_delay_op_valid${r}${c}[${k}] = '0; <% k = k + 1 %>
              %endif
            %else:
  assign in_delay_op_valid${r}${c}[${k}] = out_delay_op_valid${r1}${c1}; <% k = k + 1 %>                  
            %endif
          %endif
        %endfor
      %endfor
    <% k = 0 %>
    %endfor
  %endfor
%endif
%if streaming_cgra == 1:
  /////////////////////////////////////////
  //Streaming: PEs Valid I/Os assignments//
  /////////////////////////////////////////
  %for r in range(n_pea_rows):
    %for c in range(n_pea_cols):

  assign stream_valid_pe_in${r}${c}[0] = 1'b1; <% k = 1 %>  
      % for i in range(len(pea_in_stream_placement[c])):
        %if pea_in_stream_placement[c][i] != None:
  assign stream_valid_pe_in${r}${c}[${k}] = stream_valid_in_reg[${pea_in_stream_placement[c][i]}]; <% k = k + 1 %>  
        %else:
  assign stream_valid_pe_in${r}${c}[${k}] = 1'b1;  <% k = k + 1 %>
        %endif
      %endfor  
      %for r1 in range(r-1,r+2,1):
        %for c1 in range(c-1,c+2,1):
          %if (r1 == r or c1 == c) and (not(r1 == r and c1 == c)): #this defines noc
            %if r1 < 0 or c1 < 0 or r1 >= n_pea_rows or c1 >= n_pea_cols:
  assign stream_valid_pe_in${r}${c}[${k}] = 1'b1; <% k = k + 1 %>        
            %else:
  assign stream_valid_pe_in${r}${c}[${k}] = stream_valid_pe_out${r1}${c1}; <% k = k + 1 %>                  
            %endif
          %endif
        %endfor
      %endfor
    %endfor
  %endfor
%endif

%if streaming_cgra == 1:
  /////////////////////////////////////
  //Streaming: PEs Acc Counter Values//
  /////////////////////////////////////
  always_comb begin
    for(int i=0; i<N; i++) begin
        for(int j=0; j<M; j++) begin
            reg_acc_value_pe[i][j] = reg_acc_value_i[i][j];
        end
    end
  end
%endif


%if streaming_cgra == 1:
  ////////////////////////////////
  //  Streaming: PE Instances   //
  ////////////////////////////////
  %for r in range(n_pea_rows):
    %for c in range(n_pea_cols):

      %if ((int(r) * int(n_pea_cols) + int(c)) in div_pes) and ((int(r) * int(n_pea_cols) + int(c)) in part_add_pes) and (is_div_pipe == 1):
  pe_s_part_add_act_pipediv pe_s_part_add_act_pipediv_${r}${c} (
      %elif ((int(r) * int(n_pea_cols) + int(c)) in div_pes) and ((int(r) * int(n_pea_cols) + int(c)) in part_add_pes) and (is_div_pipe == 0):
  pe_s_part_add_act_serdiv pe_s_part_add_act_serdiv_${r}${c} (
      %elif ((int(r) * int(n_pea_cols) + int(c)) in div_pes) and ((int(r) * int(n_pea_cols) + int(c)) in part_mul_pes) and (is_div_pipe == 1):
  pe_s_part_mul_act_pipediv pe_s_part_mul_act_pipediv_${r}${c} (
      %elif ((int(r) * int(n_pea_cols) + int(c)) in div_pes) and ((int(r) * int(n_pea_cols) + int(c)) in part_mul_pes) and (is_div_pipe == 0):
  pe_s_part_mul_act_serdiv pe_s_part_mul_act_serdiv_${r}${c} (
      %elif ((int(r) * int(n_pea_cols) + int(c)) in div_pes) and (is_div_pipe == 1):
  pe_s_full_act_pipediv pe_s_full_act_pipediv_${r}${c} (
      %elif ((int(r) * int(n_pea_cols) + int(c)) in div_pes) and (is_div_pipe == 0):
  pe_s_full_act_serdiv pe_s_full_act_serdiv_${r}${c} (
      %elif ((int(r) * int(n_pea_cols) + int(c)) in part_add_pes):
  pe_s_part_gemm_add pe_s_gemm_part_add_${r}${c} (
      %elif ((int(r) * int(n_pea_cols) + int(c)) in part_mul_pes):
  pe_s_part_gemm_mul pe_s_gemm_part_mul_${r}${c} (
      %else:
  pe_s_full_gemm pe_s_full_gemm_${r}${c} (
      %endif
      .clk_i(clk_i),
      .rst_n_i(rst_n_i),
      .mage_done_i(mage_done_i),
      .neigh_pe_op_i(in_data_pe${r}${c}),
      .reg_const_i(reg_pea_rf_i[${r}][${c}]),
      .reg_pea_rf_d_o(reg_pea_rf_d_o[${r}][${c}]),
      .reg_pea_rf_de_o(reg_pea_rf_de_o[${r}][${c}]),
      .reg_acc_value_i(reg_acc_value_pe[${r}][${c}]),
      .reg_rf_value_i(reg_rf_value_i),
      .pea_ready_i(ready_in_pe[${c}]),
      .neigh_pe_op_valid_i(stream_valid_pe_in${r}${c}),
      .neigh_delay_op_i(in_delay_op${r}${c}),
      .neigh_delay_op_valid_i(in_delay_op_valid${r}${c}),
      .valid_o(stream_valid_pe_out${r}${c}),
      .ready_o(stream_ready_pe_out${r}${c}),
      .delay_op_valid_o(out_delay_op_valid${r}${c}),
      .delay_op_o(out_delay_op${r}${c}),
      .ctrl_pe_i(ctrl_pea_i[${r}][${c}]),
      .pe_res_o(out_data_pe${r}${c})
  ); 
    %endfor
  %endfor
%endif

%if dae_cgra == 1:
  ////////////////////////////////
  //     DAE: PE Instances      //
  ////////////////////////////////
  %for r in range(n_pea_rows):
    %for c in range(n_pea_cols):
      %if (int(r) * int(n_pea_cols) + int(c)) in acc_pes:
  pe_dae_part_gemm_acc pe_dae_part_gemm_acc_${r}${c} (
      .acc_match_i(acc_match_i[${r}]),
      %else:
  pe_dae pe_dae_${r}${c} (
      %endif
      .clk_i(clk_i),
      .rst_n_i(rst_n_i),
      .start_d_i(start_d_i),
      .pe_op_i(in_data_pe${r}${c}),
      %if format_full == 1:
      .acc_match_i(acc_match_i[${r}]),
      %endif
      %if activation_computation == 1:
      .neigh_delay_op_i(in_delay_op${r}${c}),
      .delay_op_o(out_delay_op${r}${c}),
      %endif
      .ctrl_pe_i(ctrl_pea_i[${r}][${c}]),
      .pe_res_o(out_data_pe${r}${c})
  ); 
    %endfor
  %endfor
%endif

%if streaming_cgra == 1:
  ////////////////////////////////////
  //Streaming: Columns Ready Signals//
  ////////////////////////////////////
  /* Overall PEA Ready */
  assign pea_ready_all_cols = 
%for r in range(n_pea_rows): 
  %for c in range(n_pea_cols): 
    %if r == n_pea_rows-1 and c == n_pea_cols-1:
    stream_ready_pe_out${r}${c};
    %else:
    stream_ready_pe_out${r}${c} &
    %endif
  %endfor 
%endfor
/* Single-Column Ready */
%for c in range(n_pea_cols):
  assign pea_ready_single_cols[${c}] =
  %for r in range(n_pea_rows):  
    %if r == n_pea_rows-1:
    stream_ready_pe_out${r}${c};
    %else:
    stream_ready_pe_out${r}${c} &
    %endif
  %endfor 
%endfor
<%import math as m%>
/* Couple of Columns Ready */
%for c in range(0, n_pea_cols, 2):
  assign pea_ready_twin_cols[${m.floor(c/2)}] =
  %for c1 in range(c, c+2):
    %for r in range(n_pea_rows):  
      %if c1 == c+1 and r == n_pea_rows-1:
    stream_ready_pe_out${r}${c1};
      %else:
    stream_ready_pe_out${r}${c1} &
      %endif
    %endfor
  %endfor 
%endfor

  always_comb begin
    if(reg_cols_grouping_i == 2'b00) begin
%for c in range(n_pea_cols):
      ready_in_pe[${c}] = pea_ready_all_cols && stream_intf_ready_i[${c}];
%endfor
    end else if (reg_cols_grouping_i == 2'b01) begin
%for c in range(n_pea_cols):
      ready_in_pe[${c}] = pea_ready_single_cols[${c}] && stream_intf_ready_i[${c}];
%endfor
    end else begin
%for c in range(n_pea_cols):
      ready_in_pe[${c}] = pea_ready_twin_cols[${m.floor(c/2)}] && stream_intf_ready_i[${c}];
%endfor
    end
  end
  /* Ready signals for all columns */
  always_comb begin
%for c in range(n_pea_cols):
    pea_ready_o[${c}] = ready_in_pe[${c}];
%endfor
  end
%endif

endmodule
