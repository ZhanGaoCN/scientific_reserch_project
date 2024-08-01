/*
 * Created on 20240730
 *
 * Copyright (c) 2024 IOA UCAS
 *
 * @Filename:   reli_tx_top.v
 * @Author:     zhangao
 * @Last edit:
 */

// Language: Verilog 2001s

`resetall
`timescale 1ns / 1ps
`default_nettype none
module reliable_tx_action_core#(
    parameter PKT_METADATA_WIDTH  = 274,
    parameter FLOWSTATE_WIDTH=33,
    parameter ADDR_WIDTH=10,
    parameter OPCODE_WIDTH=4
)(
    input  wire                     clk,
	input  wire                     rst,
    input  wire                     reliable_enable,

    input  wire                     s_mat_hit,
    input  wire [ADDR_WIDTH-1:0]    s_mat_addr,
    input  wire                     s_mat_valid,
    output wire                     s_mat_ready,

    input  wire [ADDR_WIDTH-1:0]        s_mod_addr,
    input  wire [FLOWSTATE_WIDTH:0]     s_mod_data,
    input  wire [OPCODE_WIDTH-1:0]      s_mod_opcode,
    input  wire                         s_mod_valid,
    output wire                         s_mod_ready,

    output wire [FLOWSTATE_WIDTH:0]     m_mod_bdata,
    output wire                         m_mod_bvalid,
    input  wire                         m_mod_bready,

	input  wire [PKT_METADATA_WIDTH-1:0]     s_pkt_metadata_info,
	input  wire                              s_pkt_metadata_valid,
	output wire                              s_pkt_metadata_ready,   

	output wire [PKT_METADATA_WIDTH-1:0]     m_pkt_metadata_info,
	output wire                              m_pkt_metadata_valid,
	input  wire                              m_pkt_metadata_ready
);

wire[FLOWSTATE_WIDTH-1:0]bcd_flowstate_out;
wire[ADDR_WIDTH-1:0]     bcd_addr_out;
wire                     bcd_valid_out;


wire                     m_mat_hit_ram;
wire [FLOWSTATE_WIDTH-1:0]   m_mat_value_ram;
wire [ADDR_WIDTH-1:0]    m_mat_addr_ram;
wire                     m_mat_valid_ram;

wire                              s_mat_ready_ctl;
wire [PKT_METADATA_WIDTH-1:0]     m_pkt_metadata_info_ctl;
wire [1:0]                        m_pkt_metadata_match_sel_ctl;
wire                              m_pkt_metadata_mat_hit_ctl;
wire [FLOWSTATE_WIDTH-1:0]        m_pkt_metadata_mat_value_ctl;
wire [ADDR_WIDTH-1:0]             m_pkt_metadata_mat_addr_ctl;
wire                              m_pkt_metadata_valid_ctl;

wire                              s_pkt_metadata_ready_au;

wire clear_en;
assign clear_en=(s_mod_ready && s_mod_valid && (s_mod_opcode == 4'b1101 ));


flowstate_ram #(
.VALUE_WIDTH(VALUE_WIDTH),
.FLOWSTATE_WIDTH(FLOWSTATE_WIDTH),
.ADDR_WIDTH(ADDR_WIDTH)
)  flowstate_ram_inst
(
.clk(clk),
.rst(rst),

.bcd_flowstate_in(bcd_flowstate_out),
.bcd_addr_in(bcd_addr_out),
.bcd_valid_in(bcd_valid_out),

.s_mod_addr(s_mod_addr),
.s_mod_data(s_mod_data),
.s_mod_opcode(s_mod_opcode),
.s_mod_valid(s_mod_valid),
.s_mod_ready(s_mod_ready),

.m_mod_bdata(m_mod_bdata),
.m_mod_bvalid(m_mod_bvalid),
.m_mod_bready(m_mod_bready),

.s_mat_hit(s_mat_hit),
.s_mat_addr(s_mat_addr),
.s_mat_valid(s_mat_valid),
.s_mat_ready(s_mat_ready),

.m_mat_hit(m_mat_hit_ram),
.m_mat_addr(m_mat_addr_ram),
.m_mat_value(m_mat_value_ram),
.m_mat_valid(m_mat_valid_ram),
.m_mat_ready(s_mat_ready_ctl)
);


flowstate_sendmau_addr_ctl #(
.PKT_METADATA_WIDTH(PKT_METADATA_WIDTH),
.FLOWSTATE_WIDTH(FLOWSTATE_WIDTH),
.ADDR_WIDTH(ADDR_WIDTH)
)   flowstate_addr_ctl_inst (
.clk(clk),
.rst(rst |clear_en),

.s_pkt_metadata_info(s_pkt_metadata_info),
.s_pkt_metadata_valid(s_pkt_metadata_valid),
.s_pkt_metadata_ready(s_pkt_metadata_ready),

.s_mat_hit(m_mat_hit_ram),
.s_mat_addr(m_mat_addr_ram),
.s_mat_value(m_mat_value_ram),
.s_mat_valid(m_mat_valid_ram),
.s_mat_ready(s_mat_ready_ctl),

.m_pkt_metadata_info(m_pkt_metadata_info_ctl),
.m_pkt_metadata_match_sel(m_pkt_metadata_match_sel_ctl),
.m_pkt_metadata_mat_hit(m_pkt_metadata_mat_hit_ctl),
.m_pkt_metadata_mat_value(m_pkt_metadata_mat_value_ctl),
.m_pkt_metadata_mat_addr(m_pkt_metadata_mat_addr_ctl),
.m_pkt_metadata_valid(m_pkt_metadata_valid_ctl),
.m_pkt_metadata_ready(s_pkt_metadata_ready_au)
);


mau_reliable_send_action_unit #(
.PKT_METADATA_WIDTH(PKT_METADATA_WIDTH),
.FLOWSTATE_WIDTH(FLOWSTATE_WIDTH),
.ADDR_WIDTH(ADDR_WIDTH)
)   mau_reliable_send_action_unit_inst (
.clk(clk),
.rst(rst |clear_en),
.reliable_enable(reliable_enable),
.s_pkt_metadata_info(m_pkt_metadata_info_ctl),
.s_pkt_metadata_match_sel(m_pkt_metadata_match_sel_ctl),
.s_pkt_metadata_mat_hit(m_pkt_metadata_mat_hit_ctl),
.s_pkt_metadata_mat_value(m_pkt_metadata_mat_value_ctl),
.s_pkt_metadata_mat_addr(m_pkt_metadata_mat_addr_ctl),
.s_pkt_metadata_valid(m_pkt_metadata_valid_ctl),
.s_pkt_metadata_ready(s_pkt_metadata_ready_au),

.m_pkt_metadata_info(m_pkt_metadata_info),
.m_pkt_metadata_valid(m_pkt_metadata_valid),
.m_pkt_metadata_ready(m_pkt_metadata_ready),

.bcd_flowstate_out(bcd_flowstate_out),
.bcd_addr_out(bcd_addr_out),
.bcd_valid_out(bcd_valid_out)
);


endmodule
`resetall