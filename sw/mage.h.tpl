#ifndef _MAGE_H_
#define _MAGE_H_

#include <stdint.h>

#include "mage_regs.h"

// kernel memory size
#define KMEM_SIZE ${kernel_len}
// number of rows and columns of the PEA array
#define MAGE_PEA_ROWS ${n_pea_rows}
#define MAGE_PEA_COLS ${n_pea_cols}

%if dae_cgra == 1:
////////////////////////////////////////////////////////////////
//                                                            //
//                          DAE Mage                          //
//                                                            //
////////////////////////////////////////////////////////////////
// number of hardware loops
#define MAGE_NUM_HWLP 4
// number of streams
#define MAGE_N_STREAMS ${n_age_tot/n_age_per_stream}
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
//                                                            //
//                       Streaming Mage                       //
//                                                            //
////////////////////////////////////////////////////////////////
// number of 32-bit registers used to store PE accumulation values
#define PEA_ACC_VALUES_SIZE ${n_pea_rows}
%endif

#ifdef __cplusplus
extern "C"
{
#endif

static inline void write_mage_register(uint32_t p_val, uint32_t p_addr, uint32_t p_mask, uint8_t p_sel);


/**
 * @brief Sets the PEA configuration.
 * 
 * @param mage_pea_cfg The PEA configuration array that contains the configuration for each PE.
 */
void mage_set_pea_cfg(uint32_t mage_pea_cfg[MAGE_PEA_ROWS][MAGE_PEA_COLS][KMEM_SIZE]);

/**
 * @brief Sets the configuration for a specific PE.
 * 
 * @param pe_cfg The PE configuration value.
 * @param pe_row The row index of the PE.
 * @param pe_col The column index of the PE.
 * @param time The time instant for configuration pe_cfg.
 */
void mage_set_pe_cfg(uint32_t pe_cfg, uint8_t pe_row, uint8_t pe_col, uint8_t time);

/**
 * @brief Sets the constants for each PE.
 * 
 * @param pea_constants The PEA constants array.
 */
void mage_set_pea_constants(uint32_t pea_constants[MAGE_PEA_ROWS][MAGE_PEA_COLS]);

/**
 * @brief Sets a specific constant for a PE.
 * 
 * @param pea_constant The constant value.
 * @param reg The register index.
 */
void mage_set_pe_constant(uint32_t pea_constant, uint8_t row, uint8_t col);

%if dae_cgra == 1:
////////////////////////////////////////////////////////////////
//                                                            //
//                          DAE Mage                          //
//                                                            //
////////////////////////////////////////////////////////////////

/**
 * @brief Starts Mage.
 */
void mage_start();

/**
 * @brief Checks if Mage has finished its operation.
 * 
 * @return uint32_t Returns 1 if finished, 0 otherwise.
 */
uint32_t is_mage_finished();

/**
 * @brief Sets the Iteration Interval (II).
 * 
 * @param ii The II to set.
 */
void mage_set_ii(uint8_t ii);

/**
 * @brief Sets Static/Time-multiplexed mode for AGE-PEA-OutSelectors-Xbars (from LSBs to MSBs)
 * 
 * @param snt The 4 bits to set the mode for the 4 components.
 */
void mage_set_snt(uint32_t snt);

/**
 * @brief Sets information related to accumulationmode.
 * 
 * @param mode Vector mode for the accumulation (8, 16, 32 bits)
 */
void mage_set_acc_mode(uint32_t mode);

/**
 * @brief Sets the blocksize for the address map of Mage SpM.
 * 
 * @param blocksize The blocksize to set.
 */
void mage_set_address_map_blocksize(uint32_t blocksize);

/**
 * @brief Sets the general configuration bits for Mage.
 * 
 * @param cfg_bits The configuration bits to set.
 */
void mage_set_general_cfg_bits(uint32_t cfg_bits);

/**
 * @brief Sets each PE control mode (static or time-multiplexed).
 * 
 * @param pea_control_snt The PEA control mode. Each bit sets the mode of a PE in row-major order.
 */
void mage_set_pea_control_snt(uint32_t pea_control_snt);

/**
 * @brief Sets the Initial Loop Bounds (ILB) value for the Hardware Loops.
 * 
 * @param ilb The ILB value to set. Each 8 bits correspond to the ILB value for a different loop from the inner one.
 */
void mage_set_ilb(uint8_t ilb[MAGE_NUM_HWLP]);

/**
 * @brief Sets the Final Loop Bounds (FLB) value for the Hardware Loops.
 * 
 * @param ilb The FLB value to set. Each 8 bits correspond to the ILB value for a different loop from the inner one.
 */
void mage_set_flb(uint8_t flb[MAGE_NUM_HWLP]);


/**
 * @brief Sets the increment values for the Hardware Loops.
 * 
 * @param li The increment values to set. Each 8 bits correspond to the increment value for a different loop from the inner one.
 */
void mage_set_li(uint8_t li[MAGE_NUM_HWLP]);


/**
 * @brief Sets the strides for all Address Generation Engines (AGEs).
 * 
 * @param strides strides to set.
 */
void mage_set_all_age_strides(uint32_t strides[MAGE_N_AGES]);

/**
 * @brief Sets the strides for an Address Generation Engine (AGE).
 * 
 * @param stream_id The stream ID.
 * @param age_id The age ID.
 * @param strides strides to set.
 */
void mage_set_age_strides(uint32_t stream_id, uint32_t age_id, uint32_t strides);


/**
 * @brief Sets the Prolog-Kernel-Epilog (PKE) value.
 * 
 * @param p The Prolog value.
 * @param k The Kernel value.
 * @param e The Epilog value.
 * @param len_dfg The length of the DFG.
 */
void mage_set_pke(uint8_t p, uint8_t k, uint8_t e, uint8_t len_dfg);

/**
 * @brief Sets the MAGE configuration.
 * 
 * @param mage_mage_cfg The MAGE configuration array that contains the configuration for each AGE.
 */
void mage_set_mage_cfg(uint32_t mage_mage_cfg[MAGE_N_STREAMS][MAGE_N_AGE_PER_STREAM][KMEM_SIZE]);

/**
 * @brief Sets the configuration for a specific AGE.
 * 
 * @param age_cfg The AGE configuration value.
 * @param stream_id The stream ID.
 * @param age_id The age ID.
 * @param time_kernel The time instant of the kernel in which the configuration is applied.
 */
void mage_set_age_cfg(uint32_t age_cfg, uint32_t stream_id, uint32_t age_id, uint32_t time_kernel);

/**
 * @brief Sets the Induction Variable (IV) constraints for each AGE.
 * 
 * @param iv_constraints The IV constraints values.
 */
void mage_set_iv_constraints(uint8_t iv_constraints[MAGE_N_AGES]);

/**
 * @brief Sets the Induction Variable (IV) constraint for a specific AGE.
 * 
 * @param iv_constraints The IV constraint value.
 */
void mage_set_iv_constraints_reg(uint8_t iv_constraint, int8_t stream_id, int8_t age_id);

/**
 * @brief Sets the selectors for the outputs of PEA.
 * 
 * @param sel_out_pea The selectors array for PEA.
 */
void mage_set_sel_out_pea(uint32_t sel_out_pea[SEL_OUT_PEA_SIZE]);

/**
 * @brief Sets a specific register in the selectors for the output of PEA.
 * 
 * @param sel_out_pea The selectors.
 * @param reg The register index.
 */
void mage_set_sel_out_pea_reg(uint32_t sel_out_pea, uint32_t reg);

/**
 * @brief Sets the Load Stream.
 * 
 * @param load_stream The Load Stream.
 */
void mage_set_load_stream(uint32_t load_stream[LOAD_STREAM_SIZE]);

/**
 * @brief Sets a specific register for the Load Stream.
 * 
 * @param load_stream The Load Stream.
 * @param reg The register index.
 */
void mage_set_load_stream_reg(uint32_t load_stream, uint32_t reg);

/**
 * @brief Sets the Store Stream.
 * 
 * @param store_stream The Store Stream.
 */
void mage_set_store_stream(uint32_t store_stream[STORE_STREAM_SIZE]);

/**
 * @brief Sets a specific register for the Store Stream.
 * 
 * @param store_strean The Store Stream.
 * @param reg The register index.
 */
void mage_set_store_stream_reg(uint32_t store_stream, uint32_t reg);

%endif
%if streaming_cgra == 1:
////////////////////////////////////////////////////////////////
//                                                            //
//                       Streaming Mage                       //
//                                                            //
////////////////////////////////////////////////////////////////
/**
 * @brief Sets the selector for the outputs of a column of PEA.
 * 
 * @param sel_out The selectors for PEA columns.
 * @param pea_col PEA column.
 */
void mage_set_sel_out_pea_cols(uint8_t sel_out, uint8_t pea_col);

/**
 * @brief Sets the accumulation values for a PE.
 * 
 * @param pe_acc_values The accumulation value.
 * @param pe_row PE row.
 * @param pe_col PE col.
 */
void mage_set_pe_acc_values(uint8_t acc_value, uint8_t pe_row, uint8_t pe_col);

/**
 * @brief Sets the selector for the outputs of PEA.
 * 
 * @param sel_out The selectors for PEA output.
 */
void mage_set_sel_out_xbar(uint8_t sel_out);

/**
 * @brief Sets the configuration for Mage DMA channel.
 * 
 * @param n_dma_ch Number of the DMA channel.
 * @param cfg DMA channel configuration.
 */
void mage_set_dma_rnw(uint8_t n_dma_ch, uint8_t cfg);

%endif
#ifdef __cplusplus
}
#endif

#endif // MAGE_H_