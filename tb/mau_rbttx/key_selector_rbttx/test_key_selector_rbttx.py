#!/usr/bin/env python
"""

"""

import itertools
import logging
import os

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


PhvBus, PhvTransaction, PhvSource, PhvSink, PhvMonitor = define_stream("phv",
    signals=["valid", "ready", "info"]
)

KeyBus, KeyTransaction, KeySource, KeySink, KeyMonitor = define_stream("key",
    signals=["valid", "ready", "info"]
)


class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.fork(Clock(dut.clk, 8, units="ns").start())

        self.phv_source = PhvSource(PhvBus.from_prefix(dut, "s_phv"), dut.clk, dut.rst)
        self.key_sink = KeySink(KeyBus.from_prefix(dut, "m_key"), dut.clk, dut.rst)

    def set_idle_generator(self, generator=None):
        if generator:
            self.phv_source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.key_sink.set_pause_generator(generator())

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

    async def send(self, pkt):
        phv = PhvTransaction()
  

        phv_width=int(os.getenv("PARAM_PHV_WIDTH", "456"))
        phv_length=int(phv_width/8)


        bin_val = BinaryValue(n_bits=phv_width, bigEndian=False)
        for i in range(phv_length):
            bin_val[i*8+7:i*8] = pkt[i]

        phv.info = bin_val       

        await self.phv_source.send(phv)
        

    async def recv(self):
        rx_frame = await self.key_sink.recv()
        return rx_frame.info


async def run_test(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)
    
    phv_b_count=int(os.getenv("PARAM_PHV_B_COUNT", "9"))
    phv_h_count=int(os.getenv("PARAM_PHV_H_COUNT", "2"))
    phv_w_count=int(os.getenv("PARAM_PHV_W_COUNT", "11"))

    test_data_list = []

    for i in range(128):
        phv_width=int(os.getenv("PARAM_PHV_WIDTH", "456"))
        phv_length=int(phv_width/8)
        test_data =bytearray(itertools.islice(itertools.cycle(range(i+1)), phv_length))
        
        key_width=int(os.getenv("PARAM_KEY_WIDTH", "256"))    
        bin_val = BinaryValue(n_bits=key_width, bigEndian=False)

        # W5
        bin_val[0*8+7:0*8] = test_data[13+5*4]
        bin_val[1*8+7:1*8] = test_data[13+5*4+1]
        bin_val[2*8+7:2*8] = test_data[13+5*4+2]
        bin_val[3*8+7:3*8] = test_data[13+5*4+3]
        # W6
        bin_val[4*8+7:4*8] = test_data[13+6*4]
        bin_val[5*8+7:5*8] = test_data[13+6*4+1]
        bin_val[6*8+7:6*8] = test_data[13+6*4+2]
        bin_val[7*8+7:7*8] = test_data[13+6*4+3]
        # W7
        bin_val[8*8+7:8*8] = test_data[13+7*4]
        bin_val[9*8+7:9*8] = test_data[13+7*4+1]
        bin_val[10*8+7:10*8] = test_data[13+7*4+2]
        bin_val[11*8+7:11*8] = test_data[13+7*4+3]
        # W8            
        bin_val[12*8+7:12*8] = test_data[13+8*4]
        bin_val[13*8+7:13*8] = test_data[13+8*4+1]
        bin_val[14*8+7:14*8] = test_data[13+8*4+2]
        bin_val[15*8+7:15*8] = test_data[13+8*4+3]
        # W1
        bin_val[16*8+7:16*8] = test_data[13+1*4]
        bin_val[17*8+7:17*8] = test_data[13+1*4+1]
        bin_val[18*8+7:18*8] = test_data[13+1*4+2]
        bin_val[19*8+7:19*8] = test_data[13+1*4+3]
        # W2
        bin_val[20*8+7:20*8] = test_data[13+2*4]
        bin_val[21*8+7:21*8] = test_data[13+2*4+1]
        bin_val[22*8+7:22*8] = test_data[13+2*4+2]
        bin_val[23*8+7:23*8] = test_data[13+2*4+3]
        # W3
        bin_val[24*8+7:24*8] = test_data[13+3*4]
        bin_val[25*8+7:25*8] = test_data[13+3*4+1]
        bin_val[26*8+7:26*8] = test_data[13+3*4+2]
        bin_val[27*8+7:27*8] = test_data[13+3*4+3]
        # W4         
        bin_val[28*8+7:28*8] = test_data[13+4*4]
        bin_val[29*8+7:29*8] = test_data[13+4*4+1]
        bin_val[30*8+7:30*8] = test_data[13+4*4+2]
        bin_val[31*8+7:31*8] = test_data[13+4*4+3]           
        

        test_data_list.append(bin_val)

        await tb.send(test_data)

    for test_data in test_data_list:

        key = await tb.recv()
        assert test_data == key

    assert tb.key_sink.empty()

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


def size_list():
    return list(range(1, 128))


def incrementing_payload(length):
    return bytes(itertools.islice(itertools.cycle(range(256)), length))


if cocotb.SIM_NAME:

    factory = TestFactory(run_test)
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload])
    factory.add_option("idle_inserter", [cycle_pause, cycle_pause1, cycle_pause2, cycle_pause3])
    factory.add_option("backpressure_inserter", [cycle_pause, cycle_pause1, cycle_pause2, cycle_pause3])  
    factory.generate_tests()
