// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: xbar_pkg.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: Package for crossbars

package xbar_pkg;
  import agu_pkg::*;
  import pea_pkg::*;
  <%import math as m%>
  localparam unsigned N_CFG_REGS_LOAD_STREAM = ${int(m.ceil(((n_age_tot*m.log2(n_age_per_stream))*kernel_len)/32))};
  localparam unsigned N_CFG_REGS_STORE_STREAM = ${int(m.ceil(((n_age_tot*m.log2(n_age_per_stream))*kernel_len)/32))};

  // Number of 32-bit configuration registers for storing output pea selectors: (N_ROWS * log2(N_COLS))/32
  localparam unsigned N_CFG_REGS_SEL_OUT_PEA = 2;

  // These define the modularity of the xbar.
  // If set to 2, the xbar will have 2-to-1 muxes.
  // If set to 4, the xbar will have 4-to-1 muxes.
  localparam unsigned N_BANKS_PER_BB = ${n_age_per_stream};
  localparam unsigned N_PE_PER_BB = ${n_age_per_stream};
  // Log2 of number of banks per basic block
  localparam unsigned LOG_N_BANKS_PER_BB = $clog2(N_BANKS_PER_BB);
  // Log2 of number of PEs per basic block
  localparam unsigned LOG_N_PE_PER_BB = $clog2(N_PE_PER_BB);
  // Number of pipeline stages in banks <-> pea xbar
  // N_BANKS_PER_STREAM = N_PE_PER_GROUP and N_BANKS_PER_BB = N_PE_PER_BB
  localparam unsigned N_PIPE_STAGE_BANKS_PEA = $clog2(N_BANKS_PER_STREAM) / $clog2(N_BANKS_PER_BB);
  // Number of xbar basic blocks for each stage
  localparam unsigned N_BB_BANKS_PEA_STG_0 = N_BANKS_PER_STREAM / N_BANKS_PER_BB;
  localparam unsigned N_BB_BANKS_PEA_STG_1 = N_BANKS_PER_STREAM / (2 * N_BANKS_PER_BB);
  localparam unsigned N_BB_BANKS_PEA_STG_2 = N_BANKS_PER_STREAM / (4 * N_BANKS_PER_BB);

endpackage
