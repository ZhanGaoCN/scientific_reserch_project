TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 1

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = mau_rbttx_top
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../../rtl/mau_rbttx/$(DUT).v
VERILOG_SOURCES += ../../../rtl/mau_reliable_send/reliable_send_action_core.v
VERILOG_SOURCES += ../../../rtl/mau_reliable_send/mau_reliable_send_action_unit.v
# VERILOG_SOURCES += ../../../../reliability_recv/rtl/mau_reliable_recv/flowstate_addr_ctl.v
VERILOG_SOURCES += ../../../rtl/mau_reliable_send/flowstate_sendmau_addr_ctl.v
VERILOG_SOURCES += ../../../rtl/mau_reliable_send/flowstate_ram.v
# VERILOG_SOURCES += ../../../../reliability_recv/rtl/mau_reliable_recv/flowstate_ram.v
VERILOG_SOURCES += ../../../rtl/mau_rbttx/key_selector_rbttx.v
VERILOG_SOURCES += ../../../../../../modules/memory/rtl/simple_dual_port_ram.v
VERILOG_SOURCES += ../../../../../../corundum/fpga/lib/eth/lib/axis/rtl/axis_srl_fifo.v
VERILOG_SOURCES += ../../../../../../modules/axis/rtl/axis_two_input_align.v
VERILOG_SOURCES += ../../../../../flowmod_controller/rtl/flowmod_controller.v
#em_table
VERILOG_SOURCES += ../../../../../../corundum/fpga/lib/eth/lib/axis/rtl/priority_encoder.v
VERILOG_SOURCES += ../../../../../../modules/table_flowrequest/rtl/em_table_sub4/em_table_sub4.v
VERILOG_SOURCES += ../../../../../../modules/table_flowrequest/rtl/em_table_sub4/hashing_unit_sub4.v
# VERILOG_SOURCES += ../../../../../modules/memory/rtl/simple_dual_port_ram.v
VERILOG_SOURCES += ../../../../../../modules/table_flowrequest/rtl/em_table_sub4/hashing_unit_sub4_256x9.v

VERILOG_SOURCES += ../../../../../../corundum/fpga/lib/eth/lib/axis/rtl/axis_fifo.v


export PARAM_PHV_WIDTH ?= 408
export PARAM_PHV_B_COUNT ?= 7
export PARAM_PHV_H_COUNT ?= 2
export PARAM_PHV_W_COUNT ?= 10



ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	# COMPILE_ARGS += -P $(TOPLEVEL).ADDR_WIDTH=$(PARAM_ADDR_WIDTH)
	# COMPILE_ARGS += -P $(TOPLEVEL).KEY_WIDTH=$(PARAM_KEY_WIDTH)
	# COMPILE_ARGS += -P $(TOPLEVEL).VALUE_WIDTH=$(PARAM_VALUE_WIDTH)
	# COMPILE_ARGS += -P $(TOPLEVEL).OPCODE_WIDTH=$(PARAM_OPCODE_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).PHV_WIDTH=$(PARAM_PHV_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).PHV_B_COUNT=$(PARAM_PHV_B_COUNT)
	COMPILE_ARGS += -P $(TOPLEVEL).PHV_H_COUNT=$(PARAM_PHV_H_COUNT)
	COMPILE_ARGS += -P $(TOPLEVEL).PHV_W_COUNT=$(PARAM_PHV_W_COUNT)				



	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GADDR_WIDTH=$(PARAM_ADDR_WIDTH)
	COMPILE_ARGS += -GKEY_WIDTH=$(PARAM_KEY_WIDTH)
	COMPILE_ARGS += -GVALUE_WIDTH=$(PARAM_VALUE_WIDTH)
	COMPILE_ARGS += -GOPCODE_WIDTH=$(PARAM_OPCODE_WIDTH)
	COMPILE_ARGS += -GPHV_WIDTH=$(PARAM_PHV_WIDTH)
	COMPILE_ARGS += -GPHV_B_COUNT=$(PARAM_PHV_B_COUNT)
	COMPILE_ARGS += -GPHV_H_COUNT=$(PARAM_PHV_H_COUNT)
	COMPILE_ARGS += -GPHV_W_COUNT=$(PARAM_PHV_W_COUNT)


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
	@rm -rf results.xml
	@rm -rf __pycache__
	@rm -rf sim_build
	@rm -rf iverilog_dump.v
	@rm -rf dump.fst $(TOPLEVEL).fst
