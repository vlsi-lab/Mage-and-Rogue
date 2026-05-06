#!/usr/bin/env python3

# Copyright 2020 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

#Simplified version of occamygen.py https://github.com/pulp-platform/snitch/blob/master/util/occamygen.py

import argparse
import hjson
import pathlib
import sys
import re
import logging
from subprocess import run
import csv
from jsonref import JsonRef
from mako.template import Template
import collections
from math import log2
import math

# Compile a regex to trim trailing whitespaces on lines.
re_trailws = re.compile(r'[ \t\r]+$', re.MULTILINE)

def string2int(hex_json_string):
    return (hex_json_string.split('x')[1]).split(',')[0]

def write_template(tpl_path, outdir, outfile, **kwargs):
    if tpl_path:
        tpl_path = pathlib.Path(tpl_path).absolute()
        if tpl_path.exists():
            tpl = Template(filename=str(tpl_path))
            if outfile == None:
                filename = outdir / tpl_path.with_suffix("").name
            else:
                filename = outfile
            with open(filename, "w") as file:
                code = tpl.render_unicode(**kwargs)
                code = re_trailws.sub("", code)
                file.write(code)
        else:
            raise FileNotFoundError

def main():

    # It describes how input dma nodes are organized
    # i.e. The elements at position 0 (0) indicates the dma channels connected to fifo 0
    # has to be [N_IN_STREAM[N_DMA_CH_PER_IN_STREAM]]
    #in_stream_dma_ch_placement = [[0], [1], [2], [3]];
    
    # It indicates which PEA columns outputs are to be connected to each output dma node
    # i.e. The elements at position 0 (0, 1) are PEA columns connected to dma channel 0 output 
    # has to be [N_OUT_STREAM[N_PEA_DOUT_PER_OUT_STREAM]]
    #out_stream_pea_dout_placement = [[0, 1], [0, 1], [2, 3], [2, 3]];

    # It describes how PEA inputs coming from DMA must be organized
    # i.e. The elements at position 0 (0, 1) indicates the dma channels that are connected to PEA column 0
    # has to be [N_PEA_COL[N_PE_IN_STREAM]]
    #pea_in_stream_placement = [[0, 1], [1, 0], [2, 3], [3, 2]];

    # has to be [N_PEA_COL][N_IN_MEM]?
    #pea_in_mem_placement = [[0, 1, 4, 5], [0, 1, 4, 5], [2, 3, 6, 7], [2, 3, 6, 7]];

    parser = argparse.ArgumentParser(prog="mage-gen")
    
    parser.add_argument("--config",
                        metavar="file",
                        type=str,
                        required=False,
                        help="X-Heep general configuration")

    parser.add_argument("--outdir",
                        "-of",
                        type=pathlib.Path,
                        required=True,
                        help="Target directory.")

    parser.add_argument("--outfile",
                        "-o",
                        type=pathlib.Path,
                        required=False,
                        help="Target filename, if omitted the template basename is taken.")

    # Parse arguments
    parser.add_argument("--num_words",
                        metavar="",
                        nargs='?',
                        default="1024",
                        help="")

    parser.add_argument("--pkg-sv",
                        metavar="PKG_SV",
                        help="Name of top-level package file (output)")

    parser.add_argument("--tpl-sv",
                        metavar="TPL_SV",
                        help="Name of SystemVerilog template for your module (output)")

    
    parser.add_argument(
        "--mage_cfg",
        "-c",
        metavar="FILE",
        type=argparse.FileType("r"),
        required=True,
        help="Configuration file in HJSON format",
    )
    

    args = parser.parse_args()

    if not args.outdir.is_dir():
            exit("Out directory is not a valid path.")

    outdir = args.outdir
    outdir.mkdir(parents=True, exist_ok=True)

    outfile = args.outfile

    # Read HJSON configuration file
    with args.mage_cfg as f:
        try:
            cfg = hjson.load(f, use_decimal=True)
            cfg = JsonRef.replace_refs(cfg)
        except ValueError as exc:
            raise SystemExit(sys.exc_info()[1]) from exc


    kwargs = {
        "dae_cgra"                         : cfg['dae_cgra'],
        "streaming_cgra"                   : cfg['streaming_cgra'],
        
        "format_full"                      : cfg['format_full'],
        "format_part"                      : cfg['format_part'],
        
        "gemm_computation"                 : cfg['gemm_computation'],
        "activation_computation"           : cfg['activation_computation'],
        
        "n_pea_rows"                       : cfg['common_params']['n_pea_rows'],
        "n_pea_cols"                       : cfg['common_params']['n_pea_cols'],
        "n_neigh_pe"                       : cfg['common_params']['n_neigh_pe'],
        "pattern_neigh_pe"                 : cfg['common_params']['pattern_neigh_pe'],

        "kernel_len"                       : cfg['dae_params']['kernel_len'],
        "n_pe_in_mem"                      : cfg['dae_params']['n_pe_in_mem'],
        "n_streams"                        : cfg['dae_params']['n_streams'],
        "pea_in_mem_placement"             : cfg['dae_params']['pea_in_mem_placement'],
        "n_age_per_stream_ds"              : cfg['dae_params']['n_age_per_stream_ds'],
        "n_age_tot"                        : cfg['dae_params']['n_age_tot'],
        "n_age_per_stream"                 : cfg['dae_params']['n_age_per_stream'],
        "num_words"                        : cfg['dae_params']['num_words'],
        "acc_pes"                          : cfg['dae_params']['acc_pes'],

        "n_pe_in_stream"                   : cfg['streaming_params']['n_pe_in_stream'],
        "r_fifo_synch_placement_g2"        : cfg['streaming_params']['r_fifo_synch_placement_g2'],
        "r_fifo_synch_placement_g3"        : cfg['streaming_params']['r_fifo_synch_placement_g3'],
        "r_fifo_synch_placement_g4"        : cfg['streaming_params']['r_fifo_synch_placement_g4'],
        "r_fifo_synch_placement_type"      : cfg['streaming_params']['r_fifo_synch_placement_type'],
        "pea_in_stream_placement"          : cfg['streaming_params']['pea_in_stream_placement'],
        "n_dma_ch"                         : cfg['streaming_params']['n_dma_ch'],
        "n_in_stream"                      : cfg['streaming_params']['n_in_stream'],
        "n_dma_ch_per_in_stream"           : cfg['streaming_params']['n_dma_ch_per_in_stream'],
        "n_pea_din_per_in_stream"          : cfg['streaming_params']['n_pea_din_per_in_stream'],
        "n_out_stream"                     : cfg['streaming_params']['n_out_stream'],
        "n_pea_dout_per_out_stream"        : cfg['streaming_params']['n_pea_dout_per_out_stream'],
        "n_dma_ch_per_out_stream"          : cfg['streaming_params']['n_dma_ch_per_out_stream'],
        "in_stream_xbar"                   : cfg['streaming_params']['in_stream_xbar'],
        "out_stream_xbar"                  : cfg['streaming_params']['out_stream_xbar'],
        "div_pes"                          : cfg['streaming_params']['div_pes'],
        "part_add_pes"                     : cfg['streaming_params']['part_add_pes'],
        "part_mul_pes"                     : cfg['streaming_params']['part_mul_pes'],
        "is_div_pipe"                      : cfg['streaming_params']['is_div_pipe'],
        "in_stream_dma_ch_placement"       : cfg['streaming_params']['in_stream_dma_ch_placement'],
        "out_stream_pea_dout_placement"    : cfg['streaming_params']['out_stream_pea_dout_placement'],
    }

    ###########
    #   TPL   #
    ###########
    #if args.pkg_sv != None:
        #write_template(args.pkg_sv, outdir, outfile, **kwargs)

    if args.tpl_sv != None:
        write_template(args.tpl_sv, outdir, outfile, **kwargs)

if __name__ == "__main__":
    main()
