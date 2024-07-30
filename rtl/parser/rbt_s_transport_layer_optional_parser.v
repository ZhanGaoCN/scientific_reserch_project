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

module rbt_s_transport_layer_optional_parser #
(
    parameter HEADER_WIDTH = 2048,
    parameter PKT_METADATA_WIDTH  = 272
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * proto header input
     */
    input  wire                               in_proto_hdr_valid,
    output wire                               in_proto_hdr_ready,
    input  wire [15:0]                        in_proto_hdr_length,
    input  wire [HEADER_WIDTH-1:0]            in_proto_hdr_data,
    input  wire [PKT_METADATA_WIDTH-1:0]      in_proto_hdr_pkt_metadata,

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
reg [HEADER_WIDTH-1:0]  proto_hdr_data_reg, proto_hdr_data_next;
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
localparam PROTO_NO = 40;
localparam PROTO_WIDTH = 32;
localparam PKT_PROPERTY_NO = 246;
localparam PKT_PROPERTY_WIDTH = 9;


localparam SEADP_TAG_INDEX = 12;
localparam SEAUP_TAG_INDEX = 13;
localparam SEASP_TAG_INDEX = 14;

localparam DAT_TAG_INDEX = 0;
localparam XTRANS_FIELD_TAG_INDEX = 6;
localparam RFLAG_TAG_INDEX = 7;

//pkt_metadata_init
wire [271:0] pkt_metadata;
reg  [271:0] pkt_metadata_reg;
reg  [271:0] pkt_metadata_next;

assign pkt_metadata = in_proto_hdr_pkt_metadata;
assign out_proto_hdr_pkt_metadata = pkt_metadata_reg;


always @* begin

    pkt_metadata_next = pkt_metadata_reg;
    proto_hdr_valid_next = proto_hdr_valid_reg;
    proto_hdr_data_next = proto_hdr_data_reg;
    proto_hdr_length_next = proto_hdr_length_reg;

    if(out_proto_hdr_valid & out_proto_hdr_ready) begin
        proto_hdr_valid_next = 1'b0;
    end

    if(in_proto_hdr_valid & in_proto_hdr_ready) begin
        proto_hdr_data_next = in_proto_hdr_data; //add code here which solve bug
        pkt_metadata_next = pkt_metadata;
        proto_hdr_valid_next = 1'b1;

        if(((pkt_metadata_next[PROTO_NO + SEADP_TAG_INDEX] == 1'b1) || (pkt_metadata_next[PROTO_NO + SEAUP_TAG_INDEX] == 1'b1) || (pkt_metadata_next[PROTO_NO + SEASP_TAG_INDEX] == 1'b1)) && (in_proto_hdr_data[(HEADER_WIDTH-25)-: 1] == 1'b01))begin
            pkt_metadata_next[PKT_PROPERTY_NO + XTRANS_FIELD_TAG_INDEX] = 1'b1;
            pkt_metadata_next[PKT_PROPERTY_NO + DAT_TAG_INDEX] = 1'b1;
            if(in_proto_hdr_data[(HEADER_WIDTH-33)-: 8] == 8'h80)begin
                pkt_metadata_next[PKT_PROPERTY_NO + RFLAG_TAG_INDEX] = 1'b1;
            end else begin
                pkt_metadata_next[PKT_PROPERTY_NO + RFLAG_TAG_INDEX] = pkt_metadata[PKT_PROPERTY_NO + RFLAG_TAG_INDEX];
            end
        end else begin
            pkt_metadata_next[PKT_PROPERTY_NO + XTRANS_FIELD_TAG_INDEX] = pkt_metadata[PKT_PROPERTY_NO + XTRANS_FIELD_TAG_INDEX];
            pkt_metadata_next[PKT_PROPERTY_NO + DAT_TAG_INDEX] = pkt_metadata[PKT_PROPERTY_NO + DAT_TAG_INDEX];
        end
    end else begin
        proto_hdr_data_next = in_proto_hdr_data;
        proto_hdr_length_next = in_proto_hdr_length;
    end
end



always @(posedge clk) begin

    proto_hdr_valid_reg <= proto_hdr_valid_next;
    proto_hdr_data_reg <= proto_hdr_data_next;
    proto_hdr_length_reg <= proto_hdr_length_next;
    pkt_metadata_reg <= pkt_metadata_next;




    if(rst) begin
        proto_hdr_valid_reg <= 0;
        proto_hdr_data_reg <= 0;
        proto_hdr_length_reg <= 0;
        pkt_metadata_reg <= 0;

    end

end



endmodule

`resetall