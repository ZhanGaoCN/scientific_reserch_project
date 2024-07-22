#!/usr/bin/env python
"""

"""

#from base64 import encode
import ipaddress as ip
import itertools
import logging
import os
#import binascii

import random
import copy

from scapy.layers.l2 import Ether
from scapy.layers.inet6 import IPv6
from scapy.layers.inet import UDP,IP,TCP
from scapy.all import ARP
from scapy.layers.l2 import Dot1Q
from scapy.layers.vxlan import VXLAN
from scapy.all import raw
from scapy.all import ICMP
from scapyext.seadp import IDP_Full,IDP_RBT_DAT_093,SEATL_COMMON_FIELD_093,SCMP_RBT_NACK_093,IDP_Stealth,IDP_Stealth_INT,IDP_Multi,IDP_Multi_INT,IDP_Cache,IDP_Cache_INT


import pytest
import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame
from cocotbext.axi.stream import define_stream
from cocotb.binary import BinaryValue
from miscext.hash_table import H3_4_Way, matrix_256_11
from scapyext.flowmod_controller_csr import FLOWMOD_CSR


class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.fork(Clock(dut.clk, 8, units="ns").start())

        self.axis_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk, dut.rst)
        self.axis_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk, dut.rst)

    def set_idle_generator(self, generator=None):
        if generator:
            self.axis_source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axis_sink.set_pause_generator(generator())

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

    async def recv(self):
        rx = await self.axis_sink.recv()
        return rx
    
    def gen_key_mau17_reli_send (self, RSIP=0, DstIP=0):
        IP_WIDTH = 128
        RSIP %= (1 << IP_WIDTH)
        DstIP %= (1 << IP_WIDTH)
        key_data = DstIP | RSIP << IP_WIDTH
        return key_data

    async def send_dat(self, pkt_axis, test_tuser):
        pkt_in_frame = AxiStreamFrame()  
        pkt_in_frame.tdata = bytes(pkt_axis)
        print(pkt_in_frame.tdata)#todo
        print(pkt_in_frame)#todo
        # pkt_in_frame.tuser = (len(pkt_axis)<<32) + 0x05118080 #todo
        pkt_in_frame.tuser = test_tuser
             
        await self.axis_source.send(pkt_in_frame)

    async def send_nack(self, pkt_axis):
        pkt_in_frame = AxiStreamFrame()  
        pkt_in_frame.tdata = bytes(pkt_axis)
        print(pkt_in_frame.tdata)
        print(pkt_in_frame)
        pkt_in_frame.tuser = (len(pkt_axis)<<32) + 0x11118080
             
        await self.axis_source.send(pkt_in_frame)

TRANSPORT_LAYER_PROT = 0x02 #means next protocol is SEAUP
IDP_HEADER_LEN_RBT = 40
IDP_PROT = 0x92

ETH_HEADER_LEN = 14
VLAN_HEADER_LEN=4
IPV6_HEADER_LEN = 40
IDP_HEADER_RBT_LEN = 44

SEATL_COMMON_FIELD_HEADER_LEN_RBT = 32
UDP_HEADER_LEN = 8
PHV_WIDTH = 408

IDP_version = 0x00
SEATL_version = 0x00


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

async def run_test_rbt_dat_hit(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):
    tb = TB(dut)
    await tb.reset()
    flowmod = FLOWMOD_CSR(dut,0x2800) #ctrl_addr

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    key_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))
    value_width=int(os.getenv("PARAM_VALUE_WIDTH", "0"))+1#todo
    addr_width=int(os.getenv("PARAM_ADDR_WIDTH", "11"))
    mask_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))

    hash_table = H3_4_Way(key_width = key_width, addr_width=addr_width, value_width=value_width, matrix=matrix_256_11)
    tb.log.info("flowmod table begin")

    insert_key_list=[]

    rsip_0  = int(ip.ip_address("7001::0001:0001"))
    dstip_0 = int(ip.ip_address("7001::0081:0001"))
    dstip_1 = int(ip.ip_address("5001::0001:0001"))

    err_cnt = 0
    for i in range(16):
        key_val = BinaryValue(n_bits=key_width, bigEndian=False)
        value_val = BinaryValue(n_bits=value_width, bigEndian=False)
        value_val[value_width-1] = 1

        key_val.integer = tb.gen_key_mau17_reli_send(RSIP=rsip_0, DstIP=dstip_1+i*0x10000)#todo
        result_val, addr_val = hash_table.insert(key = key_val, value = value_val)
        
        if(result_val):
            await flowmod.flowmod_write_key(addr_val,key_val,key_width)
            insert_key_list.append(copy.deepcopy(key_val))
            await flowmod.flowmod_write_value(addr_val,0x1,value_width+1)
            await flowmod.flowmod_write_state(addr_val,0x0,state_width=32)

            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
        else:
            print (f"fib_host insert conflict; addr = {addr_val}; key = {key_val.integer}; value = {key_val.integer}; err_cnt = {err_cnt}")
            err_cnt += 1
            pass
        
    tb.log.info("flowmod table complete")


    print("-----------------------------flowmod complete!!!!!!!!!!!!!--------------------------------------------")
    
    test_pkts = []
    expect_test_pkts = []
    seq = 1
    cnt =0 

    #rsip_0  = int(ip.ip_address("7001::0001:0001"))
    #dstip_1 = int(ip.ip_address("5001::0001:0001"))
    #X_Trans_Para_RSIP=b"\x70\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x01"
    # X_Trans_Para_RSIP=b"\x01\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x01\x70"
    

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
        seatl_commom_field_modify = SEATL_COMMON_FIELD_093(Version=SEATL_version, Type=0x00, Header_Length=SEATL_COMMON_FIELD_HEADER_LEN_RBT, SEATL_Flags_X_Trans=1, SEATL_Flags_PS=0, SEATL_Flags_DS=0, SEATL_Flags_SS=0, SEATL_Flags_Reserved=0,
                  X_Trans_Flag=0x80, X_Trans_Para_RPara=0x00, 
                  X_Trans_Para_RSIP=b"\x70\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x01",
                  X_Trans_Para_RPN=b"\xEE\x11\x11\xFF",
                  Packet_Number=b"\x00\x00\x00\x00",
                  Checksum=b"\xEE\xFF")

        
        # seaup_header: this simulation generator seaup dat packet (without unique seaup_header)
        
        # rawpkt_seq =  str(seq)
        #  / payload / rawpkt_seq
        test_pkt = eth / ipv6 / idp_rbt_dat_093 / seatl_commom_field
        expect_test_pkt = eth / ipv6 / idp_rbt_dat_093 / seatl_commom_field_modify
        test_tuser = 0xdcba5E8587030201

#------------------------------------------------------#
        #tuser_input_structure_&_values
        # phv_b_out[INPORT_NO] =0x01
        # phv_b_out[OUTPORT_NO] =0x02
        # phv_b_out[TID_NO] =0x03
        # phv_b_out[PKT_PROPERTY_NO] =0x87
        # phv_b_out[PKT_VALID_NO] =0x85
        # phv_b_out[SEATL_OFFSET_NO] =0x5E #94
        # phv_h_out[PKT_LEN_NO]=0xdcba
#------------------------------------------------------#

        await tb.send_dat(test_pkt, test_tuser)
        cnt = cnt + 1

        test_pkts.append(test_pkt)

        expect_test_pkts.append(bytes(expect_test_pkt))
        print(cnt)
    
    print("------------------send complete--------------------")
    
    cnt=0
    for test_pkt in test_pkts:
    # for expect_test_pkt in expect_test_pkts:
        print("------------------recv"+str(cnt)+"begin--------------------")
        rx = await tb.recv()
     
        print("!!!!!rx_data!!!!!:\n",bytes(rx.tdata))
        # print("!!!!!expect_test_pkt!!!!!:\n",bytes(expect_test_pkt))
        # assert bytes(rx.tdata) == bytes(expect_test_pkt)   
        # mat_result,mat_addr,mat_value = hash_table.match(insert_key_list[cnt])
        # bit_mat_addr = BinaryValue(n_bits=addr_width, bigEndian=False)
        # bit_mat_addr.integer = mat_addr
        # print(bit_mat_addr)

        # expect_tuser = 0x01A662dcba030E02018D87
#------------------------------------------------------#
        #tuser_output_structure_&_values
        # phv_b_out[PKT_PROPERTY_NO] =0x87
        # phv_b_out[PKT_VALID_NO] =0x8D
        # phv_b_out[INPORT_NO] =0x01
        # phv_b_out[OUTPORT_NO] =0x02
        # ip_offset = 0x0E
        # phv_b_out[TID_NO] =0x03
        # phv_h_out[PKT_LEN_NO]=0xdcba
        # phv_b_out[SEATL_OFFSET_NO] =0x62 #98
        # flow_index = 0000
#------------------------------------------------------#
        # print(len(expect_test_pkt))

        # bytes_val = expect_tuser.to_bytes(9, 'big')
        # bytes_val_1 = rx.tuser.to_bytes(9, 'big')
        # print("-------rx.tuser:------/n",bytes_val_1)
        # print("-------expect.tuser:------/n",bytes_val)
        # assert rx.tuser== expect_tuser
        cnt = cnt + 1

    # assert tb.axis_source.empty()
    # assert tb.axis_sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

async def run_test_rbt_pktout(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):
    tb = TB(dut)
    await tb.reset()
    flowmod = FLOWMOD_CSR(dut,0x2800) #ctrl_addr

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    key_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))
    value_width=int(os.getenv("PARAM_VALUE_WIDTH", "0"))+1#todo
    addr_width=int(os.getenv("PARAM_ADDR_WIDTH", "11"))
    mask_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))

    hash_table = H3_4_Way(key_width = key_width, addr_width=addr_width, value_width=value_width, matrix=matrix_256_11)
    tb.log.info("flowmod table begin")

    insert_key_list=[]

    rsip_0  = int(ip.ip_address("7001::0001:0001"))
    dstip_0 = int(ip.ip_address("7001::0081:0001"))
    dstip_1 = int(ip.ip_address("5001::0001:0001"))

    err_cnt = 0
    for i in range(16):
        key_val = BinaryValue(n_bits=key_width, bigEndian=False)
        value_val = BinaryValue(n_bits=value_width, bigEndian=False)
        value_val[value_width-1] = 1

        key_val.integer = tb.gen_key_mau17_reli_send(RSIP=rsip_0, DstIP=dstip_1+i*0x10000)#todo
        result_val, addr_val = hash_table.insert(key = key_val, value = value_val)
        
        if(result_val):
            await flowmod.flowmod_write_key(addr_val,key_val,key_width)
            insert_key_list.append(copy.deepcopy(key_val))
            await flowmod.flowmod_write_value(addr_val,0x1,value_width+1)
            await flowmod.flowmod_write_state(addr_val,0x0,state_width=32)

            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
        else:
            print (f"fib_host insert conflict; addr = {addr_val}; key = {key_val.integer}; value = {key_val.integer}; err_cnt = {err_cnt}")
            err_cnt += 1
            pass
        
    tb.log.info("flowmod table complete")


    print("-----------------------------flowmod complete!!!!!!!!!!!!!--------------------------------------------")
    
    test_pkts = []
    expect_test_pkts = []
    seq = 1
    cnt =0 

    #rsip_0  = int(ip.ip_address("7001::0001:0001"))
    #dstip_1 = int(ip.ip_address("5001::0001:0001"))
    #X_Trans_Para_RSIP=b"\x70\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x01"
    # X_Trans_Para_RSIP=b"\x01\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x01\x70"
    

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src = "ff:ff:ff:ff:ff:ff", dst = "ff:ff:ff:ff:ff:ff",  type= 0x86dd)
        ipv6 = IPv6(nh=IDP_PROT, src = "2001::200", dst = "5001::0001:0001", version=6, hlim=255, fl=0, tc=0)
        idp_rbt_dat_093 = IDP_RBT_DAT_093(Version=IDP_version, PType=TRANSPORT_LAYER_PROT, Header_Length=IDP_HEADER_LEN_RBT, IDP_Flags_IrA=0, IDP_Flags_EA=1, IDP_Flags_AuNum=0, IDP_Flags_Reserved=0, 
                  SEAID_n_Type=0x10, SEAID_n_Length=6, srvType=0, RoST=0, QP=0,
                  Dest_SEAID_n=b"\xEE\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\xFF",
                  ext_addr=b"\x20\x01\x11\x22\x33\x44\x55\x66\x77\x88\x99\xAA\xBB\xCC\x11\x00")
        
        seatl_commom_field = SEATL_COMMON_FIELD_093(Version=SEATL_version, Type=0x00, Header_Length=SEATL_COMMON_FIELD_HEADER_LEN_RBT, SEATL_Flags_X_Trans=1, SEATL_Flags_PS=0, SEATL_Flags_DS=0, SEATL_Flags_SS=0, SEATL_Flags_Reserved=0,
                  X_Trans_Flag=0x80, X_Trans_Para_RPara=0x00, 
                  X_Trans_Para_RSIP=b"\x70\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x01",
                  X_Trans_Para_RPN=b"\xEE\x11\x11\xFE",
                  Packet_Number=b"\xEE\x11\x11\xFF",
                  Checksum=b"\xEE\xFF")
        seatl_commom_field_modify = SEATL_COMMON_FIELD_093(Version=SEATL_version, Type=0x00, Header_Length=SEATL_COMMON_FIELD_HEADER_LEN_RBT, SEATL_Flags_X_Trans=1, SEATL_Flags_PS=0, SEATL_Flags_DS=0, SEATL_Flags_SS=0, SEATL_Flags_Reserved=0,
                  X_Trans_Flag=0x80, X_Trans_Para_RPara=0x00, 
                  X_Trans_Para_RSIP=b"\x70\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x01",
                  X_Trans_Para_RPN=b"\x00\x00\x00\x00",
                  Packet_Number=b"\xEE\x11\x11\xFF",
                  Checksum=b"\xEE\xFF")

        
        # seaup_header: this simulation generator seaup dat packet (without unique seaup_header)
        
        # rawpkt_seq =  str(seq)
        #  / payload / rawpkt_seq
        test_pkt = eth / ipv6 / idp_rbt_dat_093 / seatl_commom_field
        expect_test_pkt = eth / ipv6 / idp_rbt_dat_093 / seatl_commom_field_modify
        test_tuser = 0xdcba_62_00_00_FF_80_7F

#------------------------------------------------------#
        #tuser_input_structure_&_values
        # phv_b_out[INPORT_NO] =0x01
        # phv_b_out[OUTPORT_NO] =0x02
        # phv_b_out[TID_NO] =0x03
        # phv_b_out[PKT_PROPERTY_NO] =0x87
        # phv_b_out[PKT_VALID_NO] =0x85
        # phv_b_out[SEATL_OFFSET_NO] =0x62 #98
        # phv_h_out[PKT_LEN_NO]=0xdcba
#------------------------------------------------------#

        await tb.send_dat(test_pkt, test_tuser)
        cnt = cnt + 1

        test_pkts.append(test_pkt)

        expect_test_pkts.append(bytes(expect_test_pkt))
        print(cnt)
    
    print("------------------send complete--------------------")
    
    cnt=0
    for expect_test_pkt in expect_test_pkts:
        print("------------------recv"+str(cnt)+"begin--------------------")
        rx = await tb.recv()
     
        print("!!!!!rx_data!!!!!:\n",bytes(rx.tdata))
        print("!!!!!expect_test_pkt!!!!!:\n",bytes(expect_test_pkt))
        # assert bytes(rx.tdata) == bytes(expect_test_pkt)   
        mat_result,mat_addr,mat_value = hash_table.match(insert_key_list[cnt])
        bit_mat_addr = BinaryValue(n_bits=addr_width, bigEndian=False)
        bit_mat_addr.integer = mat_addr
        print(bit_mat_addr)

        expect_tuser = 0x01A662dcba030E02018D87
#------------------------------------------------------#
        #tuser_output_structure_&_values
        # phv_b_out[PKT_PROPERTY_NO] =0x87
        # phv_b_out[PKT_VALID_NO] =0x8D
        # phv_b_out[INPORT_NO] =0x01
        # phv_b_out[OUTPORT_NO] =0x02
        # ip_offset = 0x0E
        # phv_b_out[TID_NO] =0x03
        # phv_h_out[PKT_LEN_NO]=0xdcba
        # phv_b_out[SEATL_OFFSET_NO] =0x62 #98
        # flow_index = 0000
#------------------------------------------------------#
        # print(len(expect_test_pkt))

        # bytes_val = expect_tuser.to_bytes(9, 'big')
        # bytes_val_1 = rx.tuser.to_bytes(9, 'big')
        # print("-------rx.tuser:------/n",bytes_val_1)
        # print("-------expect.tuser:------/n",bytes_val)
        # assert rx.tuser== expect_tuser
        cnt = cnt + 1

    assert tb.axis_source.empty()
    assert tb.axis_sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
async def run_test_dat_hit(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):
    tb = TB(dut)
    await tb.reset()
    flowmod = FLOWMOD_CSR(dut,0x2910) #ctrl_addr

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    key_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))
    value_width=int(os.getenv("PARAM_VALUE_WIDTH", "0"))+1
    addr_width=int(os.getenv("PARAM_ADDR_WIDTH", "11"))
    mask_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))

    hash_table = H3_4_Way(key_width = key_width, addr_width=addr_width, value_width=value_width, matrix=matrix_256_11)
    tb.log.info("flowmod table begin")

    insert_key_list=[]

    rsip_0  = int(ip.ip_address("7001::0001:0001"))
    dstip_0 = int(ip.ip_address("7001::0081:0001"))
    dstip_1 = int(ip.ip_address("5001::0001:0001"))

    err_cnt = 0
    for i in range(16):
        key_val = BinaryValue(n_bits=key_width, bigEndian=False)
        value_val = BinaryValue(n_bits=value_width, bigEndian=False)

        key_val.integer = tb.gen_key_mau17_reli_send(RSIP=rsip_0, DstIP=dstip_1+i*0x10000)
        result_val, addr_val = hash_table.insert(key = key_val, value = value_val)
        
        if(result_val):
            await flowmod.flowmod_write_key(addr_val,key_val,key_width)
            insert_key_list.append(copy.deepcopy(key_val))
            await flowmod.flowmod_write_value(addr_val,0x1,value_width+1)
            await flowmod.flowmod_write_state(addr_val,0x0,state_width=32)

            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
        else:
            print (f"fib_host insert conflict; addr = {addr_val}; key = {key_val.integer}; value = {key_val.integer}; err_cnt = {err_cnt}")
            err_cnt += 1
            pass
        
    tb.log.info("flowmod table complete")


    print("-----------------------------flowmod complete!!!!!!!!!!!!!--------------------------------------------")
    
    test_pkts = []
    expect_test_pkts = []
    cnt =0 

    for payload in [payload_data(x) for x in payload_lengths()]:
        temp=cnt%8+1
        eth = Ether(src="66:77:88:99:aa:bb", dst="00:11:22:33:44:55", type=0x86dd)
        ipv6 = IPv6(nh=IDP_PROT, src="2001::200", dst="5001::000%01x:0001"%temp, version=6, hlim=255, fl=0, tc=0)

        idp_full = IDP_Full(next_header=TRANSPORT_LAYER_PROT, header_length=IDP_HEADER_LEN_FULL, dst_seaid_type=1,
                        src_seaid_type=0, dst_seaid_len=6, src_seaid_len=6,
                        service_type=0, route_policy=0, queue_priority=0, ira=0x20, ira_param_0=0,
                        ira_param_1=1,
                        ira_param_2=2, ira_param_3=0, ira_param_4=4, ira_param_5=5, ira_param_6=6, ira_param_7=7,
                        reserved=0x8, flag=0x1,
                        dst_seaid=b"\x31\xf8\xf4\x24\xb3\x7b\xb0\x65\x8f\xf5\x02\x02\x55\x9e\x97\x5e\x21\x33\x17\x77",
                        src_seaid=b"\x22\xde\xd6\x62\xde\x11\x22\x36\xbe\xad\x0a\x12\x82\x43\x26\x80\xef\x37\xd9\xc7",
                        ext_addr=b"\xEE\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\xFF",
                        option_a=b"\xEE\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xFF",
                        option_b=b"\xEE\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xFF",
                        option_c=b"\xEE\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xFF",
                        option_d=b"\xEE\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xFF")

        # 10 byte
        seagp = raw([0x00, 0x60, 0x00, 0x00, 0x00, 0x00])  # pn
        pn = raw([0x00, 0x00, 0x00, 0x00])
        # 42 byte
        seasp = raw([0x20,  # flags
                     0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 # preference offset8 net flag 
                 ])

        # NeT_defined Fields
        rsip_idx=0x01
        rsip  = int(ip.ip_address("7001::00%02x:0001"%rsip_idx))
        byte_rsip = rsip.to_bytes(16, 'big')
        rpn = int(cnt/8)
        byte_rpn = rpn.to_bytes(4, 'big')
        expect_rpn = raw([0x00,0x00,0x00, int(cnt/8)])

        test_pkt = bytes(eth / ipv6 / idp_full / seagp / pn / seasp) + byte_rsip + byte_rpn + bytes(payload) 
        expect_test_pkt = bytes(eth / ipv6 / idp_full / seagp / pn / seasp) + byte_rsip + expect_rpn + bytes(payload)

        await tb.send_dat(test_pkt)
        cnt = cnt + 1
        #rx = await tb.recv()

        test_pkts.append(test_pkt)
        expect_test_pkts.append(expect_test_pkt)
        print(cnt)
    
    print("------------------send complete--------------------")
    
    cnt=0
    for expect_test_pkt in expect_test_pkts:
        print("------------------recv"+str(cnt)+"begin--------------------")
        rx = await tb.recv()
     
        print(bytes(rx.tdata))
        print(bytes(expect_test_pkt))
        assert bytes(rx.tdata) == bytes(expect_test_pkt)   
        mat_result,mat_addr,mat_value = hash_table.match(insert_key_list[cnt])
        bit_mat_addr = BinaryValue(n_bits=addr_width, bigEndian=False)
        bit_mat_addr.integer = mat_addr
        print(bit_mat_addr)

        expect_tuser = (0xba<<64)+(int(bit_mat_addr[9:0])<<48)+(len(expect_test_pkt)<<32) + 0x250e8080
        print(len(expect_test_pkt))

        bytes_val = expect_tuser.to_bytes(9, 'big')
        bytes_val_1 = rx.tuser.to_bytes(9, 'big')
        print(bytes_val_1)
        print(bytes_val)
        assert rx.tuser== expect_tuser
        cnt = cnt + 1

    assert tb.axis_source.empty()
    assert tb.axis_sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_dat_unhit(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()
    flowmod = FLOWMOD_CSR(dut,0x2910) #ctrl_addr

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)


    key_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))
    value_width=int(os.getenv("PARAM_VALUE_WIDTH", "0"))+1
    addr_width=int(os.getenv("PARAM_ADDR_WIDTH", "11"))
    mask_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))

    hash_table = H3_4_Way(key_width = key_width, addr_width=addr_width, value_width=value_width, matrix=matrix_256_11)
    tb.log.info("flowmod table begin")

    insert_key_list=[]

    rsip_0  = int(ip.ip_address("7001::0001:0001"))
    dstip_0 = int(ip.ip_address("7001::0081:0001"))
    dstip_1 = int(ip.ip_address("5001::0001:0001"))

    err_cnt = 0
    for i in range(16):
        key_val = BinaryValue(n_bits=key_width, bigEndian=False)
        value_val = BinaryValue(n_bits=value_width, bigEndian=False)

        key_val.integer = tb.gen_key_mau17_reli_send(RSIP=rsip_0+i*0x10000, DstIP=dstip_1+i*0x10000)
        result_val, addr_val = hash_table.insert(key = key_val, value = value_val)
        
        if(result_val):
            await flowmod.flowmod_write_key(addr_val,key_val,key_width)
            insert_key_list.append(copy.deepcopy(key_val))
            await flowmod.flowmod_write_value(addr_val,0x1,value_width+1)
            await flowmod.flowmod_write_state(addr_val,0x0,state_width=32)

            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
        else:
            print (f"fib_host insert conflict; addr = {addr_val}; key = {key_val.integer}; value = {key_val.integer}; err_cnt = {err_cnt}")
            err_cnt += 1
            pass
        
    tb.log.info("flowmod table complete")


    print("-----------------------------flowmod complete!!!!!!!!!!!!!--------------------------------------------")
    
    test_pkts = []
    expect_test_pkts = []
    cnt =0 

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src="66:77:88:99:aa:bb", dst="00:11:22:33:44:55", type=0x86dd)
        ipv6 = IPv6(nh=IDP_PROT, src="2001::200", dst="5001::0001:0001", version=6, hlim=255, fl=0, tc=0)

        idp_full = IDP_Full(next_header=TRANSPORT_LAYER_PROT, header_length=IDP_HEADER_LEN_FULL, dst_seaid_type=1,
                        src_seaid_type=0, dst_seaid_len=6, src_seaid_len=6,
                        service_type=0, route_policy=0, queue_priority=0, ira=0x20, ira_param_0=0,
                        ira_param_1=1,
                        ira_param_2=2, ira_param_3=0, ira_param_4=4, ira_param_5=5, ira_param_6=6, ira_param_7=7,
                        reserved=0x8, flag=0x1,
                        dst_seaid=b"\x31\xf8\xf4\x24\xb3\x7b\xb0\x65\x8f\xf5\x02\x02\x55\x9e\x97\x5e\x21\x33\x17\x77",
                        src_seaid=b"\x22\xde\xd6\x62\xde\x11\x22\x36\xbe\xad\x0a\x12\x82\x43\x26\x80\xef\x37\xd9\xc7",
                        ext_addr=b"\xEE\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\xFF",
                        option_a=b"\xEE\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xFF",
                        option_b=b"\xEE\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xFF",
                        option_c=b"\xEE\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xFF",
                        option_d=b"\xEE\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xFF")

        # 10 byte
        seagp = raw([0x00, 0x60, 0x00, 0x00, 0x00, 0x00])  # pn
        pn = raw([0x00, 0x00, 0x00, 0x00])
        # 42 byte
        seasp = raw([0x20,  # flags
                     0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 # preference offset8 net flag 
                 ])

        # NeT_defined Fields
        rsip_idx=0x80
        rsip  = int(ip.ip_address("7001::00%02x:0001"%rsip_idx))
        byte_rsip = rsip.to_bytes(16, 'big')
        rpn = 0
        byte_rpn = rpn.to_bytes(4, 'big')
        expect_rpn = raw([0x00,0x00,0x00, 0x00])

        test_pkt = bytes(eth / ipv6 / idp_full / seagp / pn / seasp) + byte_rsip + byte_rpn + bytes(payload) 
        expect_test_pkt = bytes(eth / ipv6 / idp_full / seagp / pn / seasp) + byte_rsip + expect_rpn + bytes(payload)

        await tb.send_dat(test_pkt)
        cnt = cnt + 1
        #rx = await tb.recv()

        test_pkts.append(test_pkt)
        expect_test_pkts.append(expect_test_pkt)
        print(cnt)
    
    print("------------------send complete--------------------")
    
    for expect_test_pkt in expect_test_pkts:
        print("------------------recv begin--------------------")
        rx = await tb.recv()
     
        print(bytes(rx.tdata))
        print(bytes(expect_test_pkt))
        assert bytes(rx.tdata) == bytes(expect_test_pkt)   
        mat_result,mat_addr,mat_value = hash_table.match(insert_key_list[0])
        bit_mat_addr = BinaryValue(n_bits=addr_width, bigEndian=False)
        bit_mat_addr.integer = mat_addr
        print(bit_mat_addr)

        expect_tuser = (0xba0000<<48)+(len(expect_test_pkt)<<32) + 0x050e8080
        print(len(expect_test_pkt))

        bytes_val = expect_tuser.to_bytes(9, 'big')
        bytes_val_1 = rx.tuser.to_bytes(9, 'big')
        print(bytes_val_1)
        print(bytes_val)
        assert rx.tuser== expect_tuser
        cnt = cnt + 1

    assert tb.axis_source.empty()
    assert tb.axis_sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

async def run_test_nack_hit(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()
    flowmod = FLOWMOD_CSR(dut,0x2910) #ctrl_addr

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    key_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))
    value_width=int(os.getenv("PARAM_VALUE_WIDTH", "0"))+1
    addr_width=int(os.getenv("PARAM_ADDR_WIDTH", "11"))
    mask_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))

    hash_table = H3_4_Way(key_width = key_width, addr_width=addr_width, value_width=value_width, matrix=matrix_256_11)
    tb.log.info("flowmod table begin")

    insert_key_list=[]

    rsip_0  = int(ip.ip_address("7001::0001:0001"))
    dstip_0 = int(ip.ip_address("7001::0081:0001"))
    dstip_1 = int(ip.ip_address("5001::0001:0001"))

    err_cnt = 0
    for i in range(16):
        key_val = BinaryValue(n_bits=key_width, bigEndian=False)
        value_val = BinaryValue(n_bits=value_width, bigEndian=False)

        key_val.integer = tb.gen_key_mau17_reli_send(RSIP=rsip_0+i*0x10000, DstIP=dstip_1+i*0x10000)
        result_val, addr_val = hash_table.insert(key = key_val, value = value_val)
        
        if(result_val):
            await flowmod.flowmod_write_key(addr_val,key_val,key_width)
            insert_key_list.append(copy.deepcopy(key_val))
            await flowmod.flowmod_write_value(addr_val,0x1,value_width+1)
            await flowmod.flowmod_write_state(addr_val,0x0,state_width=32)

            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
        else:
            print (f"fib_host insert conflict; addr = {addr_val}; key = {key_val.integer}; value = {key_val.integer}; err_cnt = {err_cnt}")
            err_cnt += 1
            pass
        
    tb.log.info("flowmod table complete")


    print("-----------------------------flowmod complete!!!!!!!!!!!!!--------------------------------------------")
    
    test_pkts = []
    expect_test_pkts = []
    cnt =0 

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src="66:77:88:99:aa:bb", dst="00:11:22:33:44:55", type=0x86dd)
        ipv6 = IPv6(nh=IDP_PROT, src="5001::0001:0001", dst="7001::0001:0001", version=6, hlim=255, fl=0, tc=0)

        idp_full = IDP_Full(next_header=TRANSPORT_LAYER_PROT, header_length=IDP_HEADER_LEN_FULL, dst_seaid_type=1,
                        src_seaid_type=0, dst_seaid_len=6, src_seaid_len=6,
                        service_type=0, route_policy=0, queue_priority=0, ira=0x20, ira_param_0=0,
                        ira_param_1=1,
                        ira_param_2=2, ira_param_3=0, ira_param_4=4, ira_param_5=5, ira_param_6=6, ira_param_7=7,
                        reserved=0x8, flag=0x1,
                        dst_seaid=b"\x31\xf8\xf4\x24\xb3\x7b\xb0\x65\x8f\xf5\x02\x02\x55\x9e\x97\x5e\x21\x33\x17\x77",
                        src_seaid=b"\x22\xde\xd6\x62\xde\x11\x22\x36\xbe\xad\x0a\x12\x82\x43\x26\x80\xef\x37\xd9\xc7",
                        ext_addr=b"\xEE\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\xFF",
                        option_a=b"\xEE\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xFF",
                        option_b=b"\xEE\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xFF",
                        option_c=b"\xEE\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xFF",
                        option_d=b"\xEE\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xFF")

        # 10 byte
        seagp = raw([0x00, 0x60, 0x00, 0x00, 0x00, 0x00])  # pn
        pn = raw([0x00, 0x00, 0x00, 0x00])
        # 42 byte
        seasp = raw([0x20,  # flags
                     0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 # preference offset8 net flag 
                 ])

        # NeT_defined Fields
        rsip_idx=0x01
        rsip  = int(ip.ip_address("7001::00%02x:0001"%rsip_idx))
        byte_rsip = rsip.to_bytes(16, 'big')
        rpn = 0
        byte_rpn = rpn.to_bytes(4, 'big')
        expect_rpn = raw([0x00,0x00,0x00,0x00])

        test_pkt = bytes(eth / ipv6 / idp_full / seagp / pn / seasp) + byte_rsip + byte_rpn + bytes(payload) 
        expect_test_pkt = bytes(eth / ipv6 / idp_full / seagp / pn / seasp) + byte_rsip + expect_rpn + bytes(payload)

        await tb.send_nack(test_pkt)
        cnt = cnt + 1
        #rx = await tb.recv()

        test_pkts.append(test_pkt)
        expect_test_pkts.append(expect_test_pkt)
        print(cnt)
    
    print("------------------send complete--------------------")
    
    for expect_test_pkt in expect_test_pkts:
        print("------------------recv begin--------------------")
        rx = await tb.recv()
     
        print(bytes(rx.tdata))
        print(bytes(expect_test_pkt))
        assert bytes(rx.tdata) == bytes(expect_test_pkt)   
        mat_result,mat_addr,mat_value = hash_table.match(insert_key_list[0])
        bit_mat_addr = BinaryValue(n_bits=addr_width, bigEndian=False)
        bit_mat_addr.integer = mat_addr
        print(bit_mat_addr)

        expect_tuser = (0xba<<64)+(int(bit_mat_addr[9:0])<<48)+(len(expect_test_pkt)<<32) + 0x310e8080
        print(len(expect_test_pkt))

        bytes_val = expect_tuser.to_bytes(9, 'big')
        bytes_val_1 = rx.tuser.to_bytes(9, 'big')
        print(bytes_val_1)
        print(bytes_val)
        assert rx.tuser== expect_tuser
        cnt = cnt + 1

    assert tb.axis_source.empty()
    assert tb.axis_sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

async def run_test_nack_unhit(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()
    flowmod = FLOWMOD_CSR(dut,0x2910) #ctrl_addr

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    key_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))
    value_width=int(os.getenv("PARAM_VALUE_WIDTH", "0"))+1
    addr_width=int(os.getenv("PARAM_ADDR_WIDTH", "11"))
    mask_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))

    hash_table = H3_4_Way(key_width = key_width, addr_width=addr_width, value_width=value_width, matrix=matrix_256_11)
    tb.log.info("flowmod table begin")

    insert_key_list=[]

    rsip_0  = int(ip.ip_address("7001::0001:0001"))
    dstip_0 = int(ip.ip_address("7001::0081:0001"))
    dstip_1 = int(ip.ip_address("5001::0001:0001"))

    err_cnt = 0
    for i in range(16):
        key_val = BinaryValue(n_bits=key_width, bigEndian=False)
        value_val = BinaryValue(n_bits=value_width, bigEndian=False)

        key_val.integer = tb.gen_key_mau17_reli_send(RSIP=rsip_0+i*0x10000, DstIP=dstip_1+i*0x10000)
        result_val, addr_val = hash_table.insert(key = key_val, value = value_val)
        
        if(result_val):
            await flowmod.flowmod_write_key(addr_val,key_val,key_width)
            insert_key_list.append(copy.deepcopy(key_val))
            await flowmod.flowmod_write_value(addr_val,0x1,value_width+1)
            await flowmod.flowmod_write_state(addr_val,0x0,state_width=32)

            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
        else:
            print (f"fib_host insert conflict; addr = {addr_val}; key = {key_val.integer}; value = {key_val.integer}; err_cnt = {err_cnt}")
            err_cnt += 1
            pass
        
    tb.log.info("flowmod table complete")


    print("-----------------------------flowmod complete!!!!!!!!!!!!!--------------------------------------------")
    
    test_pkts = []
    expect_test_pkts = []
    cnt =0 

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src="66:77:88:99:aa:bb", dst="00:11:22:33:44:55", type=0x86dd)
        ipv6 = IPv6(nh=IDP_PROT, src="2001::200", dst="5001::0001:0001", version=6, hlim=255, fl=0, tc=0)

        idp_full = IDP_Full(next_header=TRANSPORT_LAYER_PROT, header_length=IDP_HEADER_LEN_FULL, dst_seaid_type=1,
                        src_seaid_type=0, dst_seaid_len=6, src_seaid_len=6,
                        service_type=0, route_policy=0, queue_priority=0, ira=0x20, ira_param_0=0,
                        ira_param_1=1,
                        ira_param_2=2, ira_param_3=0, ira_param_4=4, ira_param_5=5, ira_param_6=6, ira_param_7=7,
                        reserved=0x8, flag=0x1,
                        dst_seaid=b"\x31\xf8\xf4\x24\xb3\x7b\xb0\x65\x8f\xf5\x02\x02\x55\x9e\x97\x5e\x21\x33\x17\x77",
                        src_seaid=b"\x22\xde\xd6\x62\xde\x11\x22\x36\xbe\xad\x0a\x12\x82\x43\x26\x80\xef\x37\xd9\xc7",
                        ext_addr=b"\xEE\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\xFF",
                        option_a=b"\xEE\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xFF",
                        option_b=b"\xEE\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xFF",
                        option_c=b"\xEE\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xFF",
                        option_d=b"\xEE\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xFF")

        # 10 byte
        seagp = raw([0x00, 0x60, 0x00, 0x00, 0x00, 0x00])  # pn
        pn = raw([0x00, 0x00, 0x00, 0x00])
        # 42 byte
        seasp = raw([0x20,  # flags
                     0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 # preference offset8 net flag 
                 ])

        # NeT_defined Fields
        rsip_idx=0x01
        rsip  = int(ip.ip_address("7001::00%02x:0001"%rsip_idx))
        byte_rsip = rsip.to_bytes(16, 'big')
        rpn = 0
        byte_rpn = rpn.to_bytes(4, 'big')
        expect_rpn = raw([0x00,0x00,0x00,0x00])

        test_pkt = bytes(eth / ipv6 / idp_full / seagp / pn / seasp) + byte_rsip + byte_rpn + bytes(payload) 
        expect_test_pkt = bytes(eth / ipv6 / idp_full / seagp / pn / seasp) + byte_rsip + expect_rpn + bytes(payload)

        await tb.send_nack(test_pkt)
        cnt = cnt + 1
        #rx = await tb.recv()

        test_pkts.append(test_pkt)
        expect_test_pkts.append(expect_test_pkt)
        print(cnt)
    
    print("------------------send complete--------------------")
    
    for expect_test_pkt in expect_test_pkts:
        print("------------------recv begin--------------------")
        rx = await tb.recv()
     
        print(bytes(rx.tdata))
        print(bytes(expect_test_pkt))
        assert bytes(rx.tdata) == bytes(expect_test_pkt)   
        mat_result,mat_addr,mat_value = hash_table.match(insert_key_list[0])
        bit_mat_addr = BinaryValue(n_bits=addr_width, bigEndian=False)
        bit_mat_addr.integer = mat_addr
        print(bit_mat_addr)

        expect_tuser = (0xba0000<<48)+(len(expect_test_pkt)<<32) + 0x110e8080
        print(len(expect_test_pkt))

        bytes_val = expect_tuser.to_bytes(9, 'big')
        bytes_val_1 = rx.tuser.to_bytes(9, 'big')
        print(bytes_val_1)
        print(bytes_val)
        assert rx.tuser== expect_tuser
        cnt = cnt + 1

    assert tb.axis_source.empty()
    assert tb.axis_sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

async def run_test_ipv4(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()
    flowmod = FLOWMOD_CSR(dut,0x2910) #ctrl_addr

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    key_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))
    value_width=int(os.getenv("PARAM_VALUE_WIDTH", "0"))+1
    addr_width=int(os.getenv("PARAM_ADDR_WIDTH", "11"))
    mask_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))

    hash_table = H3_4_Way(key_width = key_width, addr_width=addr_width, value_width=value_width, matrix=matrix_256_11)
    tb.log.info("flowmod table begin")

    insert_key_list=[]

    rsip_0  = int(ip.ip_address("7001::0001:0001"))
    dstip_0 = int(ip.ip_address("7001::0081:0001"))
    dstip_1 = int(ip.ip_address("5001::0001:0001"))

    err_cnt = 0
    for i in range(16):
        key_val = BinaryValue(n_bits=key_width, bigEndian=False)
        value_val = BinaryValue(n_bits=value_width, bigEndian=False)

        key_val.integer = tb.gen_key_mau17_reli_send(RSIP=rsip_0+i*0x10000, DstIP=dstip_1+i*0x10000)
        result_val, addr_val = hash_table.insert(key = key_val, value = value_val)
        
        if(result_val):
            await flowmod.flowmod_write_key(addr_val,key_val,key_width)
            insert_key_list.append(copy.deepcopy(key_val))
            await flowmod.flowmod_write_value(addr_val,0x1,value_width+1)
            await flowmod.flowmod_write_state(addr_val,0x0,state_width=32)

            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
        else:
            print (f"fib_host insert conflict; addr = {addr_val}; key = {key_val.integer}; value = {key_val.integer}; err_cnt = {err_cnt}")
            err_cnt += 1
            pass
        
    tb.log.info("flowmod table complete")


    print("-----------------------------flowmod complete!!!!!!!!!!!!!--------------------------------------------")
    
    test_pkts = []
    expect_test_pkts = []
    cnt =0 

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src="66:77:88:99:aa:bb", dst="00:11:22:33:44:55", type=0x0800)
        ipv4 = IP(id=0, src = "192.168.1.2", dst = "192.168.1.4")
        rawpkt_seq =  str(cnt)
        test_pkt = eth / ipv4 / payload / rawpkt_seq

        pkt_in_frame = AxiStreamFrame()
        pkt_in_frame.tdata = bytes(test_pkt)
        print(pkt_in_frame.tdata)
        print(pkt_in_frame)
        pkt_in_frame.tuser = (len(test_pkt)<<32) + 0x010e8080

        await tb.axis_source.send(pkt_in_frame)
        cnt = cnt + 1
        #rx = await tb.recv()

        test_pkts.append(test_pkt)
        print(cnt)
    
    print("------------------send complete--------------------")
    
    for test_pkt in test_pkts:
        print("------------------recv begin--------------------")
        rx = await tb.recv()
     
        print(bytes(rx.tdata))
        print(bytes(test_pkt))
        assert bytes(rx.tdata) == bytes(test_pkt)   
        mat_result,mat_addr,mat_value = hash_table.match(insert_key_list[0])
        bit_mat_addr = BinaryValue(n_bits=addr_width, bigEndian=False)
        bit_mat_addr.integer = mat_addr
        print(bit_mat_addr)

        expect_tuser = (0x0e0000<<48)+(len(test_pkt)<<32) + 0x010e8080

        bytes_val = expect_tuser.to_bytes(9, 'big')
        bytes_val_1 = rx.tuser.to_bytes(9, 'big')
        print(bytes_val_1)
        print(bytes_val)
        assert rx.tuser== expect_tuser
        cnt = cnt + 1

    assert tb.axis_source.empty()
    assert tb.axis_sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

async def run_test_nack_dat(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):
    tb = TB(dut)
    await tb.reset()
    flowmod = FLOWMOD_CSR(dut,0x2910) #ctrl_addr

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    key_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))
    value_width=int(os.getenv("PARAM_VALUE_WIDTH", "0"))+1
    addr_width=int(os.getenv("PARAM_ADDR_WIDTH", "11"))
    mask_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))

    hash_table = H3_4_Way(key_width = key_width, addr_width=addr_width, value_width=value_width, matrix=matrix_256_11)
    tb.log.info("flowmod table begin")

    insert_key_list=[]

    rsip_0  = int(ip.ip_address("7001::0001:0001"))
    dstip_0 = int(ip.ip_address("7001::0081:0001"))
    dstip_1 = int(ip.ip_address("5001::0001:0001"))

    err_cnt = 0
    for i in range(16):
        key_val = BinaryValue(n_bits=key_width, bigEndian=False)
        value_val = BinaryValue(n_bits=value_width, bigEndian=False)

        key_val.integer = tb.gen_key_mau17_reli_send(RSIP=rsip_0, DstIP=dstip_1+i*0x10000)
        result_val, addr_val = hash_table.insert(key = key_val, value = value_val)
        
        if(result_val):
            await flowmod.flowmod_write_key(addr_val,key_val,key_width)
            insert_key_list.append(copy.deepcopy(key_val))
            await flowmod.flowmod_write_value(addr_val,0x1,value_width+1)
            await flowmod.flowmod_write_state(addr_val,0x0,state_width=32)

            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
        else:
            print (f"fib_host insert conflict; addr = {addr_val}; key = {key_val.integer}; value = {key_val.integer}; err_cnt = {err_cnt}")
            err_cnt += 1
            pass
        
    tb.log.info("flowmod table complete")


    print("-----------------------------flowmod complete!!!!!!!!!!!!!--------------------------------------------")
    
    test_pkts = []
    expect_test_pkts = []
    cnt =0 

    for payload in [payload_data(x) for x in payload_lengths()]:
        temp=cnt%8+1
        eth = Ether(src="66:77:88:99:aa:bb", dst="00:11:22:33:44:55", type=0x86dd)
        ipv6 = IPv6(nh=IDP_PROT, src="2001::200", dst="5001::000%01x:0001"%temp, version=6, hlim=255, fl=0, tc=0)

        idp_full = IDP_Full(next_header=TRANSPORT_LAYER_PROT, header_length=IDP_HEADER_LEN_FULL, dst_seaid_type=1,
                        src_seaid_type=0, dst_seaid_len=6, src_seaid_len=6,
                        service_type=0, route_policy=0, queue_priority=0, ira=0x20, ira_param_0=0,
                        ira_param_1=1,
                        ira_param_2=2, ira_param_3=0, ira_param_4=4, ira_param_5=5, ira_param_6=6, ira_param_7=7,
                        reserved=0x8, flag=0x1,
                        dst_seaid=b"\x31\xf8\xf4\x24\xb3\x7b\xb0\x65\x8f\xf5\x02\x02\x55\x9e\x97\x5e\x21\x33\x17\x77",
                        src_seaid=b"\x22\xde\xd6\x62\xde\x11\x22\x36\xbe\xad\x0a\x12\x82\x43\x26\x80\xef\x37\xd9\xc7",
                        ext_addr=b"\xEE\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\xFF",
                        option_a=b"\xEE\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xFF",
                        option_b=b"\xEE\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xFF",
                        option_c=b"\xEE\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xFF",
                        option_d=b"\xEE\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xFF")

        # 10 byte
        seagp = raw([0x00, 0x60, 0x00, 0x00, 0x00, 0x00])  # pn
        pn = raw([0x00, 0x00, 0x00, 0x00])
        # 42 byte
        seasp = raw([0x20,  # flags
                     0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 # preference offset8 net flag 
                 ])

        # NeT_defined Fields
        rsip_idx=0x01
        rsip  = int(ip.ip_address("7001::00%02x:0001"%rsip_idx))
        byte_rsip = rsip.to_bytes(16, 'big')
        rpn = int(cnt/8)
        byte_rpn = rpn.to_bytes(4, 'big')
        expect_rpn = raw([0x00,0x00,0x00, int(cnt/8)])

        test_pkt_dat = bytes(eth / ipv6 / idp_full / seagp / pn / seasp) + byte_rsip + byte_rpn + bytes(payload) 
        expect_test_pkt_dat = bytes(eth / ipv6 / idp_full / seagp / pn / seasp) + byte_rsip + expect_rpn + bytes(payload)

        await tb.send_dat(test_pkt_dat)
        cnt = cnt + 1
        #rx = await tb.recv()

        test_pkts.append(test_pkt_dat)
        expect_test_pkts.append(expect_test_pkt_dat)
        print(cnt)

    await tb.send_dat(test_pkt_dat)

    expect_rpn = raw([0x00,0x00,0x00,0x01])

    expect_test_pkt_dat1 = bytes(eth / ipv6 / idp_full / seagp / pn / seasp) + byte_rsip + expect_rpn + bytes(payload)
    expect_test_pkts.append(expect_test_pkt_dat1)
    expect_rpn = raw([0x00,0x00,0x00,0x02])
    expect_test_pkt_dat2 = bytes(eth / ipv6 / idp_full / seagp / pn / seasp) + byte_rsip + expect_rpn + bytes(payload)


    eth = Ether(src="66:77:88:99:aa:bb", dst="00:11:22:33:44:55", type=0x86dd)
    ipv6 = IPv6(nh=IDP_PROT, src="5001::0007:0001", dst="7001::0001:0001", version=6, hlim=255, fl=0, tc=0)
    idp_full = IDP_Full(next_header=TRANSPORT_LAYER_PROT, header_length=IDP_HEADER_LEN_FULL, dst_seaid_type=1,
                    src_seaid_type=0, dst_seaid_len=6, src_seaid_len=6,
                    service_type=0, route_policy=0, queue_priority=0, ira=0x20, ira_param_0=0,
                    ira_param_1=1,
                    ira_param_2=2, ira_param_3=0, ira_param_4=4, ira_param_5=5, ira_param_6=6, ira_param_7=7,
                    reserved=0x8, flag=0x1,
                    dst_seaid=b"\x31\xf8\xf4\x24\xb3\x7b\xb0\x65\x8f\xf5\x02\x02\x55\x9e\x97\x5e\x21\x33\x17\x77",
                    src_seaid=b"\x22\xde\xd6\x62\xde\x11\x22\x36\xbe\xad\x0a\x12\x82\x43\x26\x80\xef\x37\xd9\xc7",
                    ext_addr=b"\xEE\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\x33\xFF",
                    option_a=b"\xEE\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xFF",
                    option_b=b"\xEE\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xBB\xFF",
                    option_c=b"\xEE\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xFF",
                    option_d=b"\xEE\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xDD\xFF")

    # 10 byte
    seagp = raw([0x00, 0x60, 0x00, 0x00, 0x00, 0x00])  # pn
    pn = raw([0x00, 0x00, 0x00, 0x00])
    # 42 byte
    seasp = raw([0x20,  # flags
                    0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 # preference offset8 net flag 
                ])
    # NeT_defined Fields
    rsip  = int(ip.ip_address("7001::0001:0001"))
    byte_rsip = rsip.to_bytes(16, 'big')
    rpn = 0
    byte_rpn = rpn.to_bytes(4, 'big')
    expect_rpn = raw([0x00,0x00,0x00,0x00])
    test_pkt = bytes(eth / ipv6 / idp_full / seagp / pn / seasp) + byte_rsip + byte_rpn + bytes(payload) 
    expect_test_pkt = bytes(eth / ipv6 / idp_full / seagp / pn / seasp) + byte_rsip + expect_rpn + bytes(payload)
    await tb.send_nack(test_pkt)
    test_pkts.append(test_pkt)
    expect_test_pkts.append(expect_test_pkt)

    await tb.send_dat(test_pkt_dat)

    expect_rpn = raw([0x00,0x00,0x00,0x03])


    expect_test_pkt = bytes(eth / ipv6 / idp_full / seagp / pn / seasp) + byte_rsip + expect_rpn + bytes(payload)
    expect_test_pkts.append(expect_test_pkt_dat2)


    print("------------------send complete--------------------")
    
    cnt=0
    for expect_test_pkt in expect_test_pkts:
        print("------------------recv"+str(cnt)+"begin--------------------")
        rx = await tb.recv()
        if (cnt<=6 ):
            #print(bytes(rx.tdata))
            #print(bytes(expect_test_pkt))
            assert bytes(rx.tdata) == bytes(expect_test_pkt)   
            mat_result,mat_addr,mat_value = hash_table.match(insert_key_list[cnt])
            bit_mat_addr = BinaryValue(n_bits=addr_width, bigEndian=False)
            bit_mat_addr.integer = mat_addr
            print("addr:",bit_mat_addr)

            expect_tuser = (0xba<<64)+(int(bit_mat_addr[9:0])<<48)+(len(expect_test_pkt)<<32) + 0x250e8080
            print(len(expect_test_pkt))

            bytes_val = expect_tuser.to_bytes(9, 'big')
            bytes_val_1 = rx.tuser.to_bytes(9, 'big')
            print(bytes_val_1)
            print(bytes_val)
            assert rx.tuser== expect_tuser
        if (cnt==7 or cnt==8):
            pass
        if (cnt>=9 ):
            #print(bytes(rx.tdata))
            #print(bytes(expect_test_pkt))
            assert bytes(rx.tdata) == bytes(expect_test_pkt)   
            mat_result,mat_addr,mat_value = hash_table.match(insert_key_list[6])
            bit_mat_addr = BinaryValue(n_bits=addr_width, bigEndian=False)
            bit_mat_addr.integer = mat_addr
            print("addr:",bit_mat_addr)

            expect_tuser = (0xba<<64)+(int(bit_mat_addr[9:0])<<48)+(len(expect_test_pkt)<<32) + 0x250e8080
            print(len(expect_test_pkt))

            bytes_val = expect_tuser.to_bytes(9, 'big')
            bytes_val_1 = rx.tuser.to_bytes(9, 'big')
            print(bytes_val_1)
            print(bytes_val)
            assert rx.tuser== expect_tuser
        cnt = cnt + 1

    assert tb.axis_source.empty()
    assert tb.axis_sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)



def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


def size_list():
    #return [32,64]
    return list(range(2048))


def incrementing_payload(length):
    return bytes(itertools.islice(itertools.cycle(range(256)), length))


if cocotb.SIM_NAME:
	for test in [
                # run_test_rbt_pktout,
                run_test_rbt_dat_hit,
				# run_test_dat_hit,
                #  run_test_dat_unhit, 
                #  run_test_nack_hit, 
                #  run_test_nack_unhit, 
                #  run_test_ipv4,
                # run_test_nack_dat,
				]:
                factory = TestFactory(test)
                factory.add_option("payload_lengths", [size_list])
                factory.add_option("payload_data", [incrementing_payload])
                factory.add_option("idle_inserter", [None,cycle_pause])
                factory.add_option("backpressure_inserter", [None,cycle_pause])
                factory.generate_tests()


    
