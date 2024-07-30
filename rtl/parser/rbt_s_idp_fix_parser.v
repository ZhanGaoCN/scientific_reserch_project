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


`timescale 1ns / 1ps
`default_nettype none

module rbt_s_idp_fix_parser #
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
    input  wire                              in_proto_hdr_valid,
    output wire                              in_proto_hdr_ready,
    input  wire [HEADER_WIDTH-1:0]           in_proto_hdr_data,         // packet data
    input  wire [15:0]                       in_proto_hdr_length,       // total header length
    input  wire [PKT_METADATA_WIDTH-1:0]     in_proto_hdr_pkt_metadata,          // field meta data 
    /*
     * parse header output
     */
    output wire                              out_proto_hdr_valid,
    input  wire                              out_proto_hdr_ready,
    output wire [HEADER_WIDTH-1:0]           out_proto_hdr_data,
    output wire [15:0]                       out_proto_hdr_length,
    output wire [PKT_METADATA_WIDTH-1:0]     out_proto_hdr_pkt_metadata
);


// DATA offset and width in HDR
localparam IDP_NEXT_HDR_OFFSET = 0;
localparam IDP_NEXT_HDR_WIDTH = 8;
localparam IDP_HDR_LEN_OFFSET = IDP_NEXT_HDR_OFFSET + IDP_NEXT_HDR_WIDTH;
localparam IDP_HDR_LEN_WIDTH = 8;
localparam IDP_D_SEAID_TYPE_OFFSET = IDP_HDR_LEN_OFFSET + IDP_HDR_LEN_WIDTH;
localparam IDP_D_SEAID_TYPE_WIDTH = 4;
localparam IDP_S_SEAID_TYPE_OFFSET = IDP_D_SEAID_TYPE_OFFSET + IDP_D_SEAID_TYPE_WIDTH;
localparam IDP_S_SEAID_TYPE_WIDTH = 4;
localparam IDP_D_SEAID_LEN_OFFSET = IDP_S_SEAID_TYPE_OFFSET + IDP_S_SEAID_TYPE_WIDTH;
localparam IDP_D_SEAID_LEN_WIDTH = 4; 
localparam IDP_S_SEAID_LEN_OFFSET = IDP_D_SEAID_LEN_OFFSET + IDP_D_SEAID_LEN_WIDTH;
localparam IDP_S_SEAID_LEN_WIDTH = 4; 
localparam IDP_PREFERENCE_OFFSET = IDP_S_SEAID_LEN_OFFSET + IDP_S_SEAID_LEN_WIDTH;
localparam IDP_PREFERENCE_WIDTH = 56;
localparam IDP_FLAG_OFFSET = IDP_PREFERENCE_OFFSET + IDP_PREFERENCE_WIDTH;
localparam IDP_FLAG_WIDTH = 8; // 4 reserved and 4 used


localparam IDP_SEAID_OFFSET = IDP_FLAG_OFFSET + IDP_FLAG_WIDTH;
localparam IDP_D_SEAID_MAX_WIDTH = 256;
localparam IDP_S_SEAID_MAX_WIDTH = 256;


localparam IDP_EXTENDED_ADDR_WIDTH = 128;
localparam IDP_OPTION_A_WIDTH = 128;
localparam IDP_OPTION_B_WIDTH = 128;
localparam IDP_OPTION_C_WIDTH = 128;
localparam IDP_OPTION_D_WIDTH = 128;


localparam IDP_PREFERENCE_SERVICE_OFFSET = IDP_PREFERENCE_OFFSET;
localparam IDP_PREFERENCE_SERVICE_WIDTH = 6;
localparam IDP_PREFERENCE_ROUTE_OFFSET = IDP_PREFERENCE_SERVICE_OFFSET + IDP_PREFERENCE_SERVICE_WIDTH;
localparam IDP_PREFERENCE_ROUTE_WIDTH = 2;
localparam IDP_PREFERENCE_QP_OFFSET = IDP_PREFERENCE_ROUTE_OFFSET + IDP_PREFERENCE_ROUTE_WIDTH;
localparam IDP_PREFERENCE_QP_WIDTH  = 8;
localparam IDP_PREFERENCE_IRA_FLAG_OFFSET = IDP_PREFERENCE_QP_OFFSET + IDP_PREFERENCE_QP_WIDTH ;
localparam IDP_PREFERENCE_IRA_FLAG_WIDTH = 8;
localparam IDP_PREFERENCE_IRA_PARA_0_OFFSET = IDP_PREFERENCE_IRA_FLAG_OFFSET + IDP_PREFERENCE_IRA_FLAG_WIDTH;
localparam IDP_PREFERENCE_IRA_PARA_0_WIDTH = 4;
localparam IDP_PREFERENCE_IRA_PARA_1_OFFSET = IDP_PREFERENCE_IRA_PARA_0_OFFSET + IDP_PREFERENCE_IRA_PARA_0_WIDTH;
localparam IDP_PREFERENCE_IRA_PARA_1_WIDTH = 4;
localparam IDP_PREFERENCE_IRA_PARA_2_OFFSET = IDP_PREFERENCE_IRA_PARA_1_OFFSET + IDP_PREFERENCE_IRA_PARA_1_WIDTH;
localparam IDP_PREFERENCE_IRA_PARA_2_WIDTH = 4;
localparam IDP_PREFERENCE_IRA_PARA_3_OFFSET = IDP_PREFERENCE_IRA_PARA_2_OFFSET + IDP_PREFERENCE_IRA_PARA_2_WIDTH;
localparam IDP_PREFERENCE_IRA_PARA_3_WIDTH = 4;
localparam IDP_PREFERENCE_IRA_PARA_4_OFFSET = IDP_PREFERENCE_IRA_PARA_3_OFFSET + IDP_PREFERENCE_IRA_PARA_3_WIDTH;
localparam IDP_PREFERENCE_IRA_PARA_4_WIDTH = 4;
localparam IDP_PREFERENCE_IRA_PARA_5_OFFSET = IDP_PREFERENCE_IRA_PARA_4_OFFSET + IDP_PREFERENCE_IRA_PARA_4_WIDTH;
localparam IDP_PREFERENCE_IRA_PARA_5_WIDTH = 4;
localparam IDP_PREFERENCE_IRA_PARA_6_OFFSET = IDP_PREFERENCE_IRA_PARA_5_OFFSET + IDP_PREFERENCE_IRA_PARA_5_WIDTH;
localparam IDP_PREFERENCE_IRA_PARA_6_WIDTH = 4;
localparam IDP_PREFERENCE_IRA_PARA_7_OFFSET = IDP_PREFERENCE_IRA_PARA_6_OFFSET + IDP_PREFERENCE_IRA_PARA_6_WIDTH;
localparam IDP_PREFERENCE_IRA_PARA_7_WIDTH = 4;



reg proto_hdr_valid_reg, proto_hdr_valid_next;
reg [HEADER_WIDTH-1:0]  proto_hdr_data_reg, proto_hdr_data_next;
reg [15:0]              proto_hdr_length_reg, proto_hdr_length_next;

reg [15:0] idp_len_depend_by_flag;
reg [7:0] idp_flag_reg;
reg [11:0] seatl_offset;
reg [7:0] idp_hdr_len;

assign in_proto_hdr_ready = out_proto_hdr_ready;
assign out_proto_hdr_data = proto_hdr_data_reg;
assign out_proto_hdr_length = proto_hdr_length_reg;
assign out_proto_hdr_valid = proto_hdr_valid_reg;

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
localparam SEATL_OFFSET_NO = 252;
localparam SEATL_OFFSET_WIDTH = 9;

localparam IDP_TAG_INDEX = 5;
localparam IDPV6_TAG_INDEX = 10;
localparam SCMPID_TAG_INDEX = 11;
localparam SEADP_TAG_INDEX = 12;
localparam SEAUP_TAG_INDEX = 13;
localparam SEASP_TAG_INDEX = 14;
localparam SCMPV6_TAG_INDEX = 15;
localparam SCMPV6_RECMP_TAG_INDEX = 16;
localparam VLAN_TAG_INDEX = 1;
localparam ERROR_TAG_INDEX = 31;

localparam NACK_INDEX = 3;
localparam NACK_REPLY_INDEX = 4;

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
        pkt_metadata_next = pkt_metadata;
        proto_hdr_valid_next = 1'b1;
        idp_flag_reg = 0;
        idp_len_depend_by_flag = 0;
        seatl_offset = 0;

        if(pkt_metadata_next[PROTO_NO + IDP_TAG_INDEX]) begin
            if (in_proto_hdr_data[(HEADER_WIDTH-1)-: 2] == 2'b00) begin
                idp_hdr_len = in_proto_hdr_data[(HEADER_WIDTH-17)-: 8];//modify
                pkt_metadata_next[PROTO_NO + IDPV6_TAG_INDEX] = 1;

                if (in_proto_hdr_data[(HEADER_WIDTH-1-8)-: 8] == 8'h00) begin
                    pkt_metadata_next[PROTO_NO + SCMPID_TAG_INDEX] = 1;
                end else if (in_proto_hdr_data[(HEADER_WIDTH-1-8)-: 8] == 8'h01) begin
                    pkt_metadata_next[PROTO_NO + SEADP_TAG_INDEX] = 1;
                    pkt_metadata_next[SEATL_OFFSET_NO +: SEATL_OFFSET_WIDTH] = pkt_metadata[SEATL_OFFSET_NO +: SEATL_OFFSET_WIDTH] + idp_hdr_len;
                end else if (in_proto_hdr_data[(HEADER_WIDTH-1-8)-: 8] == 8'h02) begin
                    pkt_metadata_next[PROTO_NO + SEAUP_TAG_INDEX] = 1;
                    pkt_metadata_next[SEATL_OFFSET_NO +: SEATL_OFFSET_WIDTH] = pkt_metadata[SEATL_OFFSET_NO +: SEATL_OFFSET_WIDTH] + idp_hdr_len;
                end else if (in_proto_hdr_data[(HEADER_WIDTH-1-8)-: 8] == 8'h03) begin
                    pkt_metadata_next[PROTO_NO + SEASP_TAG_INDEX] = 1;
                    pkt_metadata_next[SEATL_OFFSET_NO +: SEATL_OFFSET_WIDTH] = pkt_metadata[SEATL_OFFSET_NO +: SEATL_OFFSET_WIDTH] + idp_hdr_len;
                end
            end else if (in_proto_hdr_data[(HEADER_WIDTH-1)-: 2] == 2'b01) begin //pkt is scmpv6 ;judge if pkt is NACK
                pkt_metadata_next[PROTO_NO + SCMPV6_TAG_INDEX] = 1;

                if (in_proto_hdr_data[(HEADER_WIDTH-3)-: 6] == 6'b1) begin
                    pkt_metadata_next[PROTO_NO + SCMPV6_RECMP_TAG_INDEX] = 1; 
                    if(in_proto_hdr_data[(HEADER_WIDTH-9)-: 8] == 8'h01)begin
                        pkt_metadata_next[PROTO_NO + NACK_INDEX] = 1;
                    end else if (in_proto_hdr_data[(HEADER_WIDTH-9)-: 8] == 8'h02)begin
                        pkt_metadata_next[PROTO_NO + NACK_REPLY_INDEX] = 1;
                    end else begin
                        pkt_metadata_next[PROTO_NO + NACK_INDEX] = pkt_metadata[PROTO_NO + NACK_INDEX];
                        pkt_metadata_next[PROTO_NO + NACK_REPLY_INDEX] = pkt_metadata[PROTO_NO + NACK_REPLY_INDEX];
                    end
                end else begin
                    pkt_metadata_next[PROTO_NO + SCMPV6_RECMP_TAG_INDEX] = pkt_metadata[PROTO_NO + SCMPV6_RECMP_TAG_INDEX]; 
                end
            end else begin
                pkt_metadata_next[PROTO_NO + IDPV6_TAG_INDEX] = pkt_metadata[PROTO_NO + IDPV6_TAG_INDEX];
                pkt_metadata_next[PROTO_NO + SCMPV6_TAG_INDEX] = pkt_metadata[PROTO_NO + SCMPV6_TAG_INDEX];
            end

            if(pkt_metadata_next[PROTO_NO + VLAN_TAG_INDEX]) begin
                seatl_offset = 8*(pkt_metadata_next[SEATL_OFFSET_NO +: SEATL_OFFSET_WIDTH]-58);
                proto_hdr_data_next[HEADER_WIDTH-1:0] = in_proto_hdr_data[HEADER_WIDTH-1:0] << seatl_offset;//TODO
                proto_hdr_length_next = in_proto_hdr_length - (pkt_metadata_reg[SEATL_OFFSET_NO +: SEATL_OFFSET_WIDTH]-58);//TODO
            end else begin
                seatl_offset =8*(pkt_metadata_next[SEATL_OFFSET_NO +: SEATL_OFFSET_WIDTH]-54);
                // proto_hdr_data_next[HEADER_WIDTH-1:0] = in_proto_hdr_data[HEADER_WIDTH-1:0] << (8*phv_b_reg[5]-528);//TODO
                proto_hdr_data_next[HEADER_WIDTH-1:0] = in_proto_hdr_data[HEADER_WIDTH-1:0] << seatl_offset;//TODO ?? why some is reg,some is next

                proto_hdr_length_next = in_proto_hdr_length - (pkt_metadata_reg[SEATL_OFFSET_NO +: SEATL_OFFSET_WIDTH]-54);//TODO
            end

        end else begin
            proto_hdr_data_next = 0;
            proto_hdr_length_next = 0;
        end

    end

    if(rst) begin
        seatl_offset = 0;
    end

end

always @(posedge clk) begin

    proto_hdr_valid_reg <= proto_hdr_valid_next;
    proto_hdr_data_reg <= proto_hdr_data_next;
    proto_hdr_length_reg <= proto_hdr_length_next;
    pkt_metadata_reg <= pkt_metadata_next;

    if (rst) begin
        proto_hdr_valid_reg <= 0;
        proto_hdr_data_reg <= 0;
        proto_hdr_length_reg <= 0;
        pkt_metadata_reg <= 0;
    end
end

endmodule

`resetall


