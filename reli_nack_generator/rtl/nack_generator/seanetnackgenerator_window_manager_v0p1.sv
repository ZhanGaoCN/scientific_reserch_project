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
module seanetnackgenerator_window_manager_v0p1#(
    parameter BITMAP_BASE_ADDR  = 32'h0000_0000         ,
    parameter MAX_WND_SIZE      = 16'd4096              ,
    //--------------------------------->>axi config<<------------------------------
    //AXI4 parameter
    parameter AXI_ID_WIDTH      = 4                     ,
    parameter AXI_ADDR_WIDTH    = 32                    ,
    parameter AXI_DATA_WIDTH    = 512                   ,
    parameter AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8                    
)(
    input   wire                                        sys_clk         ,
    input   wire                                        sys_rst         ,
    // connect to window manager
    input   wire    [15:0]                              i_wnd_sn        ,
    input   wire    [31:0]                              i_wnd_chksum    ,
    input   wire    [95:0]                              i_wnd_key_msg   ,
    input   wire    [1 :0]                              i_wnd_tpye      ,//01:normal 10:nack reply 11:reset
    input   wire                                        i_wnd_valid     ,
    output  wire                                        o_wnd_ready     ,
    // connect to timer manager
    output  wire    [15:0]                              o_tmg_sn	        ,
    output  wire    [31:0]                              o_tmg_chksum	    ,    
    output  wire    [64+384-1:0]                        o_tmg_gen_req	    ,    
    output  wire                                        o_tmg_valid	        ,
    input   wire                                        i_tmg_ready	        ,

    output  wire    [63:0]                              o_tmg_wnd	        ,
    output  wire                                        o_tmg_wnd_valid	    ,    
    input   wire                                        i_tmg_wnd_ready	    ,    
    input   wire    [15:0]                              i_tmg_wnd_req_sn	,        
    input   wire                                        i_tmg_wnd_req_valid	,        
    output  wire                                        o_tmg_wnd_req_ready	,      

    input   wire    [15:0]                              i_timer_ot_sn       ,
    input   wire                                        i_timer_ot_sn_vld   ,
    input   wire                                        i_timer_ot_vld      ,
    // axi4 
    output wire [AXI_ID_WIDTH-1:0]                      m_axi_awid      ,
    output wire [AXI_ADDR_WIDTH-1:0]                    m_axi_awaddr    ,
    output wire [7:0]                                   m_axi_awlen     ,
    output wire [2:0]                                   m_axi_awsize    ,
    output wire [1:0]                                   m_axi_awburst   ,    
    output wire                                         m_axi_awlock    ,
    output wire [3:0]                                   m_axi_awcache   ,    
    output wire [2:0]                                   m_axi_awprot    ,
    output wire                                         m_axi_awvalid   ,    
    input  wire                                         m_axi_awready   ,    
    output wire [AXI_DATA_WIDTH-1:0]                    m_axi_wdata     ,
    output wire [AXI_STRB_WIDTH-1:0]                    m_axi_wstrb     ,
    output wire                                         m_axi_wlast     ,
    output wire                                         m_axi_wvalid    ,
    input  wire                                         m_axi_wready    ,
    input  wire [AXI_ID_WIDTH-1:0]                      m_axi_bid       ,
    input  wire [1:0]                                   m_axi_bresp     ,
    input  wire                                         m_axi_bvalid    ,
    output wire                                         m_axi_bready    ,

    output wire [AXI_ID_WIDTH-1:0]                      m_axi_arid      ,
    output wire [AXI_ADDR_WIDTH-1:0]                    m_axi_araddr    ,
    output wire [7:0]                                   m_axi_arlen     ,
    output wire [2:0]                                   m_axi_arsize    ,
    output wire [1:0]                                   m_axi_arburst   ,    
    output wire                                         m_axi_arlock    ,
    output wire [3:0]                                   m_axi_arcache   ,    
    output wire [2:0]                                   m_axi_arprot    ,
    output wire                                         m_axi_arvalid   ,    
    input  wire                                         m_axi_arready   ,    
    input  wire [AXI_ID_WIDTH-1:0]                      m_axi_rid       ,
    input  wire [AXI_DATA_WIDTH-1:0]                    m_axi_rdata     ,
    input  wire [1:0]                                   m_axi_rresp     ,
    input  wire                                         m_axi_rlast     ,
    input  wire                                         m_axi_rvalid    ,
    output wire                                         m_axi_rready    ,  
    // connect to dfx port
    input   wire    [31:0]                              i_cfg_reg0      ,
    input   wire    [31:0]                              i_cfg_reg1      ,
    output  wire    [31:0]                              o_sta_reg0      ,
    output  wire    [31:0]                              o_sta_reg1      ,
    output  wire    [31:0]                              o_sta_reg2      ,
    output  wire    [31:0]                              o_sta_reg3      ,
    output  wire    [31:0]                              o_sta_reg4      ,
    output  wire    [31:0]                              o_sta_reg5       
);
reg     [2:0]   dfx_sta_clear=2'd0;
always@(posedge sys_clk)
if(sys_rst)
    dfx_sta_clear <= 2'd0;
else
    dfx_sta_clear <= {2{i_cfg_reg0[0]}};
    wire    [31:0]      ddr_cmd_addr    ;
    wire    [511:0]     ddr_cmd_data    ;
    wire    [7:0]       ddr_cmd_len     ;
    wire    [1:0]       ddr_cmd_type    ;
    wire                ddr_cmd_valid   ;
    wire                ddr_cmd_ready   ;
    wire    [31:0]      cur_wnd_hdr     ;
    wire    [31:0]      cur_wnd_tail    ;
    wire    [15:0]      cur_wnd_sn      ;
    wire    [31:0]      cur_wnd_chksum  ;
    wire    [95:0]      cur_wnd_keymsg  ;
    wire    [1:0]       cur_wnd_type    ;
    wire                cur_wnd_valid   ;
    wire                cur_wnd_otsta   ;
    wire                cur_wnd_ready   ;
    wire    [31:0]      new_wnd_hdr     ;
    wire    [31:0]      new_wnd_tail    ;
    wire    [15:0]      new_wnd_sn      ;
    wire                new_wnd_valid   ;
    wire    [15:0]      timer_req_sn    ;
    wire    [31:0]      timer_req_hdr   ;
    wire    [31:0]      timer_req_tail  ;
    wire    [383:0]     timer_req_bitmap;
    wire    [31:0]      timer_req_chksum;
    wire                timer_req_valid ;
    wire                timer_req_ready ;

    wire                sys_rst_d9;
    reg     [15:0]      sys_rst_d={16{1'd1}};
    always@(posedge sys_clk)
    if(sys_rst)
        sys_rst_d <= {16{1'd1}};
    else
        sys_rst_d <= {sys_rst_d[14:0],1'd0};
    assign sys_rst_d9 = sys_rst_d[9];
    //ram init 
    reg     [9:0]       init_addr=10'd0;
    always@(posedge sys_clk)
    if(sys_rst_d9)
        init_addr <= 10'd0;
    else if(init_addr < 10'h3FF)
        init_addr <= init_addr + 1;
    else
        init_addr <= init_addr;
    reg                 init_done=0;
    always@(posedge sys_clk)
    if(sys_rst_d9)
        init_done <= 0;
    else if(init_addr == 10'h3FF)
        init_done <= 1;
    else
        init_done <= 0;
//------------------------------------------------------------
// window ptr ram
    wire                bram_wnd_clka    ;
    wire    [9:0]       bram_wnd_addra   ;
    wire    [63 :0]     bram_wnd_dina    ;
    wire                bram_wnd_ena     ;
    wire                bram_wnd_wea     ;
    wire                bram_wnd_clkb    ;
    wire    [9:0]       bram_wnd_addrb   ;
    wire    [63 :0]     bram_wnd_doutb   ;
    wire                bram_wnd_enb     ;
    wire                bram_wnd_rstb    ;
    ipbase_sdpram_sync#(
        .MEMORY_PRIMITIVE                ("block"       ),//auto, block, distributed, mixed, ultra
        .MEMORY_SIZE                     (64*1024       ),// DECIMAL
        .ADDR_WIDTH_A                    (10            ),// DECIMAL
        .ADDR_WIDTH_B                    (10            ),// DECIMAL
        .WRITE_DATA_WIDTH_A              (64            ),// DECIMAL
        .BYTE_WRITE_WIDTH_A              (64            ),// DECIMAL
        .READ_DATA_WIDTH_B               (64            ),// DECIMAL
        .READ_LATENCY_B                  (2             ),// DECIMAL
        .READ_RESET_VALUE_B              ("0"           ),// String
        .WRITE_MODE_B                    ("read_first"  ),// String
        .WRITE_PROTECT                   (0             ) // DECIMAL
    )bram_wnd_64w1024d(
        .clka               (bram_wnd_clka               ),//input   wire                                                
        .addra              (bram_wnd_addra              ),//input   wire    [ADDR_WIDTH_A-1:0]                          
        .dina               (bram_wnd_dina               ),//input   wire    [WRITE_DATA_WIDTH_A-1:0]                    
        .ena                (bram_wnd_ena                ),//input   wire                                                
        .wea                (bram_wnd_wea                ),//input   wire    [WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-1:0] 

        .clkb               (bram_wnd_clkb               ),//input   wire                                                
        .addrb              (bram_wnd_addrb              ),//input   wire    [ADDR_WIDTH_B-1:0]                          
        .doutb              (bram_wnd_doutb              ),//output  wire    [READ_DATA_WIDTH_B-1:0]                    
        .enb                (bram_wnd_enb                ),//input   wire                                                

        .dbiterrb           (),//output  wire                                                
        .sbiterrb           (),//output  wire                                                
        .injectdbiterra     (0),//input   wire                                                
        .injectsbiterra     (0),//input   wire                                                
        .regceb             (1),//input   wire                                                
        .rstb               (bram_wnd_rstb               ),//input   wire                                                
        .sleep              (0) //input   wire                                                
    );
    assign bram_wnd_clka    = sys_clk;
    assign bram_wnd_addra   = init_done ? new_wnd_sn[9:0] : init_addr;
    assign bram_wnd_dina    = init_done ? {new_wnd_hdr,new_wnd_tail} : 64'd0;
    assign bram_wnd_ena     = 1;
    assign bram_wnd_wea     = init_done ? new_wnd_valid : 1;
    assign bram_wnd_clkb    = sys_clk;
    assign bram_wnd_addrb   = i_wnd_sn[9:0];
    assign bram_wnd_enb     = 1;
    assign bram_wnd_rstb    = sys_rst;
    
    wire    [31:0]          wnd_hdr;
    wire    [31:0]          wnd_tail;
    assign wnd_hdr  = bram_wnd_doutb[31:0];
    assign wnd_tail = bram_wnd_doutb[63:32];
//------------------------------------------------------------
// <re-hit process>
    reg     [1023:0]        ot_hitbox_1w1024d={1024{1'b1}};
    wire    [31:0]          ot_hitbox_32w32d[31:0];
    wire    [9:0]           ot_hitbox_wrptr;
    wire                    ot_hitbox_wren;
    wire    [4:0]           ot_hitbox_rdptr_L0;
    wire    [4:0]           ot_hitbox_rdptr_L1;
    wire                    ot_hitbox_rden;
    assign ot_hitbox_wrptr = i_wnd_sn[9:0];
    assign ot_hitbox_rdptr_L0 = i_wnd_sn[9:5];
    assign ot_hitbox_rdptr_L1 = r0_i_wnd_sn[4:0];
    genvar i;
    generate
        for(i=0;i<1024;i=i+1)
            always@(posedge sys_clk)
            if(sys_rst)
                ot_hitbox_1w1024d[i] <= 1;
            else
                ot_hitbox_1w1024d[i] <= 
                    (i_timer_ot_vld && (i_timer_ot_sn == i)) ? 1 :
                    (new_wnd_valid && (new_wnd_sn == i)) ? 0 : 
                    ot_hitbox_1w1024d[i];
        for(i=0;i<32;i=i+1)
            assign ot_hitbox_32w32d[i] = ot_hitbox_1w1024d[32*i+31:32*i];
    endgenerate
    reg     [31:0]          ot_hitbox_L0={32{1'b1}};
    reg                     ot_hitbox_L1=1;
    always@(posedge sys_clk)
    if(sys_rst)
        ot_hitbox_L0 <= {32{1'b1}};
    else
        ot_hitbox_L0 <= ot_hitbox_32w32d[ot_hitbox_rdptr_L0];
    always@(posedge sys_clk)
    if(sys_rst)
        ot_hitbox_L1 <= 1;
    else
        ot_hitbox_L1 <= ot_hitbox_L0[ot_hitbox_rdptr_L1];

    reg                     ot_sn_hit=0;
    always@(posedge sys_clk)
    if(sys_rst)
        ot_sn_hit <= 0;
    else if(i_wnd_valid)
        ot_sn_hit <=  (i_timer_ot_sn_vld && (i_timer_ot_sn == i_wnd_sn)) ? 1 : 0;
    else
        ot_sn_hit <= ot_sn_hit;

    reg                     ot_new_judge_hit=0;
    reg                     ot_new_judge_hit_d1=0;
    wire                    c_ot_new_judge_hit;
    wire                    max_window_size;
    always@(posedge sys_clk)
    if(sys_rst)
        ot_new_judge_hit <= 0;
    else
        ot_new_judge_hit <= c_ot_new_judge_hit;
    always@(posedge sys_clk)
    if(sys_rst)
        ot_new_judge_hit_d1 <= 0;
    else
        ot_new_judge_hit_d1 <= ot_new_judge_hit;
    wire    [31:0]      cur_wnd_nor_exprpn  ;
    wire    [31:0]      cur_wnd_nor_rpn     ;
    wire                cur_wnd_nor_vld     ;
    wire                judge_new           ;
    assign cur_wnd_nor_exprpn   = i_wnd_key_msg[63:32];//exp rpn
    assign cur_wnd_nor_rpn      = i_wnd_key_msg[31:0];//rpn
    assign cur_wnd_nor_vld      = i_wnd_tpye==2'b01 && i_wnd_valid;
    assign judge_new = 
            cur_wnd_nor_rpn < cur_wnd_nor_exprpn ?
                cur_wnd_nor_rpn < max_window_size && cur_wnd_nor_exprpn > ~max_window_size ? 1 : 
                0 :
            cur_wnd_nor_rpn > cur_wnd_nor_exprpn ?
                cur_wnd_nor_exprpn < max_window_size && cur_wnd_nor_rpn > ~max_window_size ? 0 : 
                1 :
            0;
    assign c_ot_new_judge_hit = cur_wnd_nor_vld & judge_new;


    reg     [15:0]                              r0_i_wnd_sn        =16'd0;
    reg     [31:0]                              r0_i_wnd_chksum    =32'd0;
    reg     [95:0]                              r0_i_wnd_key_msg   =96'd0;
    reg     [1 :0]                              r0_i_wnd_tpye      =2'd0;//01:normal 10:nack reply 11:reset
    reg                                         r0_i_wnd_valid     =1'd0;
    reg     [15:0]                              r1_i_wnd_sn        =16'd0;
    reg     [31:0]                              r1_i_wnd_chksum    =32'd0;
    reg     [95:0]                              r1_i_wnd_key_msg   =96'd0;
    reg     [1 :0]                              r1_i_wnd_tpye      =2'd0;//01:normal 10:nack reply 11:reset
    reg                                         r1_i_wnd_valid     =1'd0;

    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r0_i_wnd_sn        <= 16'd0;
            r0_i_wnd_chksum    <= 32'd0;
            r0_i_wnd_key_msg   <= 96'd0;
            r0_i_wnd_tpye      <= 2'd0;//01:normal 10:nack reply 11:reset
            r0_i_wnd_valid     <= 1'd0;
            r1_i_wnd_sn        <= 16'd0;
            r1_i_wnd_chksum    <= 32'd0;
            r1_i_wnd_key_msg   <= 96'd0;
            r1_i_wnd_tpye      <= 2'd0;//01:normal 10:nack reply 11:reset
            r1_i_wnd_valid     <= 1'd0;
        end
    else
        begin
            r0_i_wnd_sn        <= i_wnd_sn           ;
            r0_i_wnd_chksum    <= i_wnd_chksum       ;
            r0_i_wnd_key_msg   <= i_wnd_key_msg      ;
            r0_i_wnd_tpye      <= i_wnd_tpye         ;
            r0_i_wnd_valid     <= i_wnd_valid        ;
            r1_i_wnd_sn        <= r0_i_wnd_sn        ;
            r1_i_wnd_chksum    <= r0_i_wnd_chksum    ;
            r1_i_wnd_key_msg   <= r0_i_wnd_key_msg   ;
            r1_i_wnd_tpye      <= r0_i_wnd_tpye      ;
            r1_i_wnd_valid     <= r0_i_wnd_valid     ;
        end
//-------------------------------------------------------------------------------------------------\\
//                                        >>>cal core<<<                                           \\
//-------------------------------------------------------------------------------------------------\\
assign cur_wnd_hdr     = cur_wnd_type != 2'b11 ? wnd_tail : 32'd0;
assign cur_wnd_tail    = cur_wnd_type != 2'b11 ? wnd_hdr  : 32'd0;
assign cur_wnd_sn      = r1_i_wnd_sn;
assign cur_wnd_chksum  = r1_i_wnd_chksum;
assign cur_wnd_keymsg  = r1_i_wnd_key_msg;
assign cur_wnd_type    = ((ot_hitbox_L1 || (ot_sn_hit && i_timer_ot_vld)) && ot_new_judge_hit_d1) ? 2'b11 : r1_i_wnd_tpye;
assign cur_wnd_valid   = r1_i_wnd_valid;
assign cur_wnd_otsta   = (ot_hitbox_L1 || (ot_sn_hit && i_timer_ot_vld));
assign o_wnd_ready     = cur_wnd_ready & init_done;

assign o_tmg_sn	        =   timer_req_sn;
assign o_tmg_chksum	    =   timer_req_chksum;
assign o_tmg_gen_req    =   {timer_req_hdr,timer_req_tail,timer_req_bitmap};
assign o_tmg_valid	    =   timer_req_valid;
assign timer_req_ready  =   i_tmg_ready;
seanetnackgenerator_window_calcore#(
    .MAX_WND_SIZE(MAX_WND_SIZE)
)seanetnackgenerator_window_calcore_dut(
    .sys_clk         (sys_clk         ),//input   wire                                        
    .sys_rst         (sys_rst         ),//input   wire                                        
    // current window msg
    .cur_wnd_hdr     (cur_wnd_hdr     ),//input   wire    [31:0]                              
    .cur_wnd_tail    (cur_wnd_tail    ),//input   wire    [31:0]                              
    // current exprpn/rpn msg
    .cur_wnd_sn      (cur_wnd_sn      ),//input   wire    [15:0]                              
    .cur_wnd_chksum  (cur_wnd_chksum  ),//input   wire    [31:0]                              
    .cur_wnd_keymsg  (cur_wnd_keymsg  ),//input   wire    [95:0]                              
    .cur_wnd_type    (cur_wnd_type    ),//input   wire    [1:0]                               //01normal 10nackreply 11reset
    .cur_wnd_valid   (cur_wnd_valid   ),//input   wire                                        
    .cur_wnd_otsta   (cur_wnd_otsta   ),//input   wire                                        
    .cur_wnd_ready   (cur_wnd_ready   ),//output  wire                                        
    // update window msg(dir-write ram)
    .new_wnd_hdr     (new_wnd_hdr     ),//output  wire    [31:0]                              
    .new_wnd_tail    (new_wnd_tail    ),//output  wire    [31:0]                              
    .new_wnd_sn      (new_wnd_sn      ),//output  wire    [15:0]                              
    .new_wnd_valid   (new_wnd_valid   ),//output  wire                                        
    // generate timer request
    .timer_req_sn    (timer_req_sn    ),//output  wire    [15:0]                              
    .timer_req_hdr   (timer_req_hdr   ),//output  wire    [31:0]                              
    .timer_req_tail  (timer_req_tail  ),//output  wire    [31:0]                              
    .timer_req_bitmap(timer_req_bitmap),//output  wire    [383:0]                             
    .timer_req_chksum(timer_req_chksum),//output  wire    [31:0]                              
    .timer_req_valid (timer_req_valid ),//output  wire                                        
    .timer_req_ready (timer_req_ready ),//input   wire                                        
    // generate ddr rw cmd
    .ddr_cmd_addr    (ddr_cmd_addr    ),//output  wire    [31:0]                              
    .ddr_cmd_data    (ddr_cmd_data    ),//output  wire    [511:0]                             
    .ddr_cmd_len     (ddr_cmd_len     ),//output  wire    [7:0]                               
    .ddr_cmd_type    (ddr_cmd_type    ),//output  wire    [1:0]                               //01bitmap update 
    .ddr_cmd_valid   (ddr_cmd_valid   ),//output  wire                                        
    .ddr_cmd_ready   (ddr_cmd_ready   ),//input   wire                                        
    // connect to dfx port      
    .i_cfg_reg0      ({31'd0,dfx_sta_clear[0]}),//input   wire    [31:0]                              
    .i_cfg_reg1      (i_cfg_reg1),//input   wire    [31:0]                              
    .o_sta_reg0      (o_sta_reg0),//output  wire    [31:0]                              
    .o_sta_reg1      (o_sta_reg1),//output  wire    [31:0]                              
    .o_sta_reg2      (o_sta_reg2),//output  wire    [31:0]                              
    .o_sta_reg3      (o_sta_reg3) //output  wire    [31:0]              
);
//-------------------------------------------------------------------------------------------------\\
//                                          >>>Arbit<<<                                            \\
//-------------------------------------------------------------------------------------------------\\
seanetnackgenerator_ddr_bitmapcmd_arbit#(
    .BITMAP_BASE_ADDR  (BITMAP_BASE_ADDR      ),
    //------------------------------->>arbit config<<------------------------------
    //--------------------------------->>axi config<<------------------------------
    //AXI4 parameter
    .AXI_ID_WIDTH      (4                     ),
    .AXI_ADDR_WIDTH    (32                    ),
    .AXI_DATA_WIDTH    (512                   ) 
)seanetnackgenerator_ddr_bitmapcmd_arbit_dut(
    .sys_clk         (sys_clk         ),//input   wire                                        
    .sys_rst         (sys_rst         ),//input   wire                                        
    // cmd input
    .ddr_cmd_addr    (ddr_cmd_addr    ),//input   wire    [31:0]                              
    .ddr_cmd_data    (ddr_cmd_data    ),//input   wire    [511:0]                             
    .ddr_cmd_len     (ddr_cmd_len     ),//input   wire    [7:0]                               
    .ddr_cmd_type    (ddr_cmd_type    ),//input   wire    [1:0]                               //[2'b00: adapt write 0] [2'b01: adapt write 1] [2'b11:froce write 1]
    .ddr_cmd_valid   (ddr_cmd_valid   ),//input   wire                                        
    .ddr_cmd_ready   (ddr_cmd_ready   ),//output  wire                                         
    // axi4 
    .m_axi_awid      (m_axi_awid      ),//output wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_awaddr    (m_axi_awaddr    ),//output wire [AXI_ADDR_WIDTH-1:0]                    
    .m_axi_awlen     (m_axi_awlen     ),//output wire [7:0]                                   
    .m_axi_awsize    (m_axi_awsize    ),//output wire [2:0]                                   
    .m_axi_awburst   (m_axi_awburst   ),//output wire [1:0]                                       
    .m_axi_awlock    (m_axi_awlock    ),//output wire                                         
    .m_axi_awcache   (m_axi_awcache   ),//output wire [3:0]                                       
    .m_axi_awprot    (m_axi_awprot    ),//output wire [2:0]                                   
    .m_axi_awvalid   (m_axi_awvalid   ),//output wire                                             
    .m_axi_awready   (m_axi_awready   ),//input  wire                                             
    .m_axi_wdata     (m_axi_wdata     ),//output wire [AXI_DATA_WIDTH-1:0]                    
    .m_axi_wstrb     (m_axi_wstrb     ),//output wire [AXI_STRB_WIDTH-1:0]                    
    .m_axi_wlast     (m_axi_wlast     ),//output wire                                         
    .m_axi_wvalid    (m_axi_wvalid    ),//output wire                                         
    .m_axi_wready    (m_axi_wready    ),//input  wire                                         
    .m_axi_bid       (m_axi_bid       ),//input  wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_bresp     (m_axi_bresp     ),//input  wire [1:0]                                   
    .m_axi_bvalid    (m_axi_bvalid    ),//input  wire                                         
    .m_axi_bready    (m_axi_bready    ),//output wire                                         
    .m_axi_arid      (m_axi_arid      ),//output wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_araddr    (m_axi_araddr    ),//output wire [AXI_ADDR_WIDTH-1:0]                    
    .m_axi_arlen     (m_axi_arlen     ),//output wire [7:0]                                   
    .m_axi_arsize    (m_axi_arsize    ),//output wire [2:0]                                   
    .m_axi_arburst   (m_axi_arburst   ),//output wire [1:0]                                       
    .m_axi_arlock    (m_axi_arlock    ),//output wire                                         
    .m_axi_arcache   (m_axi_arcache   ),//output wire [3:0]                                       
    .m_axi_arprot    (m_axi_arprot    ),//output wire [2:0]                                   
    .m_axi_arvalid   (m_axi_arvalid   ),//output wire                                             
    .m_axi_arready   (m_axi_arready   ),//input  wire                                             
    .m_axi_rid       (m_axi_rid       ),//input  wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_rdata     (m_axi_rdata     ),//input  wire [AXI_DATA_WIDTH-1:0]                    
    .m_axi_rresp     (m_axi_rresp     ),//input  wire [1:0]                                   
    .m_axi_rlast     (m_axi_rlast     ),//input  wire                                         
    .m_axi_rvalid    (m_axi_rvalid    ),//input  wire                                         
    .m_axi_rready    (m_axi_rready    ),//output wire                                         
    // connect to dfx port
    .dfx_cfg0        ({31'd0,dfx_sta_clear[1]}),//input  wire [31:0]
    .dfx_sta0        (o_sta_reg4),//output wire [31:0]                                  
    .dfx_sta1        (o_sta_reg5) //output wire [31:0]                                                                
);

//------------------------------------------------------------
// window ptr ram(con to timer manager)
    wire                bram_wndout_clka    ;
    wire    [9:0]       bram_wndout_addra   ;
    wire    [63 :0]     bram_wndout_dina    ;
    wire                bram_wndout_ena     ;
    wire                bram_wndout_wea     ;
    wire                bram_wndout_clkb    ;
    wire    [9:0]       bram_wndout_addrb   ;
    wire    [63 :0]     bram_wndout_doutb   ;
    wire                bram_wndout_enb     ;
    wire                bram_wndout_rstb    ;
    ipbase_sdpram_sync#(
        .MEMORY_PRIMITIVE                ("block"       ),
        .MEMORY_SIZE                     (64*1024       ),// DECIMAL
        .ADDR_WIDTH_A                    (10            ),// DECIMAL
        .ADDR_WIDTH_B                    (10            ),// DECIMAL
        .WRITE_DATA_WIDTH_A              (64            ),// DECIMAL
        .BYTE_WRITE_WIDTH_A              (64            ),// DECIMAL
        .READ_DATA_WIDTH_B               (64            ),// DECIMAL
        .READ_LATENCY_B                  (2             ),// DECIMAL
        .READ_RESET_VALUE_B              ("0"           ),// String
        .WRITE_MODE_B                    ("read_first"  ),// String
        .WRITE_PROTECT                   (0             ) // DECIMAL
    )bram_wndout_64w1024d(
        .clka               (bram_wndout_clka               ),//input   wire                                                
        .addra              (bram_wndout_addra              ),//input   wire    [ADDR_WIDTH_A-1:0]                          
        .dina               (bram_wndout_dina               ),//input   wire    [WRITE_DATA_WIDTH_A-1:0]                    
        .ena                (bram_wndout_ena                ),//input   wire                                                
        .wea                (bram_wndout_wea                ),//input   wire    [WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-1:0] 

        .clkb               (bram_wndout_clkb               ),//input   wire                                                
        .addrb              (bram_wndout_addrb              ),//input   wire    [ADDR_WIDTH_B-1:0]                          
        .doutb              (bram_wndout_doutb              ),//output  wire    [READ_DATA_WIDTH_B-1:0]                    
        .enb                (bram_wndout_enb                ),//input   wire                                                

        .dbiterrb           (),//output  wire                                                
        .sbiterrb           (),//output  wire                                                
        .injectdbiterra     (0),//input   wire                                                
        .injectsbiterra     (0),//input   wire                                                
        .regceb             (1),//input   wire                                                
        .rstb               (bram_wndout_rstb               ),//input   wire                                                
        .sleep              (0) //input   wire                                                
    );
    assign bram_wndout_clka    = sys_clk;
    assign bram_wndout_addra   = init_done ? new_wnd_sn[9:0] : init_addr;
    assign bram_wndout_dina    = init_done ? {new_wnd_hdr,new_wnd_tail} : 64'd0;
    assign bram_wndout_ena     = 1;
    assign bram_wndout_wea     = init_done ? new_wnd_valid : 1;
    assign bram_wndout_clkb    = sys_clk;
    assign bram_wndout_addrb   = i_tmg_wnd_req_sn[9:0];
    assign bram_wndout_enb     = 1;
    assign bram_wndout_rstb    = sys_rst;

    reg     r0_i_tmg_wnd_req_valid=0;
    reg     r1_i_tmg_wnd_req_valid=0;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r0_i_tmg_wnd_req_valid <= 0;
            r1_i_tmg_wnd_req_valid <= 0;
        end 
    else
        begin
            r0_i_tmg_wnd_req_valid <=    i_tmg_wnd_req_valid;
            r1_i_tmg_wnd_req_valid <= r0_i_tmg_wnd_req_valid;
        end 
    assign o_tmg_wnd = bram_wndout_doutb;
    assign o_tmg_wnd_valid = r1_i_tmg_wnd_req_valid;
    assign o_tmg_wnd_req_ready = 1;

//\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
//  <DFX Config>
//----------------------------------------------------------------------------------
    wire    [15:0]      c_max_wnd_size;
    reg     [15:0]      r_max_wnd_size=16'd0;
    assign c_max_wnd_size = i_cfg_reg1[31] ? i_cfg_reg1[15:0] : MAX_WND_SIZE;
    always@(posedge sys_clk)
    if(sys_rst)
        r_max_wnd_size <= 16'd0;
    else
        r_max_wnd_size <= c_max_wnd_size;

    `ifdef USED_FIXED_PARAM
        assign max_window_size            = {16'd0,MAX_WND_SIZE};
    `else
        assign max_window_size            = {16'd0,r_max_wnd_size};
    `endif
endmodule