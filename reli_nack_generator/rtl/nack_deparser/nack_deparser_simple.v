/*
 * @Descripttion: 
 * @version: v0.3
 * @Author: Lin Li
 * @Date: 2024-06-29 13:40:04
 * @LastEditors: Lin Li
 * @LastEditTime: 2024-07-09 20:39:44
 */

`resetall
`timescale 1ns/1ps
`default_nettype none

module nack_deparser_simple #(
    parameter CSR_ADDR_WIDTH                    = 16,
    parameter CSR_DATA_WIDTH                    = 32,
    parameter CSR_STRB_WIDTH                    = (CSR_DATA_WIDTH/8),

    // parameter INFO_WIDTH                        = 512,
    parameter TASK_REQ_WIDTH                    = 632,

    parameter BITMAP_WIDTH                      = 64,
    parameter RPN_WIDTH                         = 32,

    parameter AXIS_DATA_WIDTH                   = 512,
    parameter AXIS_KEEP_WIDTH                   = AXIS_DATA_WIDTH/8,
    parameter AXIS_USER_WIDTH                   = 40
) (
    input  wire                                 clk,
    input  wire                                 rst,

//control register interface
    input  wire [CSR_ADDR_WIDTH-1:0]            csr_wr_addr,
    input  wire [CSR_DATA_WIDTH-1:0]            csr_wr_data,
    input  wire [CSR_STRB_WIDTH-1:0]            csr_wr_strb,
    input  wire                                 csr_wr_en,
    output wire                                 csr_wr_wait,
    output wire                                 csr_wr_ack,
    input  wire [CSR_ADDR_WIDTH-1:0]            csr_rd_addr,
    input  wire                                 csr_rd_en,
    output wire [CSR_DATA_WIDTH-1:0]            csr_rd_data,
    output wire                                 csr_rd_wait,
    output wire                                 csr_rd_ack,

// //input
//     input  wire [INFO_WIDTH-1:0]                s_nack_gen_info,
//     input  wire [RPN_WIDTH-1:0]                 s_nack_gen_rpn,
//     input  wire [RPN_WIDTH-1:0]                 s_nack_gen_exp_rpn,
//     input  wire                                 m_sp_valid,
//     output wire                                 m_sp_ready,
//  output pkt num
    input  wire [3:0] 		                    output_pkt_num,
// 	simple
    input  wire [TASK_REQ_WIDTH-1:0] 		    m_sp_task_req,
	input  wire 							    m_sp_valid,
	output wire 							    m_sp_ready,

//output NACK
    output wire [AXIS_DATA_WIDTH-1:0]           m_axis_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]           m_axis_tkeep,
    output wire                                 m_axis_tvalid,
    input  wire                                 m_axis_tready,
    output wire                                 m_axis_tlast,
    output wire [AXIS_USER_WIDTH-1:0]           m_axis_tuser
);

/*
 .--------------------------------------------------------------------.
 |                       nack gen req structure                       |
 |------------------------------------------+--------------------------|
 |    s_info(512bit)     |    bitmap(64bit)    |     NPN(32bit)       |
 `--------------------------------------------------------------------'
 <<-high------------------------608bit---------------------------low->>

 .-----------------------------------------------------------------------------------------------------------------------------------------------------------.
 |                                                                   PHV structure                                                                        |
 |-----------------------------------------------------------------------------------------------------------------------------------------------------------|
 | Reserved(40bit) | Inport(8bit) | DstIP(128bit) | SrcIP(128bit) | PPP(16bit) | PPPoE(48bit) | VLan(32bit) | EthType(16bit) | SrcMAC(48bit) | DstMAC(48bit) |
 `-----------------------------------------------------------------------------------------------------------------------------------------------------------'
 <<-high------------------------------------------------------------------512bit------------------------------------------------------------------------low->>

 .---------------------------------------------------------------------.
 |                             tuser structure                         |
 |---------------------------------------------------------------------|
 | PKT_PROPERTY(8bit) | NextTable(8bit) | Outport(8bit) | Inport(8bit) |
 `---------------------------------------------------------------------'
 <<-high-----------------------32bit-----------------------------low->>
*/

localparam DST_MAC_OFFSET = 0;
localparam DST_MAC_WIDTH = 48;
localparam SRC_MAC_OFFSET = DST_MAC_OFFSET + DST_MAC_WIDTH;
localparam SRC_MAC_WIDTH = 48;
localparam VLAN_ID_OFFSET = SRC_MAC_WIDTH + SRC_MAC_OFFSET;
localparam VLAN_ID_WIDTH = 16;
localparam SRC_IP_OFFSET = VLAN_ID_WIDTH + VLAN_ID_OFFSET;
localparam SRC_IP_WIDTH = 128;
localparam DST_IP_OFFSET = SRC_IP_WIDTH + SRC_IP_OFFSET;
localparam DST_IP_WIDTH = 128;
localparam INPORT_OFFSET = DST_IP_WIDTH + DST_IP_OFFSET;
localparam INPORT_WIDTH = 8;

//s_info reg

reg [8-1:0]                               inport_reg;

reg [VLAN_ID_WIDTH-1:0]                   vlan_id_reg;
reg [SRC_MAC_WIDTH-1:0]                   src_mac_reg;
reg [DST_MAC_WIDTH-1:0]                   dst_mac_reg;

reg [DST_IP_WIDTH-1:0]                    dst_ip_reg;
reg [SRC_IP_WIDTH-1:0]                    src_ip_reg;

reg [BITMAP_WIDTH-1:0]                    bitmap_reg;
wire [BITMAP_WIDTH-1:0]                   bitmap_inv;
reg [RPN_WIDTH-1:0]                       init_npn_reg;

localparam  NACK_PKTLEN_VLAN      = 592;
localparam  NACK_PKTLEN           = 560;
localparam  NACK_PKT_WIDTH        = (AXIS_DATA_WIDTH == 512)?1024:640;
localparam  PADDING_VLAN          = NACK_PKT_WIDTH-NACK_PKTLEN_VLAN;
localparam  PADDING_WITHOUT       = NACK_PKT_WIDTH-NACK_PKTLEN;

localparam  BEAT_PER_PACKET      = NACK_PKT_WIDTH / AXIS_DATA_WIDTH;

// assign output_pkt_num = 4'd2;

//mac vlan  144 b
// reg [47:0] dst_mac_reg;
// reg [47:0] src_mac_reg;
reg [15:0] eth_type_reg;
// reg [15:0] vlan_id_reg;
reg [15:0] vlan_type_reg;

//ipv6  320 b
reg [31:0] version_traffic_flow_reg;
reg [15:0] payload_length_reg;
reg [7:0] next_header_reg;
reg [7:0] hop_limit_reg;
// reg [127:0] src_ip_reg;
// reg [127:0] dst_ip_reg;


//scmp public header 32 b
reg [7:0] scmp_ptype_reg;
reg [7:0] scmp_code_reg;
reg [15:0] scmp_checksum_reg;

//NACK  96 b


//padding  ppp  64   vlan  32  TODO parameter
reg [PADDING_VLAN-1:0] padding_reg_with_vlan = {PADDING_VLAN{1'b0}};
reg [PADDING_WITHOUT-1:0] padding_reg_without = {PADDING_WITHOUT{1'b0}};
//axis

reg axis_tvalid_reg;
reg [AXIS_USER_WIDTH-1:0] axis_tuser_reg;

//counter
reg [$clog2(BEAT_PER_PACKET)-1:0] counter;
reg [3:0]                         pkt_num_reg;

//nack packet
reg [NACK_PKT_WIDTH-1:0]    nack_packet;

reg [AXIS_KEEP_WIDTH-1:0]   m_axis_tkeep_reg;
reg                         m_axis_tlast_reg;
assign m_axis_tkeep =       m_axis_tkeep_reg;
assign m_axis_tlast =       m_axis_tlast_reg;

reg [RPN_WIDTH-1:0]     rpn_reg;
reg [RPN_WIDTH-1:0]     exp_rpn_reg;
reg [RPN_WIDTH-1:0]     npn_num_reg;
//求bitmap
always@(*)begin
    case(npn_num_reg)
    {26'd0,6'd0}:bitmap_reg = 64'h0000_0000_0000_0000;
    {26'd0,6'd1}:bitmap_reg = 64'h0000_0000_0000_0001;
    {26'd0,6'd2}:bitmap_reg = 64'h0000_0000_0000_0003;
    {26'd0,6'd3}:bitmap_reg = 64'h0000_0000_0000_0007;
    {26'd0,6'd4}:bitmap_reg = 64'h0000_0000_0000_000F;
    {26'd0,6'd5}:bitmap_reg = 64'h0000_0000_0000_001F;
    {26'd0,6'd6}:bitmap_reg = 64'h0000_0000_0000_003F;
    {26'd0,6'd7}:bitmap_reg = 64'h0000_0000_0000_007F;
    {26'd0,6'd8}:bitmap_reg = 64'h0000_0000_0000_00FF;
    {26'd0,6'd9}:bitmap_reg = 64'h0000_0000_0000_01FF;
    {26'd0,6'd10}:bitmap_reg = 64'h0000_0000_0000_03FF;
    {26'd0,6'd11}:bitmap_reg = 64'h0000_0000_0000_07FF;
    {26'd0,6'd12}:bitmap_reg = 64'h0000_0000_0000_0FFF;
    {26'd0,6'd13}:bitmap_reg = 64'h0000_0000_0000_1FFF;
    {26'd0,6'd14}:bitmap_reg = 64'h0000_0000_0000_3FFF;
    {26'd0,6'd15}:bitmap_reg = 64'h0000_0000_0000_7FFF;
    {26'd0,6'd16}:bitmap_reg = 64'h0000_0000_0000_FFFF;
    {26'd0,6'd17}:bitmap_reg = 64'h0000_0000_0001_FFFF;
    {26'd0,6'd18}:bitmap_reg = 64'h0000_0000_0003_FFFF;
    {26'd0,6'd19}:bitmap_reg = 64'h0000_0000_0007_FFFF;
    {26'd0,6'd20}:bitmap_reg = 64'h0000_0000_000F_FFFF;
    {26'd0,6'd21}:bitmap_reg = 64'h0000_0000_001F_FFFF;
    {26'd0,6'd22}:bitmap_reg = 64'h0000_0000_003F_FFFF;
    {26'd0,6'd23}:bitmap_reg = 64'h0000_0000_007F_FFFF;
    {26'd0,6'd24}:bitmap_reg = 64'h0000_0000_00FF_FFFF;
    {26'd0,6'd25}:bitmap_reg = 64'h0000_0000_01FF_FFFF;
    {26'd0,6'd26}:bitmap_reg = 64'h0000_0000_03FF_FFFF;
    {26'd0,6'd27}:bitmap_reg = 64'h0000_0000_07FF_FFFF;
    {26'd0,6'd28}:bitmap_reg = 64'h0000_0000_0FFF_FFFF;
    {26'd0,6'd29}:bitmap_reg = 64'h0000_0000_1FFF_FFFF;
    {26'd0,6'd30}:bitmap_reg = 64'h0000_0000_3FFF_FFFF;
    {26'd0,6'd31}:bitmap_reg = 64'h0000_0000_7FFF_FFFF;
    {26'd0,6'd32}:bitmap_reg = 64'h0000_0000_FFFF_FFFF;
    {26'd0,6'd33}:bitmap_reg = 64'h0000_0001_FFFF_FFFF;
    {26'd0,6'd34}:bitmap_reg = 64'h0000_0003_FFFF_FFFF;
    {26'd0,6'd35}:bitmap_reg = 64'h0000_0007_FFFF_FFFF;
    {26'd0,6'd36}:bitmap_reg = 64'h0000_000F_FFFF_FFFF;
    {26'd0,6'd37}:bitmap_reg = 64'h0000_001F_FFFF_FFFF;
    {26'd0,6'd38}:bitmap_reg = 64'h0000_003F_FFFF_FFFF;
    {26'd0,6'd39}:bitmap_reg = 64'h0000_007F_FFFF_FFFF;
    {26'd0,6'd40}:bitmap_reg = 64'h0000_00FF_FFFF_FFFF;
    {26'd0,6'd41}:bitmap_reg = 64'h0000_01FF_FFFF_FFFF;
    {26'd0,6'd42}:bitmap_reg = 64'h0000_03FF_FFFF_FFFF;
    {26'd0,6'd43}:bitmap_reg = 64'h0000_07FF_FFFF_FFFF;
    {26'd0,6'd44}:bitmap_reg = 64'h0000_0FFF_FFFF_FFFF;
    {26'd0,6'd45}:bitmap_reg = 64'h0000_1FFF_FFFF_FFFF;
    {26'd0,6'd46}:bitmap_reg = 64'h0000_3FFF_FFFF_FFFF;
    {26'd0,6'd47}:bitmap_reg = 64'h0000_7FFF_FFFF_FFFF;
    {26'd0,6'd48}:bitmap_reg = 64'h0000_FFFF_FFFF_FFFF;
    {26'd0,6'd49}:bitmap_reg = 64'h0001_FFFF_FFFF_FFFF;
    {26'd0,6'd50}:bitmap_reg = 64'h0003_FFFF_FFFF_FFFF;
    {26'd0,6'd51}:bitmap_reg = 64'h0007_FFFF_FFFF_FFFF;
    {26'd0,6'd52}:bitmap_reg = 64'h000F_FFFF_FFFF_FFFF;
    {26'd0,6'd53}:bitmap_reg = 64'h001F_FFFF_FFFF_FFFF;
    {26'd0,6'd54}:bitmap_reg = 64'h003F_FFFF_FFFF_FFFF;
    {26'd0,6'd55}:bitmap_reg = 64'h007F_FFFF_FFFF_FFFF;
    {26'd0,6'd56}:bitmap_reg = 64'h00FF_FFFF_FFFF_FFFF;
    {26'd0,6'd57}:bitmap_reg = 64'h01FF_FFFF_FFFF_FFFF;
    {26'd0,6'd58}:bitmap_reg = 64'h03FF_FFFF_FFFF_FFFF;
    {26'd0,6'd59}:bitmap_reg = 64'h07FF_FFFF_FFFF_FFFF;
    {26'd0,6'd60}:bitmap_reg = 64'h0FFF_FFFF_FFFF_FFFF;
    {26'd0,6'd61}:bitmap_reg = 64'h1FFF_FFFF_FFFF_FFFF;
    {26'd0,6'd62}:bitmap_reg = 64'h3FFF_FFFF_FFFF_FFFF;
    {26'd0,6'd63}:bitmap_reg = 64'h7FFF_FFFF_FFFF_FFFF;
    default:bitmap_reg = 64'hFFFF_FFFF_FFFF_FFFF;
endcase
end

wire [RPN_WIDTH-1:0] bitmap_tail;//bitmap最大的位置
assign bitmap_tail = {exp_rpn_reg[31:6],6'b111111};
// axis keep logic TODO
always@(*)begin
    case(vlan_id_reg[15])
    1'b1:begin
        m_axis_tkeep_reg = (counter == BEAT_PER_PACKET-1) ? {AXIS_KEEP_WIDTH{1'b1}}>>(PADDING_VLAN/8) : {AXIS_KEEP_WIDTH{1'b1}};
        m_axis_tlast_reg = (counter == BEAT_PER_PACKET-1) ? 1 : 0;
    end
    1'b0:begin
        m_axis_tkeep_reg = (counter == BEAT_PER_PACKET-1) ? {AXIS_KEEP_WIDTH{1'b1}}>>(PADDING_WITHOUT/8) : {AXIS_KEEP_WIDTH{1'b1}};
        m_axis_tlast_reg = (counter == BEAT_PER_PACKET-1) ? 1 : 0;
    end
endcase
end

// packet logic 不带reg的是从phv中解析出的
always@(*)begin
case(vlan_id_reg[15])
1'b1:begin//有 vlan                            
nack_packet =   {dst_mac_reg,src_mac_reg,vlan_type_reg,4'b0,vlan_id_reg[11:0],eth_type_reg,
                                version_traffic_flow_reg,payload_length_reg,next_header_reg,hop_limit_reg,src_ip_reg,dst_ip_reg,
                                scmp_ptype_reg,scmp_code_reg,scmp_checksum_reg,    
                                init_npn_reg,bitmap_inv,
                                padding_reg_with_vlan};
end
1'b0:begin // 无vlan
nack_packet =   {dst_mac_reg,src_mac_reg,eth_type_reg,
                                version_traffic_flow_reg,payload_length_reg,next_header_reg,hop_limit_reg,src_ip_reg,dst_ip_reg,
                                scmp_ptype_reg,scmp_code_reg,scmp_checksum_reg,
                                init_npn_reg,bitmap_inv,
                                padding_reg_without};
end
endcase
end
// 改变字节序
 wire  [NACK_PKT_WIDTH-1:0] nack_packet_axis;
 localparam WIRE_WIDTH = NACK_PKT_WIDTH/8;

 generate
    genvar j;
     for (j = 0; j < WIRE_WIDTH ; j = j+1)begin
        assign nack_packet_axis[(8*(WIRE_WIDTH-j)-1)-:8] = nack_packet[(8*(j+1)-1)-:8];
     end
 endgenerate

 
 generate
    genvar k;
     for (k= 0; k < 64 ; k = k+1)begin
        assign bitmap_inv[63-k] = bitmap_reg[k];
     end
 endgenerate
reg drop_flag;

assign m_axis_tvalid = axis_tvalid_reg & ~drop_flag;
assign m_axis_tdata = nack_packet_axis[counter*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH];
assign m_axis_tuser = {8'b0,8'h08,8'hff,8'b0,inport_reg};

//assign m_sp_ready = !axis_tvalid_reg || (m_axis_tready && (counter == BEAT_PER_PACKET - 1));
assign m_sp_ready = !axis_tvalid_reg || (m_axis_tready && m_axis_tlast_reg && (pkt_num_reg == output_pkt_num -1));



always @(posedge clk) begin
    if(rst) begin
        dst_mac_reg                     <= 0;
        src_mac_reg                     <= 0;
        eth_type_reg                    <= 16'h86dd;
        vlan_id_reg                     <= 0;
        vlan_type_reg                   <= 16'h8100;

        version_traffic_flow_reg    <= 32'h6000_0000;
        payload_length_reg          <= 16'd16;
        next_header_reg             <= 8'h92;
        hop_limit_reg               <= 8'hff;
        src_ip_reg                      <= 0;
        dst_ip_reg                      <= 0;


        scmp_ptype_reg              <= 8'h41;
        scmp_code_reg               <= 8'h01;
        scmp_checksum_reg           <= 16'h0000;

        init_npn_reg                 <= 0;
        npn_num_reg                  <= 0;
        axis_tvalid_reg             <= 1'b0;
        axis_tuser_reg              <= 0;

        counter                     <= 0;
        pkt_num_reg                 <= 0;

        drop_flag                   <= 0;
    end else begin
        if(m_axis_tvalid && m_axis_tready) begin
            
            
                if(counter == BEAT_PER_PACKET - 1) begin
                    counter <= 0;
                    if(pkt_num_reg == output_pkt_num -1) begin
                        axis_tvalid_reg <= 1'b0;
                        pkt_num_reg <= 0;
                        
                    end else
                        pkt_num_reg <= pkt_num_reg + 1;
                end else
                    counter <= counter + 1;
            end
        end                                   
        

        if(m_sp_valid && m_sp_ready && (m_sp_task_req[16]==1)) begin // 只处理dat包
            
         // {inport_reg,dst_ip_reg,src_ip_reg,vlan_id_reg,src_mac_reg,dst_mac_reg} <= m_sp_task_req[631:120];  // original order
            {inport_reg,src_ip_reg,dst_ip_reg,vlan_id_reg,src_mac_reg,dst_mac_reg} <= m_sp_task_req[631:120];//invert address
                rpn_reg      <= m_sp_task_req[55:24];
                init_npn_reg <= m_sp_task_req[87:56];          
                exp_rpn_reg  <= m_sp_task_req[87:56];
                npn_num_reg  <= m_sp_task_req[55:24] - m_sp_task_req[87:56];
            if((m_sp_task_req[55:24] == m_sp_task_req[87:56])||(m_sp_task_req[55:24] < m_sp_task_req[87:56]))begin
                drop_flag <= 1'b1;
            end else begin
                drop_flag <= 1'b0;
            end
            axis_tvalid_reg <= 1'b1;

            
        end
    end
endmodule
`resetall