//------------------------------------------------------------
// <seanetnackgenerator Module>
// Author: chenfeiyu@seanet.com.cn
// Date. : 2024/05/27
// Func  : seanetnackgenerator
//                      >>Instruction<<
// Port[System]---clock and reset
// Port[upstream KEY]---retran req
// Port[downstream KEY]---nack req
// Port[AXI4 Master]---ddr rw port
// Port[AXI-Lite]---config port
// Port[Dfx]---DFX Port
//                       >>>Mention<<<
// Only used in SEANet PRJ.
// Unexpected usage will lead to ERROR.
//                      >>Version Log<<
//  [v0.1]
//      
//                                       @All Rights Reserved. 
//------------------------------------------------------------
`define AXI_INTERX_DISABLED
module seanetnackgenerator_top_v0p1 #(
    parameter BITMAP_BASE_ADDR      = 32'h0000_0000             ,
    parameter TIMER_BASE_ADDR       = 32'h0010_0000             ,
    parameter P_CLK_FHZ             = 300_000_000               ,//1s
    parameter P_1MS_COUNTER_VALUE   = P_CLK_FHZ/1000            ,//1ms
    parameter P_CLOCK_CYCTIME       = P_1MS_COUNTER_VALUE * 30  ,//30ms
    parameter INIT_JUMP_THRESH      = 16'd25000                 ,
    parameter MAX_WND_SIZE          = 16'd4096                  ,
    //--------------------------------->>axi config<<------------------------------
    //AXI4 parameter
    parameter AXI_ID_WIDTH      = 4                     ,
    parameter AXI_ADDR_WIDTH    = 32                    ,
    parameter AXI_DATA_WIDTH    = 512                   ,
    parameter AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8      ,

    parameter M_AXI_ID_WIDTH    = 8                     ,
    parameter M_AXI_ADDR_WIDTH  = 32                    ,
    parameter M_AXI_DATA_WIDTH  = 512                   ,
    parameter M_AXI_STRB_WIDTH  = AXI_DATA_WIDTH/8      ,
    //AXIL parameter
    parameter AXIL_ADDR_WIDTH    = 64                    ,
    parameter AXIL_DATA_WIDTH    = 512                   ,
    parameter AXIL_STRB_WIDTH    = AXIL_ADDR_WIDTH/8      
)(
    input   wire                                        sys_clk         ,
    input   wire                                        sys_rst         ,
    // connect to upstream port
    input   wire     [511:0]                            i_s_info        ,
    input   wire     [15:0]                             i_s_id          ,
    input   wire     [95:0]                             i_key_msg       ,
    input   wire     [1:0]                              i_type          ,
    input   wire                                        i_valid         ,
    output  wire                                        o_ready         ,
    // connect to dnstream port
    output  wire    [511:0]                             o_nack_s_info   ,
    output  wire    [63:0]                              o_nack_bitmap   ,
    output  wire    [31:0]                              o_nack_npn      ,
    output  wire                                        o_nack_valid    ,
    input   wire                                        i_nack_ready    ,
    `ifndef AXI_INTERX_DISABLED
        // connect to DDR MIG (AXI4-MM)
        input  wire                                         m_axi_aclk      ,
        output wire                                         m_axi_aresetn   ,
        output wire [M_AXI_ID_WIDTH-1:0]                    m_axi_awid      ,
        output wire [M_AXI_ADDR_WIDTH-1:0]                  m_axi_awaddr    ,
        output wire [7:0]                                   m_axi_awlen     ,
        output wire [2:0]                                   m_axi_awsize    ,
        output wire [1:0]                                   m_axi_awburst   ,    
        output wire                                         m_axi_awlock    ,
        output wire [3:0]                                   m_axi_awcache   ,    
        output wire [2:0]                                   m_axi_awprot    ,
        output wire [3:0]                                   m_axi_awqos     ,
        output wire                                         m_axi_awvalid   ,    
        input  wire                                         m_axi_awready   ,    
        output wire [M_AXI_DATA_WIDTH-1:0]                  m_axi_wdata     ,
        output wire [M_AXI_STRB_WIDTH-1:0]                  m_axi_wstrb     ,
        output wire                                         m_axi_wlast     ,
        output wire                                         m_axi_wvalid    ,
        input  wire                                         m_axi_wready    ,
        input  wire [M_AXI_ID_WIDTH-1:0]                    m_axi_bid       ,
        input  wire [1:0]                                   m_axi_bresp     ,
        input  wire                                         m_axi_bvalid    ,
        output wire                                         m_axi_bready    ,
        output wire [M_AXI_ID_WIDTH-1:0]                    m_axi_arid      ,
        output wire [M_AXI_ADDR_WIDTH-1:0]                  m_axi_araddr    ,
        output wire [7:0]                                   m_axi_arlen     ,
        output wire [2:0]                                   m_axi_arsize    ,
        output wire [1:0]                                   m_axi_arburst   ,    
        output wire                                         m_axi_arlock    ,
        output wire [3:0]                                   m_axi_arcache   ,    
        output wire [2:0]                                   m_axi_arprot    ,
        output wire [3:0]                                   m_axi_arqos     ,
        output wire                                         m_axi_arvalid   ,    
        input  wire                                         m_axi_arready   ,    
        input  wire [M_AXI_ID_WIDTH-1:0]                    m_axi_rid       ,
        input  wire [M_AXI_DATA_WIDTH-1:0]                  m_axi_rdata     ,
        input  wire [1:0]                                   m_axi_rresp     ,
        input  wire                                         m_axi_rlast     ,
        input  wire                                         m_axi_rvalid    ,
        output wire                                         m_axi_rready    ,
    `else
        // connect to DDR MIG P0 (AXI4-MM)
        output wire [M_AXI_ID_WIDTH-1:0]                    m00_axi_awid      ,
        output wire [M_AXI_ADDR_WIDTH-1:0]                  m00_axi_awaddr    ,
        output wire [7:0]                                   m00_axi_awlen     ,
        output wire [2:0]                                   m00_axi_awsize    ,
        output wire [1:0]                                   m00_axi_awburst   ,    
        output wire                                         m00_axi_awlock    ,
        output wire [3:0]                                   m00_axi_awcache   ,    
        output wire [2:0]                                   m00_axi_awprot    ,
        output wire [3:0]                                   m00_axi_awqos     ,
        output wire                                         m00_axi_awvalid   ,    
        input  wire                                         m00_axi_awready   ,    
        output wire [M_AXI_DATA_WIDTH-1:0]                  m00_axi_wdata     ,
        output wire [M_AXI_STRB_WIDTH-1:0]                  m00_axi_wstrb     ,
        output wire                                         m00_axi_wlast     ,
        output wire                                         m00_axi_wvalid    ,
        input  wire                                         m00_axi_wready    ,
        input  wire [M_AXI_ID_WIDTH-1:0]                    m00_axi_bid       ,
        input  wire [1:0]                                   m00_axi_bresp     ,
        input  wire                                         m00_axi_bvalid    ,
        output wire                                         m00_axi_bready    ,
        output wire [M_AXI_ID_WIDTH-1:0]                    m00_axi_arid      ,
        output wire [M_AXI_ADDR_WIDTH-1:0]                  m00_axi_araddr    ,
        output wire [7:0]                                   m00_axi_arlen     ,
        output wire [2:0]                                   m00_axi_arsize    ,
        output wire [1:0]                                   m00_axi_arburst   ,    
        output wire                                         m00_axi_arlock    ,
        output wire [3:0]                                   m00_axi_arcache   ,    
        output wire [2:0]                                   m00_axi_arprot    ,
        output wire [3:0]                                   m00_axi_arqos     ,
        output wire                                         m00_axi_arvalid   ,    
        input  wire                                         m00_axi_arready   ,    
        input  wire [M_AXI_ID_WIDTH-1:0]                    m00_axi_rid       ,
        input  wire [M_AXI_DATA_WIDTH-1:0]                  m00_axi_rdata     ,
        input  wire [1:0]                                   m00_axi_rresp     ,
        input  wire                                         m00_axi_rlast     ,
        input  wire                                         m00_axi_rvalid    ,
        output wire                                         m00_axi_rready    ,
        // connect to DDR MIG P1 (AXI4-MM)
        output wire [M_AXI_ID_WIDTH-1:0]                    m01_axi_awid      ,
        output wire [M_AXI_ADDR_WIDTH-1:0]                  m01_axi_awaddr    ,
        output wire [7:0]                                   m01_axi_awlen     ,
        output wire [2:0]                                   m01_axi_awsize    ,
        output wire [1:0]                                   m01_axi_awburst   ,    
        output wire                                         m01_axi_awlock    ,
        output wire [3:0]                                   m01_axi_awcache   ,    
        output wire [2:0]                                   m01_axi_awprot    ,
        output wire [3:0]                                   m01_axi_awqos     ,
        output wire                                         m01_axi_awvalid   ,    
        input  wire                                         m01_axi_awready   ,    
        output wire [M_AXI_DATA_WIDTH-1:0]                  m01_axi_wdata     ,
        output wire [M_AXI_STRB_WIDTH-1:0]                  m01_axi_wstrb     ,
        output wire                                         m01_axi_wlast     ,
        output wire                                         m01_axi_wvalid    ,
        input  wire                                         m01_axi_wready    ,
        input  wire [M_AXI_ID_WIDTH-1:0]                    m01_axi_bid       ,
        input  wire [1:0]                                   m01_axi_bresp     ,
        input  wire                                         m01_axi_bvalid    ,
        output wire                                         m01_axi_bready    ,
        output wire [M_AXI_ID_WIDTH-1:0]                    m01_axi_arid      ,
        output wire [M_AXI_ADDR_WIDTH-1:0]                  m01_axi_araddr    ,
        output wire [7:0]                                   m01_axi_arlen     ,
        output wire [2:0]                                   m01_axi_arsize    ,
        output wire [1:0]                                   m01_axi_arburst   ,    
        output wire                                         m01_axi_arlock    ,
        output wire [3:0]                                   m01_axi_arcache   ,    
        output wire [2:0]                                   m01_axi_arprot    ,
        output wire [3:0]                                   m01_axi_arqos     ,
        output wire                                         m01_axi_arvalid   ,    
        input  wire                                         m01_axi_arready   ,    
        input  wire [M_AXI_ID_WIDTH-1:0]                    m01_axi_rid       ,
        input  wire [M_AXI_DATA_WIDTH-1:0]                  m01_axi_rdata     ,
        input  wire [1:0]                                   m01_axi_rresp     ,
        input  wire                                         m01_axi_rlast     ,
        input  wire                                         m01_axi_rvalid    ,
        output wire                                         m01_axi_rready    ,
    `endif
    // connect to CONFIG BUS (AXI-LITE)
    input  wire [AXIL_ADDR_WIDTH-1:0]                   s_axil_awaddr   ,
    input  wire [2:0]                                   s_axil_awport   ,
    input  wire                                         s_axil_awvalid  ,
    output wire                                         s_axil_awready  ,
    input  wire [AXIL_DATA_WIDTH-1:0]                   s_axil_wdata    ,
    input  wire [AXIL_STRB_WIDTH-1:0]                   s_axil_wstrb    ,
    input  wire                                         s_axil_wvalid   ,
    output wire                                         s_axil_wready   ,
    output wire [1:0]                                   s_axil_bresp    ,
    output wire                                         s_axil_bvalid   ,
    input  wire                                         s_axil_bready   ,
    input  wire [AXIL_ADDR_WIDTH-1:0]                   s_axil_araddr   ,
    input  wire [2:0]                                   s_axil_arport   ,
    input  wire                                         s_axil_arvalid  ,
    output wire                                         s_axil_arready  ,
    input  wire [AXIL_DATA_WIDTH-1:0]                   s_axil_rdata    ,
    input  wire [1:0]                                   s_axil_rresp    ,
    input  wire                                         s_axil_rvalid   ,
    output wire                                         s_axil_rready   ,
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
    output wire [31:0]                                  dfx_sta_0x13     
);
reg     [31:0]                              r0_i_cfg_reg0=32'd0;
reg     [31:0]                              r0_i_cfg_reg1=32'd0;
reg     [31:0]                              r0_i_cfg_reg2=32'd0;
reg     [31:0]                              r0_i_cfg_reg3=32'd0;
reg     [31:0]                              r1_i_cfg_reg0=32'd0;
reg     [31:0]                              r1_i_cfg_reg1=32'd0;
reg     [31:0]                              r1_i_cfg_reg2=32'd0;
reg     [31:0]                              r1_i_cfg_reg3=32'd0;
always@(posedge sys_clk)
if(sys_rst)
    begin
        r0_i_cfg_reg0 <= 32'd0;
        r0_i_cfg_reg1 <= 32'd0;
        r0_i_cfg_reg2 <= 32'd0;
        r0_i_cfg_reg3 <= 32'd0;
        r1_i_cfg_reg0 <= 32'd0;
        r1_i_cfg_reg1 <= 32'd0;
        r1_i_cfg_reg2 <= 32'd0;
        r1_i_cfg_reg3 <= 32'd0;
    end
else
    begin
        r0_i_cfg_reg0 <=    dfx_cfg0;
        r0_i_cfg_reg1 <=    dfx_cfg1;
        r0_i_cfg_reg2 <=    dfx_cfg2;
        r0_i_cfg_reg3 <=    dfx_cfg3;
        r1_i_cfg_reg0 <= r0_i_cfg_reg0;
        r1_i_cfg_reg1 <= r0_i_cfg_reg1;
        r1_i_cfg_reg2 <= r0_i_cfg_reg2;
        r1_i_cfg_reg3 <= r0_i_cfg_reg3;
    end 

reg     [3:0]   dfx_sta_clear=4'd0;
always@(posedge sys_clk)
if(sys_rst)
    dfx_sta_clear <= 4'd0;
else
    dfx_sta_clear <= {4{r1_i_cfg_reg0[0]}};

    wire    [15:0]                              o_wnd_sn                    ;
    wire    [31:0]                              o_wnd_chksum                ;
    wire    [95:0]                              o_wnd_key_msg               ;
    wire    [1 :0]                              o_wnd_tpye                  ;
    wire                                        o_wnd_valid                 ;
    wire                                        i_wnd_ready                 ;
    wire    [31:0]                              sm_o_tmg_chksum             ;
    wire    [511:0]                             sm_o_tmg_s_info             ;
    wire                                        sm_o_tmg_valid              ;
    wire                                        sm_i_tmg_ready              ;
    wire    [15:0]                              sm_i_tmg_req_sn             ;
    wire                                        sm_i_tmg_req_valid          ;
    wire                                        sm_o_tmg_req_ready          ;
    wire    [15:0]                              i_wnd_sn                    ;
    wire    [31:0]                              i_wnd_chksum                ;
    wire    [95:0]                              i_wnd_key_msg               ;
    wire    [1 :0]                              i_wnd_tpye                  ;
    wire                                        i_wnd_valid                 ;
    wire                                        o_wnd_ready                 ;
    wire    [15:0]                              wm_o_tmg_sn                 ;
    wire    [31:0]                              wm_o_tmg_chksum             ;
    wire    [64+384-1:0]                        wm_o_tmg_gen_req            ;
    wire                                        wm_o_tmg_valid              ;
    wire                                        wm_i_tmg_ready              ;
    wire    [63:0]                              wm_o_tmg_wnd                ;
    wire                                        wm_o_tmg_wnd_valid          ;
    wire                                        wm_i_tmg_wnd_ready          ;
    wire    [15:0]                              wm_i_tmg_wnd_req_sn         ;
    wire                                        wm_i_tmg_wnd_req_valid      ;
    wire                                        wm_o_tmg_wnd_req_ready      ;
    `ifndef AXI_INTERX_DISABLED
    wire [AXI_ID_WIDTH-1:0]                     m00_axi_awid                ;
    wire [AXI_ADDR_WIDTH-1:0]                   m00_axi_awaddr              ;
    wire [7:0]                                  m00_axi_awlen               ;
    wire [2:0]                                  m00_axi_awsize              ;
    wire [1:0]                                  m00_axi_awburst             ;
    wire                                        m00_axi_awlock              ;
    wire [3:0]                                  m00_axi_awcache             ;
    wire [2:0]                                  m00_axi_awprot              ;
    wire                                        m00_axi_awvalid             ;
    wire                                        m00_axi_awready             ;
    wire [AXI_DATA_WIDTH-1:0]                   m00_axi_wdata               ;
    wire [AXI_STRB_WIDTH-1:0]                   m00_axi_wstrb               ;
    wire                                        m00_axi_wlast               ;
    wire                                        m00_axi_wvalid              ;
    wire                                        m00_axi_wready              ;
    wire [AXI_ID_WIDTH-1:0]                     m00_axi_bid                 ;
    wire [1:0]                                  m00_axi_bresp               ;
    wire                                        m00_axi_bvalid              ;
    wire                                        m00_axi_bready              ;
    wire [AXI_ID_WIDTH-1:0]                     m00_axi_arid                ;
    wire [AXI_ADDR_WIDTH-1:0]                   m00_axi_araddr              ;
    wire [7:0]                                  m00_axi_arlen               ;
    wire [2:0]                                  m00_axi_arsize              ;
    wire [1:0]                                  m00_axi_arburst             ;
    wire                                        m00_axi_arlock              ;
    wire [3:0]                                  m00_axi_arcache             ;
    wire [2:0]                                  m00_axi_arprot              ;
    wire                                        m00_axi_arvalid             ;
    wire                                        m00_axi_arready             ;
    wire [AXI_ID_WIDTH-1:0]                     m00_axi_rid                 ;
    wire [AXI_DATA_WIDTH-1:0]                   m00_axi_rdata               ;
    wire [1:0]                                  m00_axi_rresp               ;
    wire                                        m00_axi_rlast               ;
    wire                                        m00_axi_rvalid              ;
    wire                                        m00_axi_rready              ;
    wire [AXI_ID_WIDTH-1:0]                     m01_axi_awid                ;
    wire [AXI_ADDR_WIDTH-1:0]                   m01_axi_awaddr              ;
    wire [7:0]                                  m01_axi_awlen               ;
    wire [2:0]                                  m01_axi_awsize              ;
    wire [1:0]                                  m01_axi_awburst             ;
    wire                                        m01_axi_awlock              ;
    wire [3:0]                                  m01_axi_awcache             ;
    wire [2:0]                                  m01_axi_awprot              ;
    wire                                        m01_axi_awvalid             ;
    wire                                        m01_axi_awready             ;
    wire [AXI_DATA_WIDTH-1:0]                   m01_axi_wdata               ;
    wire [AXI_STRB_WIDTH-1:0]                   m01_axi_wstrb               ;
    wire                                        m01_axi_wlast               ;
    wire                                        m01_axi_wvalid              ;
    wire                                        m01_axi_wready              ;
    wire [AXI_ID_WIDTH-1:0]                     m01_axi_bid                 ;
    wire [1:0]                                  m01_axi_bresp               ;
    wire                                        m01_axi_bvalid              ;
    wire                                        m01_axi_bready              ;
    wire [AXI_ID_WIDTH-1:0]                     m01_axi_arid                ;
    wire [AXI_ADDR_WIDTH-1:0]                   m01_axi_araddr              ;
    wire [7:0]                                  m01_axi_arlen               ;
    wire [2:0]                                  m01_axi_arsize              ;
    wire [1:0]                                  m01_axi_arburst             ;
    wire                                        m01_axi_arlock              ;
    wire [3:0]                                  m01_axi_arcache             ;
    wire [2:0]                                  m01_axi_arprot              ;
    wire                                        m01_axi_arvalid             ;
    wire                                        m01_axi_arready             ;
    wire [AXI_ID_WIDTH-1:0]                     m01_axi_rid                 ;
    wire [AXI_DATA_WIDTH-1:0]                   m01_axi_rdata               ;
    wire [1:0]                                  m01_axi_rresp               ;
    wire                                        m01_axi_rlast               ;
    wire                                        m01_axi_rvalid              ;
    wire                                        m01_axi_rready              ;
    `endif
    wire    [15:0]                              tmg_i_sn                    ;
    wire    [31:0]                              tmg_i_chksum                ;
    wire    [64+384-1:0]                        tmg_i_gen_req               ;
    wire                                        tmg_i_valid                 ;
    wire                                        tmg_o_ready                 ;
    wire    [31:0]                              i_tmg_chksum                ;
    wire    [511:0]                             i_tmg_s_info                ;
    wire                                        i_tmg_valid                 ;
    wire                                        o_tmg_ready                 ;
    wire    [15:0]                              o_tmg_req_sn                ;
    wire                                        o_tmg_req_valid             ;
    wire                                        i_tmg_req_ready             ;
    wire    [63:0]                              i_tmg_wnd                   ;
    wire                                        i_tmg_wnd_valid             ;
    wire                                        o_tmg_wnd_ready             ;
    wire    [15:0]                              o_tmg_wnd_req_sn            ;
    wire                                        o_tmg_wnd_req_valid         ;
    wire                                        i_tmg_wnd_req_ready         ;
    wire    [15:0]                              o_nackgen_sn                ;
    wire    [1024+32-1:0]                       o_nackgen_req               ;
    wire                                        o_nackgen_vld               ;
    wire                                        i_nackgen_rdy               ;
    wire    [15:0]                              i_nackgen_sn                ;
    wire    [1024+32-1:0]                       i_nackgen_req               ;
    wire                                        i_nackgen_vld               ;
    wire                                        o_nackgen_rdy               ;
    wire                                        m00_axi_aclk                ;
    wire                                        m01_axi_aclk                ;
    wire                                        m00_axi_aresetn             ;
    wire                                        m01_axi_aresetn             ;
    assign tmg_i_sn                 = wm_o_tmg_sn           ;
    assign tmg_i_chksum             = wm_o_tmg_chksum       ;
    assign tmg_i_gen_req            = wm_o_tmg_gen_req      ;
    assign tmg_i_valid              = wm_o_tmg_valid        ;
    assign wm_i_tmg_ready           = tmg_o_ready           ;
    assign i_tmg_chksum             = sm_o_tmg_chksum       ;
    assign i_tmg_s_info             = sm_o_tmg_s_info       ;
    assign i_tmg_valid              = sm_o_tmg_valid        ;
    assign sm_i_tmg_ready           = o_tmg_ready           ;
    assign sm_i_tmg_req_sn          = o_tmg_req_sn          ;
    assign sm_i_tmg_req_valid       = o_tmg_req_valid       ;
    assign i_tmg_req_ready          = sm_o_tmg_req_ready    ;
    assign i_tmg_wnd                = wm_o_tmg_wnd          ;
    assign i_tmg_wnd_valid          = wm_o_tmg_wnd_valid    ;
    assign wm_i_tmg_wnd_ready       = o_tmg_wnd_ready       ;
    assign wm_i_tmg_wnd_req_sn      = o_tmg_wnd_req_sn      ;
    assign wm_i_tmg_wnd_req_valid   = o_tmg_wnd_req_valid   ;
    assign i_tmg_wnd_req_ready      = wm_o_tmg_wnd_req_ready;
    assign i_wnd_sn                 = o_wnd_sn              ;
    assign i_wnd_chksum             = o_wnd_chksum          ;
    assign i_wnd_key_msg            = o_wnd_key_msg         ;
    assign i_wnd_tpye               = o_wnd_tpye            ;
    assign i_wnd_valid              = o_wnd_valid           ;
    assign i_wnd_ready              = o_wnd_ready           ;
    assign i_nackgen_sn             = o_nackgen_sn          ;
    assign i_nackgen_req            = o_nackgen_req         ;
    assign i_nackgen_vld            = o_nackgen_vld         ;
    assign i_nackgen_rdy            = o_nackgen_rdy         ;
    assign m00_axi_aclk             = sys_clk               ;
    assign m01_axi_aclk             = sys_clk               ;

    wire    [15:0]                  o_timer_ot_sn           ;                           
    wire                            o_timer_ot_sn_vld       ;                           
    wire                            o_timer_ot_vld          ;       
    wire    [15:0]                  i_timer_ot_sn           ;                           
    wire                            i_timer_ot_sn_vld       ;                           
    wire                            i_timer_ot_vld          ;                      
    assign i_timer_ot_sn     = o_timer_ot_sn    ;
    assign i_timer_ot_sn_vld = o_timer_ot_sn_vld;
    assign i_timer_ot_vld    = o_timer_ot_vld   ;

    seanetnackgenerator_stream_manager_v0p1 seanetnackgenerator_stream_manager_v0p1_dut(
        .sys_clk                (sys_clk                ),//input   wire                                        
        .sys_rst                (sys_rst                ),//input   wire                                        
        // connect to upstream port
        .i_s_info               (i_s_info               ),//input   wire     [511:0]                            
        .i_s_id                 (i_s_id                 ),//input   wire     [15:0]                             //only support 0-1023 value
        .i_key_msg              (i_key_msg              ),//input   wire     [95:0]                             
        .i_type                 (i_type                 ),//input   wire     [1:0]                              //01:normal 10:nack reply 11:reset
        .i_valid                (i_valid                ),//input   wire                                        
        .o_ready                (o_ready                ),//output  wire                                        
        // connect to window manager
        .o_wnd_sn               (o_wnd_sn               ),//output  wire    [15:0]                              
        .o_wnd_chksum           (o_wnd_chksum           ),//output  wire    [31:0]                              
        .o_wnd_key_msg          (o_wnd_key_msg          ),//output  wire    [95:0]                              
        .o_wnd_tpye             (o_wnd_tpye             ),//output  wire    [1 :0]                              //01:normal 10:nack reply 11:reset
        .o_wnd_valid            (o_wnd_valid            ),//output  wire                                        
        .i_wnd_ready            (i_wnd_ready            ),//input   wire                                        
        // connect to timer manager
        .o_tmg_chksum           (sm_o_tmg_chksum           ),//output  wire    [31:0]                              
        .o_tmg_s_info           (sm_o_tmg_s_info           ),//output  wire    [511:0]                             
        .o_tmg_valid            (sm_o_tmg_valid            ),//output  wire                                        
        .i_tmg_ready            (sm_i_tmg_ready            ),//input   wire                                        
        .i_tmg_req_sn           (sm_i_tmg_req_sn           ),//input   wire    [15:0]                              
        .i_tmg_req_valid        (sm_i_tmg_req_valid        ),//input   wire                                        
        .o_tmg_req_ready        (sm_o_tmg_req_ready        ),//output  wire                                        
        // connect to dfx port
        .i_cfg_reg0             ({31'd0,dfx_sta_clear[0]}   ),//input   wire    [31:0]                              
        .o_sta_reg0             (dfx_sta_0x00               ),//output  wire    [31:0]                                 
        .o_sta_reg1             (dfx_sta_0x01               ) //output  wire    [31:0]                                 
    );

    seanetnackgenerator_window_manager_v0p1 #(
        .BITMAP_BASE_ADDR(BITMAP_BASE_ADDR),
        .MAX_WND_SIZE(MAX_WND_SIZE)
    )seanetnackgenerator_window_manager_v0p1_dut(
        .sys_clk                (sys_clk                ),//input   wire                                        
        .sys_rst                (sys_rst                ),//input   wire                                        
        // connect to window manager
        .i_wnd_sn               (i_wnd_sn               ),//input   wire    [15:0]                              
        .i_wnd_chksum           (i_wnd_chksum           ),//input   wire    [31:0]                              
        .i_wnd_key_msg          (i_wnd_key_msg          ),//input   wire    [95:0]                              
        .i_wnd_tpye             (i_wnd_tpye             ),//input   wire    [1 :0]                              //01:normal 10:nack reply 11:reset
        .i_wnd_valid            (i_wnd_valid            ),//input   wire                                        
        .o_wnd_ready            (o_wnd_ready            ),//output  wire                                        
        // connect to timer manager
        .o_tmg_sn               (wm_o_tmg_sn               ),//output  wire    [15:0]                              
        .o_tmg_chksum           (wm_o_tmg_chksum           ),//output  wire    [31:0]                                  
        .o_tmg_gen_req          (wm_o_tmg_gen_req          ),//output  wire    [64+384-1:0]                            
        .o_tmg_valid            (wm_o_tmg_valid            ),//output  wire                                        
        .i_tmg_ready            (wm_i_tmg_ready            ),//input   wire                                        
        .o_tmg_wnd              (wm_o_tmg_wnd              ),//output  wire    [63:0]                              
        .o_tmg_wnd_valid        (wm_o_tmg_wnd_valid        ),//output  wire                                            
        .i_tmg_wnd_ready        (wm_i_tmg_wnd_ready        ),//input   wire                                            
        .i_tmg_wnd_req_sn       (wm_i_tmg_wnd_req_sn       ),//input   wire    [15:0]                                      
        .i_tmg_wnd_req_valid    (wm_i_tmg_wnd_req_valid    ),//input   wire                                                
        .o_tmg_wnd_req_ready    (wm_o_tmg_wnd_req_ready    ),//output  wire                                              
        .i_timer_ot_sn          (i_timer_ot_sn             ),//output wire  [15:0]
        .i_timer_ot_sn_vld      (i_timer_ot_sn_vld         ),//output wire  
        .i_timer_ot_vld         (i_timer_ot_vld            ),//output wire  
        // axi4 
        .m_axi_awid             (m00_axi_awid             ),//output wire [AXI_ID_WIDTH-1:0]                      
        .m_axi_awaddr           (m00_axi_awaddr           ),//output wire [AXI_ADDR_WIDTH-1:0]                    
        .m_axi_awlen            (m00_axi_awlen            ),//output wire [7:0]                                   
        .m_axi_awsize           (m00_axi_awsize           ),//output wire [2:0]                                   
        .m_axi_awburst          (m00_axi_awburst          ),//output wire [1:0]                                       
        .m_axi_awlock           (m00_axi_awlock           ),//output wire                                         
        .m_axi_awcache          (m00_axi_awcache          ),//output wire [3:0]                                       
        .m_axi_awprot           (m00_axi_awprot           ),//output wire [2:0]                                   
        .m_axi_awvalid          (m00_axi_awvalid          ),//output wire                                             
        .m_axi_awready          (m00_axi_awready          ),//input  wire                                             
        .m_axi_wdata            (m00_axi_wdata            ),//output wire [AXI_DATA_WIDTH-1:0]                    
        .m_axi_wstrb            (m00_axi_wstrb            ),//output wire [AXI_STRB_WIDTH-1:0]                    
        .m_axi_wlast            (m00_axi_wlast            ),//output wire                                         
        .m_axi_wvalid           (m00_axi_wvalid           ),//output wire                                         
        .m_axi_wready           (m00_axi_wready           ),//input  wire                                         
        .m_axi_bid              (m00_axi_bid              ),//input  wire [AXI_ID_WIDTH-1:0]                      
        .m_axi_bresp            (m00_axi_bresp            ),//input  wire [1:0]                                   
        .m_axi_bvalid           (m00_axi_bvalid           ),//input  wire                                         
        .m_axi_bready           (m00_axi_bready           ),//output wire                                         
        .m_axi_arid             (m00_axi_arid             ),//output wire [AXI_ID_WIDTH-1:0]                      
        .m_axi_araddr           (m00_axi_araddr           ),//output wire [AXI_ADDR_WIDTH-1:0]                    
        .m_axi_arlen            (m00_axi_arlen            ),//output wire [7:0]                                   
        .m_axi_arsize           (m00_axi_arsize           ),//output wire [2:0]                                   
        .m_axi_arburst          (m00_axi_arburst          ),//output wire [1:0]                                       
        .m_axi_arlock           (m00_axi_arlock           ),//output wire                                         
        .m_axi_arcache          (m00_axi_arcache          ),//output wire [3:0]                                       
        .m_axi_arprot           (m00_axi_arprot           ),//output wire [2:0]                                   
        .m_axi_arvalid          (m00_axi_arvalid          ),//output wire                                             
        .m_axi_arready          (m00_axi_arready          ),//input  wire                                             
        .m_axi_rid              (m00_axi_rid              ),//input  wire [AXI_ID_WIDTH-1:0]                      
        .m_axi_rdata            (m00_axi_rdata            ),//input  wire [AXI_DATA_WIDTH-1:0]                    
        .m_axi_rresp            (m00_axi_rresp            ),//input  wire [1:0]                                   
        .m_axi_rlast            (m00_axi_rlast            ),//input  wire                                         
        .m_axi_rvalid           (m00_axi_rvalid           ),//input  wire                                         
        .m_axi_rready           (m00_axi_rready           ),//output wire                                           
        // connect to dfx port
        .i_cfg_reg0             ({31'd0,dfx_sta_clear[1]}   ),//input   wire    [31:0]                              
        .i_cfg_reg1             (r1_i_cfg_reg3              ),//input   wire    [31:0]                              
        .o_sta_reg0             (dfx_sta_0x02               ),//output  wire    [31:0]                                 
        .o_sta_reg1             (dfx_sta_0x03               ),//output  wire    [31:0]                                 
        .o_sta_reg2             (dfx_sta_0x04               ),//output  wire    [31:0]                                 
        .o_sta_reg3             (dfx_sta_0x05               ),//output  wire    [31:0]                                 
        .o_sta_reg4             (dfx_sta_0x06               ),//output  wire    [31:0]                                 
        .o_sta_reg5             (dfx_sta_0x07               ) //output  wire    [31:0]                                 
    );
    
    seanetnackgenerator_timer_manager_v0p1#(
        .BITMAP_BASE_ADDR      (BITMAP_BASE_ADDR      ),
        .INIT_JUMP_THRESH      (INIT_JUMP_THRESH      ),
        .TIMER_BASE_ADDR       (TIMER_BASE_ADDR       ),
        .P_CLK_FHZ             (P_CLK_FHZ             ),//1s
        .P_1MS_COUNTER_VALUE   (P_1MS_COUNTER_VALUE   ),//1ms
        .P_CLOCK_CYCTIME       (P_CLOCK_CYCTIME       ) //30ms
    ) seanetnackgenerator_timer_manager_v0p1_dut(
        .sys_clk                    (sys_clk                    ),//input   wire                                        
        .sys_rst                    (sys_rst                    ),//input   wire                                        
        //new timer request
        .i_sn                       (tmg_i_sn                       ),//input   wire    [15:0]                              
        .i_chksum                   (tmg_i_chksum                   ),//input   wire    [31:0]                                  
        .i_gen_req                  (tmg_i_gen_req                  ),//input   wire    [64+384-1:0]                            
        .i_valid                    (tmg_i_valid                    ),//input   wire                                        
        .o_ready                    (tmg_o_ready                    ),//output  wire                                        
        //con to stream manager
        .i_tmg_chksum               (i_tmg_chksum                   ),//input   wire    [31:0]                              
        .i_tmg_s_info               (i_tmg_s_info                   ),//input   wire    [511:0]                             
        .i_tmg_valid                (i_tmg_valid                    ),//input   wire                                        
        .o_tmg_ready                (o_tmg_ready                    ),//output  wire                                        
        .o_tmg_req_sn               (o_tmg_req_sn                   ),//output  wire    [15:0]                              
        .o_tmg_req_valid            (o_tmg_req_valid                ),//output  wire                                        
        .i_tmg_req_ready            (i_tmg_req_ready                ),//input   wire                                        
        //con to window manager
        .i_tmg_wnd                  (i_tmg_wnd                      ),//input   wire    [63:0]                              
        .i_tmg_wnd_valid            (i_tmg_wnd_valid                ),//input   wire                                            
        .o_tmg_wnd_ready            (o_tmg_wnd_ready                ),//output  wire                                            
        .o_tmg_wnd_req_sn           (o_tmg_wnd_req_sn               ),//output  wire    [15:0]                                      
        .o_tmg_wnd_req_valid        (o_tmg_wnd_req_valid            ),//output  wire                                                
        .i_tmg_wnd_req_ready        (i_tmg_wnd_req_ready            ),//input   wire                                        
        .o_timer_ot_sn              (o_timer_ot_sn              ),//output  wire    [15:0]                              
        .o_timer_ot_sn_vld          (o_timer_ot_sn_vld          ),//output  wire                                        
        .o_timer_ot_vld             (o_timer_ot_vld             ),//output  wire                                        
        //con to nack gen
        .o_nackgen_sn               (o_nackgen_sn               ),//output  wire    [15:0]                              
        .o_nackgen_req              (o_nackgen_req              ),//output  wire    [1024+32-1:0]                       
        .o_nackgen_vld              (o_nackgen_vld              ),//output  wire                                        
        .i_nackgen_rdy              (i_nackgen_rdy              ),//input   wire                        
        // axi4 
        .m_axi_awid                 (m01_axi_awid                 ),//output wire [AXI_ID_WIDTH-1:0]                      
        .m_axi_awaddr               (m01_axi_awaddr               ),//output wire [AXI_ADDR_WIDTH-1:0]                    
        .m_axi_awlen                (m01_axi_awlen                ),//output wire [7:0]                                   
        .m_axi_awsize               (m01_axi_awsize               ),//output wire [2:0]                                   
        .m_axi_awburst              (m01_axi_awburst              ),//output wire [1:0]                                       
        .m_axi_awlock               (m01_axi_awlock               ),//output wire                                         
        .m_axi_awcache              (m01_axi_awcache              ),//output wire [3:0]                                       
        .m_axi_awprot               (m01_axi_awprot               ),//output wire [2:0]                                   
        .m_axi_awvalid              (m01_axi_awvalid              ),//output wire                                             
        .m_axi_awready              (m01_axi_awready              ),//input  wire                                             
        .m_axi_wdata                (m01_axi_wdata                ),//output wire [AXI_DATA_WIDTH-1:0]                    
        .m_axi_wstrb                (m01_axi_wstrb                ),//output wire [AXI_STRB_WIDTH-1:0]                    
        .m_axi_wlast                (m01_axi_wlast                ),//output wire                                         
        .m_axi_wvalid               (m01_axi_wvalid               ),//output wire                                         
        .m_axi_wready               (m01_axi_wready               ),//input  wire                                         
        .m_axi_bid                  (m01_axi_bid                  ),//input  wire [AXI_ID_WIDTH-1:0]                      
        .m_axi_bresp                (m01_axi_bresp                ),//input  wire [1:0]                                   
        .m_axi_bvalid               (m01_axi_bvalid               ),//input  wire                                         
        .m_axi_bready               (m01_axi_bready               ),//output wire                                         
        .m_axi_arid                 (m01_axi_arid                 ),//output wire [AXI_ID_WIDTH-1:0]                      
        .m_axi_araddr               (m01_axi_araddr               ),//output wire [AXI_ADDR_WIDTH-1:0]                    
        .m_axi_arlen                (m01_axi_arlen                ),//output wire [7:0]                                   
        .m_axi_arsize               (m01_axi_arsize               ),//output wire [2:0]                                   
        .m_axi_arburst              (m01_axi_arburst              ),//output wire [1:0]                                       
        .m_axi_arlock               (m01_axi_arlock               ),//output wire                                         
        .m_axi_arcache              (m01_axi_arcache              ),//output wire [3:0]                                       
        .m_axi_arprot               (m01_axi_arprot               ),//output wire [2:0]                                   
        .m_axi_arvalid              (m01_axi_arvalid              ),//output wire                                             
        .m_axi_arready              (m01_axi_arready              ),//input  wire                                             
        .m_axi_rid                  (m01_axi_rid                  ),//input  wire [AXI_ID_WIDTH-1:0]                      
        .m_axi_rdata                (m01_axi_rdata                ),//input  wire [AXI_DATA_WIDTH-1:0]                    
        .m_axi_rresp                (m01_axi_rresp                ),//input  wire [1:0]                                   
        .m_axi_rlast                (m01_axi_rlast                ),//input  wire                                         
        .m_axi_rvalid               (m01_axi_rvalid               ),//input  wire                                         
        .m_axi_rready               (m01_axi_rready               ),//output wire                                         
        // connect to dfx port
        .i_cfg_reg0                 ({31'd0,dfx_sta_clear[2]}   ),//input   wire    [31:0]                              
        .i_cfg_reg1                 (r1_i_cfg_reg1              ),//input   wire    [31:0]                              
        .i_cfg_reg2                 (r1_i_cfg_reg2              ),//input   wire    [31:0]                              
        .i_cfg_reg3                 (32'd0                      ),//input   wire    [31:0]                              
        .o_sta_reg0                 (dfx_sta_0x08               ),//output  wire    [31:0]                              
        .o_sta_reg1                 (dfx_sta_0x09               ),//output  wire    [31:0]                              
        .o_sta_reg2                 (dfx_sta_0x0a               ),//output  wire    [31:0]                              
        .o_sta_reg3                 (dfx_sta_0x0b               ),//output  wire    [31:0]                              
        .o_sta_reg4                 (dfx_sta_0x0c               ),//output  wire    [31:0]                              
        .o_sta_reg5                 (dfx_sta_0x0d               ),//output  wire    [31:0]                              
        .o_sta_reg6                 (dfx_sta_0x0e               ),//output  wire    [31:0]                              
        .o_sta_reg7                 (dfx_sta_0x0f               ),//output  wire    [31:0]                              
        .o_sta_reg8                 (dfx_sta_0x10               ),//output  wire    [31:0]                              
        .o_sta_reg9                 (dfx_sta_0x11               ) //output  wire    [31:0]                              
    );
    
    seanetnackgenerator_nack_generator_v0p1 seanetnackgenerator_nack_generator_v0p1_dut(
        .sys_clk                    (sys_clk                    ),//input   wire                                        
        .sys_rst                    (sys_rst                    ),//input   wire                                        
        //con to nack gen
        .i_nackgen_sn               (i_nackgen_sn               ),//input   wire    [15:0]                              
        .i_nackgen_req              (i_nackgen_req              ),//input   wire    [1024+32-1:0]                       
        .i_nackgen_vld              (i_nackgen_vld              ),//input   wire                                        
        .o_nackgen_rdy              (o_nackgen_rdy              ),//output  wire                                        
        // output
        .o_nack_s_info              (o_nack_s_info              ),//output  wire    [511:0]                             
        .o_nack_npn                 (o_nack_npn                 ),//output  wire    [31:0]                              
        .o_nack_bitmap              (o_nack_bitmap              ),//output  wire    [63:0]                              
        .o_nack_valid               (o_nack_valid               ),//output  wire                                        
        .i_nack_ready               (i_nack_ready               ),//input   wire                                        
        // connect to dfx port
        .i_cfg_reg0                 ({31'd0,dfx_sta_clear[3]}   ),//input   wire    [31:0]                              
        .o_sta_reg0                 (dfx_sta_0x12               ),//output  wire    [31:0]                              
        .o_sta_reg1                 (dfx_sta_0x13               ) //output  wire    [31:0]                              
    );

    `ifndef AXI_INTERX_DISABLED
        axi_interconnect_nackgen axi_interconnect_nackgen_dut (
        .INTERCONNECT_ACLK                (sys_clk),  
        .INTERCONNECT_ARESETN             (~sys_rst),  
        .S00_AXI_ARESET_OUT_N             (m00_axi_aresetn   ),  
        .S00_AXI_ACLK                     (m00_axi_aclk   ),                  
        .S00_AXI_AWID                     (m00_axi_awid   ),                  
        .S00_AXI_AWADDR                   (m00_axi_awaddr ),              
        .S00_AXI_AWLEN                    (m00_axi_awlen  ),                
        .S00_AXI_AWSIZE                   (m00_axi_awsize ),              
        .S00_AXI_AWBURST                  (m00_axi_awburst),            
        .S00_AXI_AWLOCK                   (m00_axi_awlock ),              
        .S00_AXI_AWCACHE                  (m00_axi_awcache),            
        .S00_AXI_AWPROT                   (m00_axi_awprot ),              
        .S00_AXI_AWQOS                    (4'd0  ),                
        .S00_AXI_AWVALID                  (m00_axi_awvalid),            
        .S00_AXI_AWREADY                  (m00_axi_awready),            
        .S00_AXI_WDATA                    (m00_axi_wdata  ),                
        .S00_AXI_WSTRB                    (m00_axi_wstrb  ),                
        .S00_AXI_WLAST                    (m00_axi_wlast  ),                
        .S00_AXI_WVALID                   (m00_axi_wvalid ),              
        .S00_AXI_WREADY                   (m00_axi_wready ),              
        .S00_AXI_BID                      (m00_axi_bid    ),                    
        .S00_AXI_BRESP                    (m00_axi_bresp  ),                
        .S00_AXI_BVALID                   (m00_axi_bvalid ),              
        .S00_AXI_BREADY                   (m00_axi_bready ),              
        .S00_AXI_ARID                     (m00_axi_arid   ),                  
        .S00_AXI_ARADDR                   (m00_axi_araddr ),              
        .S00_AXI_ARLEN                    (m00_axi_arlen  ),                
        .S00_AXI_ARSIZE                   (m00_axi_arsize ),              
        .S00_AXI_ARBURST                  (m00_axi_arburst),            
        .S00_AXI_ARLOCK                   (m00_axi_arlock ),              
        .S00_AXI_ARCACHE                  (m00_axi_arcache),            
        .S00_AXI_ARPROT                   (m00_axi_arprot ),              
        .S00_AXI_ARQOS                    (4'd0  ),                
        .S00_AXI_ARVALID                  (m00_axi_arvalid),            
        .S00_AXI_ARREADY                  (m00_axi_arready),            
        .S00_AXI_RID                      (m00_axi_rid    ),                    
        .S00_AXI_RDATA                    (m00_axi_rdata  ),                
        .S00_AXI_RRESP                    (m00_axi_rresp  ),                
        .S00_AXI_RLAST                    (m00_axi_rlast  ),                
        .S00_AXI_RVALID                   (m00_axi_rvalid ),              
        .S00_AXI_RREADY                   (m00_axi_rready ),   

        .S01_AXI_ARESET_OUT_N             (m01_axi_aresetn),  
        .S01_AXI_ACLK                     (m01_axi_aclk   ),                  
        .S01_AXI_AWID                     (m01_axi_awid   ),           
        .S01_AXI_AWADDR                   (m01_axi_awaddr ),           
        .S01_AXI_AWLEN                    (m01_axi_awlen  ),           
        .S01_AXI_AWSIZE                   (m01_axi_awsize ),           
        .S01_AXI_AWBURST                  (m01_axi_awburst),           
        .S01_AXI_AWLOCK                   (m01_axi_awlock ),           
        .S01_AXI_AWCACHE                  (m01_axi_awcache),           
        .S01_AXI_AWPROT                   (m01_axi_awprot ),           
        .S01_AXI_AWQOS                    (4'd0  ),           
        .S01_AXI_AWVALID                  (m01_axi_awvalid),           
        .S01_AXI_AWREADY                  (m01_axi_awready),           
        .S01_AXI_WDATA                    (m01_axi_wdata  ),           
        .S01_AXI_WSTRB                    (m01_axi_wstrb  ),           
        .S01_AXI_WLAST                    (m01_axi_wlast  ),           
        .S01_AXI_WVALID                   (m01_axi_wvalid ),           
        .S01_AXI_WREADY                   (m01_axi_wready ),           
        .S01_AXI_BID                      (m01_axi_bid    ),           
        .S01_AXI_BRESP                    (m01_axi_bresp  ),           
        .S01_AXI_BVALID                   (m01_axi_bvalid ),           
        .S01_AXI_BREADY                   (m01_axi_bready ),           
        .S01_AXI_ARID                     (m01_axi_arid   ),           
        .S01_AXI_ARADDR                   (m01_axi_araddr ),           
        .S01_AXI_ARLEN                    (m01_axi_arlen  ),           
        .S01_AXI_ARSIZE                   (m01_axi_arsize ),           
        .S01_AXI_ARBURST                  (m01_axi_arburst),           
        .S01_AXI_ARLOCK                   (m01_axi_arlock ),           
        .S01_AXI_ARCACHE                  (m01_axi_arcache),           
        .S01_AXI_ARPROT                   (m01_axi_arprot ),           
        .S01_AXI_ARQOS                    (4'd0  ),           
        .S01_AXI_ARVALID                  (m01_axi_arvalid),           
        .S01_AXI_ARREADY                  (m01_axi_arready),           
        .S01_AXI_RID                      (m01_axi_rid    ),           
        .S01_AXI_RDATA                    (m01_axi_rdata  ),           
        .S01_AXI_RRESP                    (m01_axi_rresp  ),           
        .S01_AXI_RLAST                    (m01_axi_rlast  ),           
        .S01_AXI_RVALID                   (m01_axi_rvalid ),           
        .S01_AXI_RREADY                   (m01_axi_rready ),   


        .M00_AXI_ARESET_OUT_N             (m_axi_aresetn  ),  
        .M00_AXI_ACLK                     (m_axi_aclk     ),                  
        .M00_AXI_AWID                     (m_axi_awid     ),           
        .M00_AXI_AWADDR                   (m_axi_awaddr   ),           
        .M00_AXI_AWLEN                    (m_axi_awlen    ),           
        .M00_AXI_AWSIZE                   (m_axi_awsize   ),           
        .M00_AXI_AWBURST                  (m_axi_awburst  ),           
        .M00_AXI_AWLOCK                   (m_axi_awlock   ),           
        .M00_AXI_AWCACHE                  (m_axi_awcache  ),           
        .M00_AXI_AWPROT                   (m_axi_awprot   ),           
        .M00_AXI_AWQOS                    (m_axi_awqos    ),           
        .M00_AXI_AWVALID                  (m_axi_awvalid  ),           
        .M00_AXI_AWREADY                  (m_axi_awready  ),           
        .M00_AXI_WDATA                    (m_axi_wdata    ),           
        .M00_AXI_WSTRB                    (m_axi_wstrb    ),           
        .M00_AXI_WLAST                    (m_axi_wlast    ),           
        .M00_AXI_WVALID                   (m_axi_wvalid   ),           
        .M00_AXI_WREADY                   (m_axi_wready   ),           
        .M00_AXI_BID                      (m_axi_bid      ),           
        .M00_AXI_BRESP                    (m_axi_bresp    ),           
        .M00_AXI_BVALID                   (m_axi_bvalid   ),           
        .M00_AXI_BREADY                   (m_axi_bready   ),           
        .M00_AXI_ARID                     (m_axi_arid     ),           
        .M00_AXI_ARADDR                   (m_axi_araddr   ),           
        .M00_AXI_ARLEN                    (m_axi_arlen    ),           
        .M00_AXI_ARSIZE                   (m_axi_arsize   ),           
        .M00_AXI_ARBURST                  (m_axi_arburst  ),           
        .M00_AXI_ARLOCK                   (m_axi_arlock   ),           
        .M00_AXI_ARCACHE                  (m_axi_arcache  ),           
        .M00_AXI_ARPROT                   (m_axi_arprot   ),           
        .M00_AXI_ARQOS                    (m_axi_arqos    ),           
        .M00_AXI_ARVALID                  (m_axi_arvalid  ),           
        .M00_AXI_ARREADY                  (m_axi_arready  ),           
        .M00_AXI_RID                      (m_axi_rid      ),           
        .M00_AXI_RDATA                    (m_axi_rdata    ),           
        .M00_AXI_RRESP                    (m_axi_rresp    ),           
        .M00_AXI_RLAST                    (m_axi_rlast    ),           
        .M00_AXI_RVALID                   (m_axi_rvalid   ),           
        .M00_AXI_RREADY                   (m_axi_rready   )    
        );
    `else
        assign m00_axi_awqos = 4'd0;
        assign m00_axi_arqos = 4'd0;

        assign m01_axi_awqos = 4'd0;
        assign m01_axi_arqos = 4'd0;
    `endif
endmodule