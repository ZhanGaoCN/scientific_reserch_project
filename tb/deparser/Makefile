TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 1

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = seanet_rbttx_deparser_top
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/deparser/$(DUT).v
VERILOG_SOURCES += ../../../../../corundum/fpga/lib/eth/lib/axis/rtl/axis_srl_fifo.v
VERILOG_SOURCES += ../../../../../modules/common/rtl/add_tuser.v
VERILOG_SOURCES += ../../../../../modules/action/rtl/action_modify_fixed_len.v
# VERILOG_SOURCES += ../../../../modules/common/rtl/add_tuser.v
# VERILOG_SOURCES += ../../../../corundum/sriov/lib/eth/lib/axis/rtl/axis_fifo.v
# VERILOG_SOURCES += ../../../../corundum/sriov/lib/eth/lib/axis/rtl/axis_srl_fifo.v
# VERILOG_SOURCES += ../../../../modules/action/rtl/action_modify_fixed_len.v

# module parameters
export PARAM_DATA_WIDTH ?= 128


ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).DATA_WIDTH=$(PARAM_DATA_WIDTH)


	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GDATA_WIDTH=$(PARAM_DATA_WIDTH)


	ifeq ($(WAVES), 1)
		COMPILE_ARGS += --trace-fst
	endif
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

iverilog_dump.v:
	echo 'module iverilog_dump();' > $@
	echo 'initial begin' >> $@
	echo '    $$dumpfile("$(TOPLEVEL).fst");' >> $@
	echo '    $$dumpvars(0, $(TOPLEVEL));' >> $@
	echo 'end' >> $@
	echo 'endmodule' >> $@

clean::
	@rm -rf iverilog_dump.v
	@rm -rf dump.fst $(TOPLEVEL).fst
