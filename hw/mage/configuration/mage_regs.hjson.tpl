{ name: "mage",
  clock_primary: "clk_i",
  bus_interfaces: [
    { protocol: "reg_iface", direction: "device" }
  ],
  registers: [
%if dae_cgra == 1:
    { name:     "STATUS",
      desc:     "MAGE-CGRA status",
      swaccess: "rw",
      hwaccess: "hrw",
      resval:   0,
      fields: [
        { bits: "0", 
          name: "START",
          desc: "Start for computation" 
        },
        { bits: "1", 
          name: "DONE",
          desc: "It signals that the computation is finished" 
        },
      ]
    },
    { name:     "GEN_CFG",
      desc:     "General Configuration Bits",
      swaccess: "rw",
      hwaccess: "hro",
      resval:   0,
      fields: [
        { bits: "3:0", 
          name: "II",
          desc: "Initiation interval" 
        },
        { bits: "4:4", 
          name: "S_N_T_AGU",
          desc: "Static/Time-Multiplexed configuration for MAGE" 
        },
        { bits: "5:5", 
          name: "S_N_T_PEA",
          desc: "Static/Time-Multiplexed configuration for MAGE-CGRA" 
        },
        { bits: "6:6", 
          name: "S_N_T_PEA_SEL_OUT_REGS",
          desc: "Static/Time-Multiplexed configuration for MAGE-CGRA" 
        },
        { bits: "7:7", 
          name: "S_N_T_LOAD_STREAM",
          desc: "Static/Time-Multiplexed configuration for MAGE-CGRA" 
        },
        { bits: "8:8", 
          name: "S_N_T_STREAM_STREAM",
          desc: "Static/Time-Multiplexed configuration for MAGE-CGRA" 
        },
%if format_part == 1:
        { bits: "12:9", 
          name: "ACC_VEC_MODE",
          desc: "Vector mode for accumulation" 
        }
%endif
      ]
    },
    { name:     "ILB_HWL",
      desc:     "Initial Loop Bounds for Hardware Loops",
      swaccess: "rw",
      hwaccess: "hro",
      resval:   0,
      fields: [
        { bits: "7:0", 
          name: "ILB_0",
          desc: "Initial Loop Bound for loop 0" 
        },
        { bits: "15:8", 
          name: "ILB_1",
          desc: "Initial Loop Bound for loop 1" 
        },
        { bits: "23:16", 
          name: "ILB_2",
          desc: "Initial Loop Bound for loop 2" 
        },
        { bits: "31:24", 
          name: "ILB_3",
          desc: "Initial Loop Bound for loop 3" 
        },
      ]
    },
    { name:     "FLB_HWL",
      desc:     "Final Loop Bounds for Hardware Loops",
      swaccess: "rw",
      hwaccess: "hro",
      resval:   0,
      fields: [
        { bits: "7:0", 
          name: "FLB_0",
          desc: "Final Loop Bound for loop 0" 
        },
        { bits: "15:8", 
          name: "FLB_1",
          desc: "Final Loop Bound for loop 1" 
        },
        { bits: "23:16", 
          name: "FLB_2",
          desc: "Final Loop Bound for loop 2" 
        },
        { bits: "31:24", 
          name: "FLB_3",
          desc: "Final Loop Bound for loop 3" 
        },
      ]
    },
    { name:     "INC_HWL",
      desc:     "Increments for Hardware Loops",
      swaccess: "rw",
      hwaccess: "hro",
      resval:   0,
      fields: [
        { bits: "7:0", 
          name: "INC_0",
          desc: "Increment for loop 0" 
        },
        { bits: "15:8", 
          name: "INC_1",
          desc: "Increment for loop 1" 
        },
        { bits: "23:16", 
          name: "INC_2",
          desc: "Increment for loop 2" 
        },
        { bits: "31:24", 
          name: "INC_3",
          desc: "Increment for loop 3" 
        },
      ]
    },
    { name:     "PEA_CONTROL_SNT",
      desc:     "Each bit controls the control mode of each pe, static or time-multiplexed",
      swaccess: "rw",
      hwaccess: "hro",
      resval:   0,
      fields: [
        { bits: "31:0"
        }
      ]
    },
    { multireg:
        { name: "STRIDES",
        desc: "Configuration for AGEs strides",
        count : "${n_age_tot}",
        cname: "STRIDES",
        swaccess: "rw",
        hwaccess: "hro",
        fields: [
        { bits: "7:0", 
          name: "S0",
          desc: "Stride 0" 
        },
        { bits: "15:8", 
          name: "S1",
          desc: "Stride 1" 
        },
        { bits: "23:16", 
          name: "S2",
          desc: "Stride 2" 
        },
        { bits: "31:24", 
          name: "S3",
          desc: "Stride 3" 
        },
        ],
        }
    },
    { name:     "PKE",
      desc:     "Length of Prologue, Kernel and Epilogue execution stage, and number of times for Kernel to be repeated",
      swaccess: "rw",
      hwaccess: "hro",
      resval:   0,
      fields: [
        { bits: "3:0", 
          name: "LEN_P",
          desc: "Length of Prologue execution stage" 
        },
        { bits: "7:4", 
          name: "LEN_K",
          desc: "Length of Kernel execution stage" 
        },
        { bits: "11:8", 
          name: "LEN_E",
          desc: "Length of Epilogue execution stage" 
        },
        { bits: "15:12", 
          name: "LEN_DFG",
          desc: "Lenght of DFG" 
        }
      ]
    },
%endif
  <%import math as m%>
%for r in range(n_pea_rows):
    %for c in range(n_pea_cols):
    { multireg:
        { name: "CFG_PE_${r}${c}",
        desc: "Configuration for MAGE-CGRA PE 00",
        count : "${m.ceil(kernel_len)}",
        cname: "PE_${r}${c}",
        swaccess: "rw",
        hwaccess: "hro",
        fields: [
        { bits: "31:0"
        }
        ],
        }
    },
    %endfor
%endfor
%if dae_cgra == 1:
<%import math as m%>
    { multireg:
        { name: "SEL_OUT_PEA",
        desc: "Selection signals for output of MAGE-CGRA PEA",
        count: "${m.ceil(((2*n_pea_rows*m.log2(n_pea_cols))*kernel_len)/32)}",
        cname: "ISOP",
        swaccess: "rw",
        hwaccess: "hro",
        fields: [
        { bits: "31:0"
        }
        ],
        }
    }, 
    { multireg:
        { name: "L_STREAM_SEL_AGE",
        desc: "Selection signals for load streams",
        count: "${int(m.ceil(((n_age_tot*m.log2(n_age_per_stream))*kernel_len)/32))}",
        cname: "SSS",
        swaccess: "rw",
        hwaccess: "hro",
        fields: [
        { bits: "31:0"
        }
        ],
        }
    },
    { multireg:
        { name: "S_STREAM_SEL_AGE",
        desc: "Selection signals for store streams",
        count: "${int(m.ceil(((n_age_tot*m.log2(n_age_per_stream))*kernel_len)/32))}",
        cname: "LSS",
        swaccess: "rw",
        hwaccess: "hro",
        fields: [
        { bits: "31:0"
        }
        ],
        }
    },
  %for s in range(int(n_age_tot/n_age_per_stream)):
    %for a in range(n_age_per_stream):
    { multireg:
        { name: "CFG_MAGE_S${s}_AGE${a}",
        desc: "Configuration for AGE ${a} of Stream ${s}",
        count : "${kernel_len}",
        cname: "IM",
        swaccess: "rw",
        hwaccess: "hro",
        fields: [
        { bits: "31:0", 
          name: "AGE_INST",
          desc: "Instruction for AGE ${a} of Stream ${s}" 
        },
        ],
        }
    },
    %endfor
  %endfor
%endif
    { multireg:
        { name: "PEA_CONSTANTS",
        desc: "PEs constants",
        count : "${n_pea_rows*n_pea_cols}",
        cname: "PEA_CONSTANTS",
        swaccess: "rw",
        hwaccess: "hro",
        fields: [
        { bits: "31:0", 
          name: "CONSTANT",
          desc: "Constant for PE" 
        },
        ],
        }
    },
    { multireg:
        { name: "PEA_RF",
        desc: "PEs RF",
        count : "${n_pea_rows*n_pea_cols}",
        cname: "PEA_CONSTANTS",
        swaccess: "rw",
        hwaccess: "hrw",
        fields: [
        { bits: "31:0", 
          name: "CONSTANT",
          desc: "Constant for PE" 
        },
        ],
        }
    },
%if dae_cgra == 1:
    { multireg:
        { name: "AGE_STRIDES",
        desc: "Configuration for AGE IV constraints",
        count : "${int(n_age_tot/4)}",
        cname: "AGE_STRIDES",
        swaccess: "rw",
        hwaccess: "hro",
        fields: [
        { bits: "7:0", 
          name: "C0",
          desc: "Constraint 0" 
        },
        { bits: "15:8", 
          name: "C1",
          desc: "Constraint 1" 
        },
        { bits: "23:16", 
          name: "C2",
          desc: "Constraint 2" 
        },
        { bits: "31:24", 
          name: "C3",
          desc: "Constraint 3" 
        },
        ],
        }
    },
%endif
%if streaming_cgra == 1:
  %for i in range(n_dma_ch):
    { name: "TRANS_SIZE_DMA_CH_${i}",
      desc: "Transaction size for DMA channel ${i}. It indicates the number of elements to be read or written by that dma channel. Once the associated down-counter reaches zero, the DMA channel is will receive a done signal",
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
      { bits: "31:0"
      }
      ],
    },
    { name: "TRANS_SIZE_SYNC_DMA_CH_${i}",
      desc: "Transaction size for DMA channel ${i} useful to sync with another DMA channel. When the associated down-counter reaches zero, the other DMA channel will be informed that it can operate. This is useful to let one DMA channel be dependent on a transaction window of another channel.",
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
      { bits: "15:0"
      }
      ],
    },
  %endfor
    { name: "RF_VAL",
      desc: "RF Counter final value",
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
      { bits: "1:0",
      },
      ],
    },
    { name: "DMA_RNW",
      desc: "If set to 1, the downcounter for DMA i downcounts each time a data is pushed to the read fifo, otherwise the downcount is based on the write fifo push",
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
      { bits: "${n_dma_ch-1}:0"
      },
      ],
    },
    { name: "COLS_GROUPING",
      desc: "If set to 1, each column of Mage works in streaming separately from all the others. If 2, columns are grouped in 2 groups of 2 each. If 0, all columns are grouped together.",
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
      { bits: "1:0",
      },
      ],
    },
    { name: "SYNC_DMA_CH_TRANS",
      desc: "It makes the related DMA channel (bit 0 -> dma ch 0) work in sync with its stream mate in pea_in_stream_placement based on TRANS_SIZE_SYNC_DMA_CH_{i}. If bit 0 is set to 1, DMA ch 0 will be syncronized to its stream mate based on TRANS_SIZE_SYNC_DMA_CH_{mate}",  
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
      { bits: "${2*n_dma_ch-1}:0",
      },
      ],
    },
  %if in_stream_xbar == 1:
    { name: "STREAM_IN_XBAR_SEL",
      desc: "Selection signals for input stream crossbars",
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
    %for i in range(int(n_in_stream*n_dma_ch_per_in_stream)):
      { bits: "${2*i+1}:${2*i}", 
        name: "SEL_IN_XBAR_${i}",
        desc: "Selection signals for output stream crossbar" 
      },
    %endfor
      ],
    },
  %endif
  %if out_stream_xbar == 1:
    { name: "STREAM_OUT_XBAR_SEL",
      desc: "Selection signals for output stream crossbars",
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
    %for i in range(int(n_out_stream*n_dma_ch_per_out_stream)):
      { bits: "${2*i+1}:${2*i}", 
        name: "SEL_OUT_XBAR_${i}",
        desc: "Selection signals for output stream crossbar" 
      },
    %endfor
      ],
    },
  %endif
    { multireg:
      { name: "SEL_OUT_COL_PEA",
      desc: "Selection signals for output of PEA Column",
      count : "${m.ceil((int(m.ceil(m.log2(n_pea_cols)))*n_pea_rows)/32)}",
      cname: "SEL_OUT_COL_PEA",
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
  %for i in range(n_pea_cols):
      { bits: "${4*i+3}:${4*i}", 
        name: "SEL_COL_${i}",
        desc: "Selection signals for column ${i} output" 
      },
  %endfor
      ],
      }
    },
    { multireg:
      { name: "ACC_VALUE",
      desc: "Accumulation Value for PEs",
      count : "${n_pea_cols*n_pea_rows}",
      cname: "ACC_VALUE_PE",
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
      { bits: "15:0", 
        name: "ACC",
        desc: "Accumulation value" 
      },
      ],
      }
    },
%endif   
  ]
}