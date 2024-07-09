#!/usr/bin/env python
"""

"""

import itertools
import logging
import os
import random

from scapy.layers.l2 import Ether
from scapy.all import raw


import pytest
import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi.stream import define_stream
from cocotb.binary import BinaryValue, BinaryRepresentation


sPhvBus, sPhvTransaction, sPhvSource, sPhvSink, sPhvMonitor = define_stream("sphv",
    signals=["valid", "ready", "info"]
)

MatBus, MatTransaction, MatSource, MatSink, MatMonitor = define_stream("smat",
    signals=["valid", "ready", "hit","addr"]
)
mPhvBus, mPhvTransaction, mPhvSource, mPhvSink, mPhvMonitor = define_stream("mphv",
    signals=["valid", "ready", "info"]
)


class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.fork(Clock(dut.clk, 5, units="ns").start())

        self.phv_source = sPhvSource(sPhvBus.from_prefix(dut, "s_phv"), dut.clk, dut.rst)
        self.mat_source = MatSource(MatBus.from_prefix(dut, "s_mat"), dut.clk, dut.rst)
        self.phv_sink = mPhvSink(mPhvBus.from_prefix(dut, "m_phv"), dut.clk, dut.rst)

    def set_idle_generator(self, generator=None):
        if generator:
            self.phv_source.set_pause_generator(generator())
            self.mat_source.set_pause_generator(generator())

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
        self.dut.reliable_enable.value=1
        
    async def send_phv(self, phv):
        phvFrame = sPhvTransaction()
        phvFrame.info = phv       
        await self.phv_source.send(phvFrame)
        
    async def send_mat(self, hit, addr):
        mat = MatTransaction()
        mat.hit = hit    
        mat.addr =addr
        await self.mat_source.send(mat)        

    async def recv(self):
        rx_frame = await self.phv_sink.recv()
        return rx_frame

def convert(phv_b,phv_h,phv_w):
    phv_b_count=int(os.getenv("PARAM_PHV_B_COUNT", "9"))
    phv_h_count=int(os.getenv("PARAM_PHV_H_COUNT", "2"))
    phv_w_count=int(os.getenv("PARAM_PHV_W_COUNT", "11"))
    phv_width=int(os.getenv("PARAM_PHV_WIDTH", "456"))
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

async def run_test(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    phv_b_count=int(os.getenv("PARAM_PHV_B_COUNT", "9"))
    phv_h_count=int(os.getenv("PARAM_PHV_H_COUNT", "2"))
    phv_w_count=int(os.getenv("PARAM_PHV_W_COUNT", "11"))

    test_data_list = []
    hit_list = []

    addr_list=[1,1,2,2, 1,2,3]
    hit_list=[1,1,1,1, 1,1,1,]
    #expect_matsel_list=[0,1,0,1,3,2,0, 3,0]
    #matsel_list=[0,1,2,3,0]

    pktrpn_list=[1,2,0,1,3,1,0]
    #flowst_list=[0,0,0,0,7]
    exprpn_list=[0,2,0,1,3,2,0]
    for i in range(7):
        phv_b_in = [0] * phv_b_count
        phv_h_in = [0] * phv_h_count
        phv_w_in = [0] * phv_w_count

        phv_b_out = [0] * phv_b_count
        phv_h_out = [0] * phv_h_count
        phv_w_out = [0] * phv_w_count
    
        phv_w_in[9]=pktrpn_list[i]
        phv_b_in[4]=0x02
        phv_b_in[0] = phv_b_in[0] | 0x4

        phv_w_out[10]=exprpn_list[i]
        phv_w_out[9]=pktrpn_list[i]
        phv_b_out[4]=phv_b_in[4] |0x04
        if (i==0):
            phv_b_out[0]=phv_b_in[0] | 0xc0

        sendphv=convert(phv_b_in,phv_h_in,phv_w_in)
        test_data_list.append(convert(phv_b_out,phv_h_out,phv_w_out))
        await tb.send_mat(1,addr_list[i])
        await tb.send_phv(sendphv)

    for i in range(7):
        phv = await tb.recv()
        print("test:",i)
        #assert test_data_list[i] == phv.info

    assert tb.phv_sink.empty()

    for _ in range(20):
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
        run_test,
    ]:
        factory = TestFactory(run_test)
        factory.add_option("idle_inserter", [ cycle_pause1])
        factory.add_option("backpressure_inserter", [ cycle_pause3])                  
        factory.generate_tests()

# cocotb-test
