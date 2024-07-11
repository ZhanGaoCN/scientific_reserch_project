/*
 * Created on 20231103
 *
 *
 * @Filename:	 reli_nack_generator_top.v
 * @Author:		 songmg
 * @Last edit:	 
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

module reli_nack_generator_top #(
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
    parameter CSR_STRB_WIDTH = (CSR_DATA_WIDTH/8)  
    // multi queue top register offset
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
    output  wire [DDR_ID_WIDTH-1:0]                     m00_axi_arid,
    output  wire [DDR_ADDR_WIDTH-1:0]                   m00_axi_araddr,
    output  wire [7:0]                                  m00_axi_arlen,
    output  wire [2:0]                                  m00_axi_arsize,
    output  wire [1:0]                                  m00_axi_arburst,
    output  wire                                        m00_axi_arlock,
    output  wire [3:0]                                  m00_axi_arcache,
    output  wire [2:0]                                  m00_axi_arprot,
    output  wire [3:0]                                  m00_axi_arqos,
    output  wire                                        m00_axi_arvalid,
    input   wire                                        m00_axi_arready,
    input   wire [DDR_ID_WIDTH-1:0]                     m00_axi_rid,
    input   wire [DDR_DATA_WIDTH-1:0]                   m00_axi_rdata,
    input   wire [1:0]                                  m00_axi_rresp,
    input   wire                                        m00_axi_rlast,
    input   wire                                        m00_axi_rvalid,
    output  wire                                        m00_axi_rready,
    output  wire [DDR_ID_WIDTH-1:0]                     m00_axi_awid,
    output  wire [DDR_ADDR_WIDTH-1:0]                   m00_axi_awaddr,
    output  wire [7:0]                                  m00_axi_awlen,
    output  wire [2:0]                                  m00_axi_awsize,
    output  wire [1:0]                                  m00_axi_awburst,
    output  wire                                        m00_axi_awlock,
    output  wire [3:0]                                  m00_axi_awcache,
    output  wire [2:0]                                  m00_axi_awprot,
    output  wire [3:0]                                  m00_axi_awqos,
    output  wire                                        m00_axi_awvalid,
    input   wire                                        m00_axi_awready,
    output  wire [DDR_DATA_WIDTH-1:0]                   m00_axi_wdata,
    output  wire [DDR_STRB_WIDTH-1:0]                   m00_axi_wstrb,
    output  wire                                        m00_axi_wlast,
    output  wire                                        m00_axi_wvalid,
    input   wire                                        m00_axi_wready,
    input   wire [DDR_ID_WIDTH-1:0]                     m00_axi_bid,
    input   wire [1:0]                                  m00_axi_bresp,
    input   wire                                        m00_axi_bvalid,
    output  wire                                        m00_axi_bready,
    //AXI-MM-p1
    output  wire [DDR_ID_WIDTH-1:0]                     m01_axi_arid,
    output  wire [DDR_ADDR_WIDTH-1:0]                   m01_axi_araddr,
    output  wire [7:0]                                  m01_axi_arlen,
    output  wire [2:0]                                  m01_axi_arsize,
    output  wire [1:0]                                  m01_axi_arburst,
    output  wire                                        m01_axi_arlock,
    output  wire [3:0]                                  m01_axi_arcache,
    output  wire [2:0]                                  m01_axi_arprot,
    output  wire [3:0]                                  m01_axi_arqos,
    output  wire                                        m01_axi_arvalid,
    input   wire                                        m01_axi_arready,
    input   wire [DDR_ID_WIDTH-1:0]                     m01_axi_rid,
    input   wire [DDR_DATA_WIDTH-1:0]                   m01_axi_rdata,
    input   wire [1:0]                                  m01_axi_rresp,
    input   wire                                        m01_axi_rlast,
    input   wire                                        m01_axi_rvalid,
    output  wire                                        m01_axi_rready,
    output  wire [DDR_ID_WIDTH-1:0]                     m01_axi_awid,
    output  wire [DDR_ADDR_WIDTH-1:0]                   m01_axi_awaddr,
    output  wire [7:0]                                  m01_axi_awlen,
    output  wire [2:0]                                  m01_axi_awsize,
    output  wire [1:0]                                  m01_axi_awburst,
    output  wire                                        m01_axi_awlock,
    output  wire [3:0]                                  m01_axi_awcache,
    output  wire [2:0]                                  m01_axi_awprot,
    output  wire [3:0]                                  m01_axi_awqos,
    output  wire                                        m01_axi_awvalid,
    input   wire                                        m01_axi_awready,
    output  wire [DDR_DATA_WIDTH-1:0]                   m01_axi_wdata,
    output  wire [DDR_STRB_WIDTH-1:0]                   m01_axi_wstrb,
    output  wire                                        m01_axi_wlast,
    output  wire                                        m01_axi_wvalid,
    input   wire                                        m01_axi_wready,
    input   wire [DDR_ID_WIDTH-1:0]                     m01_axi_bid,
    input   wire [1:0]                                  m01_axi_bresp,
    input   wire                                        m01_axi_bvalid,
    output  wire                                        m01_axi_bready,
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
//------------------------------------------------------------
// <Parameter>
    localparam P_CLK_FHZ             = 300_000_000;//1s
    localparam P_1MS_COUNTER_VALUE   = P_CLK_FHZ/1000;//1ms
    localparam P_CLOCK_CYCTIME       = P_1MS_COUNTER_VALUE * 30;//30ms
//--------------------------------->>axi config<<------------------------------
//AXI4 parameter
    localparam AXI_ID_WIDTH      = 8                         ;
    localparam AXI_ADDR_WIDTH    = 32                        ;
    localparam AXI_DATA_WIDTH    = 512                       ;
    localparam AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8          ;
//AXIL parameter
    localparam AXIL_ADDR_WIDTH    = 64                       ;
    localparam AXIL_DATA_WIDTH    = 512                      ;
    localparam AXIL_STRB_WIDTH    = AXIL_ADDR_WIDTH/8        ;
    localparam S_INFO_WIDTH = 512   ;
    localparam INFO_WIDTH   = S_INFO_WIDTH;
    localparam NPN_WIDTH    = 32    ;
    localparam RPN_WIDTH    = NPN_WIDTH;
    localparam BITMAP_WIDTH = 64    ;
    localparam NACK_GEN_RQ_WIDTH = S_INFO_WIDTH+NPN_WIDTH+BITMAP_WIDTH;
//------------------------------------------------------------
// <Define>
    wire    [NACK_GEN_RQ_WIDTH-1:0]     axis_nack_gen_rq_fifo       ;
    wire                                axis_nack_gen_rq_valid_fifo ;
    wire                                axis_nack_gen_rq_ready_fifo ;
    wire    [NACK_GEN_RQ_WIDTH-1:0]     axis_nack_gen_rq            ;
    wire                                axis_nack_gen_rq_valid      ;
    wire                                axis_nack_gen_rq_ready      ;
    wire    [511:0]                     net_s_info  ;
    wire    [15:0]                      net_s_id    ;
    wire    [95:0]                      net_key_msg ;
    wire    [1:0]                       net_type    ;
    wire                                net_valid   ;
    wire                                net_ready   ;
    wire    [15:0]                      in_flow_index   ;
    wire    [7:0]                       in_tpye_onehot  ;
    wire    [31:0]                      in_rpn          ;
    wire    [63:0]                      in_exp_rpn      ;
    wire    [511:0]                     in_s_info       ;
    wire    [INFO_WIDTH-1:0]            nack_s_info        ;
    wire    [BITMAP_WIDTH-1:0]          nack_bitmap        ;
    wire    [RPN_WIDTH-1:0]             nack_npn           ;
    wire                                nack_valid         ;
    wire                                nack_ready         ;
    wire    [INFO_WIDTH-1:0]            s_nack_gen_info    ;
    wire    [BITMAP_WIDTH-1:0]          s_nack_gen_bitmap  ;
    wire    [RPN_WIDTH-1:0]             s_nack_gen_init_npn;
    wire                                s_nack_gen_valid   ;
    wire                                s_nack_gen_ready   ;
//------------------------------------------------------------
// <net assign>
    assign {
        in_s_info           ,
        in_exp_rpn          ,
        in_rpn              ,
        in_tpye_onehot      ,
        in_flow_index       
    }=m_sp_task_req;
    assign net_s_info   = in_s_info;
    assign net_s_id     = in_flow_index;
    assign net_key_msg  = {in_exp_rpn,in_rpn};
    assign net_type     = 
                in_tpye_onehot[0] ? 2'b01 :
                in_tpye_onehot[1] ? 2'b10 :
                in_tpye_onehot[2] ? 2'b11 : 2'b00;
    assign net_valid    = m_sp_valid    ;
    assign m_sp_ready   = net_ready     ;
    assign axis_nack_gen_rq_fifo = {
        nack_s_info,
        nack_npn   ,
        nack_bitmap 
    };
    assign axis_nack_gen_rq_valid_fifo = nack_valid;
    assign nack_ready = axis_nack_gen_rq_ready;
    assign {s_nack_gen_info       ,    
            s_nack_gen_init_npn   ,
            s_nack_gen_bitmap       }=axis_nack_gen_rq;
    assign s_nack_gen_valid = axis_nack_gen_rq_valid;
    assign axis_nack_gen_rq_ready = s_nack_gen_ready;
//------------------------------------------------------------
// <inst seanetnackgenerator_top_v0p1>
    wire    [AXI_ADDR_WIDTH-1:0]    m00_axi_araddr_x32bit;
    wire    [AXI_ADDR_WIDTH-1:0]    m00_axi_awaddr_x32bit;
    wire    [AXI_ADDR_WIDTH-1:0]    m01_axi_araddr_x32bit;
    wire    [AXI_ADDR_WIDTH-1:0]    m01_axi_awaddr_x32bit;
    localparam [31:0] BITMAP_BASE_ADDR = DDR_RNG_TP_BASEADDR & 32'hFFFF_FFFF;
    localparam [31:0] TIMER_BASE_ADDR  = DDR_RNG_TIMER_BASEADDR & 32'hFFFF_FFFF;
    assign m00_axi_araddr = {1'b1,m00_axi_araddr_x32bit};
    assign m00_axi_awaddr = {1'b1,m00_axi_awaddr_x32bit};
    assign m01_axi_araddr = {1'b1,m01_axi_araddr_x32bit};
    assign m01_axi_awaddr = {1'b1,m01_axi_awaddr_x32bit};
    seanetnackgenerator_top_v0p1 #(
        .P_CLK_FHZ             (P_CLK_FHZ             ),//1s
        .P_1MS_COUNTER_VALUE   (P_1MS_COUNTER_VALUE   ),//1ms
        .P_CLOCK_CYCTIME       (P_CLOCK_CYCTIME       ),//30ms
        .INIT_JUMP_THRESH      (INIT_JUMP_THRESH      ),
        .MAX_WND_SIZE          (MAX_WND_SIZE          ),
        .BITMAP_BASE_ADDR      (BITMAP_BASE_ADDR      ),
        .TIMER_BASE_ADDR       (TIMER_BASE_ADDR       ),
        //--------------------------------->>axi config<<------------------------------
        //AXI4 parameter
        .AXI_ID_WIDTH       (AXI_ID_WIDTH       ),
        .AXI_ADDR_WIDTH     (AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH     (AXI_DATA_WIDTH     ),
        .AXI_STRB_WIDTH     (AXI_STRB_WIDTH     ),
        //AXIL parameter
        .AXIL_ADDR_WIDTH    (AXIL_ADDR_WIDTH    ),
        .AXIL_DATA_WIDTH    (AXIL_DATA_WIDTH    ),
        .AXIL_STRB_WIDTH    (AXIL_STRB_WIDTH    ) 
    )seanetnackgenerator_top_v0p1_dut(
        .sys_clk            (clk                ),//input   wire                                        
        .sys_rst            (rst                ),//input   wire                                        
        // connect to upstream port
        .i_s_info           (net_s_info         ),//input   wire     [511:0]                            
        .i_s_id             (net_s_id           ),//input   wire     [15:0]                             
        .i_key_msg          (net_key_msg        ),//input   wire     [95:0]                             
        .i_type             (net_type           ),//input   wire     [1:0]                              
        .i_valid            (net_valid          ),//input   wire                                        
        .o_ready            (net_ready          ),//output  wire                                        
        // connect to dnstream port
        .o_nack_s_info      (nack_s_info        ),//output  wire    [511:0]                             
        .o_nack_bitmap      (nack_bitmap        ),//output  wire    [63:0]                              
        .o_nack_npn         (nack_npn           ),//output  wire    [31:0]                              
        .o_nack_valid       (nack_valid         ),//output  wire                                        
        .i_nack_ready       (nack_ready         ),//input   wire                                        
        // connect to DDR MIG p0(AXI4-MM)
        .m00_axi_awid         (m00_axi_awid     ),//output wire [AXI_ID_WIDTH-1:0]                      
        .m00_axi_awaddr       (m00_axi_awaddr_x32bit   ),//output wire [AXI_ADDR_WIDTH-1:0]                    
        .m00_axi_awlen        (m00_axi_awlen    ),//output wire [7:0]                                   
        .m00_axi_awsize       (m00_axi_awsize   ),//output wire [2:0]                                   
        .m00_axi_awburst      (m00_axi_awburst  ),//output wire [1:0]                                       
        .m00_axi_awlock       (m00_axi_awlock   ),//output wire                                         
        .m00_axi_awcache      (m00_axi_awcache  ),//output wire [3:0]                                       
        .m00_axi_awprot       (m00_axi_awprot   ),//output wire [2:0]                                   
        .m00_axi_awqos        (m00_axi_awqos    ),//output wire [3:0]                                   
        .m00_axi_awvalid      (m00_axi_awvalid  ),//output wire                                             
        .m00_axi_awready      (m00_axi_awready  ),//input  wire                                             
        .m00_axi_wdata        (m00_axi_wdata    ),//output wire [AXI_DATA_WIDTH-1:0]                    
        .m00_axi_wstrb        (m00_axi_wstrb    ),//output wire [AXI_STRB_WIDTH-1:0]                    
        .m00_axi_wlast        (m00_axi_wlast    ),//output wire                                         
        .m00_axi_wvalid       (m00_axi_wvalid   ),//output wire                                         
        .m00_axi_wready       (m00_axi_wready   ),//input  wire                                         
        .m00_axi_bid          (m00_axi_bid      ),//input  wire [AXI_ID_WIDTH-1:0]                      
        .m00_axi_bresp        (m00_axi_bresp    ),//input  wire [1:0]                                   
        .m00_axi_bvalid       (m00_axi_bvalid   ),//input  wire                                         
        .m00_axi_bready       (m00_axi_bready   ),//output wire                                         
        .m00_axi_arid         (m00_axi_arid     ),//output wire [AXI_ID_WIDTH-1:0]                      
        .m00_axi_araddr       (m00_axi_araddr_x32bit   ),//output wire [AXI_ADDR_WIDTH-1:0]                    
        .m00_axi_arlen        (m00_axi_arlen    ),//output wire [7:0]                                   
        .m00_axi_arsize       (m00_axi_arsize   ),//output wire [2:0]                                   
        .m00_axi_arburst      (m00_axi_arburst  ),//output wire [1:0]                                       
        .m00_axi_arlock       (m00_axi_arlock   ),//output wire                                         
        .m00_axi_arcache      (m00_axi_arcache  ),//output wire [3:0]                                       
        .m00_axi_arprot       (m00_axi_arprot   ),//output wire [2:0]                                   
        .m00_axi_arqos        (m00_axi_arqos    ),//output wire [3:0]                                   
        .m00_axi_arvalid      (m00_axi_arvalid  ),//output wire                                             
        .m00_axi_arready      (m00_axi_arready  ),//input  wire                                             
        .m00_axi_rid          (m00_axi_rid      ),//input  wire [AXI_ID_WIDTH-1:0]                      
        .m00_axi_rdata        (m00_axi_rdata    ),//input  wire [AXI_DATA_WIDTH-1:0]                    
        .m00_axi_rresp        (m00_axi_rresp    ),//input  wire [1:0]                                   
        .m00_axi_rlast        (m00_axi_rlast    ),//input  wire                                         
        .m00_axi_rvalid       (m00_axi_rvalid   ),//input  wire                                         
        .m00_axi_rready       (m00_axi_rready   ),//output wire                                         
        // connect to DDR MIG p1(AXI4-MM)
        .m01_axi_awid         (m01_axi_awid     ),//output wire [AXI_ID_WIDTH-1:0]                      
        .m01_axi_awaddr       (m01_axi_awaddr_x32bit   ),//output wire [AXI_ADDR_WIDTH-1:0]                    
        .m01_axi_awlen        (m01_axi_awlen    ),//output wire [7:0]                                   
        .m01_axi_awsize       (m01_axi_awsize   ),//output wire [2:0]                                   
        .m01_axi_awburst      (m01_axi_awburst  ),//output wire [1:0]                                       
        .m01_axi_awlock       (m01_axi_awlock   ),//output wire                                         
        .m01_axi_awcache      (m01_axi_awcache  ),//output wire [3:0]                                       
        .m01_axi_awprot       (m01_axi_awprot   ),//output wire [2:0]                                   
        .m01_axi_awqos        (m01_axi_awqos    ),//output wire [3:0]                                   
        .m01_axi_awvalid      (m01_axi_awvalid  ),//output wire                                             
        .m01_axi_awready      (m01_axi_awready  ),//input  wire                                             
        .m01_axi_wdata        (m01_axi_wdata    ),//output wire [AXI_DATA_WIDTH-1:0]                    
        .m01_axi_wstrb        (m01_axi_wstrb    ),//output wire [AXI_STRB_WIDTH-1:0]                    
        .m01_axi_wlast        (m01_axi_wlast    ),//output wire                                         
        .m01_axi_wvalid       (m01_axi_wvalid   ),//output wire                                         
        .m01_axi_wready       (m01_axi_wready   ),//input  wire                                         
        .m01_axi_bid          (m01_axi_bid      ),//input  wire [AXI_ID_WIDTH-1:0]                      
        .m01_axi_bresp        (m01_axi_bresp    ),//input  wire [1:0]                                   
        .m01_axi_bvalid       (m01_axi_bvalid   ),//input  wire                                         
        .m01_axi_bready       (m01_axi_bready   ),//output wire                                         
        .m01_axi_arid         (m01_axi_arid     ),//output wire [AXI_ID_WIDTH-1:0]                      
        .m01_axi_araddr       (m01_axi_araddr_x32bit   ),//output wire [AXI_ADDR_WIDTH-1:0]                    
        .m01_axi_arlen        (m01_axi_arlen    ),//output wire [7:0]                                   
        .m01_axi_arsize       (m01_axi_arsize   ),//output wire [2:0]                                   
        .m01_axi_arburst      (m01_axi_arburst  ),//output wire [1:0]                                       
        .m01_axi_arlock       (m01_axi_arlock   ),//output wire                                         
        .m01_axi_arcache      (m01_axi_arcache  ),//output wire [3:0]                                       
        .m01_axi_arprot       (m01_axi_arprot   ),//output wire [2:0]                                   
        .m01_axi_arqos        (m01_axi_arqos    ),//output wire [3:0]                                   
        .m01_axi_arvalid      (m01_axi_arvalid  ),//output wire                                             
        .m01_axi_arready      (m01_axi_arready  ),//input  wire                                             
        .m01_axi_rid          (m01_axi_rid      ),//input  wire [AXI_ID_WIDTH-1:0]                      
        .m01_axi_rdata        (m01_axi_rdata    ),//input  wire [AXI_DATA_WIDTH-1:0]                    
        .m01_axi_rresp        (m01_axi_rresp    ),//input  wire [1:0]                                   
        .m01_axi_rlast        (m01_axi_rlast    ),//input  wire                                         
        .m01_axi_rvalid       (m01_axi_rvalid   ),//input  wire                                         
        .m01_axi_rready       (m01_axi_rready   ),//output wire                                         
        // connect to CONFIG BUS (AXI-LITE)
        .s_axil_awaddr      (),//input  wire [AXIL_ADDR_WIDTH-1:0]                   
        .s_axil_awport      (),//input  wire [2:0]                                   
        .s_axil_awvalid     (),//input  wire                                         
        .s_axil_awready     (),//output wire                                         
        .s_axil_wdata       (),//input  wire [AXIL_DATA_WIDTH-1:0]                   
        .s_axil_wstrb       (),//input  wire [AXIL_STRB_WIDTH-1:0]                   
        .s_axil_wvalid      (),//input  wire                                         
        .s_axil_wready      (),//output wire                                         
        .s_axil_bresp       (),//output wire [1:0]                                   
        .s_axil_bvalid      (),//output wire                                         
        .s_axil_bready      (),//input  wire                                         
        .s_axil_araddr      (),//input  wire [AXIL_ADDR_WIDTH-1:0]                   
        .s_axil_arport      (),//input  wire [2:0]                                   
        .s_axil_arvalid     (),//input  wire                                         
        .s_axil_arready     (),//output wire                                         
        .s_axil_rdata       (),//input  wire [AXIL_DATA_WIDTH-1:0]                   
        .s_axil_rresp       (),//input  wire [1:0]                                   
        .s_axil_rvalid      (),//input  wire                                         
        .s_axil_rready      (),//output wire                                         
            // connect to dfx port
        .dfx_cfg0           (dfx_cfg0       ),//input  wire [31:0]                                  
        .dfx_cfg1           (dfx_cfg1       ),//input  wire [31:0]                                  
        .dfx_cfg2           (dfx_cfg2       ),//input  wire [31:0]                                  
        .dfx_cfg3           (dfx_cfg3       ),//input  wire [31:0]                                  
        .dfx_sta_0x00       (dfx_sta_0x00   ),//output wire [31:0]                                  
        .dfx_sta_0x01       (dfx_sta_0x01   ),//output wire [31:0]                                  
        .dfx_sta_0x02       (dfx_sta_0x02   ),//output wire [31:0]                                  
        .dfx_sta_0x03       (dfx_sta_0x03   ),//output wire [31:0]                                  
        .dfx_sta_0x04       (dfx_sta_0x04   ),//output wire [31:0]                                  
        .dfx_sta_0x05       (dfx_sta_0x05   ),//output wire [31:0]                                  
        .dfx_sta_0x06       (dfx_sta_0x06   ),//output wire [31:0]                                  
        .dfx_sta_0x07       (dfx_sta_0x07   ),//output wire [31:0]                                  
        .dfx_sta_0x08       (dfx_sta_0x08   ),//output wire [31:0]                                  
        .dfx_sta_0x09       (dfx_sta_0x09   ),//output wire [31:0]                                  
        .dfx_sta_0x0a       (dfx_sta_0x0a   ),//output wire [31:0]                                  
        .dfx_sta_0x0b       (dfx_sta_0x0b   ),//output wire [31:0]                                  
        .dfx_sta_0x0c       (dfx_sta_0x0c   ),//output wire [31:0]                                  
        .dfx_sta_0x0e       (dfx_sta_0x0e   ),//output wire [31:0]                                  
        .dfx_sta_0x0d       (dfx_sta_0x0d   ),//output wire [31:0]                                  
        .dfx_sta_0x0f       (dfx_sta_0x0f   ),//output wire [31:0]                                  
        .dfx_sta_0x10       (dfx_sta_0x10   ),//output wire [31:0]                                  
        .dfx_sta_0x11       (dfx_sta_0x11   ),//output wire [31:0]                                  
        .dfx_sta_0x12       (dfx_sta_0x12   ),//output wire [31:0]                                  
        .dfx_sta_0x13       (dfx_sta_0x13   ) //output wire [31:0]                                  
    );
//------------------------------------------------------------
// <inst axis_fifo>
    axis_fifo #(
        .DEPTH(512),
        .DATA_WIDTH(NACK_GEN_RQ_WIDTH),
        .KEEP_ENABLE(0),
        .LAST_ENABLE(0),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(0),
        .PIPELINE_OUTPUT(2),
        .FRAME_FIFO(0),
        .USER_BAD_FRAME_VALUE(1),
        .USER_BAD_FRAME_MASK(1),
        .DROP_OVERSIZE_FRAME(0),
        .DROP_BAD_FRAME(0),
        .DROP_WHEN_FULL(0)
    )
    axis_fifo_nack_gen_inst (
        .clk(clk),
        .rst(rst),

        .s_axis_tdata(axis_nack_gen_rq_fifo),
        .s_axis_tvalid(axis_nack_gen_rq_valid_fifo),
        .s_axis_tready(axis_nack_gen_rq_ready_fifo),
        .s_axis_tkeep(0),
        .s_axis_tlast(0),
        .s_axis_tuser(0),

        .m_axis_tdata(axis_nack_gen_rq),
        .m_axis_tvalid(axis_nack_gen_rq_valid),
        .m_axis_tready(axis_nack_gen_rq_ready),
        .m_axis_tkeep(),
        .m_axis_tlast(),
        .m_axis_tuser(),
        
        .status_overflow(),
        .status_bad_frame(),
        .status_good_frame()
    );
//------------------------------------------------------------
// <inst nack_deparser>
    nack_deparser #(
        .CSR_ADDR_WIDTH                    (CSR_ADDR_WIDTH      ),
        .CSR_DATA_WIDTH                    (CSR_DATA_WIDTH      ),
        .CSR_STRB_WIDTH                    (CSR_STRB_WIDTH      ),
        .INFO_WIDTH                        (S_INFO_WIDTH        ),//512),
        .BITMAP_WIDTH                      (BITMAP_WIDTH        ),
        .RPN_WIDTH                         (NPN_WIDTH           ),
        .AXIS_DATA_WIDTH                   (AXIS_DATA_WIDTH     ),
        .AXIS_KEEP_WIDTH                   (AXIS_DATA_WIDTH/8   ),
        .AXIS_USER_WIDTH                   (AXIS_USER_WIDTH     ) 
    )nack_deparser_dut(
        .clk                        (clk),
        .rst                        (rst),
    //control register interface
        // csr
        .csr_wr_addr                (csr_wr_addr),
        .csr_wr_data                (csr_wr_data),
        .csr_wr_strb                (csr_wr_strb),
        .csr_wr_en                  (csr_wr_en && ((csr_wr_addr >> 12) == 16'h3)),
        .csr_wr_wait                (csr_ng_wr_wait),
        .csr_wr_ack                 (csr_ng_wr_ack),
        .csr_rd_addr                (csr_rd_addr),
        .csr_rd_en                  (csr_rd_en && ((csr_rd_addr >> 12) == 16'h3)),
        .csr_rd_data                (csr_ng_rd_data),
        .csr_rd_wait                (csr_ng_rd_wait),
        .csr_rd_ack                 (csr_ng_rd_ack), 
    //input npn
        .s_nack_gen_info            (s_nack_gen_info    ),//input  wire [INFO_WIDTH-1:0]                
        .s_nack_gen_bitmap          (s_nack_gen_bitmap  ),//input  wire [BITMAP_WIDTH-1:0]              
        .s_nack_gen_init_npn        (s_nack_gen_init_npn),//input  wire [RPN_WIDTH-1:0]                 
        .s_nack_gen_valid           (s_nack_gen_valid   ),//input  wire                                 
        .s_nack_gen_ready           (s_nack_gen_ready   ),//output wire                                 
    //output NACK
        .m_axis_tdata               (m_axis_tdata  ),
        .m_axis_tkeep               (m_axis_tkeep  ),
        .m_axis_tvalid              (m_axis_tvalid ),
        .m_axis_tready              (m_axis_tready ),
        .m_axis_tlast               (m_axis_tlast  ),
        .m_axis_tuser               (m_axis_tuser  )
    );

/************************************DEBUG**********************************/
reg                                  csr_wr_ack_reg = 1'b0;
reg [CSR_DATA_WIDTH-1:0]    csr_rd_data_reg = {CSR_DATA_WIDTH{1'b0}};
reg                                  csr_rd_ack_reg = 1'b0;
reg [CSR_DATA_WIDTH-1:0]    csr_example_reg = {CSR_DATA_WIDTH{1'b0}};    
reg                                  csr_rst_reg = 1'b0 , csr_clear_reg = 1'b0;

wire                                 csr_tm_wr_wait ;
wire                                 csr_tm_wr_ack  ;
wire [CSR_DATA_WIDTH-1:0]   csr_tm_rd_data ;
wire                                 csr_tm_rd_wait ;
wire                                 csr_tm_rd_ack  ;

wire                                 csr_tpl_wr_wait ;
wire                                 csr_tpl_wr_ack  ;
wire [CSR_DATA_WIDTH-1:0]   csr_tpl_rd_data ;
wire                                 csr_tpl_rd_wait ;
wire                                 csr_tpl_rd_ack  ;

wire                                 csr_ng_wr_wait ;
wire                                 csr_ng_wr_ack  ;
wire [CSR_DATA_WIDTH-1:0]   csr_ng_rd_data ;
wire                                 csr_ng_rd_wait ;
wire                                 csr_ng_rd_ack  ;

wire                                 csr_st_wr_wait ;
wire                                 csr_st_wr_ack  ;
wire [CSR_DATA_WIDTH-1:0]   csr_st_rd_data ;
wire                                 csr_st_rd_wait ;
wire                                 csr_st_rd_ack  ;
reg [CSR_DATA_WIDTH-1:0]  csr_out_pkt_count_reg;
reg [CSR_DATA_WIDTH-1:0]  csr_in_pkt_count_reg;
reg [CSR_DATA_WIDTH-1:0]  csr_port_valid_reg;
reg [CSR_DATA_WIDTH-1:0]  csr_port_ready_reg;

reg [31:0]      jump_posedge_threshold;

assign csr_wr_wait = 1'b0            | csr_tpl_wr_wait |  csr_tm_wr_wait |  csr_ng_wr_wait |  csr_st_wr_wait ;
assign csr_wr_ack  = csr_wr_ack_reg  | csr_tpl_wr_ack  |  csr_tm_wr_ack  |  csr_ng_wr_ack  |  csr_st_wr_ack  ;
assign csr_rd_data = csr_rd_data_reg | csr_tpl_rd_data |  csr_tm_rd_data |  csr_ng_rd_data |  csr_st_rd_data ;
assign csr_rd_wait = 1'b0            | csr_tpl_rd_wait |  csr_tm_rd_wait |  csr_ng_rd_wait |  csr_st_rd_wait ;
assign csr_rd_ack  = csr_rd_ack_reg  | csr_tpl_rd_ack  |  csr_tm_rd_ack  |  csr_ng_rd_ack  |  csr_st_rd_ack  ;



always @(posedge clk) begin
    if(m_axis_tvalid & m_axis_tready & m_axis_tlast) begin
        csr_out_pkt_count_reg <= csr_out_pkt_count_reg + 1;
    end else begin
        csr_out_pkt_count_reg <= csr_out_pkt_count_reg;
    end

    if(m_sp_ready & m_sp_valid) begin
        csr_in_pkt_count_reg <= csr_in_pkt_count_reg + 1;
    end else begin
        csr_in_pkt_count_reg <= csr_in_pkt_count_reg;
    end


    if(rst || csr_rst_reg || csr_clear_reg) begin
        csr_port_valid_reg <= 0;
        csr_port_ready_reg <= 0;
        csr_out_pkt_count_reg <= 0;
        csr_in_pkt_count_reg <= 0;
    end
end

always @(posedge clk or posedge rst) begin
    csr_wr_ack_reg <= 1'b0;
    csr_rd_ack_reg <= 1'b0;
    csr_rd_data_reg <= {CSR_DATA_WIDTH{1'b0}};

    if (csr_wr_en && !csr_wr_ack_reg) begin
        // write operation
        csr_wr_ack_reg <= 1'b1;
        case ({csr_wr_addr >> 2, 2'b00})
            16'h0000: csr_example_reg          <= csr_wr_data;
            16'h0004: csr_rst_reg              <= csr_wr_data[0];
            16'h0008: csr_clear_reg            <= csr_wr_data[0];
            16'h000c: jump_posedge_threshold   <= csr_wr_data;
            default: csr_wr_ack_reg            <= 1'b0;
        endcase
    end
    
    if (csr_rd_en && !csr_rd_ack_reg) begin	
        // read operation
        csr_rd_ack_reg <= 1'b1;
        case ({csr_rd_addr >> 2, 2'b00})
            16'h0000: csr_rd_data_reg <= csr_example_reg;
            16'h0004: csr_rd_data_reg <= csr_rst_reg;
            16'h0008: csr_rd_data_reg <= csr_clear_reg;
            16'h000c: csr_rd_data_reg <= jump_posedge_threshold;

            16'h0010: csr_rd_data_reg <= csr_in_pkt_count_reg;
            16'h0014: csr_rd_data_reg <= csr_out_pkt_count_reg;
            16'h0018: csr_rd_data_reg <= csr_port_valid_reg;
            16'h001c: csr_rd_data_reg <= csr_port_ready_reg;
         
            default: csr_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst || csr_rst_reg || csr_clear_reg) begin
        csr_wr_ack_reg <= 1'b0;
        csr_rd_ack_reg <= 1'b0;
        csr_rd_data_reg <= {CSR_DATA_WIDTH{1'b0}};
        csr_example_reg <= 32'h55667788;
        csr_clear_reg <= 1'b0;
        jump_posedge_threshold <= 'd125 * MAIN_CLK;  //170M
    end
end

/************************************DEBUG**********************************/
endmodule