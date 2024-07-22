`timescale 1ns / 1ps
`default_nettype none

module rbt_s_idp_fix_parser #
(
    parameter HEADER_WIDTH = 2048,
    parameter PHV_WIDTH = 408,
    parameter PHV_B_LEN = 8,
    parameter PHV_H_LEN = 16,
    parameter PHV_W_LEN = 32,
    parameter PHV_B_NUM = 7,
    parameter PHV_H_NUM = 2,
    parameter PHV_W_NUM = 10,
    parameter PHV_B_OFFSET = 0,
    parameter PHV_H_OFFSET = PHV_B_OFFSET + PHV_B_NUM*PHV_B_LEN,
    parameter PHV_W_OFFSET = PHV_H_OFFSET + PHV_H_NUM*PHV_H_LEN
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * proto header input
     */
    input  wire                     in_proto_hdr_valid,
    output wire                     in_proto_hdr_ready,
    input  wire [HEADER_WIDTH-1:0]  in_proto_hdr_data,         // packet data
    input  wire [15:0]              in_proto_hdr_length,       // total header length
    input  wire [PHV_WIDTH-1:0]     in_proto_hdr_phv,          // field meta data 
    /*
     * parse header output
     */
    output wire                     out_proto_hdr_valid,
    input  wire                     out_proto_hdr_ready,
    output wire [HEADER_WIDTH-1:0]  out_proto_hdr_data,
    output wire [15:0]              out_proto_hdr_length,
    output wire [PHV_WIDTH-1:0]     out_proto_hdr_phv
);


// NO start from 0
// W 32bit 
localparam PROTO_NO = 0;

// H 16bit
// localparam PKTLEN_NO = 0;

// B 8bit
localparam SEATL_OFFSET_NO = 6;
//use B3 B4
// localparam IDP_D_ID_LEN_NO = 3;
// localparam IDP_S_ID_LEN_NO = 4;



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


localparam IDP_TAG_INDEX = 5;

localparam IDPV6_TAG_INDEX = 10;
localparam SCMPID_TAG_INDEX = 11;
localparam SEADP_TAG_INDEX = 12;
localparam SEAUP_TAG_INDEX = 13;
localparam SEASP_TAG_INDEX = 14;
localparam SCMPV6_TAG_INDEX = 15;
localparam SCMPV6_RECMP_TAG_INDEX = 16;


localparam VLAN_TAG_INDEX = 1;
// localparam TRANSPORT_LAYER_TAG_INDEX = 28;
localparam IDP_OPTION_0_TAG_INDEX = 29;
localparam IDP_OPTION_1_TAG_INDEX = 30;
localparam ERROR_TAG_INDEX = 31;
localparam PKT_PROPERTY_NO = 0;
localparam NACK_INDEX = 3;
localparam NACK_REPLY_INDEX = 4;

reg proto_hdr_valid_reg, proto_hdr_valid_next;
reg [HEADER_WIDTH-1:0]  proto_hdr_data_reg, proto_hdr_data_next;
reg [15:0]              proto_hdr_length_reg, proto_hdr_length_next;

reg [15:0] idp_len_depend_by_flag;

assign in_proto_hdr_ready = out_proto_hdr_ready;
assign out_proto_hdr_data = proto_hdr_data_reg;
assign out_proto_hdr_length = proto_hdr_length_reg;
assign out_proto_hdr_valid = proto_hdr_valid_reg;

wire [7:0]  phv_b[0:PHV_B_NUM-1];
wire [15:0] phv_h[0:PHV_H_NUM-1];
wire [31:0] phv_w[0:PHV_W_NUM-1];

reg [7:0]  phv_b_reg[0:PHV_B_NUM-1];
reg [15:0] phv_h_reg[0:PHV_H_NUM-1];
reg [31:0] phv_w_reg[0:PHV_W_NUM-1];

reg [7:0]  phv_b_next[0:PHV_B_NUM-1];
reg [15:0] phv_h_next[0:PHV_H_NUM-1];
reg [31:0] phv_w_next[0:PHV_W_NUM-1];

reg [7:0] idp_flag_reg;
reg [11:0] seatl_offset;
reg [7:0] idp_hdr_len;

generate

    genvar b,h,w;

    for (b = 0; b < PHV_B_NUM; b = b + 1) begin
        assign phv_b[b] = in_proto_hdr_phv[b*8 +: 8];
    end
    for (h = 0; h < PHV_H_NUM; h = h + 1) begin
        assign phv_h[h] = in_proto_hdr_phv[8*PHV_B_NUM+h*16 +: 16];
    end
    for (w = 0; w < PHV_W_NUM; w = w + 1) begin
        assign phv_w[w] = in_proto_hdr_phv[8*PHV_B_NUM+16*PHV_H_NUM+w*32 +: 32];
    end

    for (b = 0; b < PHV_B_NUM; b = b + 1) begin
        assign out_proto_hdr_phv[b*8 +: 8] = phv_b_reg[b];
    end
    for (h = 0; h < PHV_H_NUM; h = h + 1) begin
        assign out_proto_hdr_phv[8*PHV_B_NUM+h*16 +: 16] = phv_h_reg[h];
    end
    for (w = 0; w < PHV_W_NUM; w = w + 1) begin
        assign out_proto_hdr_phv[8*PHV_B_NUM+16*PHV_H_NUM+w*32 +: 32] = phv_w_reg[w];
    end
endgenerate


integer i, j, k;

always @* begin

    for (i = 0; i < PHV_B_NUM; i = i + 1) begin
        phv_b_next[i] = phv_b_reg[i];
    end
    for (j = 0; j < PHV_H_NUM; j = j + 1) begin
        phv_h_next[j] = phv_h_reg[j];
    end
    for (k = 0; k < PHV_W_NUM; k = k + 1) begin
        phv_w_next[k] = phv_w_reg[k];
    end
    
    proto_hdr_valid_next = proto_hdr_valid_reg;
    proto_hdr_data_next = proto_hdr_data_reg;
    proto_hdr_length_next = proto_hdr_length_reg;

    if(out_proto_hdr_valid & out_proto_hdr_ready) begin
        proto_hdr_valid_next = 1'b0;
    end

    if(in_proto_hdr_valid & in_proto_hdr_ready) begin
        for (i = 0; i < PHV_B_NUM; i = i + 1) begin
            phv_b_next[i] = phv_b[i];
        end
        for (j = 0; j < PHV_H_NUM; j = j + 1) begin
            phv_h_next[j] = phv_h[j];
        end
        for (k = 0; k < PHV_W_NUM; k = k + 1) begin
            phv_w_next[k] = phv_w[k];
        end
        idp_flag_reg = 0;
        idp_len_depend_by_flag = 0;
        proto_hdr_valid_next = 1'b1;
        seatl_offset = 0;

        if(phv_w[PROTO_NO][IDP_TAG_INDEX]) begin
            if (in_proto_hdr_data[(HEADER_WIDTH-1)-: 2] == 2'b00) begin
                idp_hdr_len = in_proto_hdr_data[(HEADER_WIDTH-17)-: 8];//modify
                phv_w_next[PROTO_NO][IDPV6_TAG_INDEX] = 1'b1;

                if (in_proto_hdr_data[(HEADER_WIDTH-1-8)-: 8] == 8'h00) begin
                    phv_w_next[PROTO_NO][SCMPID_TAG_INDEX] = 1'b1;
                end else if (in_proto_hdr_data[(HEADER_WIDTH-1-8)-: 8] == 8'h01) begin
                    phv_w_next[PROTO_NO][SEADP_TAG_INDEX] = 1'b1;
                    phv_b_next[SEATL_OFFSET_NO][7:0] = phv_b[SEATL_OFFSET_NO][7:0] + idp_hdr_len;//modify
                end else if (in_proto_hdr_data[(HEADER_WIDTH-1-8)-: 8] == 8'h02) begin
                    phv_w_next[PROTO_NO][SEAUP_TAG_INDEX] = 1'b1;
                    phv_b_next[SEATL_OFFSET_NO][7:0] = phv_b[SEATL_OFFSET_NO][7:0] + idp_hdr_len;//modify
                end else if (in_proto_hdr_data[(HEADER_WIDTH-1-8)-: 8] == 8'h03) begin
                    phv_w_next[PROTO_NO][SEASP_TAG_INDEX] = 1'b1;
                    phv_b_next[SEATL_OFFSET_NO][7:0] = phv_b[SEATL_OFFSET_NO][7:0] + idp_hdr_len;//modify
                end
            end else if (in_proto_hdr_data[(HEADER_WIDTH-1)-: 2] == 2'b01) begin //pkt is scmpv6 ;judge if pkt is NACK
                
                phv_w_next[PROTO_NO][SCMPV6_TAG_INDEX] = 1'b1;

                if (in_proto_hdr_data[(HEADER_WIDTH-3)-: 6] == 6'b1) begin
                    phv_w_next[PROTO_NO][SCMPV6_RECMP_TAG_INDEX] = 1'b1; 
                    if(in_proto_hdr_data[(HEADER_WIDTH-9)-: 8] == 8'h01)begin
                        phv_b_next[PKT_PROPERTY_NO][NACK_INDEX] = 1'b1;
                    end else if (in_proto_hdr_data[(HEADER_WIDTH-9)-: 8] == 8'h02)begin
                        phv_b_next[PKT_PROPERTY_NO][NACK_REPLY_INDEX] = 1'b1;
                    end else begin
                        phv_b_next[PKT_PROPERTY_NO][NACK_INDEX] = phv_b[PKT_PROPERTY_NO][NACK_INDEX];
                        phv_b_next[PKT_PROPERTY_NO][NACK_REPLY_INDEX] = phv_b[PKT_PROPERTY_NO][NACK_REPLY_INDEX];
                    end
                end else begin
                    phv_w_next[PROTO_NO][SCMPV6_RECMP_TAG_INDEX] = phv_w[PROTO_NO][SCMPV6_RECMP_TAG_INDEX]; 
                end
            end else begin
                phv_w_next[PROTO_NO][IDPV6_TAG_INDEX] = phv_w[PROTO_NO][IDPV6_TAG_INDEX];
                phv_w_next[PROTO_NO][SCMPV6_TAG_INDEX] = phv_w[PROTO_NO][SCMPV6_TAG_INDEX];
            end

            if(phv_w[PROTO_NO][VLAN_TAG_INDEX]) begin
                seatl_offset = 8*(phv_b_next[SEATL_OFFSET_NO]-58);
                proto_hdr_data_next[HEADER_WIDTH-1:0] = in_proto_hdr_data[HEADER_WIDTH-1:0] << seatl_offset;//TODO
                proto_hdr_length_next = in_proto_hdr_length - (phv_b_reg[SEATL_OFFSET_NO]-58);//TODO
            end else begin
                seatl_offset =8*(phv_b_next[SEATL_OFFSET_NO]-54);
                // proto_hdr_data_next[HEADER_WIDTH-1:0] = in_proto_hdr_data[HEADER_WIDTH-1:0] << (8*phv_b_reg[5]-528);//TODO
                proto_hdr_data_next[HEADER_WIDTH-1:0] = in_proto_hdr_data[HEADER_WIDTH-1:0] << seatl_offset;//TODO

                proto_hdr_length_next = in_proto_hdr_length - (phv_b_reg[SEATL_OFFSET_NO]-54);//TODO
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

    for (i = 0; i < PHV_B_NUM; i = i + 1) begin
        phv_b_reg[i] <= phv_b_next[i];
    end
    for (j = 0; j < PHV_H_NUM; j = j + 1) begin
        phv_h_reg[j] <= phv_h_next[j];
    end
    for (k = 0; k < PHV_W_NUM; k = k + 1) begin
        phv_w_reg[k] <= phv_w_next[k];
    end

    if (rst) begin
        proto_hdr_valid_reg <= 0;
        proto_hdr_data_reg <= 0;
        proto_hdr_length_reg <= 0;

        for (i = 0; i < PHV_B_NUM; i = i + 1) begin
            phv_b_reg[i] <= 0;
        end
        for (j = 0; j < PHV_H_NUM; j = j + 1) begin
            phv_h_reg[j] <= 0;
        end
        for (k = 0; k < PHV_W_NUM; k = k + 1) begin
            phv_w_reg[k] <= 0;
        end
    end
end

endmodule

`resetall


