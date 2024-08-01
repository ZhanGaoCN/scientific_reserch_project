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

module flowstate_tx_addr_ctl#(
    parameter PKT_METADATA_WIDTH  = 274,
    parameter FLOWSTATE_WIDTH=33,
    parameter ADDR_WIDTH=10
)(
    input  wire                     clk,
	input  wire                     rst,

	input  wire [PKT_METADATA_WIDTH-1:0]     s_pkt_metadata_info,
	input  wire                              s_pkt_metadata_valid,
	output wire                              s_pkt_metadata_ready,     

    input  wire                         s_mat_hit,
    input  wire [FLOWSTATE_WIDTH-1:0]   s_mat_value,
    input  wire [ADDR_WIDTH-1:0]        s_mat_addr,
    input  wire                         s_mat_valid,
    output wire                         s_mat_ready,

	output wire [PKT_METADATA_WIDTH-1:0]     m_pkt_metadata_info,
    
    output wire [1:0]                        m_pkt_metadata_match_sel,//input flowstate_addr match recrnt addr  
    output  wire                             m_pkt_metadata_mat_hit,
    output  wire [FLOWSTATE_WIDTH-1:0]       m_pkt_metadata_mat_value,
    output  wire [ADDR_WIDTH-1:0]            m_pkt_metadata_mat_addr,
	output wire                              m_pkt_metadata_valid,
	input  wire                              m_pkt_metadata_ready

);

//pkt_metadata no and width
localparam PKT_PROPERTY_NO = 246;

localparam DAT_TAG_INDEX  = 0;

//high 1 bit indicate valid or not
reg [ADDR_WIDTH:0] latest_addr_0;
reg [ADDR_WIDTH:0] latest_addr_1;
reg [ADDR_WIDTH:0] latest_addr_2;

reg [1:0] match_sel_reg;
reg mat_hit_reg,m_pkt_metadata_valid_reg;
reg [FLOWSTATE_WIDTH-1:0]mat_value_reg;
reg [ADDR_WIDTH-1:0]   mat_addr_reg;


wire [271:0] pkt_metadata;
reg  [271:0] pkt_metadata_reg;

assign pkt_metadata = s_pkt_metadata_info;
assign m_pkt_metadata_info = pkt_metadata_reg;

always @(posedge clk) begin
    if(rst) begin
        latest_addr_0<=0;
        latest_addr_1<=0;
        latest_addr_2<=0;
    end
    else begin
        if (s_pkt_metadata_valid && s_pkt_metadata_ready && s_mat_valid && s_mat_ready ) begin
            if (s_mat_hit && pkt_metadata_next[PKT_PROPERTY_NO + DAT_TAG_INDEX]==1) begin
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

assign m_pkt_metadata_valid = m_pkt_metadata_valid_reg;
assign s_pkt_metadata_ready = (~m_pkt_metadata_valid || m_pkt_metadata_ready) && s_pkt_metadata_valid && s_mat_valid;
assign s_mat_ready = (~m_pkt_metadata_valid || m_pkt_metadata_ready) && s_pkt_metadata_valid && s_mat_valid;

wire latest0_match,latest1_match,latest2_match;

assign latest0_match=(s_mat_addr==latest_addr_0[ADDR_WIDTH-1:0])&& latest_addr_0[ADDR_WIDTH];
assign latest1_match=(s_mat_addr==latest_addr_1[ADDR_WIDTH-1:0]) && latest_addr_1[ADDR_WIDTH];
assign latest2_match=(s_mat_addr==latest_addr_2[ADDR_WIDTH-1:0]) && latest_addr_2[ADDR_WIDTH];

always @( posedge clk ) begin  
    if ( m_pkt_metadata_ready ) begin
        m_pkt_metadata_valid_reg <= 1'b0;
    end
    if ( s_pkt_metadata_valid && s_pkt_metadata_ready && s_mat_valid && s_mat_ready ) begin
        m_pkt_metadata_valid_reg <= 1'b1;
        mat_hit_reg<=s_mat_hit;
        mat_value_reg<=s_mat_value;
        mat_addr_reg<=s_mat_addr;
        pkt_metadata_reg<=pkt_metadata;

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
        m_pkt_metadata_valid_reg <= 1'b0;
        match_sel_reg<=2'b0;
        mat_hit_reg<=1'b0;
        mat_value_reg<={(FLOWSTATE_WIDTH){1'b0}};
        mat_addr_reg<={(ADDR_WIDTH){1'b0}};
    end
end

assign m_pkt_metadata_match_sel=match_sel_reg;
assign m_pkt_metadata_mat_hit=mat_hit_reg;
assign m_pkt_metadata_mat_addr=mat_addr_reg;
assign m_pkt_metadata_mat_value=mat_value_reg;

endmodule
`resetall