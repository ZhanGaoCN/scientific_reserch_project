/*
 * Created on 20240722
 *
 * Copyright (c) 2024 IOA UCAS
 *
 * @Filename:   reli_tx_top.v
 * @Author:     zhangao
 * @Last edit:
 */

// Language: Verilog 2001
`resetall
`timescale 1ns / 1ps
`default_nettype none

module rbt_s_pre_parser #
(

    //width of meta (decice id)
    parameter META_WIDTH = 32,
    // transfer metadata to MAT
    parameter HEADER_WIDTH = 2048,
    parameter USER_WIDTH = 36,
    parameter PKT_METADATA_WIDTH  = 272
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * proto header input
     */
    input  wire                             in_proto_hdr_valid,
    output wire                             in_proto_hdr_ready,
    input  wire [15:0]                      in_proto_hdr_length,
    input  wire [15:0]                      in_proto_hdr_pktlen,//todo
    input  wire [HEADER_WIDTH-1:0]          in_proto_hdr_data,
    input  wire [USER_WIDTH-1:0]            in_proto_hdr_tuser,
    input  wire [META_WIDTH-1:0]            in_proto_hdr_meta,

 

    /*
     * parse header output
     */
    output wire                              out_proto_hdr_valid,
    input  wire                              out_proto_hdr_ready,
    output wire [HEADER_WIDTH-1:0]           out_proto_hdr_data,
    output wire [PKT_METADATA_WIDTH-1:0]     out_proto_hdr_pkt_metadata,
    output wire [15:0]                       out_proto_hdr_length
);


reg proto_hdr_valid_reg, proto_hdr_valid_next;
reg [HEADER_WIDTH-1:0]   proto_hdr_data_reg, proto_hdr_data_next;
reg [15:0]               proto_hdr_length_reg, proto_hdr_length_next;

assign in_proto_hdr_ready   = out_proto_hdr_ready;
assign out_proto_hdr_valid  = proto_hdr_valid_reg;
assign out_proto_hdr_data   = proto_hdr_data_reg;
assign out_proto_hdr_length = proto_hdr_length_reg;

// bus width assertions
initial begin
    if (HEADER_WIDTH % 8 != 0) begin
        $error("Error: HEADER_WIDTH requires byte (8-bit) granularity (instance %m)");
        $finish;
    end
end

//pkt_metadata no and width
localparam INPORT_NO = 0;

localparam OUTPORT_NO = 8;

localparam TID_NO = 16;

localparam PKTLEN_NO = 24;
localparam PKTLEN_WIDTH = 16;
localparam PKT_PROPERTY_NO = 246;
localparam PKT_PROPERTY_WIDTH = 6;
localparam SEATL_OFFFSET_NO = 252;
localparam SEATL_OFFFSET_WIDTH = 9;
localparam RSIP_INDEX_NO = 241;

//tuser input offset
localparam INPORT_OFFSET = 0;
localparam INPORT_WIDTH = 8;
localparam OUTPORT_OFFSET = INPORT_OFFSET + INPORT_WIDTH;
localparam OUTPORT_WIDTH = 8;
localparam TID_OFFSET = OUTPORT_OFFSET + OUTPORT_WIDTH;
localparam TID_WIDTH = 8;
localparam PKT_PROPERTY_OFFSET = TID_OFFSET + TID_WIDTH;
localparam PKT_PROPERTY_WIDTH_TUSER = 6;
localparam RSIP_INDEX_OFFSET = PKT_PROPERTY_OFFSET + PKT_PROPERTY_WIDTH;
localparam RSIP_INDEX_WIDTH = 5;


//pkt_metadata_init
reg [271:0] pkt_metadata_reg;
reg [271:0] pkt_metadata_next;

assign out_proto_hdr_pkt_metadata = pkt_metadata_reg;

reg [63:0] timestamp_reg, timestamp_next;

integer i;
always @* begin
    pkt_metadata_next = pkt_metadata_reg;
    timestamp_next = timestamp_reg + 1;
    proto_hdr_valid_next = proto_hdr_valid_reg;
    proto_hdr_data_next = proto_hdr_data_reg;
    proto_hdr_length_next = proto_hdr_length_reg;
    if(out_proto_hdr_valid & out_proto_hdr_ready) begin
        proto_hdr_valid_next = 1'b0;
    end
    if(in_proto_hdr_valid & in_proto_hdr_ready) begin

        proto_hdr_valid_next = 1'b1;
        proto_hdr_data_next   = in_proto_hdr_data;
        proto_hdr_length_next = in_proto_hdr_length;
        
        pkt_metadata_next[INPORT_NO +: INPORT_WIDTH] = in_proto_hdr_tuser[INPORT_OFFSET +: INPORT_WIDTH];
        pkt_metadata_next[OUTPORT_NO +: OUTPORT_WIDTH] = in_proto_hdr_tuser[OUTPORT_OFFSET +: OUTPORT_WIDTH];
        pkt_metadata_next[TID_NO +: TID_WIDTH] = in_proto_hdr_tuser[TID_OFFSET +: TID_WIDTH];    
        pkt_metadata_next[PKTLEN_NO +: PKTLEN_WIDTH] = in_proto_hdr_pktlen;
        pkt_metadata_next[PKT_PROPERTY_NO +: PKT_PROPERTY_WIDTH_TUSER] = in_proto_hdr_tuser[PKT_PROPERTY_OFFSET +: PKT_PROPERTY_WIDTH_TUSER];
        pkt_metadata_next[RSIP_INDEX_NO +: RSIP_INDEX_WIDTH] = in_proto_hdr_tuser[RSIP_INDEX_OFFSET +: RSIP_INDEX_WIDTH];
    end
end

always @(posedge clk) begin

    pkt_metadata_reg = pkt_metadata_next;
    proto_hdr_valid_reg  <= proto_hdr_valid_next;
    proto_hdr_data_reg   <= proto_hdr_data_next;
    proto_hdr_length_reg <= proto_hdr_length_next;

    timestamp_reg <= timestamp_next;
    
    if(rst) begin
        proto_hdr_valid_reg <= 0;
        proto_hdr_data_reg <= 0;
        proto_hdr_length_reg <= 0;

        timestamp_reg <= 0;
        pkt_metadata_reg <=0;
    end
end



endmodule

`resetall