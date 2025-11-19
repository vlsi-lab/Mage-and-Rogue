#include <stddef.h>
#include <stdint.h>

#include "mage_regs.h"
#include "mage_x_heep.h"
#include "mage.h"

static inline void write_mage_register(uint32_t p_val, uint32_t p_addr, uint32_t p_mask, uint8_t p_sel){
  /*
   * An intermediate variable "value" is used to prevent writing twice into
   * the register.
   */
  uint32_t value = *((uint32_t *)p_addr);
  value &= ~(p_mask << p_sel);
  value |= (p_val & p_mask) << p_sel;
  *((uint32_t *)p_addr) = value;
}

/**
 * @brief Sets the PEA configuration.
 *
 * @param mage_pea_cfg The PEA configuration array that contains the configuration for each PE.
 */
void mage_set_pea_cfg(uint32_t mage_pea_cfg[MAGE_PEA_ROWS][MAGE_PEA_COLS][KMEM_SIZE]){
  int32_t *mage_pea_cfg_idx = (int32_t *)(MAGE_PEA_CFG_START_ADDR);
  for(uint8_t i = 0; i < MAGE_PEA_ROWS; i++){
    for(uint8_t j = 0; j < MAGE_PEA_COLS; j++){
      for(uint8_t k = 0; k < KMEM_SIZE; k++){
        mage_set_pe_cfg(mage_pea_cfg[i][j][k], i, j, k);
      }
    }
  }
}

/**
 * @brief Sets the configuration for a specific PE.
 *
 * @param pe_cfg The PE configuration value.
 * @param pe_row The row index of the PE.
 * @param pe_col The column index of the PE.
 * @param time The time instant for configuration pe_cfg.
 */
void mage_set_pe_cfg(uint32_t pe_cfg, uint8_t pe_row, uint8_t pe_col, uint8_t time){
  int32_t *mage_pe_cfg = ((int32_t *)(MAGE_PEA_CFG_START_ADDR)) + pe_row * MAGE_PEA_COLS + pe_col;
  write_mage_register(pe_cfg, mage_pe_cfg, 0xFFFFFFFF, 0);
}

/**
 * @brief Set the PEA constants.
 *
 * @param pea_constants PEA constants array.
 */
void mage_set_pea_constants(uint32_t pea_constants[MAGE_PEA_ROWS][MAGE_PEA_COLS]){
  int32_t *mage_pea_constants_idx = (int32_t *)(MAGE_PEA_CONSTANTS_START_ADDR);
  for(int i = 0; i < MAGE_PEA_COLS; i++){
    for(int j = 0; j < MAGE_PEA_ROWS; j++){
      mage_set_pe_constant(pea_constants[j][i], j, i);
    }
  }
}

/**
 * @brief Sets a specific constant for a PE.
 *
 * @param pea_constant The constant value.
 * @param reg The register index.
 */
void mage_set_pe_constant(uint32_t pe_constant, uint8_t pe_row, uint8_t pe_col){
  int32_t *mage_pea_constants = (int32_t *)(MAGE_PEA_CONSTANTS_START_ADDR);
  mage_pea_constants += pe_row * MAGE_PEA_COLS + pe_col;
  write_mage_register(pe_constant, mage_pea_constants, 0xFFFFFFFF, 0);
}

%if dae_cgra == 1:
////////////////////////////////////////////////////////////////
//                                                            //
//                          DAE Mage                          //
//                                                            //
////////////////////////////////////////////////////////////////

/**
 * @brief Start the CGRA.
 */
void mage_start(){
  int32_t *mage_start = (int32_t *)(MAGE_STATUS_START_ADDR);
  *mage_start = 1 << MAGE_STATUS_START_BIT;
}

/**
 * @brief Check if the CGRA has finished execution.
 * 
 * @return uint32_t 1 if finished, 0 otherwise.
 */
uint32_t is_mage_finished()
{
  int32_t *mage_status = (int32_t *)(MAGE_STATUS_START_ADDR);
  return (*mage_status >> MAGE_STATUS_DONE_BIT) & 0x1;
}


/**
 * @brief Sets the Iteration Interval (II).
 * 
 * @param ii The II to set.
 */
void mage_set_ii(uint8_t ii){
  int32_t *mage_gen_cfg = (int32_t *)(MAGE_GEN_CFG_START_ADDR);
  //ii is the 4 least significant bits
  *mage_gen_cfg = (*mage_gen_cfg & 0xFFFFFFF0) | ii;
}

/**
 * @brief Sets Static/Time-multiplexed mode for AGE-PEA-OutSelectors-Xbars (from LSBs to MSBs)
 * 
 * @param snt The 4 bits to set the mode for the 4 components.
 */
void mage_set_snt(uint32_t snt){
  int32_t *mage_gen_cfg = (int32_t *)(MAGE_GEN_CFG_START_ADDR);
  *mage_gen_cfg = (*mage_gen_cfg & 0xFFFFFF0F) | (snt << 4);
}

/**
 * @brief Sets information related to accumulationmode.
 * 
 * @param mode Vector mode for the accumulation (8, 16, 32 bits)
 */
void mage_set_acc_mode(uint32_t mode){
  int32_t *mage_gen_cfg = (int32_t *)(MAGE_GEN_CFG_START_ADDR);
  if(mode == 8){
    *mage_gen_cfg = *mage_gen_cfg | 0x0000100;
  }else if(mode == 16){
    *mage_gen_cfg = *mage_gen_cfg | 0x0000200;
  }
}

/**
 * @brief Sets the blocksize for the address map of Mage SpM.
 * 
 * @param blocksize The blocksize to set.
 */
void mage_set_address_map_blocksize(uint32_t blocksize){
  int32_t *mage_gen_cfg = (int32_t *)(MAGE_GEN_CFG_START_ADDR);
  *mage_gen_cfg = (*mage_gen_cfg & 0x0FFFFFFF) | (blocksize << 12);
}


/**
 * @brief Sets the general configuration bits for Mage.
 * 
 * @param cfg_bits The configuration bits to set.
 */
void mage_set_general_cfg_bits(uint32_t cfg_bits){
  int32_t *mage_gen_cfg = (int32_t *)(MAGE_GEN_CFG_START_ADDR);
  *mage_gen_cfg = cfg_bits;
}

/**
 * @brief Sets each PE control mode (static or time-multiplexed).
 * 
 * @param pea_control_snt The PEA control mode. Each bit sets the mode of a PE in row-major order.
 */
void mage_set_pea_control_snt(uint32_t pea_control_snt){
  int32_t *mage_pea_control_snt = (int32_t *)(MAGE_PEA_CONTROL_SNT_ADDR);
  *mage_pea_control_snt = pea_control_snt;
}

/**
 * @brief Sets the Initial Loop Bounds (ILB) value for the Hardware Loops.
 * 
 * @param ilb The ILB value to set. Each 8 bits correspond to the ILB value for a different loop from the inner one.
 */
void mage_set_ilb(uint8_t ilb[MAGE_NUM_HWLP]){
  for(int i = 0; i < MAGE_NUM_HWLP; i++){
    write_mage_register(ilb[i], MAGE_ILB_HWL_START_ADDR, 0xFF, 8*i);
  }
}

/**
 * @brief Sets the Final Loop Bounds (FLB) value for the Hardware Loops.
 * 
 * @param flb The FLB value to set. Each 8 bits correspond to the ILB value for a different loop from the inner one.
 */
void mage_set_flb(uint8_t flb[MAGE_NUM_HWLP]){
  for(int i = 0; i < MAGE_NUM_HWLP; i++){
    write_mage_register(flb[i], MAGE_FLB_HWL_START_ADDR, 0xFF, 8*i);
  }
}

/**
 * @brief Sets the increment values for the Hardware Loops.
 * 
 * @param li The increment values to set. Each 8 bits correspond to the increment value for a different loop from the inner one.
 */
void mage_set_li(uint8_t li[MAGE_NUM_HWLP]){
  for(int i = 0; i < MAGE_NUM_HWLP; i++){
    write_mage_register(li[i], MAGE_LI_HWL_START_ADDR, 0xFF, 8*i);
  }
}

/**
 * @brief Sets the strides for all Address Generation Engines (AGEs).
 * 
 * @param strides strides to set.
 */
void mage_set_all_age_strides(uint32_t strides[MAGE_N_AGES]){
  uint32_t* start_addr_strides = (int*)(MAGE_STRIDES_START_ADDR);
  for(int i = 0; i < MAGE_N_AGES; i++){
      *start_addr_strides = strides[i];
      start_addr_strides += 1;
  }
}

/**
 * @brief Sets the strides for an Address Generation Engine (AGE).
 * 
 * @param stream_id The stream ID.
 * @param age_id The age ID.
 * @param strides strides to set.
 */
void mage_set_age_strides(uint32_t stream_id, uint32_t age_id, uint32_t strides){
  uint32_t* start_addr_strides = (int*)(MAGE_STRIDES_START_ADDR);
  start_addr_strides += stream_id * MAGE_N_AGE_PER_STREAM + age_id;
  *start_addr_strides = strides;
}

/**
 * @brief Sets the Prolog-Kernel-Epilog (PKE) value.
 * 
 * @param p The Prolog value.
 * @param k The Kernel value.
 * @param e The Epilog value.
 * @param len_dfg The length of the DFG.
 */
void mage_set_pke(uint8_t p, uint8_t k, uint8_t e, uint8_t len_dfg){
  int32_t *mage_pke = (int32_t *)(MAGE_PKE_START_ADDR);
  *mage_pke = (*mage_pke & 0xFFFFFFF0) | (p << 0);
  *mage_pke = (*mage_pke & 0xFFFFFF0F) | (k << 4);
  *mage_pke = (*mage_pke & 0xFFFFF0FF) | (e << 8);
  *mage_pke = (*mage_pke & 0xFFF00FFF) | (len_dfg << 12);
}

/**
 * @brief Sets the AGE configuration.
 * 
 * @param mage_mage_cfg The AGE configuration array that contains the configuration for each AGE.
 */
void mage_set_mage_cfg(uint32_t mage_mage_cfg[MAGE_N_STREAMS][MAGE_N_AGE_PER_STREAM][KMEM_SIZE]){
  int32_t *mage_mage_cfg_idx = (int32_t *)(MAGE_MAGE_CFG_START_ADDR);
  for(int i = 0; i < MAGE_N_STREAMS; i++){
    for(int j = 0; j < MAGE_N_AGE_PER_STREAM; j++){
      for(int k = 0; k < KMEM_SIZE; k++){
        *mage_mage_cfg_idx = mage_mage_cfg[i][j][k];
        mage_mage_cfg_idx++;
      }
    }
  }
}

/**
 * @brief Sets the configuration for a specific AGE.
 * 
 * @param age_cfg The AGE configuration value.
 * @param stream_id The stream ID.
 * @param age_id The age ID.
 * @param time_kernel The time instant of the kernel in which the configuration is applied.
 */
void mage_set_age_cfg(uint32_t age_cfg, uint32_t stream_id, uint32_t age_id, uint32_t time_kernel){
  int32_t *mage_mage_cfg = (int32_t *)(MAGE_MAGE_CFG_START_ADDR);
  mage_mage_cfg += (stream_id * MAGE_N_AGE_PER_STREAM + age_id) * KMEM_SIZE + time_kernel;
  *mage_mage_cfg = age_cfg;
}

/**
 * @brief Sets the Induction Variable (IV) constraints for each AGE.
 * 
 * @param iv_constraints The IV constraints values.
 */
void mage_set_iv_constraints(uint8_t iv_constraints[MAGE_N_AGES]){
  for(int i = 0; i < MAGE_N_AGES; i++){
    write_mage_register(iv_constraints[i], MAGE_MAGE_IV_CONSTRAINTS_START_ADDR, 0xFF, 8*i);
  }
}

/**
 * @brief Sets the Induction Variable (IV) constraint for a specific AGE.
 * 
 * @param iv_constraints The IV constraint value.
 */
void mage_set_iv_constraints_reg(uint8_t iv_constraint, int8_t stream_id, int8_t age_id){
  int32_t *mage_iv_constraints = (int32_t *)(MAGE_MAGE_IV_CONSTRAINTS_START_ADDR);
  mage_iv_constraints += (stream_id * MAGE_N_AGE_PER_STREAM + age_id) / 4;
  uint32_t offset = ((stream_id * MAGE_N_AGE_PER_STREAM + age_id) % 4) * 8;

  write_mage_register(iv_constraint, mage_iv_constraints, 0xFF, offset);
}

/**
 * @brief Sets the selectors for the outputs of PEA.
 * 
 * @param sel_out_pea The selectors array for PEA.
 */
void mage_set_sel_out_pea(uint32_t sel_out_pea[SEL_OUT_PEA_SIZE]){
  int32_t *mage_sel_out_pea_idx = (int32_t *)(MAGE_SEL_OUT_PEA_START_ADDR);
  for(int i = 0; i < SEL_OUT_PEA_SIZE; i++){
    *mage_sel_out_pea_idx = sel_out_pea[i];
    mage_sel_out_pea_idx++;
  }
}

/**
 * @brief Sets the selectors for the outputs of PEA.
 * 
 * @param sel_out_pea The selectors array for PEA.
 */
void mage_set_sel_out_pea_reg(uint32_t sel_out_pea, uint32_t reg){
  int32_t *mage_sel_out_pea = (int32_t *)(MAGE_SEL_OUT_PEA_START_ADDR);
  mage_sel_out_pea += reg;
  *mage_sel_out_pea = sel_out_pea;
}

/**
 * @brief Sets the Load Stream.
 * 
 * @param load_stream The Load Stream.
 */
void mage_set_load_stream(uint32_t load_stream[LOAD_STREAM_SIZE]){
  int32_t *mage_load_stream_idx = (int32_t *)(MAGE_LOAD_AGE_SEL_ADDR);
  for(int i = 0; i < LOAD_STREAM_SIZE; i++){
    *mage_load_stream_idx = load_stream[i];
    mage_load_stream_idx++;
  }
}

/**
 * @brief Sets a specific register for the Load Stream.
 * 
 * @param load_stream The Load Stream.
 * @param reg The register index.
 */
void mage_set_load_stream_reg(uint32_t load_stream, uint32_t reg){
  int32_t *mage_load_stream_idx = (int32_t *)(MAGE_LOAD_AGE_SEL_ADDR);
  mage_load_stream_idx += reg;
  *mage_load_stream_idx = load_stream;
}

/**
 * @brief Sets the Store Stream.
 * 
 * @param store_stream The Store Stream.
 */
void mage_set_store_stream(uint32_t store_stream[STORE_STREAM_SIZE]){
  int32_t *mage_store_stream_idx = (int32_t *)(MAGE_PEA_DMEM_SEL_ADDR);
  for(int i = 0; i < LOAD_STREAM_SIZE; i++){
    *mage_store_stream_idx = store_stream[i];
    mage_store_stream_idx++;
  }
}

/**
 * @brief Sets a specific register for the Store Stream.
 * 
 * @param store_strean The Store Stream.
 * @param reg The register index.
 */
void mage_set_store_stream_reg(uint32_t store_stream, uint32_t reg){
  int32_t *mage_store_stream_idx = (int32_t *)(MAGE_LOAD_AGE_SEL_ADDR);
  mage_store_stream_idx += reg;
  *mage_store_stream_idx = store_stream;
}

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
void mage_set_sel_out_pea_cols(uint8_t sel_out, uint8_t pea_col){
  int32_t *mage_sel_out_pea = (int32_t *)(MAGE_COL_RES_SEL_START_ADDR);
  write_mage_register(sel_out, mage_sel_out_pea, 0xFF, pea_col << 3);
}

/**
 * @brief Sets the accumulation values for a PE.
 * 
 * @param pe_acc_values The accumulation value.
 * @param pe_row PE row.
 * @param pe_col PE col.
 */
void mage_set_pe_acc_values(uint8_t acc_value, uint8_t pe_row, uint8_t pe_col){
  int32_t *mage_acc_values_addr = (int32_t *)(MAGE_ACC_VALUES_START_ADDR);
  mage_acc_values_addr += pe_row;
  write_mage_register(acc_value, mage_acc_values_addr, 0xFF, pe_col << 3);
}
%if out_stream_xbar == 1:
/**
 * @brief Sets the selector for the outputs of PEA.
 * 
 * @param sel_out The selectors for PEA output.
 */
void mage_set_sel_out_xbar(uint8_t sel_out){
  int32_t *mage_sel_out_xbar = (int32_t *)(MAGE_OUT_XBAR_START_ADDR);
  *mage_sel_out_xbar = sel_out;
}
%endif

%endif