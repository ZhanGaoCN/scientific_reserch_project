# Copyright (c) 2021 Alex Forencich
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 1

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = reli_nack_generator_top_interconnect
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v

NACK_GENERATOR = ../..
SMARTNIC = ../../../../..
## top
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/reli_nack_generator_top.v
## nack timer
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/timer/nack_safe_timer.v
## bitmap manager
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/ipbase_arbit_priosubcore.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/ipbase_arbit_roundrobin_core_ASIC.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/ipbase_arbit_roundrobin_core_simple.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/ipbase_chksum32_w512.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/ipbase_crc32_w512.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/ipbase_crc8_w16.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/ipbase_fifo_sync.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/ipbase_intf_axi_arbit2to1_rd_chn_simplified_v0p1.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/ipbase_intf_axi_arbit2to1prio_simplified_v0p1.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/ipbase_intf_axi_arbit4to1robin_simplified_v0p1.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/ipbase_intf_axi_rd_adapter_simplified_v0p1.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/ipbase_intf_axi_wr_adapter_simplified_v0p1.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/ipbase_intf_pipeline_d2.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/ipbase_sdpram_sync.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/seanetnackgenerator_ddr_bmpcmd_arbit.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/seanetnackgenerator_ddr_bmpcmd_arbit_m.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/seanetnackgenerator_ddr_bmpcmd_arbit_mc.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/seanetnackgenerator_ddr_bmpcmd_arbit_sw.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/seanetnackgenerator_ddr_bmpcmd_subarbit.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/seanetnackgenerator_nack_generator_v0p1.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/seanetnackgenerator_stream_manager_v0p1.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/seanetnackgenerator_timer_compcore.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/seanetnackgenerator_timer_ctrlcore.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/seanetnackgenerator_timer_gencore.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/seanetnackgenerator_timer_manager_v0p1.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/seanetnackgenerator_top_v0p1.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/seanetnackgenerator_window_calcore.sv
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_generator/seanetnackgenerator_window_manager_v0p1.sv
## nack deparser
VERILOG_SOURCES += $(NACK_GENERATOR)/rtl/nack_deparser/nack_deparser.v

## lib
# VERILOG_SOURCES += ../../../../../corundum/fpga/lib/eth/lib/axis/rtl/axis_srl_fifo.v
VERILOG_SOURCES += $(SMARTNIC)/modules/memory/rtl/simple_dual_port_ram.v
VERILOG_SOURCES += $(SMARTNIC)/corundum/fpga/lib/pcie/rtl/ipbase_fifo_distribute_v1p1.v
VERILOG_SOURCES += $(SMARTNIC)/corundum/fpga/lib/eth/lib/axis/rtl/axis_adapter.v
VERILOG_SOURCES += $(SMARTNIC)/corundum/fpga/lib/eth/lib/axis/rtl/axis_srl_fifo.v
VERILOG_SOURCES += $(SMARTNIC)/corundum/fpga/lib/eth/lib/axis/rtl/axis_fifo.v
VERILOG_SOURCES += $(SMARTNIC)/corundum/fpga/lib/axi/rtl/axi_interconnect.v
VERILOG_SOURCES += $(SMARTNIC)/corundum/fpga/lib/axi/rtl/arbiter.v
VERILOG_SOURCES += $(SMARTNIC)/corundum/fpga/lib/axi/rtl/priority_encoder.v

# VERILOG_SOURCES += $(NACK_GENERATOR)/lib/simple_dual_port_ram.v
# VERILOG_SOURCES += $(NACK_GENERATOR)/lib/ipbase_fifo_distribute_v1p1.v
# VERILOG_SOURCES += $(NACK_GENERATOR)/lib/axis_adapter.v
# VERILOG_SOURCES += $(NACK_GENERATOR)/lib/axis_srl_fifo.v
# VERILOG_SOURCES += $(NACK_GENERATOR)/lib/axis_fifo.v
# VERILOG_SOURCES += $(NACK_GENERATOR)/lib/ipbase_fifo_distribute_v1p1.v


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
	@rm -rf iverilog_dump.v
	@rm -rf *.xml
	@rm -rf __pycache__/
	@rm -rf dump.fst $(TOPLEVEL).fst
