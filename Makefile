.PHONY: clean help

PYTHON = python3
FUSESOC = fusesoc

MAGE_CORE = vlsi:polito:mage-stream
MAGE_CFG_HJSON ?= config/cfg_s_4x4_pipediv.hjson

### Regtool ###
REGTOOL_SCRIPT = /home/alessio.naclerio/polheepo/hw/vendor/x-heep/hw/vendor/pulp_platform_register_interface/vendor/lowrisc_opentitan/util/regtool.py
REGTOOL_DEST_DIR = ./hw/mage/configuration
REGTOOL_SRC_FILE = ./hw/mage/configuration/mage_regs.hjson
REGTOOL_SW_DEST_DIR = ./sw

re-vendor:
	./util/vendor.py ./vendor/lowrisc_opentitan.vendor.hjson -v --update; \
	./util/vendor.py ./vendor/pulp_platform_register_interface.vendor.hjson -v --update; \
	./util/vendor.py ./vendor/pulp_platform_common_cells.vendor.hjson -v --update; \
	./util/vendor.py ./vendor/pulp_platform_tech_cells_generic.vendor.hjson -v --update;

mage-gen:
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/stream --tpl-sv hw/mage/stream/streaming_interface.sv.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/packages --tpl-sv hw/mage/packages/stream_intf_pkg.sv.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/execute --tpl-sv hw/mage/execute/pea.sv.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/execute/pe/dae --tpl-sv hw/mage/execute/pe/dae/pe_dae.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/execute/pe/dae --tpl-sv hw/mage/execute/pe/dae/pe_dae_part_gemm_acc.sv.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/packages --tpl-sv hw/mage/packages/agu_pkg.sv.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/packages --tpl-sv hw/mage/packages/xbar_pkg.sv.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/access --tpl-sv hw/mage/access/age.sv.tpl  
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/access --tpl-sv hw/mage/access/hwlp_rou.sv.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/packages --tpl-sv hw/mage/packages/pea_pkg.sv.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/configuration --tpl-sv hw/mage/configuration/peripheral_regs.sv.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw --tpl-sv hw/mage_top.sv.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw --tpl-sv hw/mage_wrapper.sv.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/configuration --tpl-sv hw/mage/configuration/mage_regs.hjson.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/access --tpl-sv hw/mage/access/agu.sv.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/access --tpl-sv hw/mage/access/cfg_dispatcher.sv.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/access --tpl-sv hw/mage/access/k_controller.sv.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/fpga/scripts/ --tpl-sv hw/fpga/scripts/generate_sram.tcl.tpl
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage.h.tpl 
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage.c.tpl 
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage_x_heep.h.tpl
	util/format-verible;
	$(PYTHON) $(REGTOOL_SCRIPT) -r -t $(REGTOOL_DEST_DIR) $(REGTOOL_SRC_FILE)
	$(PYTHON) $(REGTOOL_SCRIPT) -D $(REGTOOL_SRC_FILE) > $(REGTOOL_SW_DEST_DIR)/mage_regs.h

	util/format-verible;

verible:
	util/format-verible;

verilator-sim:
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=verilator $(FUSESOC_FLAGS) --setup --build $(MAGE_CORE)  2>&1 | tee buildsim.log

questasim-sim:
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=modelsim $(FUSESOC_FLAGS) --setup --build $(MAGE_CORE) 2>&1 | tee buildsim.log

synthesis:
	$(FUSESOC) --cores-root . run --no-export --target=syn $(FUSESOC_FLAGS_SYN) --setup $(MAGE_CORE) ${FUSESOC_PARAM} 2>&1 | tee builddesigncompiler.log

regtool:
	$(PYTHON) $(REGTOOL_SCRIPT) -r -t $(REGTOOL_DEST_DIR) $(REGTOOL_SRC_FILE)
	$(PYTHON) $(REGTOOL_SCRIPT) -D $(REGTOOL_SRC_FILE) > $(REGTOOL_SW_DEST_DIR)/mage_regs.h

run-verilator:
	cd ./build/vlsi_polito_mage/sim-verilator;\
	make Vmage_wrapper;\
	./Vmage_wrapper;\

run-synthesis:
	cd ./build/vlsi_polito_mage/syn-design_compiler;\
	make -f Makefile;\

run-power-analysis:
	cd ./build/vlsi_polito_mage/power-analysis;\
	pt_shell -file  ../../../scripts/power_analysis/pwr_script.tcl\

waves:
	gtkwave ./build/vlsi_polito_mage/sim-verilator/waveform.vcd

clean-build:
	rm -rf build buildsim.log builddesigncompiler.log

clean-synthesis:
	rm -rf build/vlsi_polito_mage/syn-design_compiler buildsim.log builddesigncompiler.log
