/*
 * @Author: lur
 */
`resetall
`timescale 1ns / 1ps
`default_nettype none
module flowstate_sendmau_addr_ctl#(
	parameter VALUE_WIDTH = 32,
	parameter PHV_WIDTH = 592,
    parameter PHV_B_COUNT = 10,
    parameter PHV_H_COUNT = 2,
    parameter PHV_W_COUNT = 15,
    parameter FLOWSTATE_WIDTH=32,
    parameter ADDR_WIDTH=10
)(
    input  wire                     clk,
	input  wire                     rst,

	input  wire [PHV_WIDTH-1:0]     s_phv_info,
	input  wire                     s_phv_valid,
	output wire                     s_phv_ready,     

    input  wire                     s_mat_hit,
    input  wire [FLOWSTATE_WIDTH-1:0]s_mat_value,
    input  wire [ADDR_WIDTH-1:0]    s_mat_addr,
    input  wire                     s_mat_valid,
    output wire                     s_mat_ready,

	output wire [PHV_WIDTH-1:0]     m_phv_info,
    output wire [1:0]               m_phv_match_sel,//input flowstate_addr match recrnt addr  
    output  wire                    m_phv_mat_hit,
    output  wire [FLOWSTATE_WIDTH-1:0]m_phv_mat_value,
    output  wire [ADDR_WIDTH-1:0]   m_phv_mat_addr,
	output wire                     m_phv_valid,
	input  wire                     m_phv_ready

    //recv broadcast new flowstate & addr
    //input  wire[FLOWSTATE_WIDTH:0]  bcd_flowstate_in,
    //input  wire[ADDR_WIDTH-1:0]     bcd_addr_in,
    //input  wire                     bcd_valid_in
);

localparam SEADP=3'b01;
localparam SEAUP=3'b10;
localparam SEASP=3'b11;
localparam NACK=8'h02;
localparam INITNPN_INDEX=1;
localparam PKTPROT_INDEX=0;
localparam DAT_INDEX=2;
//high 1 bit indicate valid or not
reg [ADDR_WIDTH:0] latest_addr_0;
reg [ADDR_WIDTH:0] latest_addr_1;
reg [ADDR_WIDTH:0] latest_addr_2;

reg [1:0] match_sel_reg;
reg mat_hit_reg,m_phv_valid_reg;
reg [FLOWSTATE_WIDTH-1:0]mat_value_reg;
reg [ADDR_WIDTH-1:0]   mat_addr_reg;

generate

    genvar b,h,w;

    for (b = 0; b < PHV_B_COUNT; b = b + 1) begin
        assign phv_b[b] = s_phv_info[b*8 +: 8];
    end
    for (h = 0; h < PHV_H_COUNT; h = h + 1) begin
        assign phv_h[h] = s_phv_info[8*PHV_B_COUNT+h*16 +: 16];
    end
    for (w = 0; w < PHV_W_COUNT; w = w + 1) begin
        assign phv_w[w] = s_phv_info[8*PHV_B_COUNT+16*PHV_H_COUNT+w*32 +: 32];
    end

    for (b = 0; b < PHV_B_COUNT; b = b + 1) begin
        assign m_phv_info[b*8 +: 8] = phv_b_reg[b];
    end
    for (h = 0; h < PHV_H_COUNT; h = h + 1) begin
        assign m_phv_info[8*PHV_B_COUNT+h*16 +: 16] = phv_h_reg[h];
    end
    for (w = 0; w < PHV_W_COUNT; w = w + 1) begin
        assign m_phv_info[8*PHV_B_COUNT+16*PHV_H_COUNT+w*32 +: 32] = phv_w_reg[w];
    end
endgenerate


always @(posedge clk) begin
    if(rst) begin
        latest_addr_0<=0;
        latest_addr_1<=0;
        latest_addr_2<=0;
    end
    else begin
        if (s_phv_valid && s_phv_ready && s_mat_valid && s_mat_ready ) begin
            if (s_mat_hit && phv_b[PKTPROT_INDEX][DAT_INDEX]==1) begin
            //if (s_mat_hit) begin
            latest_addr_0<={1'b1,s_mat_addr};
            latest_addr_1<=latest_addr_0;
            latest_addr_2<=latest_addr_1;
            end
            else begin
            latest_addr_0<={1'b0,s_mat_addr};
            latest_addr_1<=latest_addr_0;
            latest_addr_2<=latest_addr_1;
            end
        end
    end
end

assign m_phv_valid = m_phv_valid_reg;
assign s_phv_ready = (~m_phv_valid || m_phv_ready) && s_phv_valid && s_mat_valid;
assign s_mat_ready = (~m_phv_valid || m_phv_ready) && s_phv_valid && s_mat_valid;

wire [7:0]  phv_b[0:PHV_B_COUNT-1];
wire [15:0] phv_h[0:PHV_H_COUNT-1];
wire [31:0] phv_w[0:PHV_W_COUNT-1];

reg [7:0]  phv_b_reg[0:PHV_B_COUNT-1];
reg [15:0] phv_h_reg[0:PHV_H_COUNT-1];
reg [31:0] phv_w_reg[0:PHV_W_COUNT-1];

wire latest0_match,latest1_match,latest2_match;

assign latest0_match=(s_mat_addr==latest_addr_0[ADDR_WIDTH-1:0])&& latest_addr_0[ADDR_WIDTH];
assign latest1_match=(s_mat_addr==latest_addr_1[ADDR_WIDTH-1:0]) && latest_addr_1[ADDR_WIDTH];
assign latest2_match=(s_mat_addr==latest_addr_2[ADDR_WIDTH-1:0]) && latest_addr_2[ADDR_WIDTH];


integer i, j, k;
always @( posedge clk ) begin  
    if ( m_phv_ready ) begin
        m_phv_valid_reg <= 1'b0;
    end
    if ( s_phv_valid && s_phv_ready && s_mat_valid && s_mat_ready ) begin
        m_phv_valid_reg <= 1'b1;
        mat_hit_reg<=s_mat_hit;
        mat_value_reg<=s_mat_value;
        mat_addr_reg<=s_mat_addr;
        for (i = 0; i < PHV_B_COUNT; i = i + 1) begin
            phv_b_reg[i] <= phv_b[i];
        end
        for (j = 0; j < PHV_H_COUNT; j = j + 1) begin
            phv_h_reg[j] <= phv_h[j];
        end
        for (k = 0; k < PHV_W_COUNT; k = k + 1) begin
            phv_w_reg[k] <= phv_w[k];
        end

        if (latest0_match) begin
            match_sel_reg<=2'b01;
        end
        else if (latest1_match) begin
            match_sel_reg<=2'b10;
        end
        else if (latest2_match) begin
            match_sel_reg<=2'b11;
        end
        else begin
            match_sel_reg<=2'b0;
        end
    end

    if (rst) begin
        m_phv_valid_reg <= 1'b0;
        match_sel_reg<=2'b0;
        mat_hit_reg<=1'b0;
        mat_value_reg<={(VALUE_WIDTH){1'b0}};
        mat_addr_reg<={(ADDR_WIDTH){1'b0}};
    end
end

assign m_phv_match_sel=match_sel_reg;
assign m_phv_mat_hit=mat_hit_reg;
assign m_phv_mat_addr=mat_addr_reg;
assign m_phv_mat_value=mat_value_reg;

endmodule
`resetall