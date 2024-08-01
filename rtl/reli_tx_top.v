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

`resetall
`timescale 1ns / 1ps
`default_nettype none

module reli_tx_top # (
    parameter DATA_WIDTH            = 128,
    parameter KEEP_ENABLE           = 1,
    parameter KEEP_WIDTH            = DATA_WIDTH/8,
    parameter LAST_ENABLE           = 1,
    parameter ID_WIDTH              = 8,
    parameter DEST_WIDTH            = 4,
    parameter USER_ENABLE           = 1,
    parameter S_USER_WIDTH          = 36,   //3*8+6+6
    parameter M_USER_WIDTH          = 71,   //defined in design document
    parameter MAX_MTU               = 8192,

    parameter RELI_TX_DEPTH       = 1024,//num of reli_tx_table entry

    parameter TID_WIDTH             = 8,
    parameter ADDR_WIDTH            = $clog2(RELI_TX_DEPTH*2),
    parameter KEY_WIDTH             = 133, //dst_ip(128bit) + rsip_index(5bit)
    parameter MASK_WIDTH            = KEY_WIDTH,
    parameter VALUE_WIDTH           = 0,
    // parameter STATE_WIDTH           = 33, //rpn(32bit) + rst_flag(1bit)  todo this parameter is not used 
    parameter OPCODE_WIDTH          = 4,

    parameter FLOWSTATE_WIDTH       = 33, //rpn(32bit) + rst_flag(1bit)  todo what is the difference between state_width and flowstate_width?

    parameter CSR_ADDR_WIDTH        = 16,
    parameter CSR_DATA_WIDTH        = 32,
    parameter CSR_STRB_WIDTH        = CSR_DATA_WIDTH/8,

    parameter PIPELINE_OUTPUT       = 2,//fifo parameters
    parameter FRAME_FIFO            = 0,
    parameter USER_BAD_FRAME_VALUE  = 1'b1,
    parameter USER_BAD_FRAME_MASK   = 1'b1,
    parameter DROP_OVERSIZE_FRAME   = FRAME_FIFO,
    parameter DROP_BAD_FRAME        = 0,
    parameter DROP_WHEN_FULL        = 0,

    parameter PKT_METADATA_WIDTH = 274
) (
    input  wire clk,
    input  wire rst,

    input  wire [DATA_WIDTH-1:0]                s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]                s_axis_tkeep,
    input  wire                                 s_axis_tvalid,
    output wire                                 s_axis_tready,
    input  wire                                 s_axis_tlast,
    input  wire [S_USER_WIDTH-1:0]              s_axis_tuser,

    output wire [DATA_WIDTH-1:0]                m_axis_to_mac_tdata,
    output wire [KEEP_WIDTH-1:0]                m_axis_to_mac_tkeep,
    output wire                                 m_axis_to_mac_tvalid,
    input  wire                                 m_axis_to_mac_tready,
    output wire                                 m_axis_to_mac_tlast,
    output wire [M_USER_WIDTH-1:0]              m_axis_to_mac_tuser,

    output wire [DATA_WIDTH-1:0]                m_axis_to_ctl_tdata,
    output wire [KEEP_WIDTH-1:0]                m_axis_to_ctl_tkeep,
    output wire                                 m_axis_to_ctl_tvalid,
    input  wire                                 m_axis_to_ctl_tready,
    output wire                                 m_axis_to_ctl_tlast,
    output wire [M_USER_WIDTH-1:0]              m_axis_to_ctl_tuser,

    output wire [DATA_WIDTH-1:0]                m_axis_to_buf_tdata,
    output wire [KEEP_WIDTH-1:0]                m_axis_to_buf_tkeep,
    output wire                                 m_axis_to_buf_tvalid,
    input  wire                                 m_axis_to_buf_tready,
    output wire                                 m_axis_to_buf_tlast,
    output wire [M_USER_WIDTH-1:0]              m_axis_to_buf_tuser,

    input  wire [CSR_ADDR_WIDTH-1:0]            ctrl_reg_app_wr_addr,
    input  wire [CSR_DATA_WIDTH-1:0]            ctrl_reg_app_wr_data,
    input  wire [CSR_STRB_WIDTH-1:0]            ctrl_reg_app_wr_strb,
    input  wire                                 ctrl_reg_app_wr_en,
    output wire                                 ctrl_reg_app_wr_wait,
    output wire                                 ctrl_reg_app_wr_ack,

    input  wire [CSR_ADDR_WIDTH-1:0]            ctrl_reg_app_rd_addr,
    input  wire                                 ctrl_reg_app_rd_en,
    output wire [CSR_DATA_WIDTH-1:0]            ctrl_reg_app_rd_data,
    output wire                                 ctrl_reg_app_rd_wait,
    output wire                                 ctrl_reg_app_rd_ack,

    input wire                                  reliable_enbale,
    input wire                                  device_id
);



wire [PKT_METADATA_WIDTH-1:0] m_pkt_metadata_info;
wire                 m_pkt_metadata_valid;
wire                 m_pkt_metadata_ready;
/*
 * 1. Parser
 */
wire [DATA_WIDTH-1:0]           axis_psr_tdata;
wire [KEEP_WIDTH-1:0]           axis_psr_tkeep;
wire                            axis_psr_tvalid;
wire                            axis_psr_tready;
wire                            axis_psr_tlast;
wire [S_USER_WIDTH-1:0]         axis_psr_tuser;

wire                            csr_psr_wr_wait;
wire                            csr_psr_wr_ack;
wire [CSR_DATA_WIDTH-1:0]       csr_psr_rd_data;
wire                            csr_psr_rd_wait;
wire                            csr_psr_rd_ack;

rbt_s_parser_top #(
    .DATA_WIDTH                 (DATA_WIDTH),
    .KEEP_WIDTH                 (KEEP_WIDTH),
    .USER_WIDTH                 (S_USER_WIDTH),
    .PKT_METADATA_WIDTH         (PKT_METADATA_WIDTH)
    .DEPTH                      (MAX_MTU)
) parser_inst(
    .clk                        (clk),
    .rst                        (rst),

    .s_axis_tdata               (s_axis_tdata),
    .s_axis_tkeep               (s_axis_tkeep),
    .s_axis_tvalid              (s_axis_tvalid),
    .s_axis_tready              (s_axis_tready),
    .s_axis_tlast               (s_axis_tlast),
    .s_axis_tuser               (s_axis_tuser),

    .m_axis_tdata               (axis_psr_tdata),
    .m_axis_tkeep               (axis_psr_tkeep),
    .m_axis_tvalid              (axis_psr_tvalid),
    .m_axis_tready              (axis_psr_tready),
    .m_axis_tlast               (axis_psr_tlast),
    .m_axis_tuser               (axis_psr_tuser),
    
    .m_pkt_metadata_info,                 (m_pkt_metadata_info),
    .m_pkt_metadata_valid                (m_pkt_metadata_valid),
    .m_pkt_metadata_ready                (m_pkt_metadata_ready)
);

/*
 * 1.1. AXIS_FIFO
 */
wire [DATA_WIDTH-1:0]           axis_fifo_tdata;
wire [KEEP_WIDTH-1:0]           axis_fifo_tkeep;
wire                            axis_fifo_tvalid;
wire                            axis_fifo_tready;
wire                            axis_fifo_tlast;
wire [S_USER_WIDTH-1:0]         axis_fifo_tuser;

axis_fifo #(
    .DEPTH(MAX_MTU),
    .DATA_WIDTH(DATA_WIDTH),
    .KEEP_ENABLE(KEEP_ENABLE),
    .KEEP_WIDTH(KEEP_WIDTH),
    .LAST_ENABLE(LAST_ENABLE),
    .ID_ENABLE(0),
    .ID_WIDTH(ID_WIDTH),
    .DEST_ENABLE(0),
    .DEST_WIDTH(DEST_WIDTH),
    .USER_ENABLE(USER_ENABLE),
    .USER_WIDTH(S_USER_WIDTH),
    .PIPELINE_OUTPUT(PIPELINE_OUTPUT),
    .FRAME_FIFO(FRAME_FIFO),
    .USER_BAD_FRAME_VALUE(USER_BAD_FRAME_VALUE),
    .USER_BAD_FRAME_MASK(USER_BAD_FRAME_MASK),
    .DROP_OVERSIZE_FRAME(DROP_OVERSIZE_FRAME),
    .DROP_BAD_FRAME(DROP_BAD_FRAME),
    .DROP_WHEN_FULL(DROP_WHEN_FULL)
)
axis_fifo_inst (
    .clk(clk),
    .rst(rst),

    .s_axis_tdata(axis_psr_tdata),
    .s_axis_tvalid(axis_psr_tvalid),
    .s_axis_tready(axis_psr_tready),
    .s_axis_tkeep(axis_psr_tkeep),
    .s_axis_tlast(axis_psr_tlast),
    .s_axis_tuser(axis_psr_tuser),

	.m_axis_tdata(axis_fifo_tdata),
	.m_axis_tvalid(axis_fifo_tvalid),
	.m_axis_tready(axis_fifo_tready),
    .m_axis_tkeep(axis_fifo_tkeep),
    .m_axis_tlast(axis_fifo_tlast),
    .m_axis_tuser(axis_fifo_tuser),
	
	.status_overflow(),
	.status_bad_frame(),
	.status_good_frame()
);

/*
 * 1.2 rbttx_table 
 */


wire [PHV_WIDTH-1:0] phv_mau_info;
wire                 phv_mau_valid;
wire                 phv_mau_ready;

// ####################################### new flowmod ######################################

wire                        csr_mau_wr_wait;
wire                        csr_mau_wr_ack;
wire [CSR_DATA_WIDTH-1:0]   csr_mau_rd_data;
wire                        csr_mau_rd_wait;
wire                        csr_mau_rd_ack;

mau_rbttx_top #(
    .KEY_WIDTH                     (KEY_WIDTH),
    .VALUE_WIDTH                   (VALUE_WIDTH),
    .OPCODE_WIDTH                  (OPCODE_WIDTH),
    .ADDR_WIDTH                    (ADDR_WIDTH),
    .PHV_B_COUNT                   (PHV_B_COUNT),
    .PHV_H_COUNT                   (PHV_H_COUNT),
    .PHV_W_COUNT                   (PHV_W_COUNT),
    .PHV_WIDTH                     (PHV_WIDTH)
) mau_rbttx_inst (
    .clk                    (clk),
    .rst                    (rst),

    .ctrl_reg_app_wr_addr            (ctrl_reg_app_wr_addr),
    .ctrl_reg_app_wr_data            (ctrl_reg_app_wr_data),
    .ctrl_reg_app_wr_strb            (ctrl_reg_app_wr_strb),
    .ctrl_reg_app_wr_en              (ctrl_reg_app_wr_en && ((ctrl_reg_app_wr_addr >> 12) == 16'h2) || ((ctrl_reg_app_wr_addr >> 12) == 16'h7)),
    .ctrl_reg_app_wr_wait            (csr_mau_wr_wait),
    .ctrl_reg_app_wr_ack             (csr_mau_wr_ack),

    .ctrl_reg_app_rd_addr            (ctrl_reg_app_rd_addr),
    .ctrl_reg_app_rd_en              (ctrl_reg_app_rd_en && ((ctrl_reg_app_rd_addr >> 12) == 16'h2) || ((ctrl_reg_app_wr_addr >> 12) == 16'h7)),
    .ctrl_reg_app_rd_wait            (csr_mau_rd_wait),
    .ctrl_reg_app_rd_data            (csr_mau_rd_data),
    .ctrl_reg_app_rd_ack             (csr_mau_rd_ack),

    .s_phv_info                     (m_pkt_metadata_info       ),
    .s_phv_valid                    (m_pkt_metadata_valid      ),
    .s_phv_ready                    (m_pkt_metadata_ready      ),

    .m_phv_info                     (phv_mau_info       ),
    .m_phv_valid                    (phv_mau_valid      ),
    .m_phv_ready                    (phv_mau_ready      )
);


/*
 * 1.3. deparser
*/
wire csr_deparser_wr_wait;
wire csr_deparser_wr_ack;
wire [CSR_DATA_WIDTH-1:0] csr_deparser_rd_data;
wire csr_deparser_rd_wait;
wire csr_deparser_rd_ack;

wire m_axis_deparser_out_tdata;
wire m_axis_deparser_out_tkeep;
wire m_axis_deparser_out_tvalid;
wire m_axis_deparser_out_tready;
wire m_axis_deparser_out_tlast;
wire m_axis_deparser_out_tuser;

seanet_rbttx_deparser_top # (
    .DATA_WIDTH                 (DATA_WIDTH),
    .KEEP_WIDTH                 (KEEP_WIDTH),
    .S_USER_WIDTH               (S_USER_WIDTH),
    .M_USER_WIDTH               (M_USER_WIDTH),

    .PHV_B_COUNT                (PHV_B_COUNT),
    .PHV_H_COUNT                (PHV_H_COUNT),
    .PHV_W_COUNT                (PHV_W_COUNT),
    .PHV_WIDTH                  (PHV_WIDTH)
) seanet_deparser_inst (
    .clk(clk),
    .rst(rst),

    .csr_wr_addr            (ctrl_reg_app_wr_addr),
    .csr_wr_data            (ctrl_reg_app_wr_data),
    .csr_wr_strb            (ctrl_reg_app_wr_strb),
    .csr_wr_en              (ctrl_reg_app_wr_en && ((ctrl_reg_app_wr_addr >> 12) == 16'h7)),
    .csr_wr_wait            (csr_deparser_wr_wait),
    .csr_wr_ack             (csr_deparser_wr_ack),

    .csr_rd_addr            (ctrl_reg_app_rd_addr),
    .csr_rd_en              (ctrl_reg_app_rd_en && ((ctrl_reg_app_rd_addr >> 12) == 16'h7)),
    .csr_rd_wait            (csr_deparser_rd_wait),
    .csr_rd_data            (csr_deparser_rd_data),
    .csr_rd_ack             (csr_deparser_rd_ack),

    .s_phv_info                 (phv_mau_info),
    .s_phv_valid                (phv_mau_valid),
    .s_phv_ready                (phv_mau_ready),

    .s_axis_tdata               (axis_fifo_tdata),
    .s_axis_tkeep               (axis_fifo_tkeep),
    .s_axis_tvalid              (axis_fifo_tvalid),
    .s_axis_tready              (axis_fifo_tready),
    .s_axis_tlast               (axis_fifo_tlast),
    .s_axis_tuser               (axis_fifo_tuser),

    .m_axis_tdata               (m_axis_deparser_out_tdata),
    .m_axis_tkeep               (m_axis_deparser_out_tkeep),
    .m_axis_tvalid              (m_axis_deparser_out_tvalid),
    .m_axis_tready              (m_axis_deparser_out_tready),
    .m_axis_tlast               (m_axis_deparser_out_tlast),
    .m_axis_tuser               (m_axis_deparser_out_tuser)

);

/*
 * 1.4. reliability demux
 */ 
reli_demux #(
    .AXIS_DATA_WIDTH        (DATA_WIDTH),
    .AXIS_KEEP_WIDTH        (KEEP_WIDTH),
    .AXIS_USER_WIDTH        (M_USER_WIDTH)
)
reli_demux_inst(
    .clk(clk),
    .rst(rst),
    .s_axis_tdata           (m_axis_deparser_out_tdata),
    .s_axis_tkeep           (m_axis_deparser_out_tkeep),
    .s_axis_tvalid          (m_axis_deparser_out_tvalid),
    .s_axis_tready          (m_axis_deparser_out_tready),
    .s_axis_tlast           (m_axis_deparser_out_tlast),
    .s_axis_tuser           (m_axis_deparser_out_tuser),
    .m_axis_to_mac_tdata    (m_axis_to_mac_tdata),
    .m_axis_to_mac_tkeep    (m_axis_to_mac_tkeep),
    .m_axis_to_mac_tvalid   (m_axis_to_mac_tvalid),
    .m_axis_to_mac_tready   (m_axis_to_mac_tready),
    .m_axis_to_mac_tlast    (m_axis_to_mac_tlast),
    .m_axis_to_mac_tuser    (m_axis_to_mac_tuser),
    .m_axis_to_ctl_tdata    (m_axis_to_ctl_tdata),
    .m_axis_to_ctl_tkeep    (m_axis_to_ctl_tkeep),
    .m_axis_to_ctl_tvalid   (m_axis_to_ctl_tvalid),
    .m_axis_to_ctl_tready   (m_axis_to_ctl_tready),
    .m_axis_to_ctl_tlast    (m_axis_to_ctl_tlast),
    .m_axis_to_ctl_tuser    (m_axis_to_ctl_tuser),
    .m_axis_to_buf_tdata    (m_axis_to_buf_tdata),
    .m_axis_to_buf_tkeep    (m_axis_to_buf_tkeep),
    .m_axis_to_buf_tvalid   (m_axis_to_buf_tvalid),
    .m_axis_to_buf_tready   (m_axis_to_buf_tready),
    .m_axis_to_buf_tlast    (m_axis_to_buf_tlast),
    .m_axis_to_buf_tuser    (m_axis_to_buf_tuser)
);
/*
 * a. Control Status Registers (CSR) implementation.
 */
assign ctrl_reg_app_wr_wait  = csr_mau_wr_wait;
assign ctrl_reg_app_wr_ack   = csr_mau_wr_ack ;
assign ctrl_reg_app_rd_data  = csr_mau_rd_data;
assign ctrl_reg_app_rd_wait  = csr_mau_rd_wait;
assign ctrl_reg_app_rd_ack   = csr_mau_rd_ack;

endmodule

`resetall
