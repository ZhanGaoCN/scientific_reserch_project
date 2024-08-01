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

module key_selector_reli_tx # (
    parameter PKT_METADATA_WIDTH  = 274,
    parameter KEY_WIDTH = 133  
) (
    input  wire                         clk,
    input  wire                         rst,

    //pkt_metadata in
    input  wire [PKT_METADATA_WIDTH-1:0]         s_pkt_metadata_info,
    input  wire                                  s_pkt_metadata_valid,
    output wire                                  s_pkt_metadata_ready,    

    //key out
    output wire [KEY_WIDTH-1:0]         m_key_info,
    output wire                         m_key_valid,
    input  wire                         m_key_ready
);

//pkt_metadata no and width
localparam DST_IP_NO = 104;
localparam DST_IP_WIDTH = 128;
localparam RSIP_INDEX_NO  = 241;
localparam RSIP_INDEX_WIDTH  = 5;
localparam PKT_PROPERTY_NO = 246;

//PROPERTY structure
localparam DAT_INDEX  = 0;
localparam NACK_INDEX  = 1;
localparam LOCAL_TAG_INDEX  = 1;

wire [271:0] pkt_metadata;

reg [KEY_WIDTH-1:0] key_reg;
assign m_key_info = key_reg;

assign pkt_metadata = s_pkt_metadata_info;//todo

assign s_pkt_metadata_ready = m_key_ready;
assign m_key_valid = s_pkt_metadata_valid;

always @* begin
    key_reg = 0;

//logic start

    if(pkt_metadata_next[PKT_PROPERTY_NO + DAT_TAG_INDEX] && pkt_metadata_next[PKT_PROPERTY_NO + LOCAL_TAG_INDEX]) begin //type = DAT && LOCAL
        key_reg = {pkt_metadata_next[RSIP_INDEX_NO +: RSIP_INDEX_WIDTH],pkt_metadata_next[DST_IP_NO +: DST_IP_WIDTH]};   //rsip_index ,dst_ip
    end
    else if(pkt_metadata_next[PKT_PROPERTY_NO + NACK_INDEX] && pkt_metadata_next[PKT_PROPERTY_NO + LOCAL_TAG_INDEX]) begin   //nack
        key_reg = {pkt_metadata_next[RSIP_INDEX_NO +: RSIP_INDEX_WIDTH],pkt_metadata_next[DST_IP_NO +: DST_IP_WIDTH]};   //dst_ip, src_ip
    end

//logic end

end

endmodule
`resetall