#!/usr/bin/env python
"""

"""

import itertools
import logging
import os

from scapy.layers.l2 import Ether
from scapy.all import raw

import random
import copy

import pytest
import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi.stream import define_stream
from cocotb.binary import BinaryValue, BinaryRepresentation
from miscext.hash_table import H3_4_Way,matrix_256_11
from scapyext.flowmod_controller_csr import FLOWMOD_CSR

ModBus, ModTransaction, ModSource, ModSink, ModMonitor = define_stream("mod",
    signals=["valid", "ready", "addr", "key", "mask", "value", "opcode"]
)

PhvBus, PhvTransaction, PhvSource, PhvSink, PhvMonitor = define_stream("phv",
    signals=["valid", "ready", "info"]
)

class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.fork(Clock(dut.clk, 8, units="ns").start())

        self.phv_source = PhvSource(PhvBus.from_prefix(dut, "s_phv"), dut.clk, dut.rst)
        self.phv_sink = PhvSink(PhvBus.from_prefix(dut, "m_phv"), dut.clk, dut.rst)

    def set_idle_generator(self, generator=None):
        if generator:
            self.phv_source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.phv_sink.set_pause_generator(generator())

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

    async def send_mod(self, addr, key, mask, value, opcode):
        mod = ModTransaction()
        mod.addr = addr
        mod.opcode = opcode
        mod.key = key       
        mod.mask = mask       
        mod.value = value 

        # await self.mod_source.send(mod)
        
    async def send_phv(self, phv):
        phvFrame = PhvTransaction()
        phvFrame.info = phv       
        await self.phv_source.send(phvFrame)

    async def recv(self):
        rx_frame = await self.phv_sink.recv()
        return rx_frame


def convert(phv_b,phv_h,phv_w):
    phv_b_count=int(os.getenv("PARAM_PHV_B_COUNT", "7"))
    phv_h_count=int(os.getenv("PARAM_PHV_H_COUNT", "2"))
    phv_w_count=int(os.getenv("PARAM_PHV_W_COUNT", "10"))
    phv_width=int(os.getenv("PARAM_PHV_WIDTH", "408"))
    phv_length=int(phv_width/8)
    phv_val = BinaryValue(n_bits=phv_width, bigEndian=False)
    for i in range(phv_b_count):
        phv_val[i*8+7:i*8] = phv_b[i]

    for i in range(phv_h_count):
        phv_val[(phv_b_count+2*i)*8+7:(phv_b_count+2*i)*8+0] = phv_h[i].to_bytes(2, 'little')[0]
        phv_val[(phv_b_count+2*i)*8+15:(phv_b_count+2*i)*8+8] = phv_h[i].to_bytes(2, 'little')[1]

    for i in range(phv_w_count):
        phv_val[(phv_b_count+phv_h_count*2+4*i)*8+7:(phv_b_count+phv_h_count*2+4*i)*8+0] = phv_w[i].to_bytes(4, 'little')[0]
        phv_val[(phv_b_count+phv_h_count*2+4*i)*8+15:(phv_b_count+phv_h_count*2+4*i)*8+8] = phv_w[i].to_bytes(4, 'little')[1]
        phv_val[(phv_b_count+phv_h_count*2+4*i)*8+23:(phv_b_count+phv_h_count*2+4*i)*8+16] = phv_w[i].to_bytes(4, 'little')[2]
        phv_val[(phv_b_count+phv_h_count*2+4*i)*8+31:(phv_b_count+phv_h_count*2+4*i)*8+24] = phv_w[i].to_bytes(4, 'little')[3]

    return phv_val

def countX(list,x):
    count = 0
    for a in list:
        if(a == x):
            count = count + 1

    print(count)
    return count-1

async def run_test_nack_hash(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)
    flowmod = FLOWMOD_CSR(dut,0x800) #ctrl_addr
    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    phv_b_count=int(os.getenv("PARAM_PHV_B_COUNT", "7"))
    phv_h_count=int(os.getenv("PARAM_PHV_H_COUNT", "2"))
    phv_w_count=int(os.getenv("PARAM_PHV_W_COUNT", "10"))

    phv_width=int(os.getenv("PARAM_PHV_WIDTH", "408"))
    phv_length=int(phv_width/8)

    key_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))
    key_length=int(key_width/8)
    value_width=int(os.getenv("PARAM_VALUE_WIDTH", "32"))
    value_length=int(value_width/8)    
    addr_width=int(os.getenv("PARAM_ADDR_WIDTH", "11"))
    addr_length=int(addr_width/8) 
    mask_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))

    hash_table = H3_4_Way(key_width = key_width, addr_width=addr_width, value_width=value_width, matrix=matrix_256_11)
    tb.log.info("flowmod table")

    insert_key_list=[]
    insert_addr_list=[]
    for i in range(16):
        key_val = BinaryValue(n_bits=key_width, bigEndian=False)
        value_val = BinaryValue(n_bits=value_width+1, bigEndian=False)

        for j in range(int(key_width/8)):
            key_val[(j+1)*8-1:j*8] = random.randint(0,0xff)
        for j in range(value_width):
            value_val[j] = random.randint(0,1)
        value_val[value_width] = 1
        result_val, addr_val = hash_table.insert(key = key_val, value = value_val)
        insert_key_list.append(copy.deepcopy(key_val))
        insert_addr_list.append(copy.deepcopy(addr_val))

        if(result_val):
            await flowmod.flowmod_write_key(addr_val,key_val,key_width)
            await flowmod.flowmod_write_value(addr_val,value_val,value_width+1)
            await flowmod.flowmod_write_state(addr_val,0xff,state_width=32)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
            await RisingEdge(tb.dut.clk)
        else:
            pass
    

    #match start
    test_data_list = []
    mat_value_list = []
    mat_value_list.clear()

    phv_b_in = [0] * phv_b_count
    phv_h_in = [0] * phv_h_count
    phv_w_in = [0] * phv_w_count

    phv_b_out = [0] * phv_b_count
    phv_h_out = [0] * phv_h_count
    phv_w_out = [0] * phv_w_count

    for f in range(16):

        phv_b_in[0] = 0x08 #pkt_propertya NACK_INDEX = 1
        phv_b_in[1] = 0x80 #pkt_valid valid.send_table_mask = 1 #_1000_0000_0000_1000
        phv_b_in[2] = 0x00 #inport
        phv_b_in[3] = 0x00 #outport
        phv_b_in[4] = 0x00 #ip_offset
        phv_b_in[5] = 0x01 #tid
        phv_b_in[6] = 0x00 #seatl_offset
        
        phv_h_in[0] = 0x0000 #pkt_len
        phv_h_in[1] = 0x0000 #flow_index
        
        phv_w_in[0] = 0x00 #protocol
        phv_w_in[1] = int(insert_key_list[f][159:128]) #dst_ip[31:0]
        phv_w_in[2] = int(insert_key_list[f][191:160]) #dst_ip[63:32]
        phv_w_in[3] = int(insert_key_list[f][223:192]) #dst_ip[95:64]
        phv_w_in[4] = int(insert_key_list[f][255:224]) #dst_ip[127:96]
        phv_w_in[5] = int(insert_key_list[f][31:0])  #rs_ip
        phv_w_in[6] = int(insert_key_list[f][63:32])#rs_ip
        phv_w_in[7] = int(insert_key_list[f][95:64])#rs_ip
        phv_w_in[8] = int(insert_key_list[f][127:96])#rs_ip
        # #pkt_rpn                                                    
        phv_w_in[9] = 0x0000000f #pkt_rpn
  
        await tb.send_phv(convert(phv_b_in,phv_h_in,phv_w_in)) #send initial phv input


        mat_result,mat_addr,mat_value = hash_table.match(insert_key_list[f])
        # print("mat_result",mat_result)
        # print("mat_value",mat_value)

        #copy phv_x_in to phv_x_out
        for i in range(phv_b_count):
            phv_b_out[i] = phv_b_in[i]

        for i in range(phv_h_count):
            phv_h_out[i] = phv_h_in[i]

        for i in range(phv_w_count):
            phv_w_out[i] = phv_w_in[i] # store initial phv value to new variable: phv_out

        if(mat_result & value_val[value_width]): #nack:if hit: 
            # phv_w_in[9]=0xff
            phv_b_in[1]=phv_b_in[1] | 0x08 # phv_b_reg[PKT_VALID_ON][RELI_BUFFER_HIT_INDEX]<=1;
            phv_h_in[1] = int(insert_addr_list[f]) # flow_index:phv_h_reg[FLOW_INDEX_NO]<=s_phv_mat_addr 
            #_1000_1000_0000_1000
        else: #nack:if not hit: 
            phv_b_in[3]=0x7F # phv_b_reg[OUTPORT_ON]  <= 8'b0111_1111;
            phv_b_in[5]=0x0F # phv_b_reg[TID_ON]  <= 15;
            #0111_1111_0000_0000_1000_0000_0000_1000
            # phv_h_in[1] = int(insert_addr_list[f]) 
        test_data_list.append(convert(phv_b_in,phv_h_in,phv_w_in))

    for test_data in test_data_list:
        rx_frame = await tb.recv()
        print("test_data",test_data)
        print("rx_frame.info",rx_frame.info)
        print("if equal",test_data == rx_frame.info)

        assert test_data == rx_frame.info
    # assert tb.phv_sink.empty()
    #match end

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)  


def cycle_pause():  
    return itertools.cycle([0])   

def cycle_pause1():  
    return itertools.cycle([1,0]) 

def cycle_pause2():
    return itertools.cycle([0,1])    

def cycle_pause3():
    return itertools.cycle([1, 1, 1, 0])

if cocotb.SIM_NAME:

    for test in [
        run_test_nack_hash,
    ]:
        factory = TestFactory(test)
        factory.add_option("idle_inserter", [cycle_pause, cycle_pause1]) #, cycle_pause1
        factory.add_option("backpressure_inserter", [cycle_pause, cycle_pause1])  #, cycle_pause1    
        factory.generate_tests()

