TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 1

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = reliable_send_action_core
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../../rtl/mau_reliable_send/$(DUT).v
VERILOG_SOURCES += ../../../rtl/mau_reliable_send/flowstate_ram.v
VERILOG_SOURCES += ../../../rtl/mau_reliable_send/flowstate_sendmau_addr_ctl.v
VERILOG_SOURCES += ../../../rtl/mau_reliable_send/mau_reliable_send_action_unit.v
VERILOG_SOURCES += ../../../../../../modules/memory/rtl/simple_dual_port_ram.v
VERILOG_SOURCES += ../../../../../../modules/table/rtl/state_inflight.v
VERILOG_SOURCES += ../../../../../../corundum/fpga/lib/eth/lib/axis/rtl/priority_encoder.v

ifeq ($(SIM), icarus)
	PLUSARGS += -fst



	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	


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
	@rm -rf __pycache__
	@rm -rf sim_build
	@rm -rf iverilog_dump.v
	@rm -rf dump.fst $(TOPLEVEL).fst
	@rm -rf *xml
	@rm -rf .pytest_cache