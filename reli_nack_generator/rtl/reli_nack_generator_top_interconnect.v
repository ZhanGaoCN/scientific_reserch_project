/*
 * Created on 20240626
 *
 *
 * @Filename:	 reli_nack_generator_top_interconnect.v
 * @Author:		 zhanga
 * @Last edit:	 
 */

// Language: Verilog 2001
`resetall
`timescale 1ns / 1ps
`default_nettype none

module reli_nack_generator_top_interconnect #(
    parameter MAX_WND_SIZE      = 16'd4096,
    parameter INIT_JUMP_THRESH  = 16'd25000,
	parameter AXIS_DATA_WIDTH			 = 128,
	parameter AXIS_KEEP_ENABLE			 = 1,
	parameter AXIS_KEEP_WIDTH			 = AXIS_DATA_WIDTH/8,
	parameter AXIS_LAST_ENABLE			 = 1,

    parameter MAIN_CLK			         = 200,

	// Width of User
    parameter AXIS_USER_ENABLE           = 1,
    parameter AXIS_USER_WIDTH            = 32,  //PKT_PROPERTY8 + NextTable8 + outport8 + inport8
    //STREAM
    parameter STREAM_NUM                 = 2048,
    parameter TASK_REQ_WIDTH             = 594,
    //DDR AXI Parameters 
    parameter DDR_ID_WIDTH               = 4,
    parameter DDR_ADDR_WIDTH             = 33, 
    parameter DDR_DATA_WIDTH             = 512,
    parameter DDR_STRB_WIDTH             = DDR_DATA_WIDTH/8,
    
    parameter DDR_RNG_TIMER_BASEADDR     = 33'h130000000,
    parameter DDR_RNG_TP_BASEADDR        = 33'h132000000,

    // Width of control register interface addr in bits
    parameter CSR_ADDR_WIDTH = 16,
    // Width of control register interface data in bits
    parameter CSR_DATA_WIDTH = 32,
    // Width of control register interface strb
    parameter CSR_STRB_WIDTH = (CSR_DATA_WIDTH/8),
    // multi queue top register offset

    parameter S_COUNT = 2,
    parameter M_COUNT = 1
) (
	input  wire clk,
	input  wire rst,

	//axis input
	input  wire [TASK_REQ_WIDTH-1:0] 					m_sp_task_req,
	input  wire 									    m_sp_valid,
	output wire 									    m_sp_ready,

	//axis output
	output wire [AXIS_DATA_WIDTH-1:0] 					m_axis_tdata,
	output wire [AXIS_KEEP_WIDTH-1:0] 					m_axis_tkeep,
	output wire 									    m_axis_tvalid,
	input  wire 									    m_axis_tready,
	output wire 									    m_axis_tlast,
	output wire [AXIS_USER_WIDTH-1:0] 			        m_axis_tuser,

    //AXI-MM-p0
    output  wire [DDR_ID_WIDTH-1:0]                     m_axi_arid,
    output  wire [DDR_ADDR_WIDTH-1:0]                   m_axi_araddr,
    output  wire [7:0]                                  m_axi_arlen,
    output  wire [2:0]                                  m_axi_arsize,
    output  wire [1:0]                                  m_axi_arburst,
    output  wire                                        m_axi_arlock,
    output  wire [3:0]                                  m_axi_arcache,
    output  wire [2:0]                                  m_axi_arprot,
    output  wire [3:0]                                  m_axi_arqos,
    output  wire                                        m_axi_arvalid,
    input   wire                                        m_axi_arready,
    input   wire [DDR_ID_WIDTH-1:0]                     m_axi_rid,
    input   wire [DDR_DATA_WIDTH-1:0]                   m_axi_rdata,
    input   wire [1:0]                                  m_axi_rresp,
    input   wire                                        m_axi_rlast,
    input   wire                                        m_axi_rvalid,
    output  wire                                        m_axi_rready,
    output  wire [DDR_ID_WIDTH-1:0]                     m_axi_awid,
    output  wire [DDR_ADDR_WIDTH-1:0]                   m_axi_awaddr,
    output  wire [7:0]                                  m_axi_awlen,
    output  wire [2:0]                                  m_axi_awsize,
    output  wire [1:0]                                  m_axi_awburst,
    output  wire                                        m_axi_awlock,
    output  wire [3:0]                                  m_axi_awcache,
    output  wire [2:0]                                  m_axi_awprot,
    output  wire [3:0]                                  m_axi_awqos,
    output  wire                                        m_axi_awvalid,
    input   wire                                        m_axi_awready,
    output  wire [DDR_DATA_WIDTH-1:0]                   m_axi_wdata,
    output  wire [DDR_STRB_WIDTH-1:0]                   m_axi_wstrb,
    output  wire                                        m_axi_wlast,
    output  wire                                        m_axi_wvalid,
    input   wire                                        m_axi_wready,
    input   wire [DDR_ID_WIDTH-1:0]                     m_axi_bid,
    input   wire [1:0]                                  m_axi_bresp,
    input   wire                                        m_axi_bvalid,
    output  wire                                        m_axi_bready,

    // connect to dfx port
    input  wire [31:0]                                  dfx_cfg0        ,
    input  wire [31:0]                                  dfx_cfg1        ,
    input  wire [31:0]                                  dfx_cfg2        ,
    input  wire [31:0]                                  dfx_cfg3        ,
    output wire [31:0]                                  dfx_sta_0x00    ,
    output wire [31:0]                                  dfx_sta_0x01    ,
    output wire [31:0]                                  dfx_sta_0x02    ,
    output wire [31:0]                                  dfx_sta_0x03    ,
    output wire [31:0]                                  dfx_sta_0x04    ,
    output wire [31:0]                                  dfx_sta_0x05    ,
    output wire [31:0]                                  dfx_sta_0x06    ,
    output wire [31:0]                                  dfx_sta_0x07    ,
    output wire [31:0]                                  dfx_sta_0x08    ,
    output wire [31:0]                                  dfx_sta_0x09    ,
    output wire [31:0]                                  dfx_sta_0x0a    ,
    output wire [31:0]                                  dfx_sta_0x0b    ,
    output wire [31:0]                                  dfx_sta_0x0c    ,
    output wire [31:0]                                  dfx_sta_0x0e    ,
    output wire [31:0]                                  dfx_sta_0x0d    ,
    output wire [31:0]                                  dfx_sta_0x0f    ,
    output wire [31:0]                                  dfx_sta_0x10    ,
    output wire [31:0]                                  dfx_sta_0x11    ,
    output wire [31:0]                                  dfx_sta_0x12    ,
    output wire [31:0]                                  dfx_sta_0x13    ,
    // CSR TODO
    input  wire [CSR_ADDR_WIDTH-1:0]                    csr_wr_addr,
    input  wire [CSR_DATA_WIDTH-1:0]                    csr_wr_data,
    input  wire [CSR_STRB_WIDTH-1:0]                    csr_wr_strb,
    input  wire                                         csr_wr_en,
    output wire                                         csr_wr_wait,
    output wire                                         csr_wr_ack,

    input  wire [CSR_ADDR_WIDTH-1:0]                    csr_rd_addr,
    input  wire                                         csr_rd_en,
    output wire [CSR_DATA_WIDTH-1:0]                    csr_rd_data,
    output wire                                         csr_rd_wait,
    output wire                                         csr_rd_ack
);

wire [DDR_ID_WIDTH-1:0]                     m00_axi_arid;
wire [DDR_ADDR_WIDTH-1:0]                   m00_axi_araddr;
wire [7:0]                                  m00_axi_arlen;
wire [2:0]                                  m00_axi_arsize;
wire [1:0]                                  m00_axi_arburst;
wire                                        m00_axi_arlock;
wire [3:0]                                  m00_axi_arcache;
wire [2:0]                                  m00_axi_arprot;
wire [3:0]                                  m00_axi_arqos;
wire                                        m00_axi_arvalid;
wire                                        m00_axi_arready;
wire [DDR_ID_WIDTH-1:0]                     m00_axi_rid;
wire [DDR_DATA_WIDTH-1:0]                   m00_axi_rdata;
wire [1:0]                                  m00_axi_rresp;
wire                                        m00_axi_rlast;
wire                                        m00_axi_rvalid;
wire                                        m00_axi_rready;
wire [DDR_ID_WIDTH-1:0]                     m00_axi_awid;
wire [DDR_ADDR_WIDTH-1:0]                   m00_axi_awaddr;
wire [7:0]                                  m00_axi_awlen;
wire [2:0]                                  m00_axi_awsize;
wire [1:0]                                  m00_axi_awburst;
wire                                        m00_axi_awlock;
wire [3:0]                                  m00_axi_awcache;
wire [2:0]                                  m00_axi_awprot;
wire [3:0]                                  m00_axi_awqos;
wire                                        m00_axi_awvalid;
wire                                        m00_axi_awready;
wire [DDR_DATA_WIDTH-1:0]                   m00_axi_wdata;
wire [DDR_STRB_WIDTH-1:0]                   m00_axi_wstrb;
wire                                        m00_axi_wlast;
wire                                        m00_axi_wvalid;
wire                                        m00_axi_wready;
wire [DDR_ID_WIDTH-1:0]                     m00_axi_bid;
wire [1:0]                                  m00_axi_bresp;
wire                                        m00_axi_bvalid;
wire                                        m00_axi_bready;

wire [DDR_ID_WIDTH-1:0]                     m01_axi_arid;
wire [DDR_ADDR_WIDTH-1:0]                   m01_axi_araddr;
wire [7:0]                                  m01_axi_arlen;
wire [2:0]                                  m01_axi_arsize;
wire [1:0]                                  m01_axi_arburst;
wire                                        m01_axi_arlock;
wire [3:0]                                  m01_axi_arcache;
wire [2:0]                                  m01_axi_arprot;
wire [3:0]                                  m01_axi_arqos;
wire                                        m01_axi_arvalid;
wire                                        m01_axi_arready;
wire [DDR_ID_WIDTH-1:0]                     m01_axi_rid;
wire [DDR_DATA_WIDTH-1:0]                   m01_axi_rdata;
wire [1:0]                                  m01_axi_rresp;
wire                                        m01_axi_rlast;
wire                                        m01_axi_rvalid;
wire                                        m01_axi_rready;
wire [DDR_ID_WIDTH-1:0]                     m01_axi_awid;
wire [DDR_ADDR_WIDTH-1:0]                   m01_axi_awaddr;
wire [7:0]                                  m01_axi_awlen;
wire [2:0]                                  m01_axi_awsize;
wire [1:0]                                  m01_axi_awburst;
wire                                        m01_axi_awlock;
wire [3:0]                                  m01_axi_awcache;
wire [2:0]                                  m01_axi_awprot;
wire [3:0]                                  m01_axi_awqos;
wire                                        m01_axi_awvalid;
wire                                        m01_axi_awready;
wire [DDR_DATA_WIDTH-1:0]                   m01_axi_wdata;
wire [DDR_STRB_WIDTH-1:0]                   m01_axi_wstrb;
wire                                        m01_axi_wlast;
wire                                        m01_axi_wvalid;
wire                                        m01_axi_wready;
wire [DDR_ID_WIDTH-1:0]                     m01_axi_bid;
wire [1:0]                                  m01_axi_bresp;
wire                                        m01_axi_bvalid;
wire                                        m01_axi_bready;

reli_nack_generator_top #(
            .AXIS_DATA_WIDTH            (AXIS_DATA_WIDTH),
            .AXIS_USER_WIDTH            (AXIS_USER_WIDTH),

            .MAIN_CLK                   (MAIN_CLK),

            .STREAM_NUM                 (2048),
            .TASK_REQ_WIDTH             (TASK_REQ_WIDTH),

            .DDR_RNG_TIMER_BASEADDR     (DDR_RNG_TIMER_BASEADDR),
            .DDR_RNG_TP_BASEADDR        (DDR_RNG_TP_BASEADDR),

            .DDR_ID_WIDTH               (DDR_ID_WIDTH),
            .DDR_ADDR_WIDTH             (DDR_ADDR_WIDTH),
            .DDR_DATA_WIDTH             (DDR_DATA_WIDTH)
        ) reli_nack_generator_top_inst (
            .clk                        (clk),
            .rst                        (rst),
        
            //axis input
            .m_sp_task_req              (m_sp_task_req),
            .m_sp_valid                 (m_sp_valid),
            .m_sp_ready                 (m_sp_ready),
        
            .m_axis_tdata               (m_axis_tdata),
            .m_axis_tkeep               (m_axis_tkeep),
            .m_axis_tvalid              (m_axis_tvalid),
            .m_axis_tready              (m_axis_tready),
            .m_axis_tlast               (m_axis_tlast),
            .m_axis_tuser               (m_axis_tuser),
        
            //AXI-MM-p0
            .m00_axi_arid               (m00_axi_arid),
            .m00_axi_araddr             (m00_axi_araddr),
            .m00_axi_arlen              (m00_axi_arlen),
            .m00_axi_arsize             (m00_axi_arsize),
            .m00_axi_arburst            (m00_axi_arburst),
            .m00_axi_arlock             (m00_axi_arlock),
            .m00_axi_arcache            (m00_axi_arcache),
            .m00_axi_arprot             (m00_axi_arprot),
            .m00_axi_arvalid            (m00_axi_arvalid),
            .m00_axi_arready            (m00_axi_arready),
            .m00_axi_rid                (m00_axi_rid),
            .m00_axi_rdata              (m00_axi_rdata),
            .m00_axi_rresp              (m00_axi_rresp),
            .m00_axi_rlast              (m00_axi_rlast),
            .m00_axi_rvalid             (m00_axi_rvalid),
            .m00_axi_rready             (m00_axi_rready),
            // ddr4 write
            .m00_axi_awid               (m00_axi_awid),
            .m00_axi_awaddr             (m00_axi_awaddr),
            .m00_axi_awlen              (m00_axi_awlen),
            .m00_axi_awsize             (m00_axi_awsize),
            .m00_axi_awburst            (m00_axi_awburst),
            .m00_axi_awlock             (m00_axi_awlock),
            .m00_axi_awcache            (m00_axi_awcache),
            .m00_axi_awprot             (m00_axi_awprot),
            .m00_axi_awvalid            (m00_axi_awvalid),
            .m00_axi_awready            (m00_axi_awready),
            .m00_axi_wdata              (m00_axi_wdata),
            .m00_axi_wstrb              (m00_axi_wstrb),
            .m00_axi_wlast              (m00_axi_wlast),
            .m00_axi_wvalid             (m00_axi_wvalid),
            .m00_axi_wready             (m00_axi_wready),
            .m00_axi_bid                (m00_axi_bid),
            .m00_axi_bresp              (m00_axi_bresp),
            .m00_axi_bvalid             (m00_axi_bvalid),
            .m00_axi_bready             (m00_axi_bready),

            //AXI-MM-p1
            .m01_axi_arid               (m01_axi_arid),
            .m01_axi_araddr             (m01_axi_araddr),
            .m01_axi_arlen              (m01_axi_arlen),
            .m01_axi_arsize             (m01_axi_arsize),
            .m01_axi_arburst            (m01_axi_arburst),
            .m01_axi_arlock             (m01_axi_arlock),
            .m01_axi_arcache            (m01_axi_arcache),
            .m01_axi_arprot             (m01_axi_arprot),
            .m01_axi_arvalid            (m01_axi_arvalid),
            .m01_axi_arready            (m01_axi_arready),
            .m01_axi_rid                (m01_axi_rid),
            .m01_axi_rdata              (m01_axi_rdata),
            .m01_axi_rresp              (m01_axi_rresp),
            .m01_axi_rlast              (m01_axi_rlast),
            .m01_axi_rvalid             (m01_axi_rvalid),
            .m01_axi_rready             (m01_axi_rready),
            // ddr4 write
            .m01_axi_awid               (m01_axi_awid),
            .m01_axi_awaddr             (m01_axi_awaddr),
            .m01_axi_awlen              (m01_axi_awlen),
            .m01_axi_awsize             (m01_axi_awsize),
            .m01_axi_awburst            (m01_axi_awburst),
            .m01_axi_awlock             (m01_axi_awlock),
            .m01_axi_awcache            (m01_axi_awcache),
            .m01_axi_awprot             (m01_axi_awprot),
            .m01_axi_awvalid            (m01_axi_awvalid),
            .m01_axi_awready            (m01_axi_awready),
            .m01_axi_wdata              (m01_axi_wdata),
            .m01_axi_wstrb              (m01_axi_wstrb),
            .m01_axi_wlast              (m01_axi_wlast),
            .m01_axi_wvalid             (m01_axi_wvalid),
            .m01_axi_wready             (m01_axi_wready),
            .m01_axi_bid                (m01_axi_bid),
            .m01_axi_bresp              (m01_axi_bresp),
            .m01_axi_bvalid             (m01_axi_bvalid),
            .m01_axi_bready             (m01_axi_bready),

            .dfx_cfg0                   (dfx_cfg0),
            .dfx_cfg1                   (dfx_cfg1),
            .dfx_cfg2                   (dfx_cfg2),
            .dfx_cfg3                   (dfx_cfg3),

            .csr_wr_addr                (csr_wr_addr),
            .csr_wr_data                (csr_wr_data),
            .csr_wr_strb                (csr_wr_strb),
            .csr_wr_en                  (csr_wr_en  ),
            .csr_wr_wait                (csr_wr_wait),
            .csr_wr_ack                 (csr_wr_ack ),
            .csr_rd_addr                (csr_rd_addr),
            .csr_rd_en                  (csr_rd_en  ),
            .csr_rd_data                (csr_rd_data),
            .csr_rd_wait                (csr_rd_wait),
            .csr_rd_ack                 (csr_rd_ack )
        );

wire [S_COUNT*DDR_ID_WIDTH-1:0]     s_axi_awid;
wire [S_COUNT*DDR_ADDR_WIDTH-1:0]   s_axi_awaddr;
wire [S_COUNT*8-1:0]                s_axi_awlen;
wire [S_COUNT*3-1:0]                s_axi_awsize;
wire [S_COUNT*2-1:0]                s_axi_awburst;
wire [S_COUNT-1:0]                  s_axi_awlock;
wire [S_COUNT*4-1:0]                s_axi_awcache;
wire [S_COUNT*3-1:0]                s_axi_awprot;
wire [S_COUNT*4-1:0]                s_axi_awqos;
wire [S_COUNT-1:0]                  s_axi_awvalid;
wire [S_COUNT-1:0]                  s_axi_awready;
wire [S_COUNT*DDR_DATA_WIDTH-1:0]   s_axi_wdata;
wire [S_COUNT*DDR_STRB_WIDTH-1:0]   s_axi_wstrb;
wire [S_COUNT-1:0]                  s_axi_wlast;
wire [S_COUNT-1:0]                  s_axi_wvalid;
wire [S_COUNT-1:0]                  s_axi_wready;
wire [S_COUNT*DDR_ID_WIDTH-1:0]     s_axi_bid;
wire [S_COUNT*2-1:0]                s_axi_bresp;
wire [S_COUNT-1:0]                  s_axi_bvalid;
wire [S_COUNT-1:0]                  s_axi_bready;
wire [S_COUNT*DDR_ID_WIDTH-1:0]     s_axi_arid;
wire [S_COUNT*DDR_ADDR_WIDTH-1:0]   s_axi_araddr;
wire [S_COUNT*8-1:0]                s_axi_arlen;
wire [S_COUNT*3-1:0]                s_axi_arsize;
wire [S_COUNT*2-1:0]                s_axi_arburst;
wire [S_COUNT-1:0]                  s_axi_arlock;
wire [S_COUNT*4-1:0]                s_axi_arcache;
wire [S_COUNT*3-1:0]                s_axi_arprot;
wire [S_COUNT*4-1:0]                s_axi_arqos;
wire [S_COUNT-1:0]                  s_axi_arvalid;
wire [S_COUNT-1:0]                  s_axi_arready;
wire [S_COUNT*DDR_ID_WIDTH-1:0]     s_axi_rid;
wire [S_COUNT*DDR_DATA_WIDTH-1:0]   s_axi_rdata;
wire [S_COUNT*2-1:0]                s_axi_rresp;
wire [S_COUNT-1:0]                  s_axi_rlast;
wire [S_COUNT-1:0]                  s_axi_rvalid;
wire [S_COUNT-1:0]                  s_axi_rready;
                                 
assign s_axi_awid = {m01_axi_awid , m00_axi_awid};
assign s_axi_awaddr = {m01_axi_awaddr , m00_axi_awaddr};
assign s_axi_awlen = {m01_axi_awlen , m00_axi_awlen};
assign s_axi_awsize = {m01_axi_awsize , m00_axi_awsize};
assign s_axi_awburst = {m01_axi_awburst , m00_axi_awburst};
assign s_axi_awlock = {m01_axi_awlock , m00_axi_awlock};
assign s_axi_awcache = {m01_axi_awcache , m00_axi_awcache};
assign s_axi_awprot = {m01_axi_awprot , m00_axi_awprot};
assign s_axi_awqos = {4'd0 , 4'd0};
assign s_axi_awvalid = {m01_axi_awvalid , m00_axi_awvalid};
assign {m01_axi_awready , m00_axi_awready} = s_axi_awready;
assign s_axi_wdata = {m01_axi_wdata , m00_axi_wdata};
assign s_axi_wstrb = {m01_axi_wstrb , m00_axi_wstrb};
assign s_axi_wlast = {m01_axi_wlast , m00_axi_wlast};
assign s_axi_wvalid = {m01_axi_wvalid , m00_axi_wvalid};
assign {m01_axi_wready , m00_axi_wready} = s_axi_wready;
assign {m01_axi_bid , m00_axi_bid} = s_axi_bid;
assign {m01_axi_bresp , m00_axi_bresp} = s_axi_bresp;
assign {m01_axi_bvalid , m00_axi_bvalid} = s_axi_bvalid;
assign s_axi_bready = {m01_axi_bready , m00_axi_bready};
assign s_axi_arid = {m01_axi_arid , m00_axi_arid};
assign s_axi_araddr = {m01_axi_araddr , m00_axi_araddr};
assign s_axi_arlen = {m01_axi_arlen , m00_axi_arlen};
assign s_axi_arsize = {m01_axi_arsize , m00_axi_arsize};
assign s_axi_arburst = {m01_axi_arburst , m00_axi_arburst};
assign s_axi_arlock = {m01_axi_arlock , m00_axi_arlock};
assign s_axi_arcache = {m01_axi_arcache , m00_axi_arcache};
assign s_axi_arprot = {m01_axi_arprot , m00_axi_arprot};
assign s_axi_arqos = {4'd0 , 4'd0};
assign s_axi_arvalid = {m01_axi_arvalid , m00_axi_arvalid};
assign {m01_axi_arready , m00_axi_arready} = s_axi_arready;
assign {m01_axi_rid , m00_axi_rid} = s_axi_rid;
assign {m01_axi_rdata , m00_axi_rdata} = s_axi_rdata;
assign {m01_axi_rresp , m00_axi_rresp} = s_axi_rresp;
assign {m01_axi_rlast , m00_axi_rlast} = s_axi_rlast;
assign {m01_axi_rvalid , m00_axi_rvalid} = s_axi_rvalid;
assign s_axi_rready = {m01_axi_rready , m00_axi_rready};

axi_interconnect #(
    .S_COUNT(2),
    .M_COUNT(1),
    .DATA_WIDTH(DDR_DATA_WIDTH),
    .ADDR_WIDTH(DDR_ADDR_WIDTH),
    .STRB_WIDTH(DDR_STRB_WIDTH),
    .ID_WIDTH(DDR_ID_WIDTH),

    // .AWUSER_ENABLE(0),
    // .AWUSER_WIDTH(0),
    // .WUSER_ENABLE(0),
    // .WUSER_WIDTH(0),
    // .BUSER_ENABLE(0),
    // .BUSER_WIDTH(0),
    // .ARUSER_ENABLE(0),
    // .ARUSER_WIDTH(0),
    // .RUSER_ENABLE(0),
    // .RUSER_WIDTH(0),

    // .FORWARD_ID(FORWARD_ID),
    .M_REGIONS(2),
    // .M_BASE_ADDR(M_BASE_ADDR),
    .M_ADDR_WIDTH({2{32'd32}})
    // .M_CONNECT_READ(M_CONNECT_READ),
    // .M_CONNECT_WRITE(M_CONNECT_WRITE),
    // .M_SECURE(0)
)
UUT (
    .clk(clk),
    .rst(rst),
    .s_axi_awid(s_axi_awid),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awlen(s_axi_awlen),
    .s_axi_awsize(s_axi_awsize),
    .s_axi_awburst(s_axi_awburst),
    .s_axi_awlock(s_axi_awlock),
    .s_axi_awcache(s_axi_awcache),
    .s_axi_awprot(s_axi_awprot),
    // .s_axi_awqos(0),//
    // .s_axi_awuser(0),//
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),
    // .s_axi_wuser(0),//
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bid(s_axi_bid),
    .s_axi_bresp(s_axi_bresp),
    // .s_axi_buser(0),//
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_arid(s_axi_arid),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arlen(s_axi_arlen),
    .s_axi_arsize(s_axi_arsize),
    .s_axi_arburst(s_axi_arburst),
    .s_axi_arlock(s_axi_arlock),
    .s_axi_arcache(s_axi_arcache),
    .s_axi_arprot(s_axi_arprot),
    // .s_axi_arqos(0),//
    // .s_axi_aruser(0),//
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rid(s_axi_rid),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rlast(s_axi_rlast),
    // .s_axi_ruser(0),//
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),

    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awlock(m_axi_awlock),
    .m_axi_awcache(m_axi_awcache),
    .m_axi_awprot(m_axi_awprot),
    // .m_axi_awqos(0),//
    // .m_axi_awregion(0),//
    // .m_axi_awuser(0),//
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    // .m_axi_wuser(0),//
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bid(m_axi_bid),
    .m_axi_bresp(m_axi_bresp),
    // .m_axi_buser(0),//
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready),
    .m_axi_arid(m_axi_arid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arlock(m_axi_arlock),
    .m_axi_arcache(m_axi_arcache),
    .m_axi_arprot(m_axi_arprot),
    .m_axi_arqos(m_axi_arqos),
    // .m_axi_arregion(0),//
    // .m_axi_aruser(0),//
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    // .m_axi_ruser(0),//
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready)
);

endmodule