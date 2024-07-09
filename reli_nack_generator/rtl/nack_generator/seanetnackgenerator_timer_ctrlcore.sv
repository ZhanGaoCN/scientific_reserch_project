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
module seanetnackgenerator_timer_ctrlcore#(
    parameter BITMAP_BASE_ADDR = 32'h0000_0000,
    parameter TIMER_WIDTH = 512,
    //--------------------------------->>axi config<<------------------------------
    //AXI4 parameter
    parameter AXI_ID_SET        = 0                     ,
    parameter AXI_ID_WIDTH      = 4                     ,
    parameter AXI_ADDR_WIDTH    = 32                    ,
    parameter AXI_DATA_WIDTH    = 512                   ,
    parameter AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8      
)(
    input   wire                                        sys_clk                 ,
    input   wire                                        sys_rst                 ,
    //new timer request
    input   wire    [15:0]                              i_sn                    ,
    input   wire    [31:0]                              i_chksum                ,    
    input   wire    [64+384-1:0]                        i_gen_req               ,    
    input   wire                                        i_valid                 ,
    output  wire                                        o_ready                 ,
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
    //////rehit
    output  wire    [15:0]                              o_timer_ot_sn           ,
    output  wire                                        o_timer_ot_sn_vld       ,
    output  wire                                        o_timer_ot_vld          ,
    //con to timer queue manager
    //////write timer
    output  wire    [TIMER_WIDTH-1:0]                   o_timer_wrreq           ,
    output  wire                                        o_timer_wrreq_vld       ,
    input   wire                                        i_timer_wrreq_rdy       ,
    //////read alarm
    input   wire    [TIMER_WIDTH-1:0]                   i_timer_alarm           ,
    input   wire                                        i_timer_alarm_vld       ,
    output  wire                                        o_timer_alarm_rdy       ,
    //con to nack gen
    output  wire    [15:0]                              o_nackgen_sn            ,
    output  wire    [1024+32-1:0]                       o_nackgen_req           ,
    output  wire                                        o_nackgen_vld           ,
    input   wire                                        i_nackgen_rdy           ,
    //axi 4 (use to read bitmap)
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
    output  wire    [31:0]                              o_sta_reg0              ,                
    output  wire    [31:0]                              o_sta_reg1              ,                
    output  wire    [31:0]                              o_sta_reg2              ,                
    output  wire    [31:0]                              o_sta_reg3              ,                
    output  wire    [31:0]                              o_sta_reg4              ,                
    output  wire    [31:0]                              o_sta_reg5              ,                
    output  wire    [31:0]                              o_sta_reg6              ,                
    output  wire    [31:0]                              o_sta_reg7                               
);
reg     [1:0]   dfx_sta_clear=2'd0;
always@(posedge sys_clk)
if(sys_rst)
    dfx_sta_clear <= 2'd0;
else
    dfx_sta_clear <= {2{i_cfg_reg0[0]}};
wire    [15:0]          rld_tmg_sn     ;
wire    [15:0]          rld_tmg_cnt    ;
wire    [31:0]          rld_tmg_chksum ;
wire    [64+384-1:0]    rld_tmg_gen_req;
wire                    rld_tmg_valid  ;
wire                    rld_tmg_ready  ;
seanetnackgenerator_timer_gencore seanetnackgenerator_timer_gencore_dut(
    .sys_clk                    (sys_clk                    ),//input   wire                                        
    .sys_rst                    (sys_rst                    ),//input   wire                                        
    //timer request(new)
    .i_new_tmg_sn               (i_sn                       ),//input   wire    [15:0]                              
    .i_new_tmg_chksum           (i_chksum                   ),//input   wire    [31:0]                                 
    .i_new_tmg_gen_req          (i_gen_req                  ),//input   wire    [64+384-1:0]                            
    .i_new_tmg_valid            (i_valid                    ),//input   wire                                        
    .o_new_tmg_ready            (o_ready                    ),//output  wire                                        
    //timer request(reload)
    .i_rld_tmg_sn               (rld_tmg_sn                 ),//input   wire    [15:0]                              
    .i_rld_tmg_cnt              (rld_tmg_cnt                ),//input   wire    [15:0]                               //rld 
    .i_rld_tmg_chksum           (rld_tmg_chksum             ),//input   wire    [31:0]                                
    .i_rld_tmg_gen_req          (rld_tmg_gen_req            ),//input   wire    [64+384-1:0]                            
    .i_rld_tmg_valid            (rld_tmg_valid              ),//input   wire                                        
    .o_rld_tmg_ready            (rld_tmg_ready              ),//output  wire                                        
    //con to timer queue manager
    //////write timer
    .o_timer_wrreq              (o_timer_wrreq              ),//output  wire    [512        -1:0]                   
    .o_timer_wrreq_vld          (o_timer_wrreq_vld          ),//output  wire                                        
    .i_timer_wrreq_rdy          (i_timer_wrreq_rdy          ),//input   wire                                        
    // connect to dfx port      
    .i_cfg_reg0                 ({31'd0,dfx_sta_clear[0]}),//input   wire    [31:0]                              
    .o_sta_reg0                 (o_sta_reg0),//output  wire    [31:0]                                
    .o_sta_reg1                 (o_sta_reg1),//output  wire    [31:0]                                
    .o_sta_reg2                 (o_sta_reg2),//output  wire    [31:0]                                
    .o_sta_reg3                 (o_sta_reg3) //output  wire    [31:0]                                
);

seanetnackgenerator_timer_compcore#(
    .BITMAP_BASE_ADDR(BITMAP_BASE_ADDR),
    .AXI_ID_SET (AXI_ID_SET)
) seanetnackgenerator_timer_compcore_dut(
    .sys_clk                    (sys_clk                    ),//input   wire                                        
    .sys_rst                    (sys_rst                    ),//input   wire                                        
    //con to timer queue manager
    //////read alarm
    .i_timer_alarm              (i_timer_alarm              ),//input   wire    [512        -1:0]                   
    .i_timer_alarm_vld          (i_timer_alarm_vld          ),//input   wire                                        
    .o_timer_alarm_rdy          (o_timer_alarm_rdy          ),//output  wire                                        
    //con to stream manager
    .i_tmg_chksum               (i_tmg_chksum               ),//input   wire    [31:0]                              
    .i_tmg_s_info               (i_tmg_s_info               ),//input   wire    [511:0]                             
    .i_tmg_valid                (i_tmg_valid                ),//input   wire                                        
    .o_tmg_ready                (o_tmg_ready                ),//output  wire                                        
    .o_tmg_req_sn               (o_tmg_req_sn               ),//output  wire    [15:0]                              
    .o_tmg_req_valid            (o_tmg_req_valid            ),//output  wire                                        
    .i_tmg_req_ready            (i_tmg_req_ready            ),//input   wire                                        
    //con to window manager
    .i_tmg_wnd                  (i_tmg_wnd                  ),//input   wire    [63:0]                              
    .i_tmg_wnd_valid            (i_tmg_wnd_valid            ),//input   wire                                            
    .o_tmg_wnd_ready            (o_tmg_wnd_ready            ),//output  wire                                            
    .o_tmg_wnd_req_sn           (o_tmg_wnd_req_sn           ),//output  wire    [15:0]                                      
    .o_tmg_wnd_req_valid        (o_tmg_wnd_req_valid        ),//output  wire                                                
    .i_tmg_wnd_req_ready        (i_tmg_wnd_req_ready        ),//input   wire                                        
    .o_timer_ot_sn              (o_timer_ot_sn              ),//output  wire    [15:0]                              
    .o_timer_ot_sn_vld          (o_timer_ot_sn_vld          ),//output  wire                                        
    .o_timer_ot_vld             (o_timer_ot_vld             ),//output  wire                                        
    //timer request(reload)
    .o_rld_tmg_sn               (rld_tmg_sn                 ),//output  wire    [15:0]                              
    .o_rld_tmg_cnt              (rld_tmg_cnt                ),//output  wire    [15:0]                               //rld 
    .o_rld_tmg_chksum           (rld_tmg_chksum             ),//output  wire    [31:0]                                
    .o_rld_tmg_gen_req          (rld_tmg_gen_req            ),//output  wire    [64+384-1:0]                            
    .o_rld_tmg_valid            (rld_tmg_valid              ),//output  wire                                        
    .i_rld_tmg_ready            (rld_tmg_ready              ),//input   wire                                        
    //con to nack gen
    .o_nackgen_sn               (o_nackgen_sn               ),//output  wire    [15:0]                              
    .o_nackgen_req              (o_nackgen_req              ),//output  wire    [1024+32-1:0]                       
    .o_nackgen_vld              (o_nackgen_vld              ),//output  wire                                        
    .i_nackgen_rdy              (i_nackgen_rdy              ),//input   wire                                        
    //axi 4 (use to read bitmap)
    .m_axi_arid                 (m_axi_arid                 ),//output wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_araddr               (m_axi_araddr               ),//output wire [AXI_ADDR_WIDTH-1:0]                    
    .m_axi_arlen                (m_axi_arlen                ),//output wire [7:0]                                   
    .m_axi_arsize               (m_axi_arsize               ),//output wire [2:0]                                   
    .m_axi_arburst              (m_axi_arburst              ),//output wire [1:0]                                       
    .m_axi_arlock               (m_axi_arlock               ),//output wire                                         
    .m_axi_arcache              (m_axi_arcache              ),//output wire [3:0]                                       
    .m_axi_arprot               (m_axi_arprot               ),//output wire [2:0]                                   
    .m_axi_arvalid              (m_axi_arvalid              ),//output wire                                             
    .m_axi_arready              (m_axi_arready              ),//input  wire                                             
    .m_axi_rid                  (m_axi_rid                  ),//input  wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_rdata                (m_axi_rdata                ),//input  wire [AXI_DATA_WIDTH-1:0]                    
    .m_axi_rresp                (m_axi_rresp                ),//input  wire [1:0]                                   
    .m_axi_rlast                (m_axi_rlast                ),//input  wire                                         
    .m_axi_rvalid               (m_axi_rvalid               ),//input  wire                                         
    .m_axi_rready               (m_axi_rready               ),//output wire                                         
    // connect to dfx port      
    .i_cfg_reg0                 ({31'd0,dfx_sta_clear[1]}),//input   wire    [31:0]                              
    .o_sta_reg0                 (o_sta_reg4),//output  wire    [31:0]                                
    .o_sta_reg1                 (o_sta_reg5),//output  wire    [31:0]                                
    .o_sta_reg2                 (o_sta_reg6),//output  wire    [31:0]                                
    .o_sta_reg3                 (o_sta_reg7) //output  wire    [31:0]                                
);
endmodule