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
  localparam unsigned N_CFG_REGS_SEL_OUT_PEA = ${m.ceil(((2*n_pea_rows*m.log2(n_pea_cols))*kernel_len)/32)};

endpackage
