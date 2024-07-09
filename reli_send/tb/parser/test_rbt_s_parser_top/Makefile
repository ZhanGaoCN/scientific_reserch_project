TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 1

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = rbt_s_parser_top
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../../rtl/parser/$(DUT).v

VERILOG_SOURCES += ../../../../../../modules/common/rtl/parser_extract_header.v

VERILOG_SOURCES += ../../../rtl/parser/rbt_s_eth_parser.v
VERILOG_SOURCES += ../../../rtl/parser/rbt_s_vlan_parser.v
VERILOG_SOURCES += ../../../rtl/parser/rbt_s_ipv6_parser.v
VERILOG_SOURCES += ../../../rtl/parser/rbt_s_idp_fix_parser.v
VERILOG_SOURCES += ../../../rtl/parser/rbt_s_transport_layer_optional_parser.v
VERILOG_SOURCES += ../../../rtl/parser/rbt_s_transport_layer_parser.v
VERILOG_SOURCES += ../../../rtl/parser/rbt_s_pre_parser.v
VERILOG_SOURCES += ../../../rtl/parser/rbt_s_post_parser.v

# module parameters
export PARAM_HEADER_WIDTH ?= 2048
export PARAM_TUSER_WIDTH ?= 64
export PARAM_ROUTE_OFFSET ?= 0


ifeq ($(SIM), icarus)
	PLUSARGS += -fst
  COMPILE_ARGS += -DSEAID_160
	COMPILE_ARGS += -P $(TOPLEVEL).HEADER_WIDTH=$(PARAM_HEADER_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).USER_WIDTH=$(PARAM_TUSER_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).ROUTE_OFFSET=$(PARAM_ROUTE_OFFSET)


	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GHEADER_WIDTH=$(PARAM_HEADER_WIDTH)
	COMPILE_ARGS += -GUSER_WIDTH=$(PARAM_TUSER_WIDTH)
	COMPILE_ARGS += -GROUTE_OFFSET=$(PARAM_ROUTE_OFFSET)


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
