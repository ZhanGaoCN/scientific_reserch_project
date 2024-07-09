/*
 * @Autor: Lin Li, Zhixiang Zhao
 * @Date: 2023-10-25 16:42
 * @LastEditors: Lin Li
 * @LastEditTime: 2024-06-10 21:26:57
 */

`resetall
`timescale 1ns/1ps
`default_nettype none

module nack_deparser #(
    parameter CSR_ADDR_WIDTH                    = 16,
    parameter CSR_DATA_WIDTH                    = 32,
    parameter CSR_STRB_WIDTH                    = (CSR_DATA_WIDTH/8),

    parameter INFO_WIDTH                        = 512,

    parameter BITMAP_WIDTH                      = 64,
    parameter RPN_WIDTH                         = 32,

    parameter AXIS_DATA_WIDTH                   = 512,
    parameter AXIS_KEEP_WIDTH                   = AXIS_DATA_WIDTH/8,
    parameter AXIS_USER_WIDTH                   = 32
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

//input npn
    input  wire [INFO_WIDTH-1:0]                s_nack_gen_info,
    input  wire [BITMAP_WIDTH-1:0]              s_nack_gen_bitmap,
    input  wire [RPN_WIDTH-1:0]                 s_nack_gen_init_npn,
    input  wire                                 s_nack_gen_valid,
    output wire                                 s_nack_gen_ready,

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

reg [8-1:0]                                 inport_reg;

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

//nack packet
reg [NACK_PKT_WIDTH-1:0]    nack_packet;

reg [AXIS_KEEP_WIDTH-1:0]   m_axis_tkeep_reg;
reg                         m_axis_tlast_reg;
assign m_axis_tkeep =       m_axis_tkeep_reg;
assign m_axis_tlast =       m_axis_tlast_reg;

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
nack_packet =   {src_mac_reg,dst_mac_reg,vlan_type_reg,4'b0,vlan_id_reg[11:0],eth_type_reg,
                                version_traffic_flow_reg,payload_length_reg,next_header_reg,hop_limit_reg,dst_ip_reg,src_ip_reg,
                                scmp_ptype_reg,scmp_code_reg,scmp_checksum_reg,    
                                init_npn_reg,bitmap_inv,
                                padding_reg_with_vlan};
end
1'b0:begin // 无vlan
nack_packet =   {src_mac_reg,dst_mac_reg,eth_type_reg,
                                version_traffic_flow_reg,payload_length_reg,next_header_reg,hop_limit_reg,dst_ip_reg,src_ip_reg,
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

assign m_axis_tvalid = axis_tvalid_reg;
assign m_axis_tdata = nack_packet_axis[counter*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH];
assign m_axis_tuser = {8'h10,8'b0,inport_reg,inport_reg};

//assign s_nack_gen_ready = !axis_tvalid_reg || (m_axis_tready && (counter == BEAT_PER_PACKET - 1));
assign s_nack_gen_ready = !axis_tvalid_reg || (m_axis_tready && m_axis_tlast_reg);

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

        bitmap_reg                   <= 0;
        init_npn_reg                 <= 0;

        axis_tvalid_reg             <= 1'b0;
        axis_tuser_reg              <= 0;

        counter                     <= 0;
    end else begin
        if(m_axis_tvalid && m_axis_tready) begin
            

                if(counter == BEAT_PER_PACKET - 1) begin
                    counter <= 0;
                    axis_tvalid_reg <= 1'b0;
                end else
                    counter <= counter + 1;
            end
        end                                   
        

        if(s_nack_gen_valid && s_nack_gen_ready) begin
            // {flag_reg,axis_tuser_reg[0 +: INPORT_WIDTH], dst_ip_reg, src_ip_reg, p2p_reg, pppoe_reg,
            //  vlan_type_reg, vlan_id_reg, eth_type_reg, src_mac_reg, dst_mac_reg} <= s_nack_gen_info;
            {inport_reg,dst_ip_reg,src_ip_reg,vlan_id_reg,src_mac_reg,dst_mac_reg} <= s_nack_gen_info;
                init_npn_reg <= s_nack_gen_init_npn;           
                bitmap_reg  <= s_nack_gen_bitmap;
            
            axis_tvalid_reg <= 1'b1;

            
        end
    end
endmodule
`resetall