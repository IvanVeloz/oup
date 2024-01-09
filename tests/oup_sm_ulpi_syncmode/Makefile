# Makefile
RTL_DIR ?= $(PWD)/../../rtl

# defaults
SIM ?= verilator
SIM_ARGS += --wave=anyname.fst
EXTRA_ARGS += --trace --trace-structs

TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(RTL_DIR)/core/oup_sm_ulpi_syncmode.sv
VERILOG_INCLUDE_DIRS += $(RTL_DIR)
VERILOG_INCLUDE_DIRS += $(RTL_DIR)/core

# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = oup_sm_ulpi_syncmode

# MODULE is the basename of the Python test file
MODULE = oup_sm_ulpi_syncmode

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
