

`resetall
`timescale 1ns / 1ps
`default_nettype none

module key_selector_rbttx # (
    parameter PHV_B_COUNT = 7,
    parameter PHV_H_COUNT = 2,
    parameter PHV_W_COUNT = 10,
    parameter PHV_WIDTH = 408,

    parameter KEY_WIDTH = 256  
) (
    input  wire                         clk,
    input  wire                         rst,

    //phv in
    input  wire [PHV_WIDTH-1:0]         s_phv_info,
    input  wire                         s_phv_valid,
    output wire                         s_phv_ready,    

    //key out
    output wire [KEY_WIDTH-1:0]         m_key_info,
    output wire                         m_key_valid,
    input  wire                         m_key_ready
);

//PHV structure
//B
localparam PKT_PROPERTY_NO  = 0;
localparam PKT_VALID_NO  = 1;
localparam INPORT_NO  = 2;
localparam OUTPORT_NO  = 3;

localparam IP_OFFSET_NO  = 4;
localparam TID_NO  = 5;
localparam SEATL_OFFSET_NO  = 6;
//W
localparam RSIP_OFFSET_NO  = 5;
localparam DST_IP_NO = 1;

//PROPERTY structure
localparam DAT_INDEX  = 2;
localparam NACK_INDEX  = 3;

wire [7:0]  phv_b[0:PHV_B_COUNT-1];
wire [15:0] phv_h[0:PHV_H_COUNT-1];
wire [31:0] phv_w[0:PHV_W_COUNT-1];

reg [KEY_WIDTH-1:0] key_reg;
assign m_key_info = key_reg;

generate

    genvar i,j,k;

    for (i = 0; i < PHV_B_COUNT; i = i + 1) begin
        assign phv_b[i] = s_phv_info[i*8 +: 8];
    end
    for (j = 0; j < PHV_H_COUNT; j = j + 1) begin
        assign phv_h[j] = s_phv_info[8*PHV_B_COUNT+j*16 +: 16];
    end
    for (k = 0; k < PHV_W_COUNT; k = k + 1) begin
        assign phv_w[k] = s_phv_info[8*PHV_B_COUNT+16*PHV_H_COUNT+k*32 +: 32];
    end

endgenerate

assign s_phv_ready = m_key_ready;
assign m_key_valid = s_phv_valid;

always @* begin
    key_reg = 0;


//logic start

    if(phv_b[PKT_PROPERTY_NO][DAT_INDEX]) begin //type = DAT && LOCAL
        key_reg = {phv_w[RSIP_OFFSET_NO+3],phv_w[RSIP_OFFSET_NO+2],phv_w[RSIP_OFFSET_NO+1],phv_w[RSIP_OFFSET_NO],phv_w[DST_IP_NO+3],phv_w[DST_IP_NO+2],phv_w[DST_IP_NO+1],phv_w[DST_IP_NO]};   //rsip ,dst_ip
    end
    else if(phv_b[PKT_PROPERTY_NO][NACK_INDEX]) begin   //nack
        key_reg = {phv_w[DST_IP_NO+3],phv_w[DST_IP_NO+2],phv_w[DST_IP_NO+1],phv_w[DST_IP_NO], phv_w[RSIP_OFFSET_NO+3],phv_w[RSIP_OFFSET_NO+2],phv_w[RSIP_OFFSET_NO+1],phv_w[RSIP_OFFSET_NO]};   //dst_ip, src_ip
    end

//logic end

end

endmodule
`resetall