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
from scapyext.seadp import IDP_Full,IDP_Stealth,IDP_Stealth_INT,IDP_Multi,IDP_Multi_INT,IDP_Cache,IDP_Cache_INT


import pytest
import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory
from cocotb.binary import BinaryValue
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource, AxiStreamSink
from cocotbext.axi.stream import define_stream

InputBus, InputTransaction, InputSource, InputSink, InputMonitor = define_stream("Input",
    signals=["valid", "ready", "data", "length", "phv"]
)

OutputBus, OutputTransaction, OutputSource, OutputSink, OutputMonitor = define_stream("Output",
    signals=["valid", "ready", "data", "length", "phv"]
)
   
class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.fork(Clock(dut.clk, 8, units="ns").start())

        self.source = InputSource(InputBus.from_prefix(dut, "in_proto_hdr"), dut.clk, dut.rst)
        self.sink = OutputSink(OutputBus.from_prefix(dut, "out_proto_hdr"), dut.clk, dut.rst)


    def set_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())
            
    def set_backpressure_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())
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

    async def send(self, pkt):
        inputTransaction = InputTransaction()
        raw_pkt = raw(pkt)
        data_val = BinaryValue(n_bits=2048, bigEndian=False)
        for i in range(len(pkt)):
            if(i<256):
                data_val[(255-i)*8+7:(255-i)*8] = raw_pkt[i]

        inputTransaction.data = data_val
        inputTransaction.length = 74
        await self.source.send(inputTransaction)

    async def recv(self):
        rx = await self.sink.recv()
        return rx

IDP_PROT = 0x92
TRANSPORT_LAYER_PROT = 0x93

ETH_HEADER_LEN = 14
VLAN_HEADER_LEN=4
PPPOE_HEADER_LEN=8
VLAN_PPPOE_HEADER_LEN=12
IPV6_HEADER_LEN = 40
IDP_HEADER_LEN_FULL = 132
IDP_HEADER_LEN_STEALTH = 52
IDP_HEADER_LEN_STEALTH_INT = 100
IDP_HEADER_LEN_MULTI = 84

PUBLIC_HEADER_LEN = 10
UDP_HEADER_LEN = 8
PHV_WIDTH = 400

# W 32bit 
PROTO_NO = 0
DST_IPV6_NO = 1
SEASP_RSIP_NO = 5
SRC_IPV6_NO = 9
SEASP_RPN_NO = 13
#SRC_IPV6_SIZE = 4


# H 16bit

PKTLEN_NO = 0



# B 8bit
PKT_PROPERTY_NO = 0
PHV_IN_PORT_NO = 1
TABLE_MASK_NO=4
L3_OFFSET_NO=6
TRANSPORT_LAYER_OFFSET_NO = 7
TRANSPORT_LAYER_TYPE_NO = 8
TRANSPORT_LAYER_FLAG_NO = 9

def convert(phv_b,phv_h,phv_w):
    phv_b_count=int(os.getenv("PARAM_PHV_B_COUNT", "6"))
    phv_h_count=int(os.getenv("PARAM_PHV_H_COUNT", "2"))
    phv_w_count=int(os.getenv("PARAM_PHV_B_COUNT", "10"))
    phv_width=int(os.getenv("PARAM_PHV_WIDTH", "400"))
    phv_length=int(phv_width/8)
    phv_val = BinaryValue(n_bits=phv_width, bigEndian=False)
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


async def run_test_full(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_results = []
    seq = 1

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x86dd)
        eth_vlan = Ether(src = "66:77:88:99:aa:bb", dst = "00:11:22:33:44:55",  type= 0x8100)
        vlan = Dot1Q(vlan = 0x123, type = 0x8864)
        pppoe = raw([0x11,0x00,0x62,0xa2,0x00,0x2e,0x00,0x57])
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
        
        rawpkt_seq =  str(seq)
        # test_pkt = eth / ipv6 / idp_full / public_header_seasp / seasp / payload / rawpkt_seq
        test_pkt = eth / ipv6 / idp_full / public_header_seasp / seasp 



        
        await tb.send(test_pkt)
        seq = seq + 1

        #match start
        phv_b_count=int(os.getenv("PARAM_PHV_B_COUNT", "10"))
        phv_h_count=int(os.getenv("PARAM_PHV_H_COUNT", "2"))
        phv_w_count=int(os.getenv("PARAM_PHV_B_COUNT", "10"))

        phv_b_out = [0] * phv_b_count
        phv_h_out = [0] * phv_h_count
        phv_w_out = [0] * phv_w_count

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
        rx = await tb.recv()
        for i in range(PHV_WIDTH) :

            assert rx.phv[i]  == test_data[PHV_WIDTH-1-i]


    assert tb.sink.empty()
    assert tb.source.empty()

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
                   
                    run_test_full
         

                ] :
        factory = TestFactory(test)
        factory.add_option("payload_lengths", [size_list])
        factory.add_option("payload_data", [incrementing_payload])
        factory.add_option("idle_inserter", [None,cycle_pause])
        factory.add_option("backpressure_inserter", [None,cycle_pause])
        factory.generate_tests()


# cocotb-test
tests_dir = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl', 'parser'))
hdr_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', '..', '..', 'modules', 'common', 'rtl'))


@pytest.mark.parametrize("header_width", [592])
@pytest.mark.parametrize("tuser_width", [60])
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

