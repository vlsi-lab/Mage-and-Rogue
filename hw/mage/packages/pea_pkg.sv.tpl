// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: pea_pkg.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: Package for CGRA's Processing Element Array

<%import math as m%>

package pea_pkg;

%if streaming_cgra == 1:
  import stream_intf_pkg::*;
%endif
%if dae_cgra == 1:
  import agu_pkg::*;
%endif
  

  ////////////////////////////////////////////////////////////////
  //             Configuration Registers Parameters             //
  ////////////////////////////////////////////////////////////////
  localparam unsigned KMEM_SIZE = ${kernel_len};
  localparam unsigned N_CFG_ADDR_BITS = (KMEM_SIZE == 1) ? 1 : $clog2(KMEM_SIZE);
  localparam unsigned N_CFG_BITS_PE = 32;

  ////////////////////////////////////////////////////////////////
  //         Processing Element Array (PEA) Parameters          //
  ////////////////////////////////////////////////////////////////
  
  ////////////////////////////////
  //     Common Parameters      //
  ////////////////////////////////
  // Number of bits of operands 
  localparam unsigned N_BITS = 32;
  // PEA columns and rows
  localparam unsigned M = ${n_pea_cols};
  localparam unsigned N = ${n_pea_rows};
  localparam unsigned LOG_M = $clog2(M);
  localparam unsigned LOG_N = $clog2(N);
  // number of neighbouring PEs
  localparam unsigned N_NEIGH_PE = ${n_neigh_pe};
  // Number of supported instructions (fixed 5-bit opcode)
  localparam unsigned N_OPERATIONS = 32;
  localparam unsigned LOG_N_OPERATIONS = (N_OPERATIONS == 1) ? 1 : $clog2(N_OPERATIONS);

%if dae_cgra == 1:
  ////////////////////////////////
  //        DAE PE Groups       //
  ////////////////////////////////
  // PE groups
  localparam unsigned N_PE_GROUP = N_STREAMS;
  localparam unsigned N_PE_PER_GROUP = N_AGE_PER_STREAM;
  localparam unsigned LOG_N_PE_PER_GROUP = $clog2(N_PE_PER_GROUP);

  localparam unsigned N_IN_PEA = N_BANKS_GROUP*N_BANKS_PER_STREAM;
  localparam unsigned N_OUT_PEA = N_PE_GROUP*N_PE_PER_GROUP;
%endif

%if activation_computation == 1:
  ////////////////////////////////
  // Activation-related Params  //
  ////////////////////////////////
  localparam unsigned N_RADIX = 16;
  localparam unsigned N_DIV_STAGE = 8;
%endif

%if streaming_cgra == 1:
  ////////////////////////////////
  //      RF configuration      //
  ////////////////////////////////
  localparam unsigned RF_CFG_BITS = 5;
%endif

  ////////////////////////////////
  //   Number of PE's inputs    //
  ////////////////////////////////
%if streaming_cgra == 1:
  localparam unsigned N_INPUTS_PE = ${n_pe_in_stream + n_neigh_pe + 4};
%elif dae_cgra == 1:
  localparam unsigned N_INPUTS_PE = ${n_neigh_pe + n_pe_in_mem + 4};
%endif
  localparam unsigned LOG_N_INPUTS_PE = (N_INPUTS_PE == 1) ? 1 : $clog2(N_INPUTS_PE);
  
  ////////////////////////////////
  // PE Instruction Word Fields //
  ////////////////////////////////
  localparam unsigned OP_A_SEL_LSB       = 0;
  localparam unsigned OP_A_SEL_MSB       = LOG_N_INPUTS_PE - 1;
  localparam unsigned OP_B_SEL_LSB       = OP_A_SEL_MSB;
  localparam unsigned OP_B_SEL_MSB       = OP_B_SEL_LSB + LOG_N_INPUTS_PE - 1;
  localparam unsigned INSTR_SEL_LSB      = OP_B_SEL_MSB;
  localparam unsigned INSTR_SEL_MSB      = INSTR_SEL_LSB + LOG_N_OPERATIONS - 1;
  
  %if format_part == 1:
    localparam unsigned VEC_MODE_SEL_LSB   = INSTR_SEL_MSB;
    localparam unsigned VEC_MODE_SEL_MSB   = VEC_MODE_SEL_MSB + 2 - 1;
  %endif
  
  %if streaming_cgra == 1 and format_part == 1:
    localparam unsigned RF_SEL_LSB         = VEC_MODE_SEL_MSB;
    localparam unsigned RF_SEL_MSB         = RF_SEL_LSB + RF_CFG_BITS - 1;
  %elif streaming_cgra == 1:
    localparam unsigned RF_SEL_LSB         = INSTR_SEL_MSB;
    localparam unsigned RF_SEL_MSB         = RF_SEL_LSB + RF_CFG_BITS - 1;
  %endif
  
  %if activation_computation == 1 and streaming_cgra == 1:
    localparam unsigned DELAY_PE_SEL_LSB    = RF_SEL_MSB;
    localparam unsigned DELAY_PE_SEL_MSB    = INSTR_SEL_LSB + $clog2(N_NEIGH_PE) - 1;
    localparam unsigned DELAY_PE_OP_SEL_LSB = DELAY_PE_SEL_MSB;
    localparam unsigned DELAY_PE_OP_SEL_MSB = DELAY_PE_OP_SEL_LSB + 2 - 1;
  %elif activation_computation == 1 and format_part == 1:
    localparam unsigned DELAY_PE_SEL_LSB    = VEC_MODE_SEL_MSB;
    localparam unsigned DELAY_PE_SEL_MSB    = INSTR_SEL_LSB + $clog2(N_NEIGH_PE) - 1;
    localparam unsigned DELAY_PE_OP_SEL_LSB = DELAY_PE_SEL_MSB;
    localparam unsigned DELAY_PE_OP_SEL_MSB = DELAY_PE_OP_SEL_LSB + 2 - 1;
  %elif activation_computation == 1:
    localparam unsigned DELAY_PE_SEL_LSB    = INSTR_SEL_MSB;
    localparam unsigned DELAY_PE_SEL_MSB    = INSTR_SEL_LSB + $clog2(N_NEIGH_PE) - 1;
    localparam unsigned DELAY_PE_OP_SEL_LSB = DELAY_PE_SEL_MSB;
    localparam unsigned DELAY_PE_OP_SEL_MSB = DELAY_PE_OP_SEL_LSB + 2 - 1;
  %endif

%if dae_cgra == 1:
  ////////////////////////////////
  //Kernel Controller Parameters//
  ////////////////////////////////
  localparam unsigned NBIT_LP_P_K_E = 2;

  typedef struct packed {
    logic [NBIT_LP_P_K_E-1:0] len_e;
    logic [NBIT_LP_P_K_E-1:0] len_k;
    logic [NBIT_LP_P_K_E-1:0] len_p;
    logic [4-1:0] len_dfg;
  } loop_pipeline_info_t;
%endif

  ////////////////////////////////
  //   PE Instruction Opcodes   //
  ////////////////////////////////
%if activation_computation == 1:
  typedef enum logic[LOG_N_OPERATIONS-1:0]{
    NOP       = 5'b00000,
    ABS       = 5'b00001,
    ADD       = 5'b00010,
    SUB       = 5'b00011,
    MUL       = 5'b00100,
    LSH       = 5'b00101,
    ARSH      = 5'b00110,
    LRSH      = 5'b00111,
    MAX       = 5'b01000,
    MIN       = 5'b01001,
    DIV       = 5'b01010,
    REM       = 5'b01011,
    ACC       = 5'b01100,
    MAXS      = 5'b01101,
    SHACC     = 5'b01110,
    SGNSEL    = 5'b01111,
    ABSDIV    = 5'b10000,
    ABSMIN    = 5'b10001,
    ABSREM    = 5'b10010,
    ADDPOW    = 5'b10011,
    SUBPOW    = 5'b10100,
    SGNCSUB   = 5'b10101,
    CADDMUL   = 5'b10110,
    ADDCMUL   = 5'b10111,
    CMULADD   = 5'b11000,
    CADDDIV   = 5'b11001,
    MULCARSH  = 5'b11010,
    CLSHSUB   = 5'b11011
  } fu_instr_t;
%elif gemm_computation == 1:
  typedef enum logic[3:0]{
    NOP       = 5'b0000,
    MUL       = 5'b0001,
    SUB       = 5'b0010,
    LSH       = 5'b0011,
    LRSH      = 5'b0100,
    ARSH      = 5'b0101,
    MAX       = 5'b0110,
    MIN       = 5'b0111,
    ABS       = 5'b1000,
    ACC       = 5'b1001,
    ADD       = 5'b1010
  } fu_instr_t;
%endif

  ////////////////////////////////
  //     PE Interconnection     //
  ////////////////////////////////

  typedef enum logic [LOG_N_INPUTS_PE-1:0]{
%if  streaming_cgra == 1:
    CONSTANT   = 4'b0000,
  %for i in range(n_pe_in_stream):
    STREAM_IN${i} = 4'b${'{:04b}'.format(i+1)},
  %endfor
    UP         = 4'b${'{:04b}'.format(n_pe_in_stream+1)},
    LEFT       = 4'b${'{:04b}'.format(n_pe_in_stream+2)},
    RIGHT      = 4'b${'{:04b}'.format(n_pe_in_stream+3)},
    DOWN       = 4'b${'{:04b}'.format(n_pe_in_stream+4)},
    SELF       = 4'b${'{:04b}'.format(n_pe_in_stream+5)},
    RF         = 4'b${'{:04b}'.format(n_pe_in_stream+6)},
  %if activation_computation == 1:
    DELAY_OP   = 4'b${'{:04b}'.format(n_pe_in_stream+7)}
  %endif
%elif dae_cgra == 1:
    CONSTANT   = 4'b0000,
  %for i in range(n_pe_in_mem):
    MEM_IN_${i} = 4'b${'{:04b}'.format(i+1)},
  %endfor
    UP         = 4'b${'{:04b}'.format(n_pe_in_stream+1)},
    LEFT       = 4'b${'{:04b}'.format(n_pe_in_stream+2)},
    RIGHT      = 4'b${'{:04b}'.format(n_pe_in_stream+3)},
    DOWN       = 4'b${'{:04b}'.format(n_pe_in_stream+4)},
    SELF       = 4'b${'{:04b}'.format(n_pe_in_stream+5)},
%if activation_computation == 1:
    DELAY_OP   = 4'b${'{:04b}'.format(n_pe_in_stream+6)}
%endif
%endif
  }pe_mux_sel_t;

%if activation_computation == 1:
  typedef enum logic [$clog2(N_NEIGH_PE)-1:0] {
    D_UP      = 2'b00,
    D_LEFT    = 2'b01,
    D_RIGHT   = 2'b10,
    D_DOWN    = 2'b11
  } delay_pe_mux_sel_t;

  typedef enum logic [1:0] {
    D_PE_OP_NONE  = 2'b00,
    D_PE_RES      = 2'b01,
    D_PE_OP_A     = 2'b10,
    D_PE_OP_B     = 2'b11
  } delay_pe_op_mux_sel_t;
%endif

%if dae_cgra == 1:
  ////////////////////////////////////////////////////////////////
  //                         FSM States                         //
  ////////////////////////////////////////////////////////////////
  typedef enum logic [1:0] {
    IDLE,
    EXEC,
    DONE
  } state_t;
%endif
endpackage : pea_pkg
