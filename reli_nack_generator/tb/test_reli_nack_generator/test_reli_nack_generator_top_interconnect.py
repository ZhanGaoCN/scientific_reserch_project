#!/usr/bin/env python
"""

Copyright (c) 2021 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

"""

import itertools
import logging
import os
import random

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource, AxiStreamSink
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiLiteRam
from cocotbext.axi.stream import define_stream
from cocotb.binary import BinaryValue, BinaryRepresentation
from cocotbext.axi import AxiReadBus, AxiRamRead
from cocotbext.axi import AxiWriteBus, AxiRamWrite
from cocotbext.axi import AxiBus, AxiMaster, AxiRam
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame,  AxiBus, AxiSlave, MemoryRegion
from cocotb.binary import BinaryValue, BinaryRepresentation

from scapy.all import raw
from scapy.layers.l2 import Ether, Dot1Q
from scapy.layers.inet6 import IPv6

Reli_reqBus, Reli_reqTransaction, Reli_reqSource, Reli_reqSink, Reli_reqMonitor = define_stream("m_sp",
    signals=["task_req", "valid", "ready"]
)

# NackBus, NackTransaction, NackSource, NackSink, NackMonitor = define_stream("m_axis",
#     signals=["tdata", "tkeep", "tvalid", "tready", "tlast", "tuser"]
# )

DST_MAC_OFFSET = 0
DST_MAC_WIDTH = 48
SRC_MAC_OFFSET = DST_MAC_OFFSET + DST_MAC_WIDTH
SRC_MAC_WIDTH = 48
VLAN_ID_OFFSET = SRC_MAC_WIDTH + SRC_MAC_OFFSET
VLAN_ID_WIDTH = 16
SRC_IP_OFFSET = VLAN_ID_WIDTH + VLAN_ID_OFFSET
SRC_IP_WIDTH = 128
DST_IP_OFFSET = SRC_IP_WIDTH + SRC_IP_OFFSET
DST_IP_WIDTH = 128
INPORT_OFFSET = DST_IP_WIDTH + DST_IP_OFFSET
INPORT_WIDTH = 8

S_INFO_OFFSET = 120
KEY_MSG_OFFSET = 24
TYPE_OFFSET = 16
S_ID_OFFSET = 0

# offset in req
RPN_OFFSET = 0
EXP_RPN_OFFSET = 32
EXP_RPN_WIDTH = 64


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        self.Reli_req_source = Reli_reqSource(Reli_reqBus.from_prefix(dut, "m_sp"), dut.clk, dut.rst)
        self.Nack_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk, dut.rst)

        self.axi_ddr_ram = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.clk, dut.rst, size=2 ** 33)  # size = 2^33B (8GB) todo

        self.dut.dfx_cfg0.value = 0
        self.dut.dfx_cfg1.value = 0
        self.dut.dfx_cfg2.value = 0
        self.dut.dfx_cfg3.value = 0

        # self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), dut.clk, dut.rst)
    
    async def reset(self):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        
        self.dut.rst.value = 1
        for _ in range(0,8):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0

    def check_ram_access(self):
        assert self.axi_ddr_ram.read(0x130000000, 8) == b'\x00\x00\x00\x00\x00\x00\x00\x00'   #give verilog module base addr
       

    async def write_csr(self,wr_addr,wr_data):
        axil_ctrl_data_width=int(os.getenv("PARAM_AXIL_CTRL_DATA_WIDTH", "32"))
        data = BinaryValue(n_bits=axil_ctrl_data_width, bigEndian=False)
        data.set_value(wr_data)
        await self.axil_master.write(wr_addr, data.buff)
        await RisingEdge(self.dut.clk)

    async def read_csr(self,rd_addr):
        axil_ctrl_data_width=int(os.getenv("PARAM_AXIL_CTRL_DATA_WIDTH", "32"))
        data = BinaryValue(n_bits=axil_ctrl_data_width, bigEndian=False)
        data = await self.axil_master.read(rd_addr, int(axil_ctrl_data_width/8))
        await RisingEdge(self.dut.clk)
        return data
    
    #-----------test_vector_generation_start--------#
    def generate_light_order_list(self,sort_number):
        b = []
        for i in range(1, sort_number):
            if i % 2 == 0:
                b.append(i - 1)
            else:
                b.append(i + 1)
        return b
    
    def generate_order_list(self,sort_number):
        b = []
        for i in range(1, sort_number):
            b.append(i)
        return b

    def generate_light_order_exp_list(self,sort_number):
        b = []
        a = 1
        b.append(a)
        for i in range(1, sort_number):
            if i % 2 == 0:
                b.append(i + 1)
            else:
                b.append(i + 2)
        return b

    def generate_light_order_nack_1_list(self,sort_number):
        b = []
        a = 1
        b.append(a)
        for i in range(2, sort_number):
            if i % 2 == 0:
                b.append(i + 1)
            else:
                b.append(i - 1)
        b.pop(14)
        return b
    #-----------test_vector_generation_start--------#

    # #function to write csr para 
    # async def init_module_para(self): #initialize wnd_size and timeout value by csr interface

    #     service_type_idx=int(os.getenv("PARAM_TABLESTATE_INDEX", "8"))
    #     axil_ctrl_data_width=int(os.getenv("PARAM_AXIL_CTRL_DATA_WIDTH", "32"))
    #     data = BinaryValue(n_bits=axil_ctrl_data_width, bigEndian=False)

    #     for i in range(service_type_idx):
    #         data[axil_ctrl_data_width-1:0]=i# service_type = 0-7
    #         #print(data.buff)
    #         await self.axil_master.write(0x7c4B38 + i*0x4, data.buff)
    #         await RisingEdge(self.dut.clk)
    # #---------------------------------csr function end

    def build_s_info(self,dst_mac,src_mac, vlan_id,src_ip,dst_ip,inport):
        dst_mac %= 1 << DST_MAC_WIDTH
        src_mac %= 1 << SRC_MAC_WIDTH
        vlan_id %= 1 << VLAN_ID_WIDTH
        src_ip %= 1 << SRC_IP_WIDTH
        dst_ip %= 1 << DST_IP_WIDTH
        inport %= 1 << INPORT_WIDTH
        # s_info = (reserved << EXPRPN_OFFSET | inport << PKTRPN_OFFSET | dst_ip << DST_IP_OFFSET | src_ip << SRC_IP_OFFSET | p2p << PPP_OFFSET | pppoe << PPPOE_OFFSET | vlan << VLAN_OFFSET | eth_type << ETH_TYPE_OFFSET | src_mac << SRC_MAC_OFFSET | dst_mac << DST_MAC_OFFSET )
        s_info = (dst_mac << DST_MAC_OFFSET | src_mac << SRC_MAC_OFFSET |vlan_id << VLAN_ID_OFFSET| src_ip << SRC_IP_OFFSET | dst_ip << DST_IP_OFFSET | inport << INPORT_OFFSET)
        return s_info

    async def send_reli_req(self, s_info, s_id, key_msg, type):
        request = Reli_reqTransaction()
        request.task_req = (s_info << S_INFO_OFFSET | key_msg << KEY_MSG_OFFSET | type << TYPE_OFFSET | s_id << S_ID_OFFSET)
        await self.Reli_req_source.send(request)

    async def recv_nack(self):
        rx = await self.Nack_sink.recv()
        return rx
    
    #----functions below are used to make expected nack pkt
    def generate_scmpv6_NACK(self, pkt_type=0x41, Code=0x01, initial_npn=0x0000_0000, npn_bitmap=0x0000_0000_0000_0000):
        # type     8 bits
        type    = pkt_type
        # code 8 bits
        code = Code
        # checksum 16 bits
        chksum  = 0
        # npn 32 bits
        npn = initial_npn
        # bitmap 64 bits
        bitmap = npn_bitmap

        type    %= 1<<8
        code  %= 1<<8
        chksum  %= 1<<16
        npn %= 1<<32
        bitmap %= 1<<64
        pkt = type << 128 | code << 120 | chksum << 96 | npn << 64 | bitmap

        return pkt.to_bytes(16, 'big')

    async def generate_nack_pkt(self, initial_npn=0x0000_0000, npn_bitmap=0x0000_0000_0000_03E0):
        eth  = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x86dd)
        ipv6 = IPv6(nh=0x92, src = "2001::200", dst = "5001::0001:0001", version=6, hlim=255, fl=0, tc=0)

        scmpv6 = self.generate_scmpv6_NACK(pkt_type=0x41, Code=0x01, initial_npn=initial_npn, npn_bitmap=npn_bitmap)
        pad = 0
        # tail_idx = pad.to_bytes(12, 'big')
        # test_pkt_expect =bytes( eth / ipv6 / scmpv6 ) + tail_idx
        test_pkt_expect =bytes( eth / ipv6 / scmpv6 )
        return test_pkt_expect

    def set_idle_generator(self, generator=None):
        if generator:
            self.Reli_req_source.set_pause_generator(generator())
            
            for ram in [self.axi_ddr_ram]:
                ram.write_if.b_channel.set_pause_generator(generator())
                ram.read_if.r_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.Nack_sink.set_pause_generator(generator())

            for ram in [self.axi_ddr_ram]:
                ram.write_if.aw_channel.set_pause_generator(generator())
                ram.write_if.w_channel.set_pause_generator(generator())
                ram.read_if.ar_channel.set_pause_generator(generator())

    # def set_backpressure_generator(self, generator=None):
        # if generator:
            # self.Nack_sink.set_pause_generator(generator())
# 
            # for ram in [self.axi_ddr_ram,
                        # self.axil_master]:
                # ram.write_if.aw_channel.set_pause_generator(generator()
                # ram.write_if.w_channel.set_pause_generator(generator())
                # ram.read_if.ar_channel.set_pause_generator(generator())
#-----------------------------------test_case start-----------------------------------------------------------#
async def run_test_dat_lost(dut, sort_number, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):
    tb = TB(dut)

    await tb.reset()
    print("reset success")

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    for _ in range(128):
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

#___________________para_configuration_by_csr____________________#

    # await tb.write_csr(0x71421c, 0x100000)# todo: write csr(wnd_max)
    # await tb.write_csr(0x71421c, 0x100000)# todo: write csr(timeout)

#___________________para_configuration_by_csr____________________#

    dst_mac_dat_lost = 0x00_11_22_33_44_55
    src_mac_dat_lost = 0x66_77_88_99_aa_bb
    vlan_id_dat_lost = 0x0000
    src_ip_dat_lost = 0x2001_0000_0000_0000_0000_0000_0000_0200  # 2001:0000:0000:0000:0000:0000:0000:0200
    dst_ip_dat_lost = 0x5001_0000_0000_0000_0000_0000_0001_0001  # 5001:0000:0000:0000:0000:0000:0001:0001
    inport_dat_lost = 1
    s_info_dat_lost = tb.build_s_info(dst_mac_dat_lost, src_mac_dat_lost, 
                                      vlan_id_dat_lost, src_ip_dat_lost,
                                      dst_ip_dat_lost, inport_dat_lost)
    
    s_id_dat_lost = 0x0000 #stream_id
    key_msg_dat_lost = 0x0000_0000_0000_0005_0000_000A #rpn = 10(a); exp_rpn = 5(5) expected npn = 0 bitmap = 0000_0000_0000_03E0
    type_dat_lost = 0x01 #means dat todo
    
    await tb.send_reli_req(s_info_dat_lost, s_id_dat_lost,
                        key_msg_dat_lost, type_dat_lost)
    for _ in range(128000):
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)   

    # for j in range(1):
        # rx = await tb.recv_nack() #nack received
        # print("rx_nack:/n",rx.tdata)
        # print("expected_nack:/n",tb.generate_nack_pkt(0x0000_0000, 0x0000_0000_0000_03E0))
        # assert rx.tdata == tb.generate_nack_pkt(0x0000_0000, 0x0000_0000_0000_03E0)
#-----------------------------------test_case stop-----------------------------------------------------------#

#-----------------------------------test_case start-----------------------------------------------------------#
async def run_test_input_vector(dut, sort_number, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):
    tb = TB(dut)

    await tb.reset()
    print("reset success")

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    for _ in range(128):
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

    # await tb.write_csr(0x71421c, 0x100000)# todo: write csr(wnd_max)
    # await tb.write_csr(0x71421c, 0x100000)# todo: write csr(timeout)

    # rpn_vector = tb.generate_light_order_list(sort_number+1)
    # exp_rpn_vector = tb.generate_light_order_exp_list(sort_number)

    # rpn_vector = rpn_vector[:-1]
    # exp_rpn_vector = exp_rpn_vector[:-1]
    # del rpn_vector[1]
    # del exp_rpn_vector[1]

    # rpn_vector = [10,10,6,4,10,8,8,21]
    # exp_rpn_vector =[5,5,11,11,11,7,7,11]
    # dst_mac_dat_lost_vector = [0x00_11_22_33_44_FF,0x00_11_22_33_44_55,
                            #    0x00_11_22_33_44_55,0x00_11_22_33_44_55,
                            #    0x00_11_22_33_44_55,0x00_11_22_33_44_55,
                            #    0x00_11_22_33_44_55,0x00_11_22_33_44_55]

    rpn_vector = [10,10,6,4,10,8,21,4116]
    exp_rpn_vector =[5,5,11,11,11,7,11,15]
    dst_mac_dat_lost_vector = [0x00_11_22_33_44_FF,0x00_11_22_33_44_55,
                               0x00_11_22_33_44_55,0x00_11_22_33_44_55,
                               0x00_11_22_33_44_55,0x00_11_22_33_44_55,
                               0x00_11_22_33_44_55,0x00_11_22_33_44_55]
    print(rpn_vector)
    print(len(rpn_vector))
    print(exp_rpn_vector)
    print(len(exp_rpn_vector))

    # dst_mac_dat_lost = 0x00_11_22_33_44_55
    src_mac_dat_lost = 0x66_77_88_99_aa_bb
    vlan_id_dat_lost = 0x0000
    src_ip_dat_lost = 0x2001_0000_0000_0000_0000_0000_0000_0200
    dst_ip_dat_lost = 0x5001_0000_0000_0000_0000_0000_0001_0001
    inport_dat_lost = 1 
    
    s_id_dat_lost = 0x0000 #stream_id
    type_dat_lost = 0x01 #means dat todo

    cnt = 0
    for i in range(len(rpn_vector)):
        rpn = rpn_vector[i]              #rpn should lower than set
        exp_rpn = exp_rpn_vector[i]
        dst_mac_dat_lost = dst_mac_dat_lost_vector[i]
        s_info_dat_lost = tb.build_s_info(dst_mac_dat_lost, src_mac_dat_lost,
                                  vlan_id_dat_lost, src_ip_dat_lost,
                                  dst_ip_dat_lost, inport_dat_lost)
        key_msg_dat_lost = (0 << EXP_RPN_OFFSET + EXP_RPN_WIDTH | exp_rpn << EXP_RPN_OFFSET | rpn << RPN_OFFSET)
        print(key_msg_dat_lost)
        await tb.send_reli_req(s_info_dat_lost, s_id_dat_lost,
                        key_msg_dat_lost, type_dat_lost)
        cnt = cnt + 1
        for _ in range(64):
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
    

    for _ in range(1280):
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

#___________________expected nack generation____________________#
# 
    # for j in range(1): # 3 re_transmission
        # rx = await tb.recv_nack() #nack received
        # initial_npn = 0 # todo
        # bitmap = 0 # todo
        # print(rx.tdata)
        # print(tb.generate_nack_pkt(initial_npn, bitmap))
        # assert rx.tdata == tb.generate_nack_pkt(initial_npn, bitmap)
#___________________expected nack generation____________________#

#-----------------------------------test_case stop-----------------------------------------------------------#
def cycle_pause():
    return itertools.cycle([1, 0, 0, 0])

def size_list():
    data_width = len(cocotb.top.m_axis_tdata)
    byte_width = data_width // 8
    return list(range(1, byte_width*4+1))+[512]+[1]*64


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))



if cocotb.SIM_NAME:

    for test in [
        # run_test_dat_lost,
        run_test_input_vector
    ]:

        factory = TestFactory(test)
        factory.add_option("payload_lengths", [size_list])
        factory.add_option("payload_data", [incrementing_payload])
        factory.add_option("sort_number", [128])
        # factory.add_option("idle_inserter", [None, cycle_pause])
        # factory.add_option("backpressure_inserter", [None, cycle_pause])
        factory.generate_tests()
