#ifndef _MAGE_PARAMS_H_
#define _MAGE_PARAMS_H_

#include <stdint.h>

#include "mage_regs.h"

#define MAGE_PARTITIONED 0

// kernel memory size
#define KMEM_SIZE 1
// number of rows and columns of the PEA array
#define MAGE_PEA_ROWS 2
#define MAGE_PEA_COLS 2

////////////////////////////////////////////////////////////////
//                          DAE Mage                          //
////////////////////////////////////////////////////////////////
// number of hardware loops
#define MAGE_NUM_HWLP 4
// number of streams
#define MAGE_N_STREAMS 2
// number of ages per stream
#define MAGE_N_AGE_PER_STREAM 2
// number of total age
#define MAGE_N_AGES 4
// number of 32-bit registers used to store the selectors for the output of PEA rows
#define SEL_OUT_PEA_SIZE MAGE_SEL_OUT_PEA_MULTIREG_COUNT
// number of 32-bit registers used to store the configuration of load streams
#define LOAD_STREAM_SIZE MAGE_L_STREAM_SEL_AGE_MULTIREG_COUNT
// number of 32-bit registers used to store the configuration of store streams
#define STORE_STREAM_SIZE MAGE_S_STREAM_SEL_AGE_MULTIREG_COUNT

#ifdef __cplusplus
}
#endif

#endif // MAGE_PARAMS_H_