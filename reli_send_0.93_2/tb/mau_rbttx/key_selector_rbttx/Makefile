TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 1

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = key_selector_rbttx
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
#match_action
VERILOG_SOURCES += ../../../rtl/mau_rbttx/key_selector_rbttx.v

# module parameters
export PARAM_PHV_WIDTH ?= 456
export PARAM_KEY_WIDTH ?= 256

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).PHV_WIDTH=$(PARAM_PHV_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).KEY_WIDTH=$(PARAM_KEY_WIDTH)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GPHV_WIDTH=$(PARAM_PHV_WIDTH)
	COMPILE_ARGS += -GKEY_WIDTH=$(PARAM_KEY_WIDTH)
	
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
