#!/usr/bin/env python
"""

"""

import itertools
import logging
import os

from scapy.layers.l2 import Ether
from scapy.layers.l2 import Dot1Q
from scapy.layers.vxlan import VXLAN
from scapy.layers.inet import UDP,IP
from scapy.layers.inet6 import IPv6
from scapy.all import raw
from scapyext.seadp import IDP_Full,IDP_RBT_DAT_093,SEATL_COMMON_FIELD_093,SCMP_RBT_NACK_093,IDP_Stealth,IDP_Stealth_INT,IDP_Multi,IDP_Multi_INT,IDP_Cache,IDP_Cache_INT


import pytest
import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory
from cocotb.binary import BinaryValue
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource, AxiStreamSink
from cocotbext.axi.stream import define_stream

OutputBus, OutputTransaction, OutputSource, OutputSink, OutputMonitor = define_stream("Output",
    signals=["valid", "ready", "info"]
)
   
class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.fork(Clock(dut.clk, 8, units="ns").start())

        self.data_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk, dut.rst)
        self.data_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk, dut.rst)
        self.phv_sink = OutputSink(OutputBus.from_prefix(dut, "m_phv"), dut.clk, dut.rst)


    def set_idle_generator(self, generator=None):
        if generator:
            self.data_source.set_pause_generator(generator())
            
    def set_backpressure_generator(self, generator=None):
        if generator:
            self.phv_sink.set_pause_generator(generator())
            self.data_sink.set_pause_generator(generator())

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

    async def send(self, pkt, tuser):
        test_frame = AxiStreamFrame()
        test_frame.tdata = bytes(pkt)
        test_frame.tuser = tuser
        await self.data_source.send(test_frame)

    async def recv(self):
        rx_packet = await self.data_sink.recv()
        rx_header = await self.phv_sink.recv()
        return rx_header

IDP_PROT = 0x92
TRANSPORT_LAYER_PROT = 0x02 #means next protocol is SEAUP
IDP_version = 0x00
SEATL_version = 0x00
ETH_HEADER_LEN = 14
VLAN_HEADER_LEN=4
PPPOE_HEADER_LEN=8
VLAN_PPPOE_HEADER_LEN=12
IPV6_HEADER_LEN = 40
IDP_HEADER_LEN_FULL = 208 #define id_length as 20 Bytes
IDP_HEADER_LEN_RBT = 40
SEATL_COMMON_FIELD_HEADER_LEN_RBT = 32
IDP_HEADER_LEN_STEALTH = 52
IDP_HEADER_LEN_STEALTH_INT = 100
IDP_HEADER_LEN_MULTI = 84

PUBLIC_HEADER_LEN = 10
UDP_HEADER_LEN = 8
PHV_WIDTH = 408

#B 8bit
PKT_PROPERTY_NO = 0
PKT_VALID_NO = 1
INPORT_NO = 2
OUTPORT_NO = 3
IP_OFFSET_NO = 4
TID_NO = 5
SEATL_OFFSET_NO = 6

#H 16bit
PKT_LEN_NO = 0
FLOW_INDEX_NO = 1

#W 32bit
PROTOCOL_NO = 0
DSTIP1_NO = 1
DSTIP2_NO = 2
DSTIP3_NO = 3
DSTIP4_NO = 4
RSIP1_NO = 5
RSIP2_NO = 6
RSIP3_NO = 7
RSIP4_NO = 8
PKT_RPN_NO = 9


def convert(phv_b,phv_h,phv_w):
    phv_b_count=int(os.getenv("PARAM_PHV_B_COUNT", "7"))
    phv_h_count=int(os.getenv("PARAM_PHV_H_COUNT", "2"))
    phv_w_count=int(os.getenv("PARAM_PHV_B_COUNT", "10"))
    phv_width=int(os.getenv("PARAM_PHV_WIDTH", "408"))
    phv_length=int(phv_width/8)
    phv_val = BinaryValue(n_bits=phv_width, bigEndian=False) #host sequence little: generate little endian
    for i in range(phv_b_count):
        phv_val[i*8+7:i*8] = phv_b[i]          # 0 ~ 512

    for i in range(phv_h_count):
        phv_val[(phv_b_count+2*i)*8+7:(phv_b_count+2*i)*8+0] = phv_h[i].to_bytes(2, 'little')[0]
        phv_val[(phv_b_count+2*i)*8+15:(phv_b_count+2*i)*8+8] = phv_h[i].to_bytes(2, 'little')[1]      # 512 ~ 1088

    for i in range(phv_w_count):
        phv_val[(phv_b_count+phv_h_count*2+4*i)*8+7:(phv_b_count+phv_h_count*2+4*i)*8+0] = phv_w[i].to_bytes(4, 'little')[0]
        phv_val[(phv_b_count+phv_h_count*2+4*i)*8+15:(phv_b_count+phv_h_count*2+4*i)*8+8] = phv_w[i].to_bytes(4, 'little')[1]
        phv_val[(phv_b_count+phv_h_count*2+4*i)*8+23:(phv_b_count+phv_h_count*2+4*i)*8+16] = phv_w[i].to_bytes(4, 'little')[2]
        phv_val[(phv_b_count+phv_h_count*2+4*i)*8+31:(phv_b_count+phv_h_count*2+4*i)*8+24] = phv_w[i].to_bytes(4, 'little')[3]       #1088 ~ 592

    return phv_val



async def run_test_rbt_dat(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_results = []
    seq = 1

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x86dd)
        ipv6 = IPv6(nh=IDP_PROT, src = "2001::200", dst = "5001::0001:0001", version=6, hlim=255, fl=0, tc=0)
        idp_rbt_dat_093 = IDP_RBT_DAT_093(Version=IDP_version, PType=TRANSPORT_LAYER_PROT, Header_Length=IDP_HEADER_LEN_RBT, IDP_Flags_IrA=0, IDP_Flags_EA=1, IDP_Flags_AuNum=0, IDP_Flags_Reserved=0, 
                  SEAID_n_Type=0x10, SEAID_n_Length=5, srvType=0, RoST=0, QP=0,
                  Dest_SEAID_n=b"\xEE\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\xFF",
                  ext_addr=b"\x20\x01\x11\x22\x33\x44\x55\x66\x77\x88\x99\xAA\xBB\xCC\x11\x00")
        
        seatl_commom_field = SEATL_COMMON_FIELD_093(Version=SEATL_version, Type=0x00, Header_Length=SEATL_COMMON_FIELD_HEADER_LEN_RBT, SEATL_Flags_X_Trans=1, SEATL_Flags_PS=0, SEATL_Flags_DS=0, SEATL_Flags_SS=0, SEATL_Flags_Reserved=0,
                  X_Trans_Flag=0x80, X_Trans_Para_RPara=0x00, 
                  X_Trans_Para_RSIP=b"\x70\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x01",
                  X_Trans_Para_RPN=b"\xEE\x11\x11\xFE",
                  Packet_Number=b"\xEE\x11\x11\xFF",
                  Checksum=b"\xEE\xFF")
        
        # seaup_header: this simulation generator seaup dat packet (without unique seaup_header)
        
        rawpkt_seq =  str(seq)
        test_pkt = eth / ipv6 / idp_rbt_dat_093 / seatl_commom_field / payload / rawpkt_seq

        user_width=int(os.getenv("PARAM_USER_WIDTH", "56"))
        
        test_tuser = 0xdcba_00_05_01_03_02_01

        #------------------------------------------------------#
        #tuser_input_structure_&_values  low bit
        # phv_b_out[INPORT_NO] =0x01
        # phv_b_out[OUTPORT_NO] =0x02
        # phv_b_out[TID_NO] =0x03
        # phv_b_out[PKT_PROPERTY_NO] =0x87(expect when dat hit)
        # phv_b_out[PKT_VALID_NO] =0x85(expect when dat hit)
        # phv_b_out[SEATL_OFFSET_NO] =0x62 #98
        # phv_h_out[PKT_LEN_NO]=0xdcba  highbit
#------------------------------------------------------#
        
        await tb.send(test_pkt, test_tuser)
        seq = seq + 1

        #match start
        phv_b_count=int(os.getenv("PARAM_PHV_B_COUNT", "7"))
        phv_h_count=int(os.getenv("PARAM_PHV_H_COUNT", "2"))
        phv_w_count=int(os.getenv("PARAM_PHV_B_COUNT", "10"))

        phv_b_out = [0] * phv_b_count
        phv_h_out = [0] * phv_h_count
        phv_w_out = [0] * phv_w_count

        phv_b_out[PKT_PROPERTY_NO] =0x87
        phv_b_out[PKT_VALID_NO] =0x85
        phv_b_out[INPORT_NO] =0x01
        phv_b_out[OUTPORT_NO] =0x02
        phv_b_out[IP_OFFSET_NO] =14
        phv_b_out[TID_NO] =0x03
        phv_b_out[SEATL_OFFSET_NO] =0x5E #82
      

        phv_h_out[PKT_LEN_NO]=0xdcba
        phv_h_out[FLOW_INDEX_NO]=0x0000

        phv_w_out[PROTOCOL_NO] =0x2431 #seaup packcet 2431
        phv_w_out[DSTIP1_NO] = 0x00010001
        phv_w_out[DSTIP2_NO] = 0x00000000
        phv_w_out[DSTIP3_NO] = 0x00000000
        phv_w_out[DSTIP4_NO] = 0x50010000

        phv_w_out[RSIP1_NO] = 0x00010001
        phv_w_out[RSIP2_NO] = 0x00000000
        phv_w_out[RSIP3_NO] = 0x00000000
        phv_w_out[RSIP4_NO] = 0x70010000
        phv_w_out[PKT_RPN_NO] = 0xEE1111FE

        test_results.append(convert(phv_b_out,phv_h_out,phv_w_out))



    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    for test_data in test_results:
        rx_header = await tb.recv()
        print(rx_header.info)
        print(test_data)
   
        print(len(test_data))
        for i in range(PHV_WIDTH) :

            assert rx_header.info[i]  == test_data[PHV_WIDTH-1-i]


    assert tb.phv_sink.empty()
    assert tb.data_source.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await tb.reset()
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

async def run_test_rbt_dat_vlan(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_results = []
    seq = 1
    

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x86dd)
        eth_vlan = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x8100)
        vlan = Dot1Q(vlan = 0x123, type = 0x86dd)
        ipv6 = IPv6(nh=IDP_PROT, src = "2001::200", dst = "2001:1122:3344:5566:7788:AABB:CCDD:0100", version=6, hlim=255, fl=0, tc=0)
        idp_rbt_dat_093 = IDP_RBT_DAT_093(Version=IDP_version, PType=TRANSPORT_LAYER_PROT, Header_Length=IDP_HEADER_LEN_RBT, IDP_Flags_IrA=0, IDP_Flags_EA=0, IDP_Flags_AuNum=0, IDP_Flags_Reserved=0, 
                  SEAID_n_Type=0x10, SEAID_n_Length=6, srvType=0, RoST=0, QP=0,# value of SEAID_n_Type is not sure
                  Dest_SEAID_n=b"\xEE\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\xFF")
        
        seatl_commom_field = SEATL_COMMON_FIELD_093(Version=SEATL_version, Type=0x00, Header_Length=SEATL_COMMON_FIELD_HEADER_LEN_RBT, SEATL_Flags_X_Trans=1, SEATL_Flags_PS=0, SEATL_Flags_DS=0, SEATL_Flags_SS=0, SEATL_Flags_Reserved=0,
                  X_Trans_Flag=0x80, X_Trans_Para_RPara=0x00, 
                  X_Trans_Para_RSIP=b"\xEE\x11\x22\x33\x44\x55\x66\x77\x88\x99\xAA\xBB\xCC\xDD\xEE\xFF",
                  X_Trans_Para_RPN=b"\xEE\x11\x11\xFF",
                  Packet_Number=b"\xEE\x11\x11\xFF",
                  Checksum=b"\xEE\xFF")
        
        # seaup_header: this simulation generator seaup dat packet (without unique seaup_header)
        
        rawpkt_seq =  str(seq)
        test_pkt = eth_vlan / vlan / ipv6 / idp_rbt_dat_093 / seatl_commom_field / payload / rawpkt_seq

        user_width=int(os.getenv("PARAM_USER_WIDTH", "56"))
        
        # test_tuser = 0x010203040005ba
        test_tuser = 0xdcba560587030201

        #test_tuser = BinaryValue(n_bits=user_width, bigEndian=False)
        #inport
        #test_tuser[7:0] = 0xd0


        
        await tb.send(test_pkt, test_tuser)
        seq = seq + 1

        #match start
        phv_b_count=int(os.getenv("PARAM_PHV_B_COUNT", "7"))
        phv_h_count=int(os.getenv("PARAM_PHV_H_COUNT", "2"))
        phv_w_count=int(os.getenv("PARAM_PHV_B_COUNT", "10"))

        phv_b_out = [0] * phv_b_count
        phv_h_out = [0] * phv_h_count
        phv_w_out = [0] * phv_w_count

        phv_b_out[PKT_PROPERTY_NO] =0x87
        phv_b_out[PKT_VALID_NO] =0x85
        phv_b_out[INPORT_NO] =0x01
        phv_b_out[OUTPORT_NO] =0x02
        phv_b_out[IP_OFFSET_NO] =18
        phv_b_out[TID_NO] =0x03
        phv_b_out[SEATL_OFFSET_NO] =0x56 #82+4=86
      

        phv_h_out[PKT_LEN_NO]=0xdcba
        phv_h_out[FLOW_INDEX_NO]=0x0000

        phv_w_out[PROTOCOL_NO] =0x2433 #seaup packcet protocol:2431 0010 0100 0011 0011
        phv_w_out[DSTIP1_NO] = 0xCCDD0100
        phv_w_out[DSTIP2_NO] = 0x7788AABB
        phv_w_out[DSTIP3_NO] = 0x33445566
        phv_w_out[DSTIP4_NO] = 0x20011122

        phv_w_out[RSIP1_NO] = 0xCCDDEEFF
        phv_w_out[RSIP2_NO] = 0x8899AABB
        phv_w_out[RSIP3_NO] = 0x44556677
        phv_w_out[RSIP4_NO] = 0xEE112233
        phv_w_out[PKT_RPN_NO] = 0xEE1111FF

        test_results.append(convert(phv_b_out,phv_h_out,phv_w_out))



    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    for test_data in test_results:
        rx_header = await tb.recv()
        print(rx_header.info)
        print(test_data)
   
        print(len(test_data))
        for i in range(PHV_WIDTH) :

            assert rx_header.info[i]  == test_data[PHV_WIDTH-1-i]


    assert tb.phv_sink.empty()
    assert tb.data_source.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await tb.reset()
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

async def run_test_rbt_nack(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_results = []
    seq = 1

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x86dd)
        ipv6 = IPv6(nh=IDP_PROT, src = "2001::200", dst = "2001:1122:3344:5566:7788:AABB:CCDD:0100", version=6, hlim=255, fl=0, tc=0)
        scmpv6 = SCMP_RBT_NACK_093(PType=0x41, Code=0x01, 
                    Checksum=b"\xAA\xBB")

        rawpkt_seq =  str(seq)
        test_pkt = eth / ipv6 / scmpv6 / payload / rawpkt_seq

        user_width=int(os.getenv("PARAM_USER_WIDTH", "56"))
        
        # test_tuser = 0x010203040005ba
        test_tuser = 0xdcba520501030201

        #test_tuser = BinaryValue(n_bits=user_width, bigEndian=False)
        #inport
        #test_tuser[7:0] = 0xd0


        
        await tb.send(test_pkt, test_tuser)
        seq = seq + 1

        #match start
        phv_b_count=int(os.getenv("PARAM_PHV_B_COUNT", "7"))
        phv_h_count=int(os.getenv("PARAM_PHV_H_COUNT", "2"))
        phv_w_count=int(os.getenv("PARAM_PHV_B_COUNT", "10"))

        phv_b_out = [0] * phv_b_count
        phv_h_out = [0] * phv_h_count
        phv_w_out = [0] * phv_w_count

        phv_b_out[PKT_PROPERTY_NO] =0x09
        phv_b_out[PKT_VALID_NO] =0x85
        phv_b_out[INPORT_NO] =0x01
        phv_b_out[OUTPORT_NO] =0x02
        phv_b_out[IP_OFFSET_NO] =14
        phv_b_out[TID_NO] =0x03
        phv_b_out[SEATL_OFFSET_NO] =0x52 #82
      

        phv_h_out[PKT_LEN_NO]=0xdcba
        phv_h_out[FLOW_INDEX_NO]=0x0000

        phv_w_out[PROTOCOL_NO] =0x18031 #
        phv_w_out[DSTIP1_NO] = 0xCCDD0100
        phv_w_out[DSTIP2_NO] = 0x7788AABB
        phv_w_out[DSTIP3_NO] = 0x33445566
        phv_w_out[DSTIP4_NO] = 0x20011122

        phv_w_out[RSIP1_NO] = 0x00000200
        phv_w_out[RSIP2_NO] = 0x00000000
        phv_w_out[RSIP3_NO] = 0x00000000
        phv_w_out[RSIP4_NO] = 0x20010000
        phv_w_out[PKT_RPN_NO] = 0x00000000

        test_results.append(convert(phv_b_out,phv_h_out,phv_w_out))



    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    for test_data in test_results:
        rx_header = await tb.recv()
        print(rx_header.info)
        print(test_data)
   
        print(len(test_data))
        for i in range(PHV_WIDTH) :

            assert rx_header.info[i]  == test_data[PHV_WIDTH-1-i]


    assert tb.phv_sink.empty()
    assert tb.data_source.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await tb.reset()
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


# async def run_test_rbt_dat_vlan(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

#     tb = TB(dut)

#     await tb.reset()

#     tb.set_idle_generator(idle_inserter)
#     tb.set_backpressure_generator(backpressure_inserter)

#     test_results = []
#     seq = 1

#     for payload in [payload_data(x) for x in payload_lengths()]:
#         eth = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x86dd)
#         eth_vlan = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x8100)
#         vlan = Dot1Q(vlan = 0x123, type = 0x86dd)
#         ipv6 = IPv6(nh=IDP_PROT, src = "2001::200", dst = "2001::100", version=6, hlim=255, fl=0, tc=0)
#         idp_rbt_dat_093 = IDP_RBT_DAT_093(Version=IDP_version, PType=TRANSPORT_LAYER_PROT, header_length=IDP_HEADER_LEN_RBT, IDP_Flags_IrA=0, IDP_Flags_EA=0, IDP_Flags_AuNum=0, IDP_Flags_Reserved=0, 
#                   SEAID_n_Type=0x10, SEAID_n_Length=6, srvType=0, RoST=0, QP=0,# value of SEAID_n_Type is not sure
#                   Dest_SEAID_n=b"\xEE\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\xFF")
        
#         seatl_commom_field = SEATL_COMMON_FIELD_093(Version=SEATL_version, Type=0x00, header_length=SEATL_COMMON_FIELD_HEADER_LEN_RBT, SEATL_Flags_X_Trans=1, SEATL_Flags_PS=0, SEATL_Flags_DS=0, SEATL_Flags_SS=0, SEATL_Flags_Reserved=0,
#                   X_Trans_Flag=0x80, X_Trans_Para_RPara=0x00, 
#                   X_Trans_Para_RSIP=b"\xEE\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\xFF",
#                   X_Trans_Para_RPN=b"\xEE\x11\x11\xFF",
#                   Packet_Number=b"\xEE\x11\x11\xFF",
#                   Checksum=b"\xEE\xFF")
        
#         # seaup_header: this simulation generator seaup dat packet (without unique seaup_header)
        
#         rawpkt_seq =  str(seq)
#         test_pkt = eth_vlan / vlan / ipv6 / idp_rbt_dat_093 / seatl_commom_field / payload / rawpkt_seq

#         user_width=int(os.getenv("PARAM_USER_WIDTH", "56"))
        
#         # test_tuser = 0x010203040005ba
#         test_tuser = 0xdcba060504030201

#         #test_tuser = BinaryValue(n_bits=user_width, bigEndian=False)
#         #inport
#         #test_tuser[7:0] = 0xd0


        
#         await tb.send(test_pkt, test_tuser)
#         seq = seq + 1

#         #match start
#         phv_b_count=int(os.getenv("PARAM_PHV_B_COUNT", "7"))
#         phv_h_count=int(os.getenv("PARAM_PHV_H_COUNT", "2"))
#         phv_w_count=int(os.getenv("PARAM_PHV_B_COUNT", "10"))

#         phv_b_out = [0] * phv_b_count
#         phv_h_out = [0] * phv_h_count
#         phv_w_out = [0] * phv_w_count

#         phv_b_out[PKT_PROPERTY_NO] =0x87
#         phv_b_out[PKT_VALID_NO] =0x05
#         phv_b_out[INPORT_NO] =0x01
#         phv_b_out[OUTPORT_NO] =0x02
#         phv_b_out[IP_OFFSET_NO] =14 
#         phv_b_out[TID_NO] =0x03
#         phv_b_out[SEATL_OFFSET_NO] =0x53
      

#         phv_h_out[PKT_LEN_NO]=0xdcba
#         phv_h_out[FLOW_INDEX_NO]=0x0000

#         phv_w_out[PROTOCOL_NO] =0x2431 #seaup packcet
#         phv_w_out[DSTIP1_NO] = 0x00000100
#         phv_w_out[DSTIP2_NO] = 0x00000000
#         phv_w_out[DSTIP3_NO] = 0x00000000
#         phv_w_out[DSTIP4_NO] = 0x20010000

#         phv_w_out[RSIP1_NO] = 0x111111FF
#         phv_w_out[RSIP2_NO] = 0x11111111
#         phv_w_out[RSIP3_NO] = 0x11111111
#         phv_w_out[RSIP4_NO] = 0xEE111111
#         phv_w_out[PKT_RPN_NO] = 0xEE1111FF

#         test_results.append(convert(phv_b_out,phv_h_out,phv_w_out))



#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)

#     for test_data in test_results:
#         rx_header = await tb.recv()
#         print(rx_header.info)
#         print(test_data)
   
#         print(len(test_data))
#         for i in range(PHV_WIDTH) :

#             assert rx_header.info[i]  == test_data[PHV_WIDTH-1-i]


#     assert tb.phv_sink.empty()
#     assert tb.data_source.empty()

#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await tb.reset()
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)




# async def run_test_full(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

#     tb = TB(dut)

#     await tb.reset()

#     tb.set_idle_generator(idle_inserter)
#     tb.set_backpressure_generator(backpressure_inserter)

#     test_results = []
#     seq = 1

#     for payload in [payload_data(x) for x in payload_lengths()]:
#         eth = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x86dd)
#         eth_vlan = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x8100)
#         vlan = Dot1Q(vlan = 0x123, type = 0x8864)
#         pppoe = raw([0x11,0x00,0x62,0xa2,0x00,0x2e,0x00,0x57])
#         ipv6 = IPv6(nh=IDP_PROT, src = "2001::200", dst = "2001::100", version=6, hlim=255, fl=0, tc=0)
#         idp_full = IDP_Full(next_header=TRANSPORT_LAYER_PROT, header_length=IDP_HEADER_LEN_FULL, dst_seaid_type=0, src_seaid_type=0, dst_seaid_len=6, src_seaid_len=6,
#                   service_type=0, route_policy=0, queue_priority=0, ira=0, ira_param_0=0, ira_param_1=1,
#                   ira_param_2=2, ira_param_3=3, ira_param_4=4, ira_param_5=5, ira_param_6=6, ira_param_7=7, reserved=0x8, flag=0x1,
#                   dst_seaid=b"\xEE\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\xFF",
#                   src_seaid=b"\xEE\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\xFF",
#                   ext_addr=b"\xEE\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\xFF",
#                   option_a=b"\xEE\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xFF",
#                   option_b=b"\xEE\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xFF",
#                   option_c=b"\xEE\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xFF",
#                   option_d=b"\xEE\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xFF")
        
#         public_header_seasp = raw([0x03,0x00])
#         public_header_seadp = raw([0x01,0x20,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
#         public_header_seaup = raw([0x01,0x40,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
        
#         seasp = raw([0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x20,0x00,0x80,0x00,0x00,0x00,0x00,0x00,0x00,
#                       0xaa,0xaa,0xaa,0xaa,0xbb,0xbb,0xbb,0xbb,
#                       0xcc,0xcc,0xcc,0xcc,0xdd,0xdd,0xdd,0xdd,
#                       0xab,0xcd,0xab,0xcd])
        
#         rawpkt_seq =  str(seq)
#         test_pkt = eth / ipv6 / idp_full / public_header_seasp / seasp / payload / rawpkt_seq

#         user_width=int(os.getenv("PARAM_USER_WIDTH", "56"))
        
#         # test_tuser = 0x010203040005ba
#         test_tuser = 0xba000504030201

#         #test_tuser = BinaryValue(n_bits=user_width, bigEndian=False)
#         #inport
#         #test_tuser[7:0] = 0xd0


        
#         await tb.send(test_pkt, test_tuser)
#         seq = seq + 1

#         #match start
#         phv_b_count=int(os.getenv("PARAM_PHV_B_COUNT", "6"))
#         phv_h_count=int(os.getenv("PARAM_PHV_H_COUNT", "2"))
#         phv_w_count=int(os.getenv("PARAM_PHV_B_COUNT", "10"))

#         phv_b_out = [0] * phv_b_count
#         phv_h_out = [0] * phv_h_count
#         phv_w_out = [0] * phv_w_count

#         phv_b_out[PKT_PROPERTY_NO] =0
#         phv_b_out[INPORT_NO] =0x01
#         phv_b_out[OUTPORT_NO] =0x02
#         phv_b_out[IP_OFFSET_NO] =14
#         phv_b_out[TID_NO] =0x03
#         phv_b_out[SEATL_OFFSET_NO] =0xba
        
#         phv_h_out[PKT_LEN_NO]=0x05
#         phv_h_out[FLOW_INDEX_NO]=0

#         phv_w_out[PROTOCOL_NO] =0x4431
#         phv_w_out[DSTIP1_NO] = 0x00000100
#         phv_w_out[DSTIP2_NO] = 0x00000000
#         phv_w_out[DSTIP3_NO] = 0x00000000
#         phv_w_out[DSTIP4_NO] = 0x20010000

#         phv_w_out[RSIP1_NO] = 0
#         phv_w_out[RSIP2_NO] = 0
#         phv_w_out[RSIP3_NO] = 0
#         phv_w_out[RSIP4_NO] = 0
#         phv_w_out[PKT_RPN_NO] = 0


#         test_results.append(convert(phv_b_out,phv_h_out,phv_w_out))



#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)

#     for test_data in test_results:
#         rx_header = await tb.recv()
#         print(rx_header.info)
#         print(test_data)
   
#         print(len(test_data))
#         for i in range(PHV_WIDTH) :

#             assert rx_header.info[i]  == test_data[PHV_WIDTH-1-i]


#     assert tb.phv_sink.empty()
#     assert tb.data_source.empty()

#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await tb.reset()
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)



# async def run_test_eth_pppoe(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

#     tb = TB(dut)

#     await tb.reset()

#     tb.set_idle_generator(idle_inserter)
#     tb.set_backpressure_generator(backpressure_inserter)

#     test_results = []
#     seq = 1

#     for payload in [payload_data(x) for x in payload_lengths()]:
#         eth = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x8864)
#         eth_vlan = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x8100)
#         vlan = Dot1Q(vlan = 0x123, type = 0x8864)
#         pppoe = raw([0x11,0x00,0x62,0xa2,0x00,0x2e,0x00,0x57]) #TODO
#         ipv6 = IPv6(nh=IDP_PROT, src = "2001::200", dst = "2001::100", version=6, hlim=255, fl=0, tc=0)
#         idp_full = IDP_Full(next_header=TRANSPORT_LAYER_PROT, header_length=IDP_HEADER_LEN_FULL, dst_seaid_type=0, src_seaid_type=0, dst_seaid_len=6, src_seaid_len=6,
#                   service_type=0, route_policy=0, queue_priority=0, ira=0, ira_param_0=0, ira_param_1=1,
#                   ira_param_2=2, ira_param_3=3, ira_param_4=4, ira_param_5=5, ira_param_6=6, ira_param_7=7, reserved=0x8, flag=0x1,
#                   dst_seaid=b"\xEE\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\xFF",
#                   src_seaid=b"\xEE\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\xFF",
#                   ext_addr=b"\xEE\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\xFF",
#                   option_a=b"\xEE\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xFF",
#                   option_b=b"\xEE\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xFF",
#                   option_c=b"\xEE\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xFF",
#                   option_d=b"\xEE\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xFF")

#         public_header_seasp = raw([0x01,0x60,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
#         public_header_seadp = raw([0x01,0x20,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
#         public_header_seaup = raw([0x01,0x40,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
        
#         seasp = raw([0x20,0x00,0x80,0x00,0x00,0x00,0x00,0x00,0x00,
#                       0xaa,0xaa,0xaa,0xaa,0xbb,0xbb,0xbb,0xbb,
#                       0xcc,0xcc,0xcc,0xcc,0xdd,0xdd,0xdd,0xdd,
#                       0xab,0xcd,0xab,0xcd])
        
#         rawpkt_seq =  str(seq)
#         # test_pkt = eth_vlan / pppoe / ipv6 / idp_full / public_header_seasp / seasp / payload / rawpkt_seq
#         test_pkt = eth / pppoe / ipv6 / idp_full / public_header_seasp / seasp / payload / rawpkt_seq
#         user_width=int(os.getenv("PARAM_USER_WIDTH", "48"))
        
#         test_tuser = 0x0000040000d0
#         #test_tuser = BinaryValue(n_bits=user_width, bigEndian=False)
#         #inport
#         #test_tuser[7:0] = 0xd0


        
#         await tb.send(test_pkt, test_tuser)
#         seq = seq + 1

#         #match start
#         phv_b_count=int(os.getenv("PARAM_PHV_B_COUNT", "10"))
#         phv_h_count=int(os.getenv("PARAM_PHV_H_COUNT", "2"))
#         phv_w_count=int(os.getenv("PARAM_PHV_B_COUNT", "15"))

#         phv_b_out = [0] * phv_b_count
#         phv_h_out = [0] * phv_h_count
#         phv_w_out = [0] * phv_w_count
#         #expected value
#         #timestamp skip
#         phv_w_out[PROTO_NO] = 0x00020429 #idp ipv6 seagp seasp
#         #phv_w_out[PKTIN_ENTRYID_NO] = 0
        
#         phv_w_out[DST_IPV6_NO] = 0x100
#         phv_w_out[DST_IPV6_NO+1] = 0
#         phv_w_out[DST_IPV6_NO+2] = 0
#         phv_w_out[DST_IPV6_NO+3] = 0x20010000

#         # phv_w_out[IDP_S_SEAID_NO] = 0x222222ff
#         # phv_w_out[IDP_S_SEAID_NO+1] = 0x22222222
#         # phv_w_out[IDP_S_SEAID_NO+2] = 0x22222222
#         # phv_w_out[IDP_S_SEAID_NO+3] = 0x22222222
#         # phv_w_out[IDP_S_SEAID_NO+4] = 0xee222222
#         phv_w_out[SEASP_RSIP_NO] = 0xdddddddd
#         phv_w_out[SEASP_RSIP_NO+1] = 0xcccccccc
#         phv_w_out[SEASP_RSIP_NO+2] = 0xbbbbbbbb
#         phv_w_out[SEASP_RSIP_NO+3] = 0xaaaaaaaa
#         phv_w_out[SEASP_RPN_NO] = 0x0abcdabcd
#         phv_w_out[SRC_IPV6_NO] = 0x200
#         phv_w_out[SRC_IPV6_NO+1] = 0
#         phv_w_out[SRC_IPV6_NO+2] = 0
#         phv_w_out[SRC_IPV6_NO+3] = 0x20010000



#         phv_h_out[PKTLEN_NO]=len(test_pkt)


#         phv_b_out[PKT_PROPERTY_NO]=0x04
#         phv_b_out[PHV_IN_PORT_NO]=0xd0
#         phv_b_out[TABLE_MASK_NO] = 0  
#         phv_b_out[L3_OFFSET_NO] = ETH_HEADER_LEN + PPPOE_HEADER_LEN      
#         phv_b_out[TRANSPORT_LAYER_OFFSET_NO] = ETH_HEADER_LEN + IPV6_HEADER_LEN + IDP_HEADER_LEN_FULL+PPPOE_HEADER_LEN
#         phv_b_out[TRANSPORT_LAYER_TYPE_NO] = 0x60
#         phv_b_out[TRANSPORT_LAYER_FLAG_NO] = 0x80
     
        
#         test_results.append(convert(phv_b_out,phv_h_out,phv_w_out))



#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)

#     for test_data in test_results:
#         rx_header = await tb.recv()
#         print(rx_header.info)
#         print(test_data)
   
#         print(len(test_data))
#         for i in range(PHV_WIDTH) :
#             assert rx_header.info[i]  == test_data[PHV_WIDTH-1-i]


#     assert tb.phv_sink.empty()
#     assert tb.data_source.empty()

#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await tb.reset()
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)

# async def run_test_eth_vlan_pppoe(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

#     tb = TB(dut)

#     await tb.reset()

#     tb.set_idle_generator(idle_inserter)
#     tb.set_backpressure_generator(backpressure_inserter)

#     test_results = []
#     seq = 1

#     for payload in [payload_data(x) for x in payload_lengths()]:
#         eth = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x8864)
#         eth_vlan = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x8100)
#         # vlan = Dot1Q(vlan = 0x123, type = 0x8864)
#         vlan= raw([0x00,0xce,0x88,0x64])
#         pppoe = raw([0x11,0x00,0x62,0xa2,0x00,0x2e,0x00,0x57])
#         ipv6 = IPv6(nh=IDP_PROT, src = "2001::200", dst = "2001::100", version=6, hlim=255, fl=0, tc=0)
#         idp_full = IDP_Full(next_header=TRANSPORT_LAYER_PROT, header_length=IDP_HEADER_LEN_FULL, dst_seaid_type=0, src_seaid_type=0, dst_seaid_len=6, src_seaid_len=6,
#                   service_type=0, route_policy=0, queue_priority=0, ira=0, ira_param_0=0, ira_param_1=1,
#                   ira_param_2=2, ira_param_3=3, ira_param_4=4, ira_param_5=5, ira_param_6=6, ira_param_7=7, reserved=0x8, flag=0x1,
#                   dst_seaid=b"\xEE\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\xFF",
#                   src_seaid=b"\xEE\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\xFF",
#                   ext_addr=b"\xEE\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\xFF",
#                   option_a=b"\xEE\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xFF",
#                   option_b=b"\xEE\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xFF",
#                   option_c=b"\xEE\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xFF",
#                   option_d=b"\xEE\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xFF")

#         public_header_seasp = raw([0x01,0x60,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
#         public_header_seadp = raw([0x01,0x20,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
#         public_header_seaup = raw([0x01,0x40,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
        
#         seasp = raw([0x20,0x00,0x80,0x00,0x00,0x00,0x00,0x00,0x00,
#                       0xaa,0xaa,0xaa,0xaa,0xbb,0xbb,0xbb,0xbb,
#                       0xcc,0xcc,0xcc,0xcc,0xdd,0xdd,0xdd,0xdd,
#                       0xab,0xcd,0xab,0xcd])
        
#         rawpkt_seq =  str(seq)
#         test_pkt = eth_vlan /vlan/ pppoe / ipv6 / idp_full / public_header_seasp / seasp / payload / rawpkt_seq
#         user_width=int(os.getenv("PARAM_USER_WIDTH", "48"))
        
#         test_tuser = 0x0000040000d0
#         #test_tuser = BinaryValue(n_bits=user_width, bigEndian=False)
#         #inport
#         #test_tuser[7:0] = 0xd0


        
#         await tb.send(test_pkt, test_tuser)
#         seq = seq + 1

#         #match start
#         phv_b_count=int(os.getenv("PARAM_PHV_B_COUNT", "10"))
#         phv_h_count=int(os.getenv("PARAM_PHV_H_COUNT", "2"))
#         phv_w_count=int(os.getenv("PARAM_PHV_B_COUNT", "15"))

#         phv_b_out = [0] * phv_b_count
#         phv_h_out = [0] * phv_h_count
#         phv_w_out = [0] * phv_w_count
#         #expected value
#         #timestamp skip
#         phv_w_out[PROTO_NO] = 0x0002042b #idp ipv6 seagp seasp
#         #phv_w_out[PKTIN_ENTRYID_NO] = 0
#         phv_w_out[DST_IPV6_NO] = 0x100
#         phv_w_out[DST_IPV6_NO+1] = 0
#         phv_w_out[DST_IPV6_NO+2] = 0
#         phv_w_out[DST_IPV6_NO+3] = 0x20010000

#         phv_w_out[SEASP_RSIP_NO] = 0xdddddddd
#         phv_w_out[SEASP_RSIP_NO+1] = 0xcccccccc
#         phv_w_out[SEASP_RSIP_NO+2] = 0xbbbbbbbb
#         phv_w_out[SEASP_RSIP_NO+3] = 0xaaaaaaaa
#         phv_w_out[SEASP_RPN_NO] = 0x0abcdabcd
#         phv_w_out[SRC_IPV6_NO] = 0x200
#         phv_w_out[SRC_IPV6_NO+1] = 0
#         phv_w_out[SRC_IPV6_NO+2] = 0
#         phv_w_out[SRC_IPV6_NO+3] = 0x20010000


#         phv_h_out[PKTLEN_NO]=len(test_pkt)

#         phv_b_out[PKT_PROPERTY_NO]=0x04
#         phv_b_out[PHV_IN_PORT_NO]=0xd0
#         phv_b_out[TABLE_MASK_NO] = 0
#         phv_b_out[L3_OFFSET_NO] = ETH_HEADER_LEN + VLAN_PPPOE_HEADER_LEN 
#         phv_b_out[TRANSPORT_LAYER_OFFSET_NO] = ETH_HEADER_LEN + IPV6_HEADER_LEN + IDP_HEADER_LEN_FULL+VLAN_PPPOE_HEADER_LEN
#         phv_b_out[TRANSPORT_LAYER_TYPE_NO] = 0x60
#         phv_b_out[TRANSPORT_LAYER_FLAG_NO] = 0x80
     
        
#         test_results.append(convert(phv_b_out,phv_h_out,phv_w_out))



#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)

#     for test_data in test_results:
#         rx_header = await tb.recv()
#         print(rx_header.info)
#         print(test_data)
   
#         print(len(test_data))
#         for i in range(PHV_WIDTH) :
#             assert rx_header.info[i]  == test_data[PHV_WIDTH-1-i]


#     assert tb.phv_sink.empty()
#     assert tb.data_source.empty()

#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await tb.reset()
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)
#     await RisingEdge(dut.clk)

def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


def size_list():
    #return [1024]
    return [1,2,4,8,16,32,64,128,256,512,1024]
    #return list(range(1, 64))


def incrementing_payload(length):
    return bytes(itertools.islice(itertools.cycle(range(256)), length))


if cocotb.SIM_NAME:
    for test in [
                    run_test_rbt_dat
                    # run_test_rbt_nack
                    # run_test_rbt_dat_vlan

                ] :
        factory = TestFactory(test)
        factory.add_option("payload_lengths", [size_list])
        factory.add_option("payload_data", [incrementing_payload])
        factory.add_option("idle_inserter", [None,cycle_pause]) #,cycle_pause
        factory.add_option("backpressure_inserter", [None,cycle_pause])
        factory.generate_tests()


# cocotb-test
tests_dir = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl', 'parser'))
hdr_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', '..', '..', 'modules', 'common', 'rtl'))


@pytest.mark.parametrize("header_width", [2048])
@pytest.mark.parametrize("tuser_width", [408])
@pytest.mark.parametrize("route_offset", [0])

def test_idp_parser_top(request, header_width, tuser_width, route_offset):
    dut = "idp_parser_top"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(hdr_dir, f"parser_extract_header.v"),
        os.path.join(rtl_dir, f"seanet_eth_parser.v"),
        os.path.join(rtl_dir, f"seanet_vlan_parser.v"),
        os.path.join(rtl_dir, f"seanet_pppoe_parser.v"),
        os.path.join(rtl_dir, f"seanet_ipv6_parser.v"),
        os.path.join(rtl_dir, f"seanet_idp_fix_parser.v"),
        os.path.join(rtl_dir, f"seanet_idp_dst_id_parser.v"),
        os.path.join(rtl_dir, f"seanet_idp_src_id_parser.v"),
        os.path.join(rtl_dir, f"seanet_idp_option_0_parser.v"),
        os.path.join(rtl_dir, f"seanet_idp_option_1_parser.v"),
        os.path.join(rtl_dir, f"seanet_transport_layer_parser.v"),
        os.path.join(rtl_dir, f"seanet_pre_parser.v"),
        os.path.join(rtl_dir, f"seanet_post_parser.v"),
    ]

    parameters = {}

    parameters['HEADER_WIDTH'] = header_width
    parameters['USER_WIDTH'] = tuser_width
    parameters['ROUTE_OFFSET'] = route_offset



    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    sim_build = os.path.join(tests_dir, "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

    cocotb_test.simulator.run(
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
        defines=["SEAID_160", "OPENSOURCE"]
    )

