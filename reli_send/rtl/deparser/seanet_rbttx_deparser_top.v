`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// Create Date: 2023/05/31 15:36:11
// Design Name: songmg
// Module Name: deparser
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//////////////////////////////////////////////////////////////////////////////////

module seanet_rbttx_deparser_top #
(
    parameter DATA_WIDTH = 64,
    parameter KEEP_ENABLE = 1,
    parameter KEEP_WIDTH = (DATA_WIDTH/8),

    // Width of User
    parameter USER_ENABLE = 1,
    parameter S_USER_WIDTH = 64,
    parameter M_USER_WIDTH = 88,
    //config csr parameters
    parameter CSR_ADDR_WIDTH = 12,
    parameter CSR_DATA_WIDTH = 32,
    parameter CSR_STRB_WIDTH = 4,

    parameter PHV_B_COUNT = 7,
    parameter PHV_H_COUNT = 2,
    parameter PHV_W_COUNT = 10,
    parameter PHV_WIDTH = 408
)
(
    input  wire          clk,
    input  wire          rst,

    input  wire [PHV_WIDTH-1 : 0]    s_phv_info,
    input  wire                      s_phv_valid,
    output wire                      s_phv_ready,

    /*
     * Register interface controler interface : 
     */
    input  wire [CSR_ADDR_WIDTH-1:0]    csr_wr_addr,
    input  wire [CSR_DATA_WIDTH-1:0]    csr_wr_data,
    input  wire [CSR_STRB_WIDTH-1:0]    csr_wr_strb,
    input  wire                         csr_wr_en,
    output wire                         csr_wr_wait,
    output wire                         csr_wr_ack,

    input  wire [CSR_ADDR_WIDTH-1:0]    csr_rd_addr,
    input  wire                         csr_rd_en,
    output wire [CSR_DATA_WIDTH-1:0]    csr_rd_data,
    output wire                         csr_rd_wait,
    output wire                         csr_rd_ack,

    /*input*/
    input  wire [DATA_WIDTH-1:0]     s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]     s_axis_tkeep,
    input  wire                      s_axis_tvalid,
    output wire                      s_axis_tready,
    input  wire                      s_axis_tlast,
    input  wire [S_USER_WIDTH-1:0]   s_axis_tuser,
    /*output*/
    output wire [DATA_WIDTH-1:0]     m_axis_tdata,
    output wire [KEEP_WIDTH-1:0]     m_axis_tkeep,
    output wire                      m_axis_tvalid,
    input  wire                      m_axis_tready,
    output wire                      m_axis_tlast,
    output wire [M_USER_WIDTH-1:0]   m_axis_tuser
);

wire [7:0]  phv_b[0:PHV_B_COUNT-1];
wire [15:0] phv_h[0:PHV_H_COUNT-1];
wire [31:0] phv_w[0:PHV_W_COUNT-1];
wire reliable_enable;
/*
phv fifo
*/
wire [PHV_WIDTH-1:0] s_phv_info_fifo;
wire                 s_phv_valid_fifo;
wire                 s_phv_ready_fifo;
wire [7:0]           count ;

axis_srl_fifo #(
    .DEPTH              (8), // dly 8 clock
    .DATA_WIDTH         (PHV_WIDTH),
    .KEEP_ENABLE        (0),
    .LAST_ENABLE        (0),
    .ID_ENABLE          (0),
    .DEST_ENABLE        (0),
    .USER_ENABLE        (0)
)
phv_axis_fifo_inst (
    .clk                (clk),
    .rst                (rst),

    .s_axis_tdata       (s_phv_info),
    .s_axis_tvalid      (s_phv_valid),
    .s_axis_tready      (s_phv_ready),
    .s_axis_tkeep       (0),
    .s_axis_tlast       (0),
    .s_axis_tuser       (0),

	.m_axis_tdata       (s_phv_info_fifo),
	.m_axis_tvalid      (s_phv_valid_fifo),
	.m_axis_tready      (s_phv_ready_fifo),
    .m_axis_tkeep       (),
    .m_axis_tlast       (),
    .m_axis_tuser       (),
	
	.count              (count)
);

generate

    genvar b,h,w;

    for (b = 0; b < PHV_B_COUNT; b = b + 1) begin
        assign phv_b[b] = s_phv_info_fifo[b*8 +: 8];
    end
    for (h = 0; h < PHV_H_COUNT; h = h + 1) begin
        assign phv_h[h] = s_phv_info_fifo[8*PHV_B_COUNT+h*16 +: 16];
    end
    for (w = 0; w < PHV_W_COUNT; w = w + 1) begin
        assign phv_w[w] = s_phv_info_fifo[8*PHV_B_COUNT+16*PHV_H_COUNT+w*32 +: 32];
    end

endgenerate

localparam MODIFY_WIDTH = 'd32;
localparam RPN_OFFSET = 'd22; // common field:4Byte + 1Byte +1Byte + 16Byte
localparam MODIFY_USER_WIDTH = M_USER_WIDTH + MODIFY_WIDTH + 'd16 + 'd16 + 1 + 4; //1bit pktrst_modify_width + bit_offset
//phv_b
localparam PKTPROPERTY_NO = 'd0; 
localparam PKT_VALID_NO = 'd1; 
localparam INPORT_NO = 'd2; 
localparam OUTPORT_NO = 'd3;
localparam IPOFFSET_NO = 'd4;  
localparam TID_NO = 'd5;
localparam SEATL_OFFSET_NO = 'd6; 
 
//phv_h
localparam PKT_LEN_NO = 'd0;
localparam FLOWINDEX_NO = 'd1;
//phv_w
localparam RPN_NO = 'd9;

wire [MODIFY_USER_WIDTH-1:0]    new_tuser;
wire [14:0]                     rpn_offset;
wire [14:0]                     rpara_offset;
wire rpn_modify_flag;
wire pktrst_modify_flag;

reg  [MODIFY_USER_WIDTH-1:0]    new_tuser_reg;
assign rpn_modify_flag = (phv_b[PKTPROPERTY_NO][0] && phv_b[PKTPROPERTY_NO][2] && phv_b[PKTPROPERTY_NO][1]) ? reliable_enable : 0;  //net_flag= 80 && protocol=seagp
assign rpn_offset = phv_b[SEATL_OFFSET_NO] + RPN_OFFSET;

assign pktrst_modify_flag = phv_b[PKTPROPERTY_NO][5];   //pkt_rst_enable
assign rpara_offset = phv_b[SEATL_OFFSET_NO] + 5;
// assign seatl_offset = phv_b[SEATL_OFFSET_NO];

always @* begin
    if(phv_b[PKTPROPERTY_NO][2])begin
        new_tuser_reg = {1'b1, rpara_offset[14:0], pktrst_modify_flag, 4'd7, rpn_modify_flag, rpn_offset[14:0], phv_w[RPN_NO],phv_h[FLOWINDEX_NO],phv_b[SEATL_OFFSET_NO],phv_h[PKT_LEN_NO],phv_b[TID_NO],phv_b[IPOFFSET_NO],phv_b[OUTPORT_NO],phv_b[INPORT_NO],phv_b[PKT_VALID_NO],phv_b[PKTPROPERTY_NO]};
    end
    else begin
        new_tuser_reg = {1'b0, rpara_offset[14:0], pktrst_modify_flag, 4'd7, rpn_modify_flag, rpn_offset[14:0], phv_w[RPN_NO],phv_h[FLOWINDEX_NO],phv_b[SEATL_OFFSET_NO],phv_h[PKT_LEN_NO],phv_b[TID_NO],phv_b[IPOFFSET_NO],phv_b[OUTPORT_NO],phv_b[INPORT_NO],phv_b[PKT_VALID_NO],phv_b[PKTPROPERTY_NO]};
    end
end
assign new_tuser = new_tuser_reg;
// assign new_tuser = {1'b1, rpara_offset[14:0], pktrst_modify_flag, 4'd7, rpn_modify_flag, rpn_offset[14:0], phv_w[RPN_NO],phv_h[FLOWINDEX_NO],phv_b[SEATL_OFFSET_NO],phv_h[PKT_LEN_NO],phv_b[TID_NO],phv_b[IPOFFSET_NO],phv_b[OUTPORT_NO],phv_b[INPORT_NO],phv_b[PKT_VALID_NO],phv_b[PKTPROPERTY_NO]};
/*
add_tuser
*/

wire [DATA_WIDTH-1:0]                       m_axis_added_tdata;
wire [KEEP_WIDTH-1:0]                       m_axis_added_tkeep;
wire                                        m_axis_added_tvalid;
wire                                        m_axis_added_tready;
wire                                        m_axis_added_tlast;
wire [MODIFY_USER_WIDTH-1:0]                m_axis_added_tuser;

add_tuser #(
    .DATA_WIDTH(DATA_WIDTH),
    .KEEP_ENABLE(KEEP_ENABLE),
    .KEEP_WIDTH(KEEP_WIDTH),
    .S_USER_ENABLE(0),
    .USER_WIDTH(S_USER_WIDTH),
    .ADD_WIDTH(MODIFY_USER_WIDTH)
)
add_tuser_inst (
    .clk(clk),
    .rst(rst),

    .s_add_data(new_tuser),
    .s_add_valid(s_phv_valid_fifo),
    .s_add_ready(s_phv_ready_fifo),

    .s_axis_tdata(s_axis_tdata),
    .s_axis_tkeep(s_axis_tkeep),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tuser(s_axis_tuser),

    .m_axis_tdata(m_axis_added_tdata),
    .m_axis_tkeep(m_axis_added_tkeep),
    .m_axis_tvalid(m_axis_added_tvalid),
    .m_axis_tready(m_axis_added_tready),
    .m_axis_tlast(m_axis_added_tlast),
    .m_axis_tuser(m_axis_added_tuser)
);

wire [DATA_WIDTH-1:0]                       m_axis_modify_tdata;
wire [KEEP_WIDTH-1:0]                       m_axis_modify_tkeep;
wire                                        m_axis_modify_tvalid;
wire                                        m_axis_modify_tready;
wire                                        m_axis_modify_tlast;
wire [MODIFY_USER_WIDTH-1:0]                m_axis_modify_tuser;

action_modify_fixed_len #(
    .DATA_WIDTH         (DATA_WIDTH),
    .KEEP_ENABLE        (KEEP_ENABLE),
    .KEEP_WIDTH         (KEEP_WIDTH),
    .VALUE_WIDTH        (1),
    .USER_WIDTH         (MODIFY_USER_WIDTH)
)
action_modify_rpara_inst (
    .clk                    (clk),
    .rst                    (rst),

    .s_axis_tdata     (m_axis_added_tdata),
    .s_axis_tkeep     (m_axis_added_tkeep),
    .s_axis_tvalid    (m_axis_added_tvalid),
    .s_axis_tready    (m_axis_added_tready),
    .s_axis_tlast     (m_axis_added_tlast),
    .s_axis_tuser     (m_axis_added_tuser),

    .m_axis_tdata     (m_axis_modify_tdata),
    .m_axis_tkeep     (m_axis_modify_tkeep),
    .m_axis_tvalid    (m_axis_modify_tvalid),
    .m_axis_tready    (m_axis_modify_tready),
    .m_axis_tlast     (m_axis_modify_tlast),
    .m_axis_tuser     (m_axis_modify_tuser)
);

wire [MODIFY_USER_WIDTH-21-1:0] m_axis_modify_rpn_tuser;

action_modify_fixed_len #(
    .DATA_WIDTH         (DATA_WIDTH),
    .KEEP_ENABLE        (KEEP_ENABLE),
    .KEEP_WIDTH         (KEEP_WIDTH),
    .VALUE_WIDTH        (MODIFY_WIDTH),
    .USER_WIDTH         (MODIFY_USER_WIDTH-21)
)
action_modify_rpn_inst (
    .clk                    (clk),
    .rst                    (rst),

    .s_axis_tdata     (m_axis_modify_tdata),
    .s_axis_tkeep     (m_axis_modify_tkeep),
    .s_axis_tvalid    (m_axis_modify_tvalid),
    .s_axis_tready    (m_axis_modify_tready),
    .s_axis_tlast     (m_axis_modify_tlast),
    .s_axis_tuser     (m_axis_modify_tuser[MODIFY_USER_WIDTH-21-1:0]),

    .m_axis_tdata     (m_axis_tdata),
    .m_axis_tkeep     (m_axis_tkeep),
    .m_axis_tvalid    (m_axis_tvalid),
    .m_axis_tready    (m_axis_tready),
    .m_axis_tlast     (m_axis_tlast),
    .m_axis_tuser     (m_axis_modify_rpn_tuser)
);

assign m_axis_tuser = m_axis_modify_rpn_tuser[M_USER_WIDTH-1:0];
reg reliable_ctl_reg=1'b1;
reg csr_rd_ack_reg,csr_wr_ack_reg;
reg  [CSR_DATA_WIDTH-1:0]   csr_rd_data_reg;

assign csr_wr_wait=0;
assign csr_rd_wait=0;
assign csr_rd_ack=csr_rd_ack_reg ;
assign csr_wr_ack=csr_wr_ack_reg ;
assign csr_rd_data=csr_rd_data_reg ;
assign reliable_enable=reliable_ctl_reg;

always @(posedge clk) begin
    csr_wr_ack_reg <= 1'b0;
    csr_rd_data_reg <= {CSR_DATA_WIDTH{1'b0}};
    csr_rd_ack_reg <= 1'b0;

    if (csr_wr_en && !csr_wr_ack_reg) begin
        // write operation
        csr_wr_ack_reg <= 1'b1;
        case ({csr_wr_addr >> 2, 2'b00})
            12'h000: reliable_ctl_reg <= csr_wr_data[0];

            default: csr_wr_ack_reg <= 1'b0;
        endcase
    end

    if (csr_rd_en && !csr_rd_ack_reg) begin
        // read operation
        csr_rd_ack_reg <= 1'b1;
        case ({csr_rd_addr >> 2, 2'b00})
            12'h000: csr_rd_data_reg <= {{(CSR_DATA_WIDTH-1){1'b0}},reliable_ctl_reg};
            12'h004: csr_rd_data_reg <= {27'h0,s_phv_ready, s_phv_ready_fifo, m_axis_added_tready, s_axis_tready, m_axis_tready};
            12'h008: csr_rd_data_reg <= count;
            default: csr_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst ) begin
        csr_wr_ack_reg <= 1'b0;
        csr_rd_ack_reg <= 1'b0;
        reliable_ctl_reg <= 1'b1;
    end
end



endmodule

