// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: agu_pkg.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: Package for the address generation unit (agu)

package agu_pkg;
  //Size of each bank
  localparam unsigned BANK_SIZE = ${num_words};

  ////////////////////////////////////////////////////////////////
  //            Loop Iteration Variables parameters             //
  ////////////////////////////////////////////////////////////////

  //Maximum number of loops in loop nest
  localparam unsigned N_LP = 4;
  //Number of bits required to represent N_LP
  localparam unsigned LOG2_N_LP = $clog2(N_LP);
  //Maximum number of loop iteration variables to be used for an address generation
  localparam signed N_IVS = 4;
  //Number of bits required to represent loop iteration variables
  localparam unsigned NBIT_LP_IV = 8;
  //Number of bits required for the flat address
  localparam unsigned NBIT_FLAT_ADDR = $clog2(BANK_SIZE);


  ////////////////////////////////////////////////////////////////
  //                 Streams and AGE parameters                 //
  ////////////////////////////////////////////////////////////////
  //Total number of streams/AGEs
  localparam unsigned N_AGE_TOT = ${n_age_tot};
  //Number of streams/AGEs per stream/AGE group
  localparam unsigned N_AGE_PER_STREAM = ${n_age_per_stream};

  //Number of bits required to represent N_AGE_TOT
  localparam unsigned LOG_N_AGE_TOT = $clog2(N_AGE_TOT);
  //Log2 of Number of streams/AGEs per stream/AGE group
  localparam unsigned LOG_N_AGE_PER_STREAM = (N_AGE_PER_STREAM == 1) ? 1 : $clog2(N_AGE_PER_STREAM);
  //Number of stream/AGE groups
  localparam unsigned N_STREAMS = N_AGE_TOT / N_AGE_PER_STREAM;
  //Number of bits for blocksize in AGE configuration word
  localparam unsigned NBIT_BLOCK_SIZE = 2;
  //Number of bits required to represent the number of banks in AGE configuration word
  localparam unsigned NBIT_N_BANKS = 2;
  //Number of bits required to represent the bank from which the storage of operand begins in AGE configuration word
  localparam unsigned NBIT_START_BANK = 2;


  ////////////////////////////////////////////////////////////////
  //                      Banks parameters                      //
  ////////////////////////////////////////////////////////////////

  /*
    The number of banks per group and groups is the same as for the AGEs
  */

  //Number of banks per stream/AGE group
  localparam unsigned N_BANKS_PER_STREAM = N_AGE_PER_STREAM;
  //Number of bits required to represent N_BANKS_PER_STREAM
  localparam unsigned LOG_N_BANKS_PER_STREAM = (N_BANKS_PER_STREAM == 1) ? 1 : $clog2(N_BANKS_PER_STREAM);
  //Total number of banks
  localparam unsigned N_BANKS = N_STREAMS * N_BANKS_PER_STREAM;
  //number of bank groups
  localparam unsigned N_BANKS_GROUP = N_STREAMS;
  //Number of bits required to represent the address of a bank
  localparam unsigned NBIT_ADDR = $clog2(BANK_SIZE);

  ////////////////////////////////////////////////////////////////
  //                      HWLP parameters                       //
  ////////////////////////////////////////////////////////////////
  //Size of HWLP Register File
  localparam unsigned HWLP_RF_SIZE = 16;
  //Number of bits required to represent HWLP_RF_SIZE
  localparam unsigned LOG2_HWLP_RF_SIZE = $clog2(HWLP_RF_SIZE);
  //Number of bits required to represent the Initiation Interval
  localparam unsigned NBIT_II = 4;

  ////////////////////////////////////////////////////////////////
  //          Stream/AGE Instruction Memory parameters          //
  ////////////////////////////////////////////////////////////////
  //Size of the instruction memory
  localparam unsigned ACC_CFGMEM_SIZE = ${kernel_len};
  //Number of bits required to address the instruction memory
  % if kernel_len > 1:
  localparam unsigned LOG2_ACC_CFGMEM_SIZE = $clog2(ACC_CFGMEM_SIZE);
  % else:
  localparam unsigned LOG2_ACC_CFGMEM_SIZE = 1;
  % endif

  ////////////////////////////////////////////////////////////////
  //                     Stream Instruction                     //
  ////////////////////////////////////////////////////////////////
  typedef struct packed {
    /* IV-related */

    //selection of HWLP Register File entry in which the loop iteration variables are stored
    logic [LOG2_HWLP_RF_SIZE-1:0] hwlp_rf_sel;
    //selection signals for the constraints to the iteration variables
    logic [LOG2_N_LP-1+1:0] iv_constraint_sel;

    /* banks-related */
    //number of banks in which the operand is stored
    logic [NBIT_N_BANKS-1:0] n_banks;
    //Bank from which the storage of operand begins
    logic [NBIT_START_BANK-1:0] bank_start;
    //block size
    logic [NBIT_BLOCK_SIZE-1:0] block_size;
    //stream is load or a store
    logic lns;
    //'1' if the stream is a store of an accumulation
    logic is_acc_store;

    /* full data */
    //constant of the subscript
    logic [NBIT_LP_IV-1:0] iv_const;
    //iv constraint value
    logic [NBIT_LP_IV-1:0] iv_constraint;

    /* valid bit */
    logic valid;
  } stream_inst_t;

  ////////////////////////////////////////////////////////////////
  //           Stream Instruction utility parameters            //
  ////////////////////////////////////////////////////////////////

  typedef struct packed {
    logic [NBIT_LP_IV-1:0] iv;
    logic [NBIT_LP_IV-1:0] fv;
    logic [NBIT_LP_IV-1:0] inc;
  } loop_vars_t;

  localparam unsigned HWLP_RF_MSB = LOG2_HWLP_RF_SIZE - 1;
  localparam unsigned HWLP_RF_LSB = 0; 

  localparam unsigned IV_CONSTR_MSB = IV_CONSTR_LSB + LOG2_N_LP;
  localparam unsigned IV_CONSTR_LSB = HWLP_RF_MSB + 1; 

  localparam unsigned N_BANKS_MSB = N_BANKS_LSB + NBIT_N_BANKS - 1;
  localparam unsigned N_BANKS_LSB = IV_CONSTR_MSB + 1; 

  localparam unsigned BANK_START_MSB = BANK_START_LSB + NBIT_START_BANK - 1;
  localparam unsigned BANK_START_LSB = BANK_START_MSB + 1; 

  localparam unsigned BLOCK_SIZE_MSB = BLOCK_SIZE_LSB + NBIT_BLOCK_SIZE - 1;
  localparam unsigned BLOCK_SIZE_LSB = BANK_START_MSB + 1; 

  localparam unsigned LNS_MSB = LNS_LSB + 1 - 1;
  localparam unsigned LNS_LSB = BLOCK_SIZE_LSB + 1;

  localparam unsigned IS_ACC_STORE_MSB = IS_ACC_STORE_LSB + 1 - 1;
  localparam unsigned IS_ACC_STORE_LSB = LNS_MSB + 1; 

  localparam unsigned IV_CONST_MSB = IV_CONST_LSB + NBIT_LP_IV - 1;
  localparam unsigned IV_CONST_LSB = IS_ACC_STORE_MSB + 1; 

  localparam unsigned IV_CONSTRAINT_MSB = IV_CONSTRAINT_LSB + NBIT_LP_IV - 1;
  localparam unsigned IV_CONSTRAINT_LSB = IV_CONST_MSB + 1; 

  localparam unsigned VALID_MSB = VALID_LSB + 1 - 1;
  localparam unsigned VALID_LSB = IV_CONSTRAINT_MSB + 1;    

endpackage : agu_pkg
