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
module mau_reliable_tx_action_unit#(
    parameter PKT_METADATA_WIDTH  = 274,
    parameter FLOWSTATE_WIDTH=33,
    parameter ADDR_WIDTH=10
)(
    input  wire                       clk,
	input  wire                       rst,
    input  wire                       reliable_enable,
  
	input  wire [PKT_METADATA_WIDTH-1:0]       s_pkt_metadata_info,
	input  wire                                s_pkt_metadata_valid,
	output wire                                s_pkt_metadata_ready,

    input  wire                                s_pkt_metadata_mat_hit,
    input  wire [FLOWSTATE_WIDTH-1:0]          s_pkt_metadata_mat_value,
    input  wire [ADDR_WIDTH-1:0]               s_pkt_metadata_mat_addr,

	output wire [PKT_METADATA_WIDTH-1:0]       m_pkt_metadata_info,
	output wire                                m_pkt_metadata_valid,
	input  wire                                m_pkt_metadata_ready,
 
    //broadcast new flowstate & addr
    output  wire[FLOWSTATE_WIDTH-1:0] bcd_flowstate_out,//?
    output  wire[ADDR_WIDTH-1:0]      bcd_addr_out,
    output  wire                      bcd_valid_out
);

//pkt_metadata no and width
localparam OUTPORT_NO=8;
localparam OUTPORT_WIDTH=8;
localparam TID_NO = 16;
localparam TID_WIDTH = 8;
localparam PKT_RPN_NO = 72;
localparam PKT_RPN_WIDTH = 32;
localparam PKT_PROPERTY_NO = 246;
localparam PKT_OP_NO = 232;
localparam FLOW_INDEX_NO=263;
localparam FLOW_INDEX_WIDTH=11;

//PROPERTY structure
localparam DAT_TAG_INDEX  = 0;
localparam NACK_TAG_INDEX  = 1;
localparam PKT_RST_TAG_INDEX = 5;

//PKT_OP structure
localparam TX_TABLE_MASK_TAG_INDEX = 0;
localparam RELI_BUF_HIT_TAG_INDEX = 1;
localparam CLONE_PKTIN_TAG_INDEX = 2;

//high 1 bit indicate valid or not
reg [FLOWSTATE_WIDTH-1:0] latest_flowstate_1;
reg [FLOWSTATE_WIDTH-1:0] latest_flowstate_2;
reg [ADDR_WIDTH-1:0] latest_addr_1;
reg [ADDR_WIDTH-1:0] latest_addr_2;

reg [ADDR_WIDTH-1:0] flowstate_addr;
reg [FLOWSTATE_WIDTH-1:0] flowstate_r;
reg [FLOWSTATE_WIDTH-1:0] flowstate_wire;
reg m_pkt_metadata_valid_reg,hit_reg;

always @(posedge clk) begin
    if(rst) begin
        latest_flowstate_1<=0;
        latest_flowstate_2<=0;
    end
    else begin
        if (s_pkt_metadata_ready && s_pkt_metadata_valid) begin
            latest_flowstate_1<=bcd_flowstate_out;
            latest_flowstate_2<=latest_flowstate_1;
        end
    end
end

assign m_pkt_metadata_valid = m_pkt_metadata_valid_reg;
assign s_pkt_metadata_ready = (~m_pkt_metadata_valid || m_pkt_metadata_ready);

wire [271:0] pkt_metadata;
reg  [271:0] pkt_metadata_reg;

wire [FLOWSTATE_WIDTH-1:0] cache_flowstate;
wire                       cache_hit;
reg [ADDR_WIDTH-1:0]        state_key;
reg [FLOWSTATE_WIDTH-1:0]   state_value;
reg                         state_valid;

always @ (*) begin
    flowstate_wire = cache_hit? cache_flowstate:s_pkt_metadata_mat_value;
end 

state_inflight #(
    .KEY_WIDTH(ADDR_WIDTH),
    .VALUE_WIDTH(FLOWSTATE_WIDTH),
    .PIPELINE(3)
)
state_inflight_inst (
    .clk(clk),
    .rst(rst),
    .key(s_pkt_metadata_mat_addr),
    .value(cache_flowstate),
    .hit(cache_hit),    
    .cache_key(state_key),
    .cache_value(state_value),
    .cache_valid(state_valid)
);

always @(*) begin
    state_key = {ADDR_WIDTH{1'b0}};
    state_value = {FLOWSTATE_WIDTH{1'b0}};
    state_valid = 1'b0; 
    if(s_pkt_metadata_valid && s_pkt_metadata_ready & pkt_metadata_next[PKT_OP_NO + TX_TABLE_MASK_TAG_INDEX]) begin
        if (s_pkt_metadata_mat_hit) begin
            if (pkt_metadata_next[PKT_PROPERTY_NO + DAT_TAG_INDEX]) begin //dat
                state_key = s_pkt_metadata_mat_addr;
                state_value = flowstate_wire[FLOWSTATE_WIDTH-2 : 0]+1;
                state_valid = 1'b1;
            end
        end
    end
end

assign pkt_metadata = s_pkt_metadata_info;
assign m_pkt_metadata_info = pkt_metadata_reg;

always @( posedge clk ) begin  
    if ( m_pkt_metadata_ready ) begin
        m_pkt_metadata_valid_reg <= 1'b0;
    end
    if ( s_pkt_metadata_valid && s_pkt_metadata_ready  ) begin
        m_pkt_metadata_valid_reg <= 1'b1;
        flowstate_addr<=s_pkt_metadata_mat_addr;
        flowstate_r<=flowstate_wire;
        pkt_metadata_reg<=pkt_metadata;
        hit_reg<=0;
        if(pkt_metadata_next[PKT_OP_NO + TX_TABLE_MASK_TAG_INDEX]) begin
            if (s_pkt_metadata_mat_hit) begin
                if (pkt_metadata_next[PKT_PROPERTY_NO + DAT_TAG_INDEX]) begin //dat
                    if(flowstate_wire[FLOWSTATE_WIDTH-1] == 1)begin//rst_flag=1
                        pkt_metadata_next[PKT_PROPERTY_NO + PKT_RST_TAG_INDEX]<=1;
                        pkt_metadata_next[PKT_RPN_NO +: PKT_RPN_WIDTH]<=0;
                        flowstate_r[FLOWSTATE_WIDTH-2 : 0]<=0;
                        pkt_metadata_next[PKT_OP_NO + RELI_BUF_HIT_TAG_INDEX]<=1;
                        pkt_metadata_next[FLOW_INDEX_NO +: FLOW_INDEX_WIDTH]<=s_pkt_metadata_mat_addr;//set flow index 
                        pkt_metadata_next[PKT_OP_NO + CLONE_PKTIN_TAG_INDEX]<=0;
                        flowstate_wire[FLOWSTATE_WIDTH-1] <=0;
                        hit_reg<=1;
                    end
                    if(flowstate_wire[FLOWSTATE_WIDTH-1] == 0)begin//rst_flag=0
                        pkt_metadata_next[PKT_PROPERTY_NO + PKT_RST_TAG_INDEX]<=0;
                        pkt_metadata_next[PKT_RPN_NO +: PKT_RPN_WIDTH]<=flowstate_wire[FLOWSTATE_WIDTH-2 : 0];
                        flowstate_r[FLOWSTATE_WIDTH-2 : 0]<=flowstate_wire[FLOWSTATE_WIDTH-2 : 0]+1;
                        pkt_metadata_next[PKT_OP_NO + RELI_BUF_HIT_TAG_INDEX]<=1;
                        pkt_metadata_next[FLOW_INDEX_NO +: FLOW_INDEX_WIDTH]<=s_pkt_metadata_mat_addr;//set flow index 
                        pkt_metadata_next[PKT_OP_NO + CLONE_PKTIN_TAG_INDEX]<=0;
                        hit_reg<=1;
                    end
                end else if (pkt_metadata_next[PKT_PROPERTY_NO + NACK_TAG_INDEX]) begin//nack
                    pkt_metadata_next[PKT_OP_NO + RELI_BUF_HIT_TAG_INDEX]<=1;
                    pkt_metadata_next[FLOW_INDEX_NO +: FLOW_INDEX_WIDTH]<=s_pkt_metadata_mat_addr;//set flow index
                end 
            end else begin
                if (pkt_metadata_next[PKT_PROPERTY_NO + DAT_TAG_INDEX]) begin
                    pkt_metadata_next[PKT_PROPERTY_NO + PKT_RST_TAG_INDEX]<=1;
                    pkt_metadata_next[TID_NO +: TID_WIDTH]  <= 9;
                    pkt_metadata_next[PKT_RPN_NO +: PKT_RPN_WIDTH] <=0;
                    flowstate_r[FLOWSTATE_WIDTH-2 : 0] <= 0;
                    pkt_metadata_next[PKT_OP_NO + CLONE_PKTIN_TAG_INDEX]<=1;
                end else begin
                    pkt_metadata_next[OUTPORT_NO +: OUTPORT_WIDTH]  <= 8'b01_111111;
                    pkt_metadata_next[TID_NO +: TID_WIDTH]  <= 15;
                end
            end
        end else begin
            
        end
    end

    if (rst) begin
        flowstate_r<=0;
        m_pkt_metadata_valid <= 1'b0;
        hit_reg<=0;
    end
end

assign bcd_flowstate_out=flowstate_r;
assign bcd_addr_out=flowstate_addr;
assign bcd_valid_out=m_pkt_metadata_ready && m_pkt_metadata_valid && hit_reg;

endmodule
`resetall