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
from cocotbext.axi.stream import define_stream
from cocotb.binary import BinaryValue, BinaryRepresentation
from cocotbext.axi import AxiReadBus, AxiRamRead
from cocotbext.axi import AxiWriteBus, AxiRamWrite
from cocotbext.axi import AxiBus, AxiMaster, AxiRam
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame,  AxiBus, AxiSlave, MemoryRegion
from cocotb.binary import BinaryValue, BinaryRepresentation

DeparserBus, DeparserTransaction, DeparserSource, DeparserSink, DeparserMonitor = define_stream("Deparser",
    signals=["info", "bitmap", "init_npn", "valid", "ready"]
)


# DST_MAC_OFFSET = 0
# DST_MAC_WIDTH = 48
# SRC_MAC_OFFSET = DST_MAC_OFFSET + DST_MAC_WIDTH
# SRC_MAC_WIDTH = 48
# ETH_TYPE_OFFSET = SRC_MAC_OFFSET + SRC_MAC_WIDTH
# ETH_TYPE_WIDTH = 16
# VLAN_OFFSET = ETH_TYPE_OFFSET + ETH_TYPE_WIDTH
# VLAN_WIDTH = 32
# PPPOE_OFFSET = VLAN_OFFSET + VLAN_WIDTH
# PPPOE_WIDTH = 48
# PPP_OFFSET = PPPOE_OFFSET + PPPOE_WIDTH
# PPP_WIDTH = 16
# SRC_IP_OFFSET = PPP_OFFSET + PPP_WIDTH
# SRC_IP_WIDTH = 128
# DST_IP_OFFSET = SRC_IP_OFFSET + SRC_IP_WIDTH
# DST_IP_WIDTH = 128
# INPORT_OFFSET = DST_IP_OFFSET + DST_IP_WIDTH
# INPORT_WIDTH = 8
# RESERVED_OFFSET = INPORT_OFFSET + INPORT_WIDTH
# RESERVED_WIDTH = 40


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

class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

        self.deparser_source = DeparserSource(DeparserBus.from_prefix(dut, "s_nack_gen"), dut.clk, dut.rst)

        self.axis_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk, dut.rst)

    def set_idle_generator(self, generator=None):
        if generator:
            self.deparser_source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axis_sink.set_pause_generator(generator())

    async def reset(self):
        self.dut.rst.setimmediatevalue(0)
        for _ in range(0,8):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        for _ in range(0,8):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        for _ in range(0,8):
            await RisingEdge(self.dut.clk)

    def build_info(self,dst_mac,src_mac, vlan_id,src_ip,dst_ip,inport):
        dst_mac %= 1 << DST_MAC_WIDTH
        src_mac %= 1 << SRC_MAC_WIDTH
        vlan_id %= 1 << VLAN_ID_WIDTH
        src_ip %= 1 << SRC_IP_WIDTH
        dst_ip %= 1 << DST_IP_WIDTH
        inport %= 1 << INPORT_WIDTH
        # info = (reserved << EXPRPN_OFFSET | inport << PKTRPN_OFFSET | dst_ip << DST_IP_OFFSET | src_ip << SRC_IP_OFFSET | p2p << PPP_OFFSET | pppoe << PPPOE_OFFSET | vlan << VLAN_OFFSET | eth_type << ETH_TYPE_OFFSET | src_mac << SRC_MAC_OFFSET | dst_mac << DST_MAC_OFFSET )
        info = (dst_mac << DST_MAC_OFFSET | src_mac << SRC_MAC_OFFSET |vlan_id << VLAN_ID_OFFSET| src_ip << SRC_IP_OFFSET | dst_ip << DST_IP_OFFSET | inport << INPORT_OFFSET)
        return info

    async def send_req(self, info, bitmap,init_npn):
        request = DeparserTransaction()
        request.info = info
        request.init_npn = init_npn
        request.bitmap = bitmap
        await self.deparser_source.send(request)

async def run_test_vlan(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_frames_list = []

    req_num = list(range(0,64))
    for req_index in req_num:

        inport =0x44
        vlan_id =0x8003
        vlan_assert = 0x0003
        src_mac =0xffee_ddcc_bbaa
        dst_mac =0x6655_4433_2211
        dst_ip = 0x1234_5612_3456_1234_5612_3456_1234_5612
        src_ip = 0xabcd_abcd_abcd_abcd_abcd_abcd_abcd_abcd
        info = tb.build_info(dst_mac,src_mac, vlan_id,src_ip,dst_ip,inport)
        print("----------------------------------------info info info info info-----------------------------------")
        print(info.to_bytes(64,'big'))
        bitmap = random.randint(0, 1023)
        init_npn = random.randint(0, 1023)

        await tb.send_req(info, bitmap,init_npn)
        tb.log.debug(f"send req : cnt = {(req_index)}; info = {(info)}; bitmap = {(bitmap)}; init_npn = {(init_npn)};")

        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

    # for j, test_frame in enumerate(test_frames_list):
    # for j in range(4):
        recv_pkt = await tb.axis_sink.recv()
        tb.log.debug(f"recv pkt : cnt = {(req_index)};")
    # assert 
        packet = bytes(recv_pkt)
        user = recv_pkt.tuser
        user1 = user.to_bytes(4,'big') 
        # ssign nack_with_valn_pppoe =   {padding_reg,
        #                              init_npn_reg, npn_num_reg,
        #                              seasp_packet_number_reg, seasp_checksum_reg, seasp_length_reg, seasp_type_reg, seasp_version_reg,
        #                              per_dst_src_id_reg, sea_id_length_reg, sea_id_type_reg, idp_header_length_reg, idp_next_header_reg, 
        #                              dst_ip_reg, src_ip_reg, hop_limit_reg, next_header_reg, payload_length_reg, version_traffic_flow_reg, 
        #                              p2p_reg, pppoe_reg, type_and_length_reg, vlan_id_reg, eth_type_reg, src_mac_reg, dst_mac_reg};
        
        HDR_DST_MAC_OFFSET = 0
        HDR_DST_MAC_WIDTH = 48
        HDR_SRC_MAC_OFFSET = HDR_DST_MAC_OFFSET + HDR_DST_MAC_WIDTH
        HDR_SRC_MAC_WIDTH = 48
        HDR_ETH_TYPE_OFFSET = HDR_SRC_MAC_OFFSET + HDR_SRC_MAC_WIDTH
        HDR_ETH_TYPE_WIDTH = 16
        HDR_VLAN_OFFSET = HDR_ETH_TYPE_OFFSET + HDR_ETH_TYPE_WIDTH
        HDR_VLAN_WIDTH = 0 

        if (vlan_id & 0x8000 == 0x8000):
           HDR_VLAN_WIDTH = 16
           VLAN_TYPE_WIDTH  = 16 

        if  (vlan_id & 0x8000 != 0x8000):
           HDR_VLAN_WIDTH = 0 
           VLAN_TYPE_WIDTH  = 0 
        HDR_IP_OFFSET = 14*8+HDR_VLAN_WIDTH+VLAN_TYPE_WIDTH
        HDR_DST_IP_OFFSET = HDR_IP_OFFSET + 64
        HDR_DST_IP_WIDTH = 128
        HDR_SRC_IP_OFFSET = HDR_DST_IP_OFFSET + HDR_DST_IP_WIDTH
        HDR_SRC_IP_WIDTH = 128
        HDR_SCMP_OFFSET = 14*8+40*8+HDR_VLAN_WIDTH+VLAN_TYPE_WIDTH
        INIT_NPN_OFFSET = HDR_SCMP_OFFSET + 32
        BITMAP_OFFSET = HDR_SCMP_OFFSET + 32+32
        BITMAP_WIDTH = 64
        INIT_NPN_WIDTH = 32
        
        # print(f"\n\nmac:{dst_mac}\n\n{dst_mac.to_bytes(6,'big')}\n\n")
        # print(f"\n\ntuser:{user}\n\n")
        # print(user)
        # print(f"PPP_width={PPP_WIDTH},\npppoe={PPPOE_WIDTH},\nvlan_width={VLAN_WIDTH}\n")
        
        assert packet[0:int(HDR_DST_MAC_WIDTH/8)] == dst_mac.to_bytes(6,'big')
        assert packet[int(HDR_SRC_MAC_OFFSET/8):int(HDR_SRC_MAC_WIDTH/8+HDR_SRC_MAC_OFFSET/8)] == src_mac.to_bytes(6,'big')
        assert packet[int(HDR_VLAN_OFFSET/8):int(HDR_VLAN_WIDTH/8+HDR_VLAN_OFFSET/8)] == vlan_assert.to_bytes(2,'big')
        assert packet[int(HDR_SRC_IP_OFFSET/8):int(HDR_SRC_IP_WIDTH/8+HDR_SRC_IP_OFFSET/8)] == src_ip.to_bytes(16,'big')
        assert packet[int(HDR_DST_IP_OFFSET/8):int(HDR_DST_IP_WIDTH/8+HDR_DST_IP_OFFSET/8)] == dst_ip.to_bytes(16,'big')
        assert user1[3].to_bytes(1,"big") == inport.to_bytes(1,'big')
        assert packet[int(INIT_NPN_OFFSET/8):int(INIT_NPN_WIDTH/8+INIT_NPN_OFFSET/8)] == init_npn.to_bytes(4,'big')
        assert packet[int((BITMAP_OFFSET)/8):int(BITMAP_WIDTH/8+BITMAP_OFFSET/8)] == bitmap.to_bytes(8,'big')

        assert tb.deparser_source.empty()
        assert tb.axis_sink.empty()
async def run_test(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_frames_list = []

    req_num = list(range(0,64))
    for req_index in req_num:

        inport =0x44
        vlan_id =0x0003
        vlan_assert = 0x0003
        src_mac =0xffee_ddcc_bbaa
        dst_mac =0x6655_4433_2211
        dst_ip = 0x1234_5612_3456_1234_5612_3456_1234_5612
        src_ip = 0xabcd_abcd_abcd_abcd_abcd_abcd_abcd_abcd
        info = tb.build_info(dst_mac,src_mac, vlan_id,src_ip,dst_ip,inport)
        print("----------------------------------------info info info info info-----------------------------------")
        print(info.to_bytes(64,'big'))
        bitmap = random.randint(0, 1023)
        init_npn = random.randint(0, 1023)

        await tb.send_req(info, bitmap,init_npn)
        tb.log.debug(f"send req : cnt = {(req_index)}; info = {(info)}; bitmap = {(bitmap)}; init_npn = {(init_npn)};")

        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

    # for j, test_frame in enumerate(test_frames_list):
    # for j in range(4):
        recv_pkt = await tb.axis_sink.recv()
        tb.log.debug(f"recv pkt : cnt = {(req_index)};")
    # assert 
        packet = bytes(recv_pkt)
        user = recv_pkt.tuser
        user1 = user.to_bytes(4,'big') 
        # ssign nack_with_valn_pppoe =   {padding_reg,
        #                              init_npn_reg, npn_num_reg,
        #                              seasp_packet_number_reg, seasp_checksum_reg, seasp_length_reg, seasp_type_reg, seasp_version_reg,
        #                              per_dst_src_id_reg, sea_id_length_reg, sea_id_type_reg, idp_header_length_reg, idp_next_header_reg, 
        #                              dst_ip_reg, src_ip_reg, hop_limit_reg, next_header_reg, payload_length_reg, version_traffic_flow_reg, 
        #                              p2p_reg, pppoe_reg, type_and_length_reg, vlan_id_reg, eth_type_reg, src_mac_reg, dst_mac_reg};
        
        HDR_DST_MAC_OFFSET = 0
        HDR_DST_MAC_WIDTH = 48
        HDR_SRC_MAC_OFFSET = HDR_DST_MAC_OFFSET + HDR_DST_MAC_WIDTH
        HDR_SRC_MAC_WIDTH = 48
        HDR_ETH_TYPE_OFFSET = HDR_SRC_MAC_OFFSET + HDR_SRC_MAC_WIDTH
        HDR_ETH_TYPE_WIDTH = 16
        HDR_VLAN_OFFSET = HDR_ETH_TYPE_OFFSET + HDR_ETH_TYPE_WIDTH
        HDR_VLAN_WIDTH = 0 

        if (vlan_id & 0x8000 == 0x8000):
           HDR_VLAN_WIDTH = 16
           VLAN_TYPE_WIDTH  = 16 

        if  (vlan_id & 0x8000 != 0x8000):
           HDR_VLAN_WIDTH = 0 
           VLAN_TYPE_WIDTH  = 0 
        HDR_IP_OFFSET = 14*8+HDR_VLAN_WIDTH+VLAN_TYPE_WIDTH
        HDR_DST_IP_OFFSET = HDR_IP_OFFSET + 64
        HDR_DST_IP_WIDTH = 128
        HDR_SRC_IP_OFFSET = HDR_DST_IP_OFFSET + HDR_DST_IP_WIDTH
        HDR_SRC_IP_WIDTH = 128
        HDR_SCMP_OFFSET = 14*8+40*8+HDR_VLAN_WIDTH+VLAN_TYPE_WIDTH
        INIT_NPN_OFFSET = HDR_SCMP_OFFSET + 32
        BITMAP_OFFSET = HDR_SCMP_OFFSET + 32+32
        BITMAP_WIDTH = 64
        INIT_NPN_WIDTH = 32
        
        # print(f"\n\nmac:{dst_mac}\n\n{dst_mac.to_bytes(6,'big')}\n\n")
        # print(f"\n\ntuser:{user}\n\n")
        # print(user)
        # print(f"PPP_width={PPP_WIDTH},\npppoe={PPPOE_WIDTH},\nvlan_width={VLAN_WIDTH}\n")
        
        assert packet[0:int(HDR_DST_MAC_WIDTH/8)] == dst_mac.to_bytes(6,'big')
        assert packet[int(HDR_SRC_MAC_OFFSET/8):int(HDR_SRC_MAC_WIDTH/8+HDR_SRC_MAC_OFFSET/8)] == src_mac.to_bytes(6,'big')
        # assert packet[int(HDR_VLAN_OFFSET/8):int(HDR_VLAN_WIDTH/8+HDR_VLAN_OFFSET/8)] == vlan_assert.to_bytes(2,'big')
        assert packet[int(HDR_SRC_IP_OFFSET/8):int(HDR_SRC_IP_WIDTH/8+HDR_SRC_IP_OFFSET/8)] == src_ip.to_bytes(16,'big')
        assert packet[int(HDR_DST_IP_OFFSET/8):int(HDR_DST_IP_WIDTH/8+HDR_DST_IP_OFFSET/8)] == dst_ip.to_bytes(16,'big')
        assert user1[3].to_bytes(1,"big") == inport.to_bytes(1,'big')
        assert packet[int(INIT_NPN_OFFSET/8):int(INIT_NPN_WIDTH/8+INIT_NPN_OFFSET/8)] == init_npn.to_bytes(4,'big')
        assert packet[int((BITMAP_OFFSET)/8):int(BITMAP_WIDTH/8+BITMAP_OFFSET/8)] == bitmap.to_bytes(8,'big')

        assert tb.deparser_source.empty()
        assert tb.axis_sink.empty()

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
        run_test_vlan,
        run_test
    ]:

        factory = TestFactory(test)
        factory.add_option("payload_lengths", [size_list])
        factory.add_option("payload_data", [incrementing_payload])
        factory.add_option("idle_inserter", [None, cycle_pause])
        factory.add_option("backpressure_inserter", [None, cycle_pause])
        factory.generate_tests()
