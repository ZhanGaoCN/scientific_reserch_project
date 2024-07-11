/*
 * @Autor: lur
 */
`resetall
`timescale 1ns / 1ps
`default_nettype none
module mau_reliable_send_action_unit#(
	//parameter VALUE_WIDTH = 32,
	parameter PHV_WIDTH = 456,
    parameter PHV_B_COUNT = 9,
    parameter PHV_H_COUNT = 2,
    parameter PHV_W_COUNT = 11,
    parameter FLOWSTATE_WIDTH=32,
    parameter ADDR_WIDTH=10
)(
    input  wire                       clk,
	input  wire                       rst,
    input  wire                       reliable_enable,
  
	input  wire [PHV_WIDTH-1:0]       s_phv_info,
	input  wire                       s_phv_valid,
	output wire                       s_phv_ready,     
    input  wire                       s_phv_mat_hit,
    input  wire [FLOWSTATE_WIDTH-1:0] s_phv_mat_value,
    input  wire [ADDR_WIDTH-1:0]      s_phv_mat_addr,
    input  wire [1:0]                 s_phv_match_sel,

	output wire [PHV_WIDTH-1:0]       m_phv_info,
	output wire                       m_phv_valid,
	input  wire                       m_phv_ready,
 
    //broadcast new flowstate & addr
    output  wire[FLOWSTATE_WIDTH-1:0] bcd_flowstate_out,//?
    output  wire[ADDR_WIDTH-1:0]      bcd_addr_out,
    output  wire                      bcd_valid_out
);



localparam PKT_PROPERTY_ON=0;
localparam DAT_INDEX = 2;
localparam NACK_INDEX = 3;
localparam PKT_RST_INDEX = 5;

localparam PKT_VALID_ON = 1;
localparam SEND_TABLE_MASK = 7;
localparam RELI_BUFFER_HIT_INDEX = 3;
localparam CLONE_PKTIN_NO = 4;

localparam OUTPORT_ON=3;
localparam PKT_RPN_ON=9;
localparam TID_ON = 5;

localparam FLOW_INDEX_NO=1;


//high 1 bit indicate valid or not
reg [FLOWSTATE_WIDTH-1:0] latest_flowstate_1;
reg [FLOWSTATE_WIDTH-1:0] latest_flowstate_2;
reg [ADDR_WIDTH-1:0] latest_addr_1;
reg [ADDR_WIDTH-1:0] latest_addr_2;

reg [ADDR_WIDTH-1:0] flowstate_addr;
reg [FLOWSTATE_WIDTH-1:0] flowstate_r;
reg [FLOWSTATE_WIDTH-1:0] flowstate_wire;
reg m_phv_valid_reg,hit_reg;

always @(posedge clk) begin
    if(rst) begin
        latest_flowstate_1<=0;
        latest_flowstate_2<=0;
        //latest_addr_1<=0;
        //latest_addr_2<=0;
    end
    else begin
        if (s_phv_ready && s_phv_valid) begin
            latest_flowstate_1<=bcd_flowstate_out;
            latest_flowstate_2<=latest_flowstate_1;
        end
    end
end

assign m_phv_valid = m_phv_valid_reg;
assign s_phv_ready = (~m_phv_valid || m_phv_ready) ;

wire [7:0]  phv_b[0:PHV_B_COUNT-1];
wire [15:0] phv_h[0:PHV_H_COUNT-1];
wire [31:0] phv_w[0:PHV_W_COUNT-1];

reg [7:0]  phv_b_reg[0:PHV_B_COUNT-1];
reg [15:0] phv_h_reg[0:PHV_H_COUNT-1];
reg [31:0] phv_w_reg[0:PHV_W_COUNT-1];
//wire bcd_match,latest1_match,latest2_match;
//assign bcd_match=(s_mat_addr==bcd_addr_out)&& bcd_valid_out;
//assign latest1_match=(s_mat_addr==latest_addr_1) && latest_flowstate_1[FLOWSTATE_WIDTH];
//assign latest2_match=(s_mat_addr==latest_addr_2) && latest_flowstate_2[FLOWSTATE_WIDTH];
//assign flowstate_wire=(bcd_match)?bcd_flowstate_out:(latest1_match)?latest_flowstate_1[FLOWSTATE_WIDTH-1:0]://s_mat_value;
//(latest2_match)?latest_flowstate_2[FLOWSTATE_WIDTH-1:0]:s_mat_value;
//assign phv_w[11]=bcd_flowstate_out;
/*
always @ (*) begin
    case (s_phv_match_sel)
    2'b01: begin
        flowstate_wire=bcd_flowstate_out;
    end
    2'b10: begin
        flowstate_wire=latest_flowstate_1[FLOWSTATE_WIDTH-1:0];
    end
    2'b11: begin
        flowstate_wire=latest_flowstate_2[FLOWSTATE_WIDTH-1:0];
    end
    2'b00: begin
        flowstate_wire=s_phv_mat_value;
    end
    endcase
end
*/

wire [FLOWSTATE_WIDTH-1:0] cache_flowstate;
wire                       cache_hit;
reg [ADDR_WIDTH-1:0]        state_key;
reg [FLOWSTATE_WIDTH-1:0]   state_value;
reg                         state_valid;

always @ (*) begin
    flowstate_wire = cache_hit? cache_flowstate:s_phv_mat_value;
end 

state_inflight #(
    .KEY_WIDTH(ADDR_WIDTH),
    .VALUE_WIDTH(FLOWSTATE_WIDTH),
    .PIPELINE(3)
)
state_inflight_inst (
    .clk(clk),
    .rst(rst),
    .key(s_phv_mat_addr),
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
    if(s_phv_valid && s_phv_ready & phv_b[PKT_VALID_ON][SEND_TABLE_MASK]) begin
        if (s_phv_mat_hit) begin
            if (phv_b[PKT_PROPERTY_ON][DAT_INDEX]) begin //dat
                state_key = s_phv_mat_addr;
                state_value = flowstate_wire+1;
                state_valid = 1'b1;
            end
        end
    end
end

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

integer i, j, k;
always @( posedge clk ) begin  
    if ( m_phv_ready ) begin
        m_phv_valid_reg <= 1'b0;
    end
    if ( s_phv_valid && s_phv_ready  ) begin
        m_phv_valid_reg <= 1'b1;
        flowstate_addr<=s_phv_mat_addr;
        flowstate_r<=flowstate_wire;
        for (i = 0; i < PHV_B_COUNT; i = i + 1) begin
            phv_b_reg[i] <= phv_b[i];
        end
        for (j = 0; j < PHV_H_COUNT; j = j + 1) begin
            phv_h_reg[j] <= phv_h[j];
        end
        for (k = 0; k < PHV_W_COUNT; k = k + 1) begin
            phv_w_reg[k] <= phv_w[k];
        end
        hit_reg<=0;
        if(phv_b[PKT_VALID_ON][SEND_TABLE_MASK]) begin
            if (s_phv_mat_hit) begin
                if (phv_b[PKT_PROPERTY_ON][DAT_INDEX]) begin //dat
                    phv_b_reg[PKT_PROPERTY_ON][PKT_RST_INDEX]<=0;
                    phv_w_reg[PKT_RPN_ON]<=flowstate_wire;
                    flowstate_r<=flowstate_wire+1;
                    phv_b_reg[PKT_VALID_ON][RELI_BUFFER_HIT_INDEX]<=1;
                    phv_h_reg[FLOW_INDEX_NO]<=s_phv_mat_addr;//set flow index 
                    phv_b_reg[PKT_VALID_ON][CLONE_PKTIN_NO]<=0;
                    hit_reg<=1;
                end else if (phv_b[PKT_PROPERTY_ON][NACK_INDEX]) begin//nack
                    phv_b_reg[PKT_VALID_ON][RELI_BUFFER_HIT_INDEX]<=1;
                    phv_h_reg[FLOW_INDEX_NO]<=s_phv_mat_addr;//set flow index
                end 
            end else begin
                if (phv_b[PKT_PROPERTY_ON][DAT_INDEX]) begin
                    phv_b_reg[PKT_PROPERTY_ON][PKT_RST_INDEX]<=1;
                    //phv_b_reg[OUTPORT_ON]  <= 8'b01_111111;
                    phv_b_reg[TID_ON]  <= 9;
                    phv_w_reg[PKT_RPN_ON] <=0;
                    flowstate_r <= 0;
                    phv_b_reg[PKT_VALID_ON][CLONE_PKTIN_NO]<=1;
                end else begin
                    phv_b_reg[OUTPORT_ON]  <= 8'b01_111111;
                    phv_b_reg[TID_ON]  <= 15;
                end
            end
        end else begin
            
        end
    end

    if (rst) begin
        flowstate_r<=0;
        m_phv_valid_reg <= 1'b0;
        hit_reg<=0;
    end
end

assign bcd_flowstate_out=flowstate_r;
assign bcd_addr_out=flowstate_addr;
assign bcd_valid_out=m_phv_ready && m_phv_valid && hit_reg;

endmodule
`resetall