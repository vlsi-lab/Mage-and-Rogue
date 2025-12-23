#ifndef _MAGE_PARAMS_H_
#define _MAGE_PARAMS_H_

#include <stdint.h>

#include "mage_regs.h"

%if format_full == 1:
#define MAGE_PARTITIONED 0
%else:
#define MAGE_PARTITIONED 1
%endif

// kernel memory size
#define KMEM_SIZE ${kernel_len}
// number of rows and columns of the PEA array
#define MAGE_PEA_ROWS ${n_pea_rows}
#define MAGE_PEA_COLS ${n_pea_cols}

%if dae_cgra == 1:
////////////////////////////////////////////////////////////////
//                            Mage                            //
////////////////////////////////////////////////////////////////
// number of hardware loops
#define MAGE_NUM_HWLP 4
// number of streams
#define MAGE_N_STREAMS ${int(n_age_tot/n_age_per_stream)}
// number of ages per stream
#define MAGE_N_AGE_PER_STREAM ${n_age_per_stream}
// number of total age
#define MAGE_N_AGES ${n_age_tot}
// number of 32-bit registers used to store the selectors for the output of PEA rows
#define SEL_OUT_PEA_SIZE MAGE_SEL_OUT_PEA_MULTIREG_COUNT
// number of 32-bit registers used to store the configuration of load streams
#define LOAD_STREAM_SIZE MAGE_L_STREAM_SEL_AGE_MULTIREG_COUNT
// number of 32-bit registers used to store the configuration of store streams
#define STORE_STREAM_SIZE MAGE_S_STREAM_SEL_AGE_MULTIREG_COUNT
%endif

%if streaming_cgra == 1:
////////////////////////////////////////////////////////////////
//                           Rogue                            //
////////////////////////////////////////////////////////////////

%if n_pea_rows == 2:
    %if n_pea_cols == 2:
#define ROGUE_2x2_2x2 1
    %elif n_pea_cols == 4:
        %if r_fifo_synch_placement_type == "g2":
#define ROGUE_2x4_2x2 1
        %elif r_fifo_synch_placement_type == "g4":
#define ROGUE_2x4_4x4 1
        %endif
    %endif
%elif n_pea_rows == 4:
    %if n_pea_cols == 2:
#define ROGUE_4x2_2x2 1
    %elif n_pea_cols == 4:
        %if r_fifo_synch_placement_type == "g2":
#define ROGUE_4x4_2x2 1
        %elif r_fifo_synch_placement_type == "g4":
#define ROGUE_4x4_4x4 1
        %endif
    %endif
%endif


%endif
#ifdef __cplusplus
}
#endif

#endif // MAGE_PARAMS_H_