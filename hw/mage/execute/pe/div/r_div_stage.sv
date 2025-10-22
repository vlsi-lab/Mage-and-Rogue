// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: r_div_stage.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: Restoring Multicycle Divider Stage

module r_div_stage
  import pea_pkg::*;
(
    input logic [$clog2(N_RADIX)-1:0] n_i,
    input logic [N_BITS-1:0] d_i,
    input logic [N_BITS-1:0] r_i,
    output logic [N_BITS-1:0] r_o,
    output logic [$clog2(N_RADIX)-1:0] q_o
);

  logic [$clog2(N_RADIX)-1:0][N_BITS-1:0] r_in;
  logic [$clog2(N_RADIX)-1:0][N_BITS-1:0] r_out;
  logic [$clog2(N_RADIX)-1:0] q_out;

  always_comb begin
    for (int i = 0; i < $clog2(N_RADIX); i++) begin
      if (i == 0) begin
        r_in[i][N_BITS-1:1] = r_i[N_BITS-2:0];
        r_in[i][0] = n_i[$clog2(N_RADIX)-1];
      end else begin
        r_in[i][N_BITS-1:1] = r_out[i-1][N_BITS-2:0];
        r_in[i][0] = n_i[$clog2(N_RADIX)-1-i];
      end
    end
  end

  genvar i;
  generate
    for (i = 0; i < $clog2(N_RADIX); i++) begin
      r_div_cell r_div_cell_inst (
          .n_i(r_in[i]),
          .d_i(d_i),
          .r_o(r_out[i]),
          .q_o(q_out[i])
      );
    end
  endgenerate

  assign r_o = r_out[$clog2(N_RADIX)-1];

  genvar j;
  generate
    for (j = 0; j < $clog2(N_RADIX); j++) begin
      assign q_o[j] = q_out[$clog2(N_RADIX)-1-j];
    end
  endgenerate

endmodule
