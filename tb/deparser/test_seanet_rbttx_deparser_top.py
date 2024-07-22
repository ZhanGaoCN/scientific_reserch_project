#!/usr/bin/env python
"""

"""

import itertools
import logging
import os

import random

from scapy.layers.l2 import Ether
from scapy.layers.vxlan import VXLAN
from scapy.layers.inet import UDP,IP
from scapy.layers.l2 import Dot1Q
from scapy.layers.inet6 import IPv6
from scapy.all import ARP
from scapy.all import raw
from scapyext.seadp import IDP_Full,IDP_Stealth,IDP_Stealth_INT,IDP_Multi,IDP_Multi_INT,IDP_Cache,IDP_Cache_INT,IDP_RBT_DAT_093,SEATL_COMMON_FIELD_093


import pytest
import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory
from cocotb.binary import BinaryValue
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink,AxiStreamFrame
from cocotbext.axi.stream import define_stream


InputBus, InputTransaction, InputSource, InputSink, InputMonitor = define_stream("s_phv",
    signals=["valid", "ready", "info"]
)


class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.fork(Clock(dut.clk, 8, units="ns").start())

        self.hdr_source = InputSource(InputBus.from_prefix(dut, "s_phv"), dut.clk, dut.rst)
        self.axis_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk, dut.rst)
        self.sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk, dut.rst)


    def set_idle_generator(self, generator=None):
        if generator:
            self.axis_source.set_pause_generator(generator())
            self.hdr_source.set_pause_generator(generator())
            
    def set_backpressure_generator(self, generator=None):
        if generator:
            self.sink.set_pause_generator(generator())

    async def reset(self):
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)

    async def send_dat_hit(self, pkt_axis):
        inputTransaction = InputTransaction()
        phv_val = BinaryValue(n_bits=408, bigEndian=False)
        phv_val[7:0] = 0x87 #pkt_property
        phv_val[15:8] = 0x04 #pkt_valid
        phv_val[23:16] = 0x11 #Inport
        phv_val[31:24] = 0x22 #Outport 
        phv_val[39:32] = 0x33 #IP Offset
        phv_val[47:40] = 0x44 #tid
        phv_val[55:48] = 0x52 #seatl_offset


        phv_val[71:56] = 0x5555 #pkt_Len
        phv_val[87:72] = 0x6666 #Flow Index


        phv_val[407:376] = 0xFFFFFFFF #rpn

        # phv_val[55:48] = 0x0e
        # phv_val[63:56] = 0xba
        # phv_val[71:64] = 0x0
        # phv_val[79:72] = 0x80
        # phv_val[95:80] = len(pkt_axis)
        # phv_val[111:96] = 0x0001
        # phv_val[143:112] = 0x00
        # phv_val[271:144] = 0x08070605040302010807060504030201
        # phv_val[399:272] = 0x88776655443322118877665544332211
        # phv_val[527:400] = 0x00000000000000000000000000000001
        # phv_val[559:528] = 0x00000003
        # phv_val[591:560] = 0x0
        inputTransaction.info = phv_val

        pkt_in_frame = AxiStreamFrame()
        pkt_in_frame.tdata = bytes(pkt_axis)
        # print(pkt_in_frame.tdata)
        # print(pkt_in_frame)
        pkt_in_frame.tuser = 0xabcd # todo here

        await self.hdr_source.send(inputTransaction)
        await self.axis_source.send(pkt_in_frame)

    # async def send_dat_unhit(self, pkt_axis):
    #     inputTransaction = InputTransaction()
    #     phv_val = BinaryValue(n_bits=592, bigEndian=False)
    #     phv_val[7:0] = 0x05
    #     phv_val[15:8] = 0x80
    #     phv_val[23:16] = 0x80
    #     phv_val[31:24] = 0x00
    #     phv_val[39:32] = 0x01
    #     phv_val[47:40] = 0x0
    #     phv_val[55:48] = 0x0e
    #     phv_val[63:56] = 0xba
    #     phv_val[71:64] = 0x0
    #     phv_val[79:72] = 0x80
    #     phv_val[95:80] = len(pkt_axis)
    #     phv_val[111:96] = 0x0001
    #     phv_val[143:112] = 0x00
    #     phv_val[271:144] = 0x08070605040302010807060504030201
    #     phv_val[399:272] = 0x88776655443322118877665544332211
    #     phv_val[527:400] = 0x00000000000000000000000000000001
    #     phv_val[559:528] = 0x00000003
    #     phv_val[591:560] = 0x0
    #     inputTransaction.info = phv_val

    #     pkt_in_frame = AxiStreamFrame()
    #     pkt_in_frame.tdata = bytes(pkt_axis)
    #     print(pkt_in_frame.tdata)
    #     print(pkt_in_frame)
    #     pkt_in_frame.tuser = (len(pkt_axis)<<32) + 0x05118080

    #     await self.hdr_source.send(inputTransaction)
    #     await self.axis_source.send(pkt_in_frame)

    # async def send_nack_hit(self, pkt_axis):
    #     inputTransaction = InputTransaction()
    #     phv_val = BinaryValue(n_bits=592, bigEndian=False)
    #     phv_val[7:0] = 0x31
    #     phv_val[15:8] = 0x80
    #     phv_val[23:16] = 0x80
    #     phv_val[31:24] = 0x00
    #     phv_val[39:32] = 0x01
    #     phv_val[47:40] = 0x0
    #     phv_val[55:48] = 0x0e
    #     phv_val[63:56] = 0xba
    #     phv_val[71:64] = 0x0
    #     phv_val[79:72] = 0x80
    #     phv_val[95:80] = len(pkt_axis)
    #     phv_val[111:96] = 0x0002
    #     phv_val[143:112] = 0x00
    #     phv_val[271:144] = 0x08070605040302010807060504030201
    #     phv_val[399:272] = 0x88776655443322118877665544332211
    #     phv_val[527:400] = 0x00000000000000000000000000000001
    #     phv_val[559:528] = 0x00000003
    #     phv_val[591:560] = 0x0
    #     inputTransaction.info = phv_val

    #     pkt_in_frame = AxiStreamFrame()
    #     pkt_in_frame.tdata = bytes(pkt_axis)
    #     print(pkt_in_frame.tdata)
    #     print(pkt_in_frame)
    #     pkt_in_frame.tuser = (len(pkt_axis)<<32) + 0x31118080

    #     await self.hdr_source.send(inputTransaction)
    #     await self.axis_source.send(pkt_in_frame)

    # async def send_nack_unhit(self, pkt_axis):
    #     inputTransaction = InputTransaction()
    #     phv_val = BinaryValue(n_bits=592, bigEndian=False)
    #     phv_val[7:0] = 0x11
    #     phv_val[15:8] = 0x80
    #     phv_val[23:16] = 0x80
    #     phv_val[31:24] = 0x00
    #     phv_val[39:32] = 0x01
    #     phv_val[47:40] = 0x0
    #     phv_val[55:48] = 0x0e
    #     phv_val[63:56] = 0xba
    #     phv_val[71:64] = 0x0
    #     phv_val[79:72] = 0x80
    #     phv_val[95:80] = len(pkt_axis)
    #     phv_val[111:96] = 0x0002
    #     phv_val[143:112] = 0x00
    #     phv_val[271:144] = 0x08070605040302010807060504030201
    #     phv_val[399:272] = 0x88776655443322118877665544332211
    #     phv_val[527:400] = 0x00000000000000000000000000000001
    #     phv_val[559:528] = 0x00000003
    #     phv_val[591:560] = 0x0
    #     inputTransaction.info = phv_val

    #     pkt_in_frame = AxiStreamFrame()
    #     pkt_in_frame.tdata = bytes(pkt_axis)
    #     print(pkt_in_frame.tdata)
    #     print(pkt_in_frame)
    #     pkt_in_frame.tuser = (len(pkt_axis)<<32) + 0x31118080

    #     await self.hdr_source.send(inputTransaction)
    #     await self.axis_source.send(pkt_in_frame)

    async def recv(self):
        rx = await self.sink.recv()
        return rx

IDP_PROT = 0x92
TRANSPORT_LAYER_PROT = 0x3

ETH_HEADER_LEN = 14
VLAN_HEADER_LEN=4
PPPOE_HEADER_LEN=8
VLAN_PPPOE_HEADER_LEN=12
IPV6_HEADER_LEN = 40
IDP_HEADER_LEN_FULL = 132

IDP_version = 0x00
SEATL_version = 0x00
IDP_HEADER_LEN_RBT = 28
SEATL_COMMON_FIELD_HEADER_LEN_RBT = 31

async def run_test_dat_hit_093(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_pkts = []
    expect_test_pkts = []
    cnt =0 

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x86dd)
        eth_vlan = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x8100)
        vlan = Dot1Q(vlan = 0x123, type = 0x8864)
        ipv6 = IPv6(nh=IDP_PROT, src = "2001::200", dst = "2001::100", version=6, hlim=255, fl=0, tc=0)
        idp_rbt_dat = IDP_RBT_DAT_093(Version=IDP_version, PType=TRANSPORT_LAYER_PROT, Header_Length=IDP_HEADER_LEN_RBT, IDP_Flags_IrA=0, IDP_Flags_EA=0, IDP_Flags_AuNum=0, IDP_Flags_Reserved=0, 
                  SEAID_n_Type=0x10, SEAID_n_Length=6, srvType=0, RoST=0, QP=0,# value of SEAID_n_Type is not sure
                  Dest_SEAID_n=b"\xEE\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\xFF")
        
        seatl_commom_field = SEATL_COMMON_FIELD_093(Version=SEATL_version, Type=0x00, Header_Length=SEATL_COMMON_FIELD_HEADER_LEN_RBT, SEATL_Flags_X_Trans=1, SEATL_Flags_PS=0, SEATL_Flags_DS=0, SEATL_Flags_SS=0, SEATL_Flags_Reserved=0,
                  X_Trans_Flag=0x80, X_Trans_Para_RPara=0x00, 
                  X_Trans_Para_RSIP=b"\xEE\x11\x22\x33\x44\x55\x66\x77\x88\x99\xAA\xBB\xCC\xDD\xEE\xFF",
                  X_Trans_Para_RPN=b"\xEE\x11\x11\xFF",
                  Packet_Number=b"\xEE\x11\x11\xFF",
                  Checksum=b"\xEE\xFF")
        
        seatl_commom_field_modify = SEATL_COMMON_FIELD_093(Version=SEATL_version, Type=0x00, Header_Length=SEATL_COMMON_FIELD_HEADER_LEN_RBT, SEATL_Flags_X_Trans=1, SEATL_Flags_PS=0, SEATL_Flags_DS=0, SEATL_Flags_SS=0, SEATL_Flags_Reserved=0,
                  X_Trans_Flag=0x80, X_Trans_Para_RPara=0x00, 
                  X_Trans_Para_RSIP=b"\xEE\x11\x22\x33\x44\x55\x66\x77\x88\x99\xAA\xBB\xCC\xDD\xEE\xFF",
                  X_Trans_Para_RPN=b"\xFF\xFF\xFF\xFF",
                  Packet_Number=b"\xEE\x11\x11\xFF",
                  Checksum=b"\xEE\xFF")
    

        # rpn = raw([0xab,0xcd,0xab,0xcd])
        # expect_rpn = raw([0x00,0x00,0x00,0x03])
        # / payload / rawpkt_seq 
        rawpkt_seq =  str(cnt)
        test_pkt = eth / ipv6 / idp_rbt_dat / seatl_commom_field 
        expect_test_pkt = eth / ipv6 / idp_rbt_dat / seatl_commom_field_modify 
        await tb.send_dat_hit(test_pkt)
        # cnt = cnt + 1

        test_pkts.append(test_pkt)
        expect_test_pkts.append(expect_test_pkt)

        rx = await tb.recv()
    for expect_test_pkt in expect_test_pkts:

        print("test_pkt:",test_pkt)
        print(rx.tdata)
        print(expect_test_pkt)        
        # assert rx.tdata == expect_test_pkt 
        assert bytes(rx.tdata) == bytes(expect_test_pkt)   

        expect_tuser = 0x856666ba555533442211
#-------------------------------------------------------------old version test below------------------------------------------#
async def run_test_dat_hit(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_pkts = []
    expect_test_pkts = []
    cnt =0 

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x86dd)
        eth_vlan = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x8100)
        vlan = Dot1Q(vlan = 0x123, type = 0x8864)
        ipv6 = IPv6(nh=IDP_PROT, src = "2001::200", dst = "2001::100", version=6, hlim=255, fl=0, tc=0)
        idp_full = IDP_Full(next_header=TRANSPORT_LAYER_PROT, header_length=IDP_HEADER_LEN_FULL, dst_seaid_type=0, src_seaid_type=0, dst_seaid_len=6, src_seaid_len=6,
                  service_type=0, route_policy=0, queue_priority=0, ira=0, ira_param_0=0, ira_param_1=1,
                  ira_param_2=2, ira_param_3=3, ira_param_4=4, ira_param_5=5, ira_param_6=6, ira_param_7=7, reserved=0x8, flag=0x1,
                  dst_seaid=b"\xEE\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\xFF",
                  src_seaid=b"\xEE\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\xFF",
                  ext_addr=b"\xEE\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\xFF",
                  option_a=b"\xEE\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xFF",
                  option_b=b"\xEE\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xFF",
                  option_c=b"\xEE\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xFF",
                  option_d=b"\xEE\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xFF")

        public_header_seasp = raw([0x03,0x00])
        public_header_seadp = raw([0x01,0x20,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
        public_header_seaup = raw([0x01,0x40,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
        
        seasp = raw([0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x20,0x00,0x80,0x00,0x00,0x00,0x00,0x00,0x00,
                      0xaa,0xaa,0xaa,0xaa,0xbb,0xbb,0xbb,0xbb,
                      0xcc,0xcc,0xcc,0xcc,0xdd,0xdd,0xdd,0xdd,
                      0xab,0xcd,0xab,0xcd])
        
        seasp_modify = raw([0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x20,0x00,0x80,0x00,0x00,0x00,0x00,0x00,0x00,
                      0xaa,0xaa,0xaa,0xaa,0xbb,0xbb,0xbb,0x0,
                      0x0,0x0,0x0,0xcc,0xdd,0xdd,0xdd,0xdd,
                      0xab,0xcd,0xab,0xcd])

        # rpn = raw([0xab,0xcd,0xab,0xcd])
        # expect_rpn = raw([0x00,0x00,0x00,0x03])
        
        rawpkt_seq =  str(cnt)
        test_pkt = eth / ipv6 / idp_full / public_header_seasp / seasp
        expect_test_pkt = eth / ipv6 / idp_full / public_header_seasp / seasp_modify

        await tb.send_dat_hit(test_pkt)
        # cnt = cnt + 1

        test_pkts.append(test_pkt)
        expect_test_pkts.append(expect_test_pkt)

        rx = await tb.recv()
    for expect_test_pkt in expect_test_pkts:

        print(rx.tdata)
        print(expect_test_pkt)        
        # assert rx.tdata == expect_test_pkt 
        assert bytes(rx.tdata) == bytes(expect_test_pkt)   

        expect_tuser = 0x856666ba555533442211
        # print(len(expect_test_pkt))

        # bytes_val = expect_tuser.to_bytes(9, 'big')
        # bytes_val_1 = rx.tuser.to_bytes(9, 'big')
        # print(bytes_val_1)
        # print(bytes_val)
        # assert rx.tuser== expect_tuser ###
        # cnt = cnt + 1

    # assert tb.axis_source.empty()
    # assert tb.hdr_source.empty()
    # assert tb.sink.empty()

    # await RisingEdge(dut.clk)
    # await RisingEdge(dut.clk)

async def run_test_dat_unhit(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_pkts = []
    cnt =0 

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x86dd)
        eth_vlan = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x8100)
        vlan = Dot1Q(vlan = 0x123, type = 0x8864)
        ipv6 = IPv6(nh=IDP_PROT, src = "2001::200", dst = "2001::100", version=6, hlim=255, fl=0, tc=0)
        idp_full = IDP_Full(next_header=TRANSPORT_LAYER_PROT, header_length=IDP_HEADER_LEN_FULL, dst_seaid_type=0, src_seaid_type=0, dst_seaid_len=6, src_seaid_len=6,
                  service_type=0, route_policy=0, queue_priority=0, ira=0, ira_param_0=0, ira_param_1=1,
                  ira_param_2=2, ira_param_3=3, ira_param_4=4, ira_param_5=5, ira_param_6=6, ira_param_7=7, reserved=0x8, flag=0x1,
                  dst_seaid=b"\xEE\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\xFF",
                  src_seaid=b"\xEE\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\xFF",
                  ext_addr=b"\xEE\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\xFF",
                  option_a=b"\xEE\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xFF",
                  option_b=b"\xEE\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xFF",
                  option_c=b"\xEE\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xFF",
                  option_d=b"\xEE\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xFF")

        public_header_seasp = raw([0x01,0x60,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
        public_header_seadp = raw([0x01,0x20,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
        public_header_seaup = raw([0x01,0x40,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
        
        seasp = raw([0x20,0x00,0x80,0x00,0x00,0x00,0x00,0x00,0x00,
                      0xaa,0xaa,0xaa,0xaa,0xbb,0xbb,0xbb,0x0,
                      0x0,0x0,0x0,0xcc,0xdd,0xdd,0xdd,0xdd,
                      0xab,0xcd,0xab,0xcd])
        
        rawpkt_seq =  str(cnt)
        test_pkt = eth / ipv6 / idp_full / public_header_seasp / seasp / payload / rawpkt_seq

        await tb.send_dat_unhit(test_pkt)
        cnt = cnt + 1

        test_pkts.append(test_pkt)

    for test_pkt in test_pkts:
        rx = await tb.recv()
        print(bytes(rx.tdata))
        
        assert bytes(rx.tdata) == bytes(test_pkt)   

        expect_tuser = (0x00ba0001<<48)+(len(test_pkt)<<32) + 0x050e8080
        print(len(test_pkt))

        bytes_val = expect_tuser.to_bytes(9, 'big')
        bytes_val_1 = rx.tuser.to_bytes(9, 'big')
        print(bytes_val_1)
        print(bytes_val)
        assert rx.tuser== expect_tuser
        cnt = cnt + 1

    assert tb.axis_source.empty()
    assert tb.hdr_source.empty()
    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

async def run_test_nack_hit(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_pkts = []
    cnt =0 

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x86dd)
        eth_vlan = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x8100)
        vlan = Dot1Q(vlan = 0x123, type = 0x8864)
        ipv6 = IPv6(nh=IDP_PROT, src = "2001::200", dst = "2001::100", version=6, hlim=255, fl=0, tc=0)
        idp_full = IDP_Full(next_header=TRANSPORT_LAYER_PROT, header_length=IDP_HEADER_LEN_FULL, dst_seaid_type=0, src_seaid_type=0, dst_seaid_len=6, src_seaid_len=6,
                  service_type=0, route_policy=0, queue_priority =0, ira=0, ira_param_0=0, ira_param_1=1,
                  ira_param_2=2, ira_param_3=3, ira_param_4=4, ira_param_5=5, ira_param_6=6, ira_param_7=7, reserved=0x8, flag=0x1,
                  dst_seaid=b"\xEE\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\xFF",
                  src_seaid=b"\xEE\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\xFF",
                  ext_addr=b"\xEE\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\xFF",
                  option_a=b"\xEE\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xFF",
                  option_b=b"\xEE\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xFF",
                  option_c=b"\xEE\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xFF",
                  option_d=b"\xEE\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xFF")

        public_header_seasp = raw([0x01,0x60,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
        public_header_seadp = raw([0x01,0x20,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
        public_header_seaup = raw([0x01,0x40,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
        
        seasp = raw([0x20,0x00,0x80,0x00,0x00,0x00,0x00,0x00,0x00,
                      0xaa,0xaa,0xaa,0xaa,0xbb,0xbb,0xbb,0xbb,
                      0xcc,0xcc,0xcc,0xcc,0xdd,0xdd,0xdd,0xdd,
                      0xab,0xcd,0xab,0xcd])
        
        rawpkt_seq =  str(cnt)
        test_pkt = eth / ipv6 / idp_full / public_header_seasp / seasp / payload / rawpkt_seq

        await tb.send_nack_hit(test_pkt)
        cnt = cnt + 1

        test_pkts.append(test_pkt)

    for test_pkt in test_pkts:
        rx = await tb.recv()
        print(bytes(rx.tdata))
        
        assert bytes(rx.tdata) == bytes(test_pkt)   

        expect_tuser = (0x00ba0002<<48)+(len(test_pkt)<<32) + 0x310e8080
        print(len(test_pkt))

        bytes_val = expect_tuser.to_bytes(9, 'big')
        bytes_val_1 = rx.tuser.to_bytes(9, 'big')
        print(bytes_val_1)
        print(bytes_val)
        assert rx.tuser== expect_tuser
        cnt = cnt + 1

    assert tb.axis_source.empty()
    assert tb.hdr_source.empty()
    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

async def run_test_nack_unhit(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_pkts = []
    cnt =0 

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x86dd)
        eth_vlan = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x8100)
        vlan = Dot1Q(vlan = 0x123, type = 0x8864)
        ipv6 = IPv6(nh=IDP_PROT, src = "2001::200", dst = "2001::100", version=6, hlim=255, fl=0, tc=0)
        idp_full = IDP_Full(next_header=TRANSPORT_LAYER_PROT, header_length=IDP_HEADER_LEN_FULL, dst_seaid_type=0, src_seaid_type=0, dst_seaid_len=6, src_seaid_len=6,
                  service_type=0, route_policy=0, queue_priority=0, ira=0, ira_param_0=0, ira_param_1=1,
                  ira_param_2=2, ira_param_3=3, ira_param_4=4, ira_param_5=5, ira_param_6=6, ira_param_7=7, reserved=0x8, flag=0x1,
                  dst_seaid=b"\xEE\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\xFF",
                  src_seaid=b"\xEE\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\xFF",
                  ext_addr=b"\xEE\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\xFF",
                  option_a=b"\xEE\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xFF",
                  option_b=b"\xEE\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xFF",
                  option_c=b"\xEE\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xFF",
                  option_d=b"\xEE\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xFF")

        public_header_seasp = raw([0x01,0x60,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
        public_header_seadp = raw([0x01,0x20,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
        public_header_seaup = raw([0x01,0x40,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
        
        seasp = raw([0x20,0x00,0x80,0x00,0x00,0x00,0x00,0x00,0x00,
                      0xaa,0xaa,0xaa,0xaa,0xbb,0xbb,0xbb,0xbb,
                      0xcc,0xcc,0xcc,0xcc,0xdd,0xdd,0xdd,0xdd,
                      0xab,0xcd,0xab,0xcd])
        
        rawpkt_seq =  str(cnt)
        test_pkt = eth / ipv6 / idp_full / public_header_seasp / seasp / payload / rawpkt_seq

        await tb.send_nack_unhit(test_pkt)
        cnt = cnt + 1

        test_pkts.append(test_pkt)

    for test_pkt in test_pkts:
        rx = await tb.recv()
        print(bytes(rx.tdata))
        
        assert bytes(rx.tdata) == bytes(test_pkt)   

        expect_tuser = (0x00ba0002<<48)+(len(test_pkt)<<32) + 0x110e8080
        print(len(test_pkt))

        bytes_val = expect_tuser.to_bytes(9, 'big')
        bytes_val_1 = rx.tuser.to_bytes(9, 'big')
        print(bytes_val_1)
        print(bytes_val)
        assert rx.tuser== expect_tuser
        cnt = cnt + 1

    assert tb.axis_source.empty()
    assert tb.hdr_source.empty()
    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])

def size_list():
    return list(range(32))

def incrementing_payload(length):
    return bytes(itertools.islice(itertools.cycle(range(256)), length))


if cocotb.SIM_NAME:
	for test in [
				run_test_dat_hit_093,
                # run_test_dat_hit, 
                # run_test_dat_unhit, 
                # run_test_nack_hit, 
                # run_test_nack_unhit, 

				]:
                factory = TestFactory(test)
                factory.add_option("payload_lengths", [size_list])
                factory.add_option("payload_data", [incrementing_payload])
                factory.add_option("idle_inserter", [None, cycle_pause])
                factory.add_option("backpressure_inserter", [None, cycle_pause])
                factory.generate_tests()
