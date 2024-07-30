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

module rbt_s_eth_parser #
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
reg [15:0]              proto_hdr_length_reg, proto_hdr_length_next;

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

reg [7:0]                   L3_offset_next; 


//pkt_metadata no and width
localparam IP_OFFSET_NO = 236;
localparam IP_OFFSET_WIDTH = 5;
localparam PROTO_NO = 40;
localparam PROTO_WIDTH = 32;
localparam SEATL_OFFSET_NO = 252;
localparam SEATL_OFFSET_WIDTH = 9;

localparam ETH_TAG_INDEX = 0;
localparam VLAN_TAG_INDEX = 1;
localparam IPV6_TAG_INDEX = 4;

//pkt_metadata_init
wire [271:0] pkt_metadata;
reg  [271:0] pkt_metadata_reg;
reg  [271:0] pkt_metadata_next;

assign pkt_metadata = in_proto_hdr_pkt_metadata;
assign out_proto_hdr_pkt_metadata = pkt_metadata_reg;

always @* begin
    pkt_metadata_next = pkt_metadata_reg;
    L3_offset_next = 0;
    proto_hdr_valid_next = proto_hdr_valid_reg;
    proto_hdr_data_next = proto_hdr_data_reg;
    proto_hdr_length_next = proto_hdr_length_reg;

    if(out_proto_hdr_valid & out_proto_hdr_ready) begin
        proto_hdr_valid_next = 1'b0;
    end

    if(in_proto_hdr_valid & in_proto_hdr_ready) begin
        pkt_metadata_next = pkt_metadata;
        proto_hdr_valid_next = 1'b1;
        pkt_metadata_next[PROTO_NO + ETH_TAG_INDEX] = 1'b1;
        //IPV6
        case (in_proto_hdr_data[(HEADER_WIDTH-48-48-1)-:16])
            16'h86dd:begin
                pkt_metadata_next[PROTO_NO + IPV6_TAG_INDEX] = 1'b1;
            end 
            16'h8100:begin//VLAN
                pkt_metadata_next[PROTO_NO + VLAN_TAG_INDEX] = 1'b1;
            end
            default: begin
                pkt_metadata_next[PROTO_NO +: PROTO_WIDTH] = pkt_metadata[PROTO_NO +: PROTO_WIDTH];
            end
        endcase

        L3_offset_next = 8'd14;
        pkt_metadata_next[IP_OFFSET_NO +: IP_OFFSET_WIDTH] = L3_offset_next;
        proto_hdr_data_next[HEADER_WIDTH-1:0] = {in_proto_hdr_data[HEADER_WIDTH-48-48-16-1:0], 112'b0};
        proto_hdr_length_next = in_proto_hdr_length - 8'd14;
        pkt_metadata_next[SEATL_OFFSET_NO +: SEATL_OFFSET_WIDTH] = pkt_metadata[SEATL_OFFSET_NO +: SEATL_OFFSET_WIDTH] + 8'd14;
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