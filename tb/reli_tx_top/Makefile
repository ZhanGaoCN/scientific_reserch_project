TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 1

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = reli_tx_top
TOPLEVEL = $(DUT)
MODULE   = test_reli_tx_top
VERILOG_SOURCES += ../../rtl/$(DUT).v

#parser
VERILOG_SOURCES += ../../rtl/parser/rbt_s_parser_top.v
VERILOG_SOURCES += ../../rtl/parser/rbt_s_eth_parser.v
VERILOG_SOURCES += ../../rtl/parser/rbt_s_vlan_parser.v
VERILOG_SOURCES += ../../rtl/parser/rbt_s_ipv6_parser.v
VERILOG_SOURCES += ../../rtl/parser/rbt_s_idp_fix_parser.v
VERILOG_SOURCES += ../../rtl/parser/rbt_s_transport_layer_optional_parser.v
VERILOG_SOURCES += ../../rtl/parser/rbt_s_transport_layer_parser.v
VERILOG_SOURCES += ../../rtl/parser/rbt_s_pre_parser.v
VERILOG_SOURCES += ../../rtl/parser/rbt_s_post_parser.v

#match_action_unit
VERILOG_SOURCES += ../../rtl/mau_reli_tx/mau_reli_tx_top.v
VERILOG_SOURCES += ../../rtl/mau_reli_tx/key_selector_reli_tx.v
VERILOG_SOURCES += ../../rtl/mau_reli_tx/mau_reli_tx_action_unit.v
VERILOG_SOURCES += ../../rtl/mau_reli_tx/flowstate_reli_tx_addr_ctl.v
VERILOG_SOURCES += ../../rtl/mau_reli_tx/mau_reli_tx_action_core.v
VERILOG_SOURCES += ../../../reli_recv/rtl/mau_reliable_recv/flowstate_ram.v
VERILOG_SOURCES += ../../../reli_recv/rtl/mau_reliable_recv/flowstate_addr_ctl.v

#flowmod controller
VERILOG_SOURCES += ../../../../flowmod_controller/rtl/flowmod_controller.v

#em_table
VERILOG_SOURCES += ../../../../../corundum/fpga/lib/eth/lib/axis/rtl/priority_encoder.v
VERILOG_SOURCES += ../../../../../modules/table/rtl/state_inflight.v
VERILOG_SOURCES += ../../../../../modules/table_flowrequest/rtl/em_table_sub4/em_table_sub4.v
VERILOG_SOURCES += ../../../../../modules/table_flowrequest/rtl/em_table_sub4/hashing_unit_sub4_256x9.v
VERILOG_SOURCES += ../../../../../modules/table_flowrequest/rtl/em_table_sub4/hashing_unit_sub4_128x9.v
VERILOG_SOURCES += ../../../../../modules/table_flowrequest/rtl/em_table_sub4/hashing_unit_sub4.v


#fifo
VERILOG_SOURCES += ../../../../../corundum/fpga/lib/eth/lib/axis/rtl/axis_fifo.v
VERILOG_SOURCES += ../../../../../corundum/fpga/lib/eth/lib/axis/rtl/axis_srl_fifo.v
VERILOG_SOURCES += ../../../../../modules/axis/rtl/axis_fifo_with_threshold.v

#deparser
VERILOG_SOURCES += ../../rtl/deparser/seanet_rbttx_deparser_top.v

#common
VERILOG_SOURCES += ../../../../../modules/common/rtl/parser_extract_header.v
VERILOG_SOURCES += ../../../../../modules/common/rtl/add_tuser.v
VERILOG_SOURCES += ../../../../../modules/action/rtl/action_modify_fixed_len.v
VERILOG_SOURCES += ../../../../../modules/axis/rtl/axis_two_input_align.v

VERILOG_SOURCES += ../../../../../modules/memory/rtl/simple_dual_port_ram.v

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
	@rm -rf results.xml
	@rm -rf __pycache__
	@rm -rf sim_build
	@rm -rf iverilog_dump.v
	@rm -rf dump.fst $(TOPLEVEL).fst
