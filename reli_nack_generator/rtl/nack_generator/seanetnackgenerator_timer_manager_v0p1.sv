//------------------------------------------------------------
// <seanetnackgenerator Module>
// Author: chenfeiyu@seanet.com.cn
// Date. : 2024/05/27
// Func  : seanetnackgenerator
//                      >>Instruction<<
// Port[System]---clock and reset
// Port[]---dma data cache
// Port[]---AXI4 port
// Port[Dfx]---DFX Port
//                       >>>Mention<<<
// Only used in SEANet PRJ.
// Unexpected usage will lead to ERROR.
//                      >>Version Log<<
//  [v0.1]
//      
//                                       @All Rights Reserved. 
//------------------------------------------------------------
module seanetnackgenerator_timer_manager_v0p1#(
    parameter BITMAP_BASE_ADDR      = 32'h0000_0000,
    parameter TIMER_BASE_ADDR       = 32'h0010_0000,
    parameter TIMER_WIDTH           = 512,
    parameter P_CLK_FHZ             = 300_000_000,//1s
    parameter P_1MS_COUNTER_VALUE   = P_CLK_FHZ/1000,//1ms
    parameter P_CLOCK_CYCTIME       = P_1MS_COUNTER_VALUE * 30,//30ms
    parameter INIT_JUMP_THRESH      = 16'd25000,
    //--------------------------------->>axi config<<------------------------------
    //AXI4 parameter
    parameter AXI_ID_WIDTH      = 4                     ,
    parameter AXI_ADDR_WIDTH    = 32                    ,
    parameter AXI_DATA_WIDTH    = 512                   ,
    parameter AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8      
)(
    input   wire                                        sys_clk                 ,
    input   wire                                        sys_rst                 ,
    //timer request
    input   wire    [15:0]                              i_sn	                ,
    input   wire    [31:0]                              i_chksum	            ,    
    input   wire    [64+384-1:0]                        i_gen_req	            ,    
    input   wire                                        i_valid	                ,
    output  wire                                        o_ready	                ,
    //con to stream manager
    input   wire    [31:0]                              i_tmg_chksum            ,
    input   wire    [511:0]                             i_tmg_s_info            ,
    input   wire                                        i_tmg_valid             ,
    output  wire                                        o_tmg_ready             ,
    output  wire    [15:0]                              o_tmg_req_sn            ,
    output  wire                                        o_tmg_req_valid         ,
    input   wire                                        i_tmg_req_ready         ,
     //con to window manager
    input   wire    [63:0]                              i_tmg_wnd               ,
    input   wire                                        i_tmg_wnd_valid         ,    
    output  wire                                        o_tmg_wnd_ready         ,    
    output  wire    [15:0]                              o_tmg_wnd_req_sn        ,        
    output  wire                                        o_tmg_wnd_req_valid     ,        
    input   wire                                        i_tmg_wnd_req_ready     ,
    output  wire    [15:0]                              o_timer_ot_sn           ,
    output  wire                                        o_timer_ot_sn_vld       ,
    output  wire                                        o_timer_ot_vld          ,
    //con to nack gen
    output  wire    [15:0]                              o_nackgen_sn            ,
    output  wire    [1024+32-1:0]                       o_nackgen_req           ,
    output  wire                                        o_nackgen_vld           ,
    input   wire                                        i_nackgen_rdy           ,
    // axi4 
    output wire [AXI_ID_WIDTH-1:0]                      m_axi_awid              ,
    output wire [AXI_ADDR_WIDTH-1:0]                    m_axi_awaddr            ,
    output wire [7:0]                                   m_axi_awlen             ,
    output wire [2:0]                                   m_axi_awsize            ,
    output wire [1:0]                                   m_axi_awburst           ,    
    output wire                                         m_axi_awlock            ,
    output wire [3:0]                                   m_axi_awcache           ,    
    output wire [2:0]                                   m_axi_awprot            ,
    output wire                                         m_axi_awvalid           ,    
    input  wire                                         m_axi_awready           ,    
    output wire [AXI_DATA_WIDTH-1:0]                    m_axi_wdata             ,
    output wire [AXI_STRB_WIDTH-1:0]                    m_axi_wstrb             ,
    output wire                                         m_axi_wlast             ,
    output wire                                         m_axi_wvalid            ,
    input  wire                                         m_axi_wready            ,
    input  wire [AXI_ID_WIDTH-1:0]                      m_axi_bid               ,
    input  wire [1:0]                                   m_axi_bresp             ,
    input  wire                                         m_axi_bvalid            ,
    output wire                                         m_axi_bready            ,
    output wire [AXI_ID_WIDTH-1:0]                      m_axi_arid              ,
    output wire [AXI_ADDR_WIDTH-1:0]                    m_axi_araddr            ,
    output wire [7:0]                                   m_axi_arlen             ,
    output wire [2:0]                                   m_axi_arsize            ,
    output wire [1:0]                                   m_axi_arburst           ,    
    output wire                                         m_axi_arlock            ,
    output wire [3:0]                                   m_axi_arcache           ,    
    output wire [2:0]                                   m_axi_arprot            ,
    output wire                                         m_axi_arvalid           ,    
    input  wire                                         m_axi_arready           ,    
    input  wire [AXI_ID_WIDTH-1:0]                      m_axi_rid               ,
    input  wire [AXI_DATA_WIDTH-1:0]                    m_axi_rdata             ,
    input  wire [1:0]                                   m_axi_rresp             ,
    input  wire                                         m_axi_rlast             ,
    input  wire                                         m_axi_rvalid            ,
    output wire                                         m_axi_rready            ,
    // connect to dfx port
    input   wire    [31:0]                              i_cfg_reg0              ,
    input   wire    [31:0]                              i_cfg_reg1              ,
    input   wire    [31:0]                              i_cfg_reg2              ,
    input   wire    [31:0]                              i_cfg_reg3              ,
    output  wire    [31:0]                              o_sta_reg0              ,
    output  wire    [31:0]                              o_sta_reg1              ,
    output  wire    [31:0]                              o_sta_reg2              ,
    output  wire    [31:0]                              o_sta_reg3              ,
    output  wire    [31:0]                              o_sta_reg4              ,
    output  wire    [31:0]                              o_sta_reg5              ,
    output  wire    [31:0]                              o_sta_reg6              ,
    output  wire    [31:0]                              o_sta_reg7              ,
    output  wire    [31:0]                              o_sta_reg8              ,
    output  wire    [31:0]                              o_sta_reg9               
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
        r0_i_cfg_reg0 <=    i_cfg_reg0;
        r0_i_cfg_reg1 <=    i_cfg_reg1;
        r0_i_cfg_reg2 <=    i_cfg_reg2;
        r0_i_cfg_reg3 <=    i_cfg_reg3;
        r1_i_cfg_reg0 <= r0_i_cfg_reg0;
        r1_i_cfg_reg1 <= r0_i_cfg_reg1;
        r1_i_cfg_reg2 <= r0_i_cfg_reg2;
        r1_i_cfg_reg3 <= r0_i_cfg_reg3;
    end 
reg     [1:0]   dfx_sta_clear=2'd0;
always@(posedge sys_clk)
if(sys_rst)
    dfx_sta_clear <= 2'd0;
else
    dfx_sta_clear <= {2{r1_i_cfg_reg0[0]}};


wire [15:0]                     jump_posedge_threshold           ;
wire [AXI_ID_WIDTH-1:0]         m00_axi_arid                     ;
wire [AXI_ADDR_WIDTH-1:0]       m00_axi_araddr                   ;
wire [7:0]                      m00_axi_arlen                    ;
wire [2:0]                      m00_axi_arsize                   ;
wire [1:0]                      m00_axi_arburst                  ;
wire                            m00_axi_arlock                   ;
wire [3:0]                      m00_axi_arcache                  ;
wire [2:0]                      m00_axi_arprot                   ;
wire                            m00_axi_arvalid                  ;
wire                            m00_axi_arready                  ;
wire [AXI_ID_WIDTH-1:0]         m00_axi_rid                      ;
wire [AXI_DATA_WIDTH-1:0]       m00_axi_rdata                    ;
wire [1:0]                      m00_axi_rresp                    ;
wire                            m00_axi_rlast                    ;
wire                            m00_axi_rvalid                   ;
wire                            m00_axi_rready                   ;

wire [AXI_ID_WIDTH-1:0]         m01_axi_arid                     ;
wire [AXI_ADDR_WIDTH-1:0]       m01_axi_araddr                   ;
wire [7:0]                      m01_axi_arlen                    ;
wire [2:0]                      m01_axi_arsize                   ;
wire [1:0]                      m01_axi_arburst                  ;
wire                            m01_axi_arlock                   ;
wire [3:0]                      m01_axi_arcache                  ;
wire [2:0]                      m01_axi_arprot                   ;
wire                            m01_axi_arvalid                  ;
wire                            m01_axi_arready                  ;
wire [AXI_ID_WIDTH-1:0]         m01_axi_rid                      ;
wire [AXI_DATA_WIDTH-1:0]       m01_axi_rdata                    ;
wire [1:0]                      m01_axi_rresp                    ;
wire                            m01_axi_rlast                    ;
wire                            m01_axi_rvalid                   ;
wire                            m01_axi_rready                   ;

wire    [TIMER_WIDTH-1:0]       o_timer_wrreq                       ;
wire                            o_timer_wrreq_vld                   ;
wire                            i_timer_wrreq_rdy                   ;
wire    [TIMER_WIDTH-1:0]       i_timer_alarm                       ;
wire                            i_timer_alarm_vld                   ;
wire                            o_timer_alarm_rdy                   ;
wire    [TIMER_WIDTH-1:0]       i_timer_alarm_pp                       ;
wire                            i_timer_alarm_pp_vld                   ;
wire                            o_timer_alarm_pp_rdy                   ;
ipbase_intf_pipeline_d2#(
    .DATA_WIDTH (512)
)ipbase_intf_pipeline_d2_dut(
    .clk        (sys_clk),//input   wire                        
    .rst        (sys_rst),//input   wire                        
    .id         (i_timer_alarm),//input   wire    [DATA_WIDTH-1:0]    
    .id_vld     (i_timer_alarm_vld),//input   wire                        
    .id_rdy     (o_timer_alarm_rdy),//output  wire                        
    .od         (i_timer_alarm_pp),//output  wire    [DATA_WIDTH-1:0]    
    .od_vld     (i_timer_alarm_pp_vld),//output  wire                        
    .od_rdy     (o_timer_alarm_pp_rdy) //input   wire                        
);
seanetnackgenerator_timer_ctrlcore #(
    .BITMAP_BASE_ADDR(BITMAP_BASE_ADDR),
    .AXI_ID_SET(1)
)seanetnackgenerator_timer_ctrlcore_dut(
    .sys_clk                        (sys_clk                        ),//input   wire                                        
    .sys_rst                        (sys_rst                        ),//input   wire                                        
    //new timer request
    .i_sn                           (i_sn                           ),//input   wire    [15:0]                              
    .i_chksum                       (i_chksum                       ),//input   wire    [31:0]                                  
    .i_gen_req                      (i_gen_req                      ),//input   wire    [64+384-1:0]                            
    .i_valid                        (i_valid                        ),//input   wire                                        
    .o_ready                        (o_ready                        ),//output  wire                                        
    //con to stream manager
    .i_tmg_chksum                   (i_tmg_chksum                   ),//input   wire    [31:0]                              
    .i_tmg_s_info                   (i_tmg_s_info                   ),//input   wire    [511:0]                             
    .i_tmg_valid                    (i_tmg_valid                    ),//input   wire                                        
    .o_tmg_ready                    (o_tmg_ready                    ),//output  wire                                        
    .o_tmg_req_sn                   (o_tmg_req_sn                   ),//output  wire    [15:0]                              
    .o_tmg_req_valid                (o_tmg_req_valid                ),//output  wire                                        
    .i_tmg_req_ready                (i_tmg_req_ready                ),//input   wire                                        
    //con to window manager
    .i_tmg_wnd                      (i_tmg_wnd                      ),//input   wire    [63:0]                              
    .i_tmg_wnd_valid                (i_tmg_wnd_valid                ),//input   wire                                            
    .o_tmg_wnd_ready                (o_tmg_wnd_ready                ),//output  wire                                            
    .o_tmg_wnd_req_sn               (o_tmg_wnd_req_sn               ),//output  wire    [15:0]                                      
    .o_tmg_wnd_req_valid            (o_tmg_wnd_req_valid            ),//output  wire                                                
    .i_tmg_wnd_req_ready            (i_tmg_wnd_req_ready            ),//input   wire                                        
    //////rehit
    .o_timer_ot_sn                  (o_timer_ot_sn                  ),//output  wire    [15:0]                              
    .o_timer_ot_sn_vld              (o_timer_ot_sn_vld              ),//output  wire                                        
    .o_timer_ot_vld                 (o_timer_ot_vld                 ),//output  wire                                        
    //con to timer queue manager
    //////write timer
    .o_timer_wrreq                  (o_timer_wrreq                  ),//output  wire    [TIMER_WIDTH-1:0]                   
    .o_timer_wrreq_vld              (o_timer_wrreq_vld              ),//output  wire                                        
    .i_timer_wrreq_rdy              (i_timer_wrreq_rdy              ),//input   wire                                        
    //////read alarm
    .i_timer_alarm                  (i_timer_alarm_pp               ),//input   wire    [TIMER_WIDTH-1:0]                   
    .i_timer_alarm_vld              (i_timer_alarm_pp_vld           ),//input   wire                                        
    .o_timer_alarm_rdy              (o_timer_alarm_pp_rdy           ),//output  wire                                        
    //con to nack gen
    .o_nackgen_sn                   (o_nackgen_sn                   ),//output  wire    [15:0]                              
    .o_nackgen_req                  (o_nackgen_req                  ),//output  wire    [1024+32-1:0]                       
    .o_nackgen_vld                  (o_nackgen_vld                  ),//output  wire                                        
    .i_nackgen_rdy                  (i_nackgen_rdy                  ),//input   wire                                        
    //axi 4 (use to read bitmap)
    .m_axi_arid                     (m01_axi_arid                     ),//output wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_araddr                   (m01_axi_araddr                   ),//output wire [AXI_ADDR_WIDTH-1:0]                    
    .m_axi_arlen                    (m01_axi_arlen                    ),//output wire [7:0]                                   
    .m_axi_arsize                   (m01_axi_arsize                   ),//output wire [2:0]                                   
    .m_axi_arburst                  (m01_axi_arburst                  ),//output wire [1:0]                                       
    .m_axi_arlock                   (m01_axi_arlock                   ),//output wire                                         
    .m_axi_arcache                  (m01_axi_arcache                  ),//output wire [3:0]                                       
    .m_axi_arprot                   (m01_axi_arprot                   ),//output wire [2:0]                                   
    .m_axi_arvalid                  (m01_axi_arvalid                  ),//output wire                                             
    .m_axi_arready                  (m01_axi_arready                  ),//input  wire                                             
    .m_axi_rid                      (m01_axi_rid                      ),//input  wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_rdata                    (m01_axi_rdata                    ),//input  wire [AXI_DATA_WIDTH-1:0]                    
    .m_axi_rresp                    (m01_axi_rresp                    ),//input  wire [1:0]                                   
    .m_axi_rlast                    (m01_axi_rlast                    ),//input  wire                                         
    .m_axi_rvalid                   (m01_axi_rvalid                   ),//input  wire                                         
    .m_axi_rready                   (m01_axi_rready                   ),//output wire                                         
    // connect to dfx port      
    .i_cfg_reg0                     ({31'd0,dfx_sta_clear[0]}),//input   wire    [31:0]                              
    .o_sta_reg0                     (o_sta_reg0),//output  wire    [31:0]                              
    .o_sta_reg1                     (o_sta_reg1),//output  wire    [31:0]                              
    .o_sta_reg2                     (o_sta_reg2),//output  wire    [31:0]                              
    .o_sta_reg3                     (o_sta_reg3),//output  wire    [31:0]                              
    .o_sta_reg4                     (o_sta_reg4),//output  wire    [31:0]                              
    .o_sta_reg5                     (o_sta_reg5),//output  wire    [31:0]                              
    .o_sta_reg6                     (o_sta_reg6),//output  wire    [31:0]                              
    .o_sta_reg7                     (o_sta_reg7) //output  wire    [31:0]                              
);

reg     [31:0]      ms_counter=32'd0;
always@(posedge sys_clk)
if(sys_rst)
    ms_counter <= 32'd0;
else if(ms_counter == P_1MS_COUNTER_VALUE)
    ms_counter <= 32'd0;
else
    ms_counter <= ms_counter + 1;
//`define USED_FIXED_PARAM
wire    [7:0]       clock_cyctime;
reg     [7:0]       ms_clock=8'd0;
always@(posedge sys_clk)
if(sys_clk)
    ms_clock <= 8'd0;
else if(ms_clock == clock_cyctime && ms_counter == P_1MS_COUNTER_VALUE)
    ms_clock <= 8'd0;
else if(ms_counter == P_1MS_COUNTER_VALUE)
    ms_clock <= ms_clock + 1;
else
    ms_clock <= ms_clock;
nack_safe_timer#(
    .TIMEOUT_EVENT_WIDTH    (512                ),
    .TIMEOUT_MS_WIDTH       (8                  ),
    .TIMER_ENTRY_NUM        (512                ), 
    .TIMER_SLOT_NUM         (512                ),
    .MS_ENTRY_NUM           (8                  ),
    .TIMER_START_ADDR       (TIMER_BASE_ADDR    ),
    .AXI_DATA_WIDTH         (512                ),
    .AXI_ADDR_WIDTH         (32                 ),
    .AXI_ID_WIDTH           (4                  )
)nack_safe_timer_dut(
    /*
     * System signal
     */
    .clk                            (sys_clk),//input  wire                                                 
    .rst                            (sys_rst),//input  wire                                                 
    .jump_posedge_threshold         (jump_posedge_threshold),//input  wire [16-1:0]                                          //200*125=25000, fit 200Mhz
    /*
     * input  timeout
     */
    .s_timeout_eventms              ({o_timer_wrreq,ms_clock       }),//input  wire [TIMEOUT_EVENT_WIDTH + TIMEOUT_MS_WIDTH-1:0]    
    .s_timeout_valid                (o_timer_wrreq_vld              ),//input  wire                                                 
    .s_timeout_ready                (i_timer_wrreq_rdy              ),//output wire                                                     
    /*
     * output timeout
     */
    .m_timeout_event                (i_timer_alarm                  ),//output wire [TIMEOUT_EVENT_WIDTH-1:0]                       
    .m_timeout_valid                (i_timer_alarm_vld              ),//output wire                                                 
    .m_timeout_ready                (o_timer_alarm_rdy              ),//input  wire                                                 
    /*
     * AXI master interface
     */
    .m_axi_awid                     (m_axi_awid                     ),//output wire [AXI_ID_WIDTH-1:0]                              
    .m_axi_awaddr                   (m_axi_awaddr                   ),//output wire [AXI_ADDR_WIDTH-1:0]                            
    .m_axi_awlen                    (m_axi_awlen                    ),//output wire [7:0]                                           
    .m_axi_awsize                   (m_axi_awsize                   ),//output wire [2:0]                                           
    .m_axi_awburst                  (m_axi_awburst                  ),//output wire [1:0]                                           
    .m_axi_awlock                   (m_axi_awlock                   ),//output wire                                                 
    .m_axi_awcache                  (m_axi_awcache                  ),//output wire [3:0]                                           
    .m_axi_awprot                   (m_axi_awprot                   ),//output wire [2:0]                                           
    .m_axi_awqos                    (m_axi_awqos                    ),//output wire [3:0]                                           
    .m_axi_awvalid                  (m_axi_awvalid                  ),//output wire                                                 
    .m_axi_awready                  (m_axi_awready                  ),//input  wire                                                 
    .m_axi_wdata                    (m_axi_wdata                    ),//output wire [AXI_DATA_WIDTH-1:0]                            
    .m_axi_wstrb                    (m_axi_wstrb                    ),//output wire [AXI_DATA_WIDTH/8-1:0]                          
    .m_axi_wlast                    (m_axi_wlast                    ),//output wire                                                 
    .m_axi_wvalid                   (m_axi_wvalid                   ),//output wire                                                 
    .m_axi_wready                   (m_axi_wready                   ),//input  wire                                                 
    .m_axi_bid                      (m_axi_bid                      ),//input  wire [AXI_ID_WIDTH-1:0]                              
    .m_axi_bresp                    (m_axi_bresp                    ),//input  wire [1:0]                                           
    .m_axi_bvalid                   (m_axi_bvalid                   ),//input  wire                                                 
    .m_axi_bready                   (m_axi_bready                   ),//output wire                                                 
    .m_axi_arid                     (m00_axi_arid                   ),//output wire [AXI_ID_WIDTH-1:0]                              
    .m_axi_araddr                   (m00_axi_araddr                 ),//output wire [AXI_ADDR_WIDTH-1:0]                            
    .m_axi_arlen                    (m00_axi_arlen                  ),//output wire [7:0]                                           
    .m_axi_arsize                   (m00_axi_arsize                 ),//output wire [2:0]                                           
    .m_axi_arburst                  (m00_axi_arburst                ),//output wire [1:0]                                           
    .m_axi_arlock                   (m00_axi_arlock                 ),//output wire                                                 
    .m_axi_arcache                  (m00_axi_arcache                ),//output wire [3:0]                                           
    .m_axi_arprot                   (m00_axi_arprot                 ),//output wire [2:0]                                           
    .m_axi_arqos                    (m00_axi_arqos                  ),//output wire [3:0]                                           
    .m_axi_arvalid                  (m00_axi_arvalid                ),//output wire                                                 
    .m_axi_arready                  (m00_axi_arready                ),//input  wire                                                 
    .m_axi_rid                      (m00_axi_rid                    ),//input  wire [AXI_ID_WIDTH-1:0]                              
    .m_axi_rdata                    (m00_axi_rdata                  ),//input  wire [AXI_DATA_WIDTH-1:0]                            
    .m_axi_rresp                    (m00_axi_rresp                  ),//input  wire [1:0]                                           
    .m_axi_rlast                    (m00_axi_rlast                  ),//input  wire                                                 
    .m_axi_rvalid                   (m00_axi_rvalid                 ),//input  wire                                                 
    .m_axi_rready                   (m00_axi_rready                 ),//output wire                                                 
//csr
    .csr_wr_addr                    (),//input  wire [CSR_ADDR_WIDTH-1:0]        
    .csr_wr_data                    (),//input  wire [CSR_DATA_WIDTH-1:0]        
    .csr_wr_strb                    (),//input  wire [CSR_STRB_WIDTH-1:0]            
    .csr_wr_en                      (),//input  wire                             
    .csr_wr_wait                    (),//output wire                             
    .csr_wr_ack                     (),//output wire                             
    .csr_rd_addr                    (),//input  wire [CSR_ADDR_WIDTH-1:0]        
    .csr_rd_en                      (),//input  wire                             
    .csr_rd_data                    (),//output wire [CSR_DATA_WIDTH-1:0]        
    .csr_rd_wait                    (),//output wire                             
    .csr_rd_ack                     () //output wire                             
);

ipbase_intf_axi_arbit2to1_rd_chn_simplified_v0p1#(
    //------------------------------->>arbit config<<------------------------------
    .S00_AXI_ID_SET    (0),
    .S01_AXI_ID_SET    (1),
    //--------------------------------->>axi config<<------------------------------
    //AXI4 parameter
    .AXI_ID_WIDTH      (4                     ),
    .AXI_ADDR_WIDTH    (32                    ),
    .AXI_DATA_WIDTH    (512                   ),
    .AXI_STRB_WIDTH    (AXI_DATA_WIDTH/8      )
)ipbase_intf_axi_arbit2to1prio_simplified_dut(
    .sys_clk                        (sys_clk),//input   wire                                        
    .sys_rst                        (sys_rst),//input   wire                                        
    //s00(id0)
    .s00_axi_arid                   (m00_axi_arid                     ),//input  wire [AXI_ID_WIDTH-1:0]                      
    .s00_axi_araddr                 (m00_axi_araddr                   ),//input  wire [AXI_ADDR_WIDTH-1:0]                    
    .s00_axi_arlen                  (m00_axi_arlen                    ),//input  wire [7:0]                                   
    .s00_axi_arsize                 (m00_axi_arsize                   ),//input  wire [2:0]                                   
    .s00_axi_arburst                (m00_axi_arburst                  ),//input  wire [1:0]                                       
    .s00_axi_arlock                 (m00_axi_arlock                   ),//input  wire                                         
    .s00_axi_arcache                (m00_axi_arcache                  ),//input  wire [3:0]                                       
    .s00_axi_arprot                 (m00_axi_arprot                   ),//input  wire [2:0]                                   
    .s00_axi_arvalid                (m00_axi_arvalid                  ),//input  wire                                             
    .s00_axi_arready                (m00_axi_arready                  ),//output wire                                             
    .s00_axi_rid                    (m00_axi_rid                      ),//output wire [AXI_ID_WIDTH-1:0]                      
    .s00_axi_rdata                  (m00_axi_rdata                    ),//output wire [AXI_DATA_WIDTH-1:0]                    
    .s00_axi_rresp                  (m00_axi_rresp                    ),//output wire [1:0]                                   
    .s00_axi_rlast                  (m00_axi_rlast                    ),//output wire                                         
    .s00_axi_rvalid                 (m00_axi_rvalid                   ),//output wire                                         
    .s00_axi_rready                 (m00_axi_rready                   ),//input  wire                                         
    //s01(id1)
    .s01_axi_arid                   (m01_axi_arid                     ),//input  wire [AXI_ID_WIDTH-1:0]                      
    .s01_axi_araddr                 (m01_axi_araddr                   ),//input  wire [AXI_ADDR_WIDTH-1:0]                    
    .s01_axi_arlen                  (m01_axi_arlen                    ),//input  wire [7:0]                                   
    .s01_axi_arsize                 (m01_axi_arsize                   ),//input  wire [2:0]                                   
    .s01_axi_arburst                (m01_axi_arburst                  ),//input  wire [1:0]                                       
    .s01_axi_arlock                 (m01_axi_arlock                   ),//input  wire                                         
    .s01_axi_arcache                (m01_axi_arcache                  ),//input  wire [3:0]                                       
    .s01_axi_arprot                 (m01_axi_arprot                   ),//input  wire [2:0]                                   
    .s01_axi_arvalid                (m01_axi_arvalid                  ),//input  wire                                             
    .s01_axi_arready                (m01_axi_arready                  ),//output wire                                             
    .s01_axi_rid                    (m01_axi_rid                      ),//output wire [AXI_ID_WIDTH-1:0]                      
    .s01_axi_rdata                  (m01_axi_rdata                    ),//output wire [AXI_DATA_WIDTH-1:0]                    
    .s01_axi_rresp                  (m01_axi_rresp                    ),//output wire [1:0]                                   
    .s01_axi_rlast                  (m01_axi_rlast                    ),//output wire                                         
    .s01_axi_rvalid                 (m01_axi_rvalid                   ),//output wire                                         
    .s01_axi_rready                 (m01_axi_rready                   ),//input  wire                                         
    // axi4 master
    .m_axi_arid                     (m_axi_arid                     ),//output wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_araddr                   (m_axi_araddr                   ),//output wire [AXI_ADDR_WIDTH-1:0]                    
    .m_axi_arlen                    (m_axi_arlen                    ),//output wire [7:0]                                   
    .m_axi_arsize                   (m_axi_arsize                   ),//output wire [2:0]                                   
    .m_axi_arburst                  (m_axi_arburst                  ),//output wire [1:0]                                       
    .m_axi_arlock                   (m_axi_arlock                   ),//output wire                                         
    .m_axi_arcache                  (m_axi_arcache                  ),//output wire [3:0]                                       
    .m_axi_arprot                   (m_axi_arprot                   ),//output wire [2:0]                                   
    .m_axi_arvalid                  (m_axi_arvalid                  ),//output wire                                             
    .m_axi_arready                  (m_axi_arready                  ),//input  wire                                             
    .m_axi_rid                      (m_axi_rid                      ),//input  wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_rdata                    (m_axi_rdata                    ),//input  wire [AXI_DATA_WIDTH-1:0]                    
    .m_axi_rresp                    (m_axi_rresp                    ),//input  wire [1:0]                                   
    .m_axi_rlast                    (m_axi_rlast                    ),//input  wire                                         
    .m_axi_rvalid                   (m_axi_rvalid                   ),//input  wire                                         
    .m_axi_rready                   (m_axi_rready                   ),//output wire                                         
    // connect to dfx port  
    .dfx_cfg0                       ({31'd0,dfx_sta_clear[0]}),//input  wire [31:0]
    .dfx_sta0                       (o_sta_reg8),//output wire [31:0]                                  
    .dfx_sta1                       (o_sta_reg9),//output wire [31:0]                                  
    .dfx_sta2                       (),//output wire [31:0]                                  
    .dfx_sta3                       () //output wire [31:0]                                  
); 
//----------------------------------------------------------------------------------
//
//\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
//  <DFX Config>
//----------------------------------------------------------------------------------

reg     [15:0]          r_jump_posedge_threshold=INIT_JUMP_THRESH;
wire    [15:0]          c_jump_posedge_threshold;
assign c_jump_posedge_threshold = r1_i_cfg_reg1[31] ? r1_i_cfg_reg1[15:0] : INIT_JUMP_THRESH;
always@(posedge sys_clk)
if(sys_rst)
    r_jump_posedge_threshold <= INIT_JUMP_THRESH;
else
    r_jump_posedge_threshold <= c_jump_posedge_threshold;

wire    [7:0]           c_clock_cyctime;
reg     [7:0]           r_clock_cyctime=P_CLOCK_CYCTIME;
assign c_clock_cyctime = r1_i_cfg_reg2[31] ? r1_i_cfg_reg2[7:0] : P_CLOCK_CYCTIME;
always@(posedge sys_clk)
if(sys_rst)
    r_clock_cyctime <= 8'd0;
else
    r_clock_cyctime <= c_clock_cyctime;

`ifdef USED_FIXED_PARAM
    assign clock_cyctime            = P_CLOCK_CYCTIME;
    assign jump_posedge_threshold   = INIT_JUMP_THRESH;
`else
    assign clock_cyctime            = r_clock_cyctime;
    assign jump_posedge_threshold   = r_jump_posedge_threshold;
`endif
//\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
//  <DFX Status>
//----------------------------------------------------------------------------------

endmodule