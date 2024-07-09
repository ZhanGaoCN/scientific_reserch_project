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
module seanetnackgenerator_timer_compcore#(
    parameter BITMAP_BASE_ADDR  = 32'h0000_0000         ,
//AXI4 parameter
    parameter AXI_ID_WIDTH      = 4                     ,
    parameter AXI_ADDR_WIDTH    = 64                    ,
    parameter AXI_DATA_WIDTH    = 512                   ,
    parameter AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8      ,
    parameter AXI_ID_SET        = 0                     
)(
    input   wire                                        sys_clk                 ,
    input   wire                                        sys_rst                 ,
    //con to timer queue manager
    //////read alarm
    input   wire    [512        -1:0]                   i_timer_alarm           ,
    input   wire                                        i_timer_alarm_vld       ,
    output  wire                                        o_timer_alarm_rdy       ,
    //con to stream manager
    input   wire    [31:0]                              i_tmg_chksum            ,
    input   wire    [511:0]                             i_tmg_s_info	        ,
    input   wire                                        i_tmg_valid	            ,
    output  wire                                        o_tmg_ready	            ,
    output  wire    [15:0]                              o_tmg_req_sn	        ,
    output  wire                                        o_tmg_req_valid	        ,
    input   wire                                        i_tmg_req_ready	        ,
    //con to window manager
    input   wire    [63:0]                              i_tmg_wnd	            ,
    input   wire                                        i_tmg_wnd_valid	        ,    
    output  wire                                        o_tmg_wnd_ready	        ,    
    output  wire    [15:0]                              o_tmg_wnd_req_sn	    ,        
    output  wire                                        o_tmg_wnd_req_valid	    ,        
    input   wire                                        i_tmg_wnd_req_ready	    ,

    output  wire    [15:0]                              o_timer_ot_sn           ,
    output  wire                                        o_timer_ot_sn_vld       ,
    output  wire                                        o_timer_ot_vld          ,
    //timer request(reload)
    output  wire    [15:0]                              o_rld_tmg_sn            ,
    output  wire    [15:0]                              o_rld_tmg_cnt           ,//rld 
    output  wire    [31:0]                              o_rld_tmg_chksum        ,  
    output  wire    [64+384-1:0]                        o_rld_tmg_gen_req       ,    
    output  wire                                        o_rld_tmg_valid         ,
    input   wire                                        i_rld_tmg_ready         ,
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
    output  wire    [31:0]                              o_sta_reg3                               
);
    wire    [32-1:0]        cmd_araddr                 ;
    wire    [8-1:0]         cmd_arlen                  ;
    wire                    cmd_arvalid                ;
    wire                    cmd_arready                ;
    wire    [512-1:0]       cmd_rdata                  ;
    wire                    cmd_rlast                  ;
    wire                    cmd_rvalid                 ;
    wire                    cmd_rready                 ;

    assign o_tmg_req_sn         = i_timer_alarm[495:480];
    assign o_tmg_req_valid      = i_timer_alarm_vld & o_timer_alarm_rdy;
    assign o_tmg_wnd_req_sn     = i_timer_alarm[495:480];
    assign o_tmg_wnd_req_valid  = i_timer_alarm_vld & o_timer_alarm_rdy;

    reg     [511:0]         r0_i_timer_alarm    ;
    reg     [511:0]         r1_i_timer_alarm    ;
    reg                     r0_i_timer_alarm_vld;
    reg                     r1_i_timer_alarm_vld;
    always@(posedge sys_clk)
    if(sys_rst) begin
        r0_i_timer_alarm     <= 512'd0;
        r1_i_timer_alarm     <= 512'd0;
        r0_i_timer_alarm_vld <= 0;
        r1_i_timer_alarm_vld <= 0;
    end
    else begin
        r0_i_timer_alarm     <= i_timer_alarm       ;
        r1_i_timer_alarm     <= r0_i_timer_alarm    ;
        r0_i_timer_alarm_vld <= i_timer_alarm_vld & o_timer_alarm_rdy  ;
        r1_i_timer_alarm_vld <= r0_i_timer_alarm_vld;
    end
    assign o_timer_ot_sn        = r0_i_timer_alarm[495:480];
    assign o_timer_ot_sn_vld    = r0_i_timer_alarm_vld;
//------------------------------------------------------------
//                   >>>timer compare process<<<
// [alarm_timer_cnt         ]:
// [alarm_timer_sn          ]:
// [alarm_timer_hdr         ]:
// [alarm_timer_tail        ]:
// [stream_chksum           ]:
// [stream_info             ]:
// [ins_wnd_hdr             ]:
// [ins_wnd_tail            ]:
// [chksum_comp_failed      ]:
// [hit_ins_wnd_failed      ]:
// [retry_last_time         ]:
// [new_timer_hdr           ]:
// [new_timer_tail          ]:
// [need_update_timer_wnd   ]:
// [need_checkbitmap        ]:
// [need_reload             ]:
// [align_old_hdr_high      ]:
// [align_old_tail_high     ]:
// [old_ultra_wnd_hdr       ]:
// [old_ultra_wnd_tail      ]:
// [align_new_hdr_high      ]:
// [align_new_tail_high     ]:
// [new_ultra_wnd_hdr       ]:
// [new_ultra_wnd_tail      ]:
// []:
//------------------------------------------------------------
    wire    [15:0]      alarm_timer_cnt         ;
    wire    [1:0]       alarm_timer_cnt_dead    ;
    wire    [1:0]       alarm_timer_cntx0       ;
    wire    [1:0]       alarm_timer_cntx1       ;
    wire    [1:0]       alarm_timer_cntx2       ;
    wire    [1:0]       alarm_timer_cntx3       ;
    wire    [1:0]       alarm_timer_cntx4       ;
    wire    [1:0]       alarm_timer_cntx5       ;
    wire    [1:0]       alarm_timer_cntx6       ;
    wire    [1:0]       alarm_timer_cntx7       ;
    wire    [15:0]      alarm_timer_sn          ;
    wire    [31:0]      alarm_timer_chksum      ;
    wire    [31:0]      alarm_timer_hdr         ;
    wire    [31:0]      alarm_timer_tail        ;
    wire    [31:0]      stream_chksum           ;
    wire    [511:0]     stream_info             ;
    wire    [31:0]      ins_wnd_hdr             ;
    wire    [31:0]      ins_wnd_tail            ;
    wire                chksum_comp_failed      ;
    wire                hit_ins_wnd_failed      ;
    wire                retry_last_time         ;
    wire    [31:0]      new_timer_hdr           ;
    wire    [31:0]      new_timer_tail          ;
    wire                need_update_timer_wnd   ;
    wire                need_checkbitmap        ;
    wire                need_reload             ;
    wire    [22:0]      align_old_hdr_high      ;
    wire    [22:0]      align_old_tail_high     ;
    wire    [31:0]      old_ultra_wnd_hdr       ;
    wire    [31:0]      old_ultra_wnd_tail      ;
    wire    [22:0]      align_new_hdr_high      ;
    wire    [22:0]      align_new_tail_high     ;
    wire    [31:0]      new_ultra_wnd_hdr       ;
    wire    [31:0]      new_ultra_wnd_tail      ;
    wire    [31:0]      alarm_timer_hdr_exact   ;
    assign alarm_timer_cnt      = r1_i_timer_alarm[511:496];
    assign alarm_timer_sn       = r1_i_timer_alarm[495:480];
    assign alarm_timer_chksum   = r1_i_timer_alarm[479:448];
    assign alarm_timer_hdr      = r1_i_timer_alarm[447:416];
    assign alarm_timer_tail     = r1_i_timer_alarm[415:384];
    assign alarm_timer_hdr_exact= r1_i_timer_alarm[383:352];//add by chenfeiyu at 2024/06/28 to support 64w timer counter
    assign alarm_timer_cnt_dead = r1_i_timer_alarm[321:320];//add by chenfeiyu at 2024/06/28 to support 64w timer counter
    assign stream_chksum        = i_tmg_chksum  ;
    assign stream_info          = i_tmg_s_info  ;
    assign ins_wnd_hdr          = i_tmg_wnd[63:32];
    assign ins_wnd_tail         = i_tmg_wnd[31:0 ];
    assign chksum_comp_failed   = alarm_timer_chksum != stream_chksum;
    assign hit_ins_wnd_failed   = 
                ins_wnd_hdr > ins_wnd_tail && ins_wnd_tail > alarm_timer_hdr && alarm_timer_hdr > alarm_timer_tail ? 1 :
                alarm_timer_hdr > alarm_timer_tail && alarm_timer_tail >= ins_wnd_hdr && ins_wnd_hdr > ins_wnd_tail ? 1 :
                alarm_timer_tail >= ins_wnd_hdr && ins_wnd_hdr > ins_wnd_tail && ins_wnd_tail > alarm_timer_hdr ? 1 :
                ins_wnd_tail > alarm_timer_hdr && alarm_timer_hdr > alarm_timer_tail && alarm_timer_tail >= ins_wnd_hdr ? 1 :
                ins_wnd_hdr == ins_wnd_tail ? 1 :
                0;

    
    assign new_timer_hdr        = alarm_timer_hdr;//header never change
    assign new_timer_tail       = ins_wnd_tail;
    assign need_update_timer_wnd= 
                ins_wnd_hdr > new_ultra_wnd_tail && new_ultra_wnd_tail > alarm_timer_tail ? 1 :
                new_ultra_wnd_tail > alarm_timer_tail && alarm_timer_tail > ins_wnd_hdr ? 1 :
                alarm_timer_tail > ins_wnd_hdr && ins_wnd_hdr > new_ultra_wnd_tail ? 1 :
                0;

    assign need_checkbitmap     = ~chksum_comp_failed && ~hit_ins_wnd_failed;
    assign need_reload          = need_checkbitmap && ~retry_last_time;
    //assign align_old_hdr_high   = alarm_timer_hdr[31:9]-23'd1;
    //assign align_old_tail_high  = alarm_timer_tail[31:9];
    assign old_ultra_wnd_hdr    = alarm_timer_hdr;
    assign old_ultra_wnd_tail   = alarm_timer_tail;
    //assign align_new_hdr_high   = new_timer_hdr[31:9]-23'd1;
    assign align_new_tail_high  = new_timer_tail[31:9];
    assign new_ultra_wnd_hdr    = new_timer_hdr;
    assign new_ultra_wnd_tail   = {align_new_tail_high,9'd0};

    wire    [31:0]          covered_hdr;
    wire    [31:0]          covered_tail;
    assign covered_hdr = 
                ins_wnd_hdr > alarm_timer_hdr && alarm_timer_hdr >= ins_wnd_tail ? alarm_timer_hdr :
                alarm_timer_hdr > ins_wnd_hdr && ins_wnd_hdr > ins_wnd_tail ? ins_wnd_hdr-1 :
                alarm_timer_hdr >= ins_wnd_tail && ins_wnd_tail > ins_wnd_hdr ? alarm_timer_hdr :
                ins_wnd_tail > alarm_timer_hdr && alarm_timer_hdr >= ins_wnd_hdr ? ins_wnd_hdr-1 : 
                ins_wnd_tail > ins_wnd_hdr && ins_wnd_hdr > alarm_timer_hdr ? alarm_timer_hdr :
                32'd0;
    assign covered_tail = 
                ins_wnd_hdr > alarm_timer_tail && alarm_timer_tail >= ins_wnd_tail ? alarm_timer_tail :
                ins_wnd_hdr > ins_wnd_tail && ins_wnd_tail >= alarm_timer_tail ? ins_wnd_tail :
                alarm_timer_tail >= ins_wnd_tail && ins_wnd_tail > ins_wnd_hdr ? alarm_timer_tail :
                ins_wnd_tail >= alarm_timer_tail && alarm_timer_tail >= ins_wnd_hdr ? ins_wnd_tail :
                ins_wnd_tail > ins_wnd_hdr && ins_wnd_hdr > alarm_timer_tail ? alarm_timer_tail :
                32'd0;
    //add by chenfeiyu at 2024/06/28 to support 64w timer counter
    assign alarm_timer_cntx0 = alarm_timer_cnt[2*0+1:2*0];
    assign alarm_timer_cntx1 = alarm_timer_cnt[2*1+1:2*1];
    assign alarm_timer_cntx2 = alarm_timer_cnt[2*2+1:2*2];
    assign alarm_timer_cntx3 = alarm_timer_cnt[2*3+1:2*3];
    assign alarm_timer_cntx4 = alarm_timer_cnt[2*4+1:2*4];
    assign alarm_timer_cntx5 = alarm_timer_cnt[2*5+1:2*5];
    assign alarm_timer_cntx6 = alarm_timer_cnt[2*6+1:2*6];
    assign alarm_timer_cntx7 = alarm_timer_cnt[2*7+1:2*7];

    wire    [7:0]       alarm_timer_cnt_inc_enb;
    wire    [7:0]       alarm_timer_cnt_clr_enb;
    wire    [1:0]       alarm_timer_cntx0_nxt  ;
    wire    [1:0]       alarm_timer_cntx1_nxt  ;
    wire    [1:0]       alarm_timer_cntx2_nxt  ;
    wire    [1:0]       alarm_timer_cntx3_nxt  ;
    wire    [1:0]       alarm_timer_cntx4_nxt  ;
    wire    [1:0]       alarm_timer_cntx5_nxt  ;
    wire    [1:0]       alarm_timer_cntx6_nxt  ;
    wire    [1:0]       alarm_timer_cntx7_nxt  ;
    genvar i;
    generate for(i=0;i<8;i=i+1)begin
    assign alarm_timer_cnt_clr_enb[i] = 
                                    alarm_timer_hdr_exact[8:0] != 9'h1FF ?
                                        alarm_timer_hdr_exact[8:6] == i ? 
                                            ins_wnd_hdr[31:9] == alarm_timer_hdr_exact[31:9] ? 
                                                ins_wnd_hdr[8:0] == alarm_timer_hdr_exact[8:0] ? 0 :
                                                1 :
                                            1 :
                                        0 :
                                    0 ;
    end
    endgenerate
    assign alarm_timer_cnt_inc_enb[0] = alarm_timer_cntx0 < 2 ? alarm_timer_hdr_exact[8:6] >= 0 ? 1 : 0 : 0;
    assign alarm_timer_cnt_inc_enb[1] = alarm_timer_cntx1 < 2 ? alarm_timer_hdr_exact[8:6] >= 1 ? 1 : 0 : 0;
    assign alarm_timer_cnt_inc_enb[2] = alarm_timer_cntx2 < 2 ? alarm_timer_hdr_exact[8:6] >= 2 ? 1 : 0 : 0;
    assign alarm_timer_cnt_inc_enb[3] = alarm_timer_cntx3 < 2 ? alarm_timer_hdr_exact[8:6] >= 3 ? 1 : 0 : 0;
    assign alarm_timer_cnt_inc_enb[4] = alarm_timer_cntx4 < 2 ? alarm_timer_hdr_exact[8:6] >= 4 ? 1 : 0 : 0;
    assign alarm_timer_cnt_inc_enb[5] = alarm_timer_cntx5 < 2 ? alarm_timer_hdr_exact[8:6] >= 5 ? 1 : 0 : 0;
    assign alarm_timer_cnt_inc_enb[6] = alarm_timer_cntx6 < 2 ? alarm_timer_hdr_exact[8:6] >= 6 ? 1 : 0 : 0;
    assign alarm_timer_cnt_inc_enb[7] = alarm_timer_cntx7 < 2 ? alarm_timer_hdr_exact[8:6] >= 7 ? 1 : 0 : 0;
    assign alarm_timer_cntx0_nxt = alarm_timer_cnt_clr_enb[0] ? 2'd0 : alarm_timer_cnt_inc_enb[0] ? alarm_timer_cntx0 + 1 : alarm_timer_cntx0;
    assign alarm_timer_cntx1_nxt = alarm_timer_cnt_clr_enb[1] ? 2'd0 : alarm_timer_cnt_inc_enb[1] ? alarm_timer_cntx1 + 1 : alarm_timer_cntx1;
    assign alarm_timer_cntx2_nxt = alarm_timer_cnt_clr_enb[2] ? 2'd0 : alarm_timer_cnt_inc_enb[2] ? alarm_timer_cntx2 + 1 : alarm_timer_cntx2;
    assign alarm_timer_cntx3_nxt = alarm_timer_cnt_clr_enb[3] ? 2'd0 : alarm_timer_cnt_inc_enb[3] ? alarm_timer_cntx3 + 1 : alarm_timer_cntx3;
    assign alarm_timer_cntx4_nxt = alarm_timer_cnt_clr_enb[4] ? 2'd0 : alarm_timer_cnt_inc_enb[4] ? alarm_timer_cntx4 + 1 : alarm_timer_cntx4;
    assign alarm_timer_cntx5_nxt = alarm_timer_cnt_clr_enb[5] ? 2'd0 : alarm_timer_cnt_inc_enb[5] ? alarm_timer_cntx5 + 1 : alarm_timer_cntx5;
    assign alarm_timer_cntx6_nxt = alarm_timer_cnt_clr_enb[6] ? 2'd0 : alarm_timer_cnt_inc_enb[6] ? alarm_timer_cntx6 + 1 : alarm_timer_cntx6;
    assign alarm_timer_cntx7_nxt = alarm_timer_cnt_clr_enb[7] ? 2'd0 : alarm_timer_cnt_inc_enb[7] ? alarm_timer_cntx7 + 1 : alarm_timer_cntx7;
    wire    [15:0]      alarm_timer_cnt_nxt;
    assign alarm_timer_cnt_nxt = {
                alarm_timer_cntx7_nxt,
                alarm_timer_cntx6_nxt,
                alarm_timer_cntx5_nxt,
                alarm_timer_cntx4_nxt,
                alarm_timer_cntx3_nxt,
                alarm_timer_cntx2_nxt,
                alarm_timer_cntx1_nxt,
                alarm_timer_cntx0_nxt};
    wire                alarm_timer_cnt_dead_inc_enb    ;
    wire    [1:0]       alarm_timer_cnt_dead_nxt        ;
    wire                alarm_timer_cnt_dead_last_time  ;
    wire    [31:0]      alarm_timer_cnt_dead_tail       ;
    assign alarm_timer_cnt_dead_inc_enb = alarm_timer_cnt_dead < 2 ? (((alarm_timer_tail + 511) < alarm_timer_hdr) || (alarm_timer_tail > alarm_timer_hdr)) : 0;
    assign alarm_timer_cnt_dead_nxt = alarm_timer_cnt_dead_inc_enb ? alarm_timer_cnt_dead + 1 : alarm_timer_cnt_dead;
    assign alarm_timer_cnt_dead_last_time = alarm_timer_cnt_dead == 2;
    assign alarm_timer_cnt_dead_tail = {alarm_timer_hdr_exact[31:9],9'd0};

    wire    [7:0]       sub_retry_last_time;
    assign sub_retry_last_time[0] = alarm_timer_cntx0 == 2 ;
    assign sub_retry_last_time[1] = alarm_timer_cntx1 == 2 ;
    assign sub_retry_last_time[2] = alarm_timer_cntx2 == 2 ;
    assign sub_retry_last_time[3] = alarm_timer_cntx3 == 2 ;
    assign sub_retry_last_time[4] = alarm_timer_cntx4 == 2 ;
    assign sub_retry_last_time[5] = alarm_timer_cntx5 == 2 ;
    assign sub_retry_last_time[6] = alarm_timer_cntx6 == 2 ;
    assign sub_retry_last_time[7] = alarm_timer_cntx7 == 2 ;
    wire    [7:0]       hit_sub_retry_last_time;
    generate
        for(i=0;i<8;i=i+1)
            assign hit_sub_retry_last_time[i] = alarm_timer_hdr_exact[8:6] >= i ? sub_retry_last_time[i] : 1 ;
    endgenerate
    
    assign retry_last_time      = (&hit_sub_retry_last_time) && (alarm_timer_cnt_clr_enb == 8'd0);

    wire    [31:0]          alarm_timer_hdr_exact_nxt;
    assign alarm_timer_hdr_exact_nxt = 
                ins_wnd_hdr[31:9] == alarm_timer_hdr_exact[31:9] ? ins_wnd_hdr : {alarm_timer_hdr_exact[31:9],9'd511};
    //re-hit process
    wire                    timer_ot_flag;
    assign timer_ot_flag = (ins_wnd_hdr == alarm_timer_hdr_exact) && retry_last_time;
//------------------------------------------------------------
// <rehit>
    reg                     r_timer_ot_vld=0;
    wire                    c_timer_ot_vld;
    assign c_timer_ot_vld = timer_ot_flag;
    always@(posedge sys_clk)
    if(sys_rst)
        r_timer_ot_vld <= 0;
    else
        r_timer_ot_vld <= c_timer_ot_vld;
    assign o_timer_ot_vld = r_timer_ot_vld;
//------------------------------------------------------------
// <reload cmd generate>
    reg     [15:0]          r_rld_tmg_sn        ;
    reg     [15:0]          r_rld_tmg_cnt       ;//rld 
    reg     [31:0]          r_rld_tmg_chksum    ;  
    reg     [64+384-1:0]    r_rld_tmg_gen_req   ;    
    reg                     r_rld_tmg_valid     ;

    wire    [15:0]          c_rld_tmg_sn        ;
    wire    [15:0]          c_rld_tmg_cnt       ;//rld 
    wire    [31:0]          c_rld_tmg_chksum    ;  
    wire    [64+384-1:0]    c_rld_tmg_gen_req   ;    
    wire                    c_rld_tmg_valid     ;

    assign c_rld_tmg_sn      = alarm_timer_sn;
    assign c_rld_tmg_cnt     = alarm_timer_cnt_nxt;
    assign c_rld_tmg_chksum  = alarm_timer_chksum;
    assign c_rld_tmg_gen_req = 
                alarm_timer_cnt_dead_last_time ? {alarm_timer_hdr,alarm_timer_cnt_dead_tail,alarm_timer_hdr_exact_nxt,30'd0,alarm_timer_cnt_dead_nxt,{320{1'b1}}} :
                need_update_timer_wnd ? {new_timer_hdr,new_ultra_wnd_tail,alarm_timer_hdr_exact_nxt,30'd0,alarm_timer_cnt_dead_nxt,{320{1'b1}}} :
                {alarm_timer_hdr,alarm_timer_tail,alarm_timer_hdr_exact_nxt,30'd0,alarm_timer_cnt_dead_nxt,{320{1'b1}}} ;
    assign c_rld_tmg_valid   = need_reload && r1_i_timer_alarm_vld ;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_rld_tmg_sn      <= 16'd0;
            r_rld_tmg_cnt     <= 16'd0;
            r_rld_tmg_chksum  <= 32'd0;
            r_rld_tmg_gen_req <= 448'd0;
            r_rld_tmg_valid   <= 1'd0;
        end
    else
        begin
            r_rld_tmg_sn      <= c_rld_tmg_sn     ;
            r_rld_tmg_cnt     <= c_rld_tmg_cnt    ;
            r_rld_tmg_chksum  <= c_rld_tmg_chksum ;
            r_rld_tmg_gen_req <= c_rld_tmg_gen_req;
            r_rld_tmg_valid   <= c_rld_tmg_valid  ;
        end
    assign o_rld_tmg_sn      = r_rld_tmg_sn     ;
    assign o_rld_tmg_cnt     = r_rld_tmg_cnt    ;
    assign o_rld_tmg_chksum  = r_rld_tmg_chksum ;
    assign o_rld_tmg_gen_req = r_rld_tmg_gen_req;
    assign o_rld_tmg_valid   = r_rld_tmg_valid  ;
    wire    cmd_cache_rdy;
    
    // ready logic must have 2 tap idle
    
    localparam FLOWCTRL_CYCLE = 4'd4;
    localparam FLOWCTRL_TRIG  = 4'd0;
    reg     [3:0]           cyc_flowctrl_cnt=4'd0;
    always@(posedge sys_clk)
    if(sys_rst)
        cyc_flowctrl_cnt <= 4'd0;
    else if(cyc_flowctrl_cnt == FLOWCTRL_CYCLE)
        cyc_flowctrl_cnt <= 0;
    else
        cyc_flowctrl_cnt <= cyc_flowctrl_cnt + 1;
    reg                     cyc_flowctrl_nenb=0;
    always@(posedge sys_clk)
    if(sys_rst)
        cyc_flowctrl_nenb <= 0;
    else if(cyc_flowctrl_cnt == FLOWCTRL_TRIG)
        cyc_flowctrl_nenb <= 1;
    else
        cyc_flowctrl_nenb <= 0;

    assign o_timer_alarm_rdy = i_rld_tmg_ready  && cmd_cache_rdy && cyc_flowctrl_nenb;
//------------------------------------------------------------
// <read bitmap cmd generate>
    reg     [31:0]          r_ddr_rd_addr=32'd0;
    wire    [31:0]          c_ddr_rd_addr;
    assign c_ddr_rd_addr = 
                need_update_timer_wnd ? {7'd0,alarm_timer_sn[9:0],new_ultra_wnd_tail[17:9],6'd0} : 
                {7'd0,alarm_timer_sn[9:0],old_ultra_wnd_tail[17:9],6'd0} ;
    reg     [7:0]           r_ddr_rd_len=8'd0;
    wire    [7:0]           c_ddr_rd_len;
    assign c_ddr_rd_len = 
                need_update_timer_wnd ? (new_ultra_wnd_hdr[31:9]-new_ultra_wnd_tail[31:9]) : 
                (old_ultra_wnd_hdr[31:9]-old_ultra_wnd_tail[31:9]);
    reg                     r_ddr_rd_vld=0;
    wire                    c_ddr_rd_vld;
    assign c_ddr_rd_vld = need_checkbitmap && r1_i_timer_alarm_vld;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_ddr_rd_addr   <= 32'd0    ;
            r_ddr_rd_len    <= 8'd0     ;
            r_ddr_rd_vld    <= 1'd0     ;
        end
    else
        begin
            r_ddr_rd_addr   <= c_ddr_rd_addr    ;
            r_ddr_rd_len    <= c_ddr_rd_len     ;
            r_ddr_rd_vld    <= c_ddr_rd_vld     ;
        end
    localparam CMD_FIFO_WIDTH = 32+8;
    wire                            cmd_fifo_clk    ;
    wire                            cmd_fifo_rst    ;
    wire                            cmd_fifo_wren   ;
    wire    [CMD_FIFO_WIDTH-1:0]    cmd_fifo_wrdat  ;
    wire    [CMD_FIFO_WIDTH-1:0]    cmd_fifo_rddat  ;
    wire                            cmd_fifo_rden   ;
    wire                            cmd_fifo_empty  ;
    wire                            cmd_fifo_pempty ;
    wire                            cmd_fifo_full   ;
    wire                            cmd_fifo_pfull  ;
    ipbase_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("distribute"), // String
        .FIFO_READ_LATENCY(0),     // DECIMAL
        .FIFO_WRITE_DEPTH(16),   // DECIMAL
        .FULL_RESET_VALUE(1),      // DECIMAL
        .PROG_EMPTY_THRESH(5),    // DECIMAL
        .PROG_FULL_THRESH(9),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(4),   // DECIMAL
        .READ_DATA_WIDTH(CMD_FIFO_WIDTH),      // DECIMAL
        .READ_MODE("fwft"),         // String
        .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0707"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(CMD_FIFO_WIDTH),     // DECIMAL
        .WR_DATA_COUNT_WIDTH(4)    // DECIMAL
   )
   cmd_fifo_16d (
        .almost_empty     (),
        .almost_full      (),
        .data_valid       (),
        .dbiterr          (),
        .dout             (cmd_fifo_rddat     ),
        .empty            (cmd_fifo_empty     ),
        .full             (cmd_fifo_full      ),
        .overflow         (),
        .prog_empty       (cmd_fifo_pempty    ),
        .prog_full        (cmd_fifo_pfull     ),
        .rd_data_count    (),
        .rd_rst_busy      (),
        .sbiterr          (),
        .underflow        (),
        .wr_ack           (),
        .wr_data_count    (),
        .wr_rst_busy      (),
        .din              (cmd_fifo_wrdat     ),
        .injectdbiterr    (),
        .injectsbiterr    (),
        .rd_en            (cmd_fifo_rden      ),
        .rst              (cmd_fifo_rst       ),
        .sleep            (),
        .wr_clk           (cmd_fifo_clk       ),
        .wr_en            (cmd_fifo_wren      )                     
   );
    assign cmd_fifo_clk = sys_clk;
    assign cmd_fifo_rst = sys_rst;
    assign cmd_fifo_wren    = r_ddr_rd_vld;
    assign cmd_fifo_wrdat   = {
        r_ddr_rd_addr ,
        r_ddr_rd_len 
    };

    wire    [31:0]          ddr_rd_addr;
    wire    [7:0]           ddr_rd_len;
    assign { 
        ddr_rd_addr ,
        ddr_rd_len  } = cmd_fifo_rddat;
    assign cmd_cache_rdy = ~cmd_fifo_pfull;
    assign cmd_fifo_rden = ~cmd_fifo_empty & cmd_arready;
//------------------------------------------------------------
// <bitmap message cache>
// 512bit s info
// 32bit npn
    reg     [511:0]         r_cache_s_info=512'd0;
    wire    [511:0]         c_cache_s_info;
    assign c_cache_s_info = stream_info;
    reg     [31:0]          r_cache_hdr=32'd0;
    wire    [31:0]          c_cache_hdr;
    assign c_cache_hdr = covered_hdr;
    reg     [31:0]          r_cache_tail=32'd0;
    wire    [31:0]          c_cache_tail;
    assign c_cache_tail= covered_tail;
    reg     [7:0]           r_cache_len=8'd0;
    wire    [7:0]           c_cache_len;
    assign c_cache_len = need_update_timer_wnd ? (new_ultra_wnd_hdr[31:9]-new_ultra_wnd_tail[31:9]) : (old_ultra_wnd_hdr[31:9]-old_ultra_wnd_tail[31:9]);
    reg                     r_cache_pushen=0;
    wire                    c_cache_pushen;
    assign c_cache_pushen = need_checkbitmap && r1_i_timer_alarm_vld;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_cache_s_info  <= 512'd0   ;
            r_cache_hdr     <= 32'd0    ;
            r_cache_tail    <= 32'd0    ;
            r_cache_len     <= 8'd0     ;
            r_cache_pushen  <= 1'd0     ;
        end 
    else
        begin
            r_cache_s_info  <= c_cache_s_info;
            r_cache_hdr     <= c_cache_hdr   ;
            r_cache_tail    <= c_cache_tail  ;
            r_cache_len     <= c_cache_len   ;
            r_cache_pushen  <= c_cache_pushen;
        end
    localparam MSG_FIFO_WIDTH = 512+32+32+8;
    wire                            msg_fifo_clk    ;
    wire                            msg_fifo_rst    ;
    wire                            msg_fifo_wren   ;
    wire    [MSG_FIFO_WIDTH-1:0]    msg_fifo_wrdat  ;
    wire    [MSG_FIFO_WIDTH-1:0]    msg_fifo_rddat  ;
    wire                            msg_fifo_rden   ;
    wire                            msg_fifo_empty  ;
    wire                            msg_fifo_pempty ;
    wire                            msg_fifo_full   ;
    wire                            msg_fifo_pfull  ;
    ipbase_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("bram"), // String
        .FIFO_READ_LATENCY(0),     // DECIMAL
        .FIFO_WRITE_DEPTH(512),   // DECIMAL
        .FULL_RESET_VALUE(1),      // DECIMAL
        .PROG_EMPTY_THRESH(16),    // DECIMAL
        .PROG_FULL_THRESH(488),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(10),   // DECIMAL
        .READ_DATA_WIDTH(MSG_FIFO_WIDTH),      // DECIMAL
        .READ_MODE("fwft"),         // String
        .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0707"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(MSG_FIFO_WIDTH),     // DECIMAL
        .WR_DATA_COUNT_WIDTH(10)    // DECIMAL
   )
   msgcmd_fifo_512d (
        .almost_empty     (),
        .almost_full      (),
        .data_valid       (),
        .dbiterr          (),
        .dout             (msg_fifo_rddat     ),
        .empty            (msg_fifo_empty     ),
        .full             (msg_fifo_full      ),
        .overflow         (),
        .prog_empty       (msg_fifo_pempty    ),
        .prog_full        (msg_fifo_pfull     ),
        .rd_data_count    (),
        .rd_rst_busy      (),
        .sbiterr          (),
        .underflow        (),
        .wr_ack           (),
        .wr_data_count    (),
        .wr_rst_busy      (),
        .din              (msg_fifo_wrdat     ),
        .injectdbiterr    (),
        .injectsbiterr    (),
        .rd_en            (msg_fifo_rden      ),
        .rst              (msg_fifo_rst       ),
        .sleep            (),
        .wr_clk           (msg_fifo_clk       ),
        .wr_en            (msg_fifo_wren      )                     
   );
    assign msg_fifo_clk = sys_clk;
    assign msg_fifo_rst = sys_rst;
    assign msg_fifo_wren    = r_cache_pushen;
    assign msg_fifo_wrdat   = {
        r_cache_len ,
        r_cache_hdr ,
        r_cache_tail,
        r_cache_s_info
    };

    wire    [7:0]           bitmap_len      ;
    wire    [31:0]          bitmap_hdr      ;
    wire    [31:0]          bitmap_tail     ;
    wire    [511:0]         bitmap_s_info   ;
    assign { 
        bitmap_len  ,
        bitmap_hdr  ,
        bitmap_tail ,
        bitmap_s_info } = msg_fifo_rddat;
//------------------------------------------------------------
// <ddr read cmd generate>
    assign cmd_araddr   = ddr_rd_addr       +BITMAP_BASE_ADDR;
    assign cmd_arlen    = ddr_rd_len        ;
    assign cmd_arvalid  = ~cmd_fifo_empty   ;
    assign cmd_rready   = i_nackgen_rdy     ;
    wire    [31-1:0]                adp_axi_araddr      ;
    wire    [7:0]                   adp_axi_arlen       ;
    wire                            adp_axi_arvalid     ;
    wire                            adp_axi_arready     ;
    wire    [512-1:0]               adp_axi_rdata       ;
    wire                            adp_axi_rlast       ;
    wire    [1:0]                   adp_axi_rresp       ;
    wire                            adp_axi_rvalid      ;
    wire                            adp_axi_rready      ;
    wire                            adp_err_trig        ;
    wire    [31:0]                  adp_dfx_sta         ;

    assign m_axi_arid       = AXI_ID_SET;
    assign m_axi_araddr     = adp_axi_araddr;
    assign m_axi_arlen      = adp_axi_arlen;
    assign m_axi_arsize     = 3'b110;
    assign m_axi_arburst    = 2'b01;
    assign m_axi_arlock     = 0;
    assign m_axi_arcache    = 0;
    assign m_axi_arprot     = 0;
    assign m_axi_arvalid    = adp_axi_arvalid;
    assign adp_axi_rdata    = m_axi_rdata;
    assign adp_axi_rlast    = m_axi_rlast;
    assign adp_axi_rresp    = m_axi_rresp;
    assign adp_axi_rvalid   = m_axi_rvalid;
    assign m_axi_rready     = adp_axi_rready;
    assign adp_axi_arready  = m_axi_arready ;
    ipbase_intf_axi_rd_adapter_simplified_v0p1#(
        ///--->>>>Caution! FIXED PARAM!
        // adapter parameter
        .DATA_WIDTH        ( 512 ),
        .ADDR_WIDTH        ( 32  ),
        .TLEN_WIDTH        ( 8   ) 
    )ipbase_intf_axi_rd_adapter_simplified_v0p1_dut(
        .sys_clk                (sys_clk                    ),//input   wire                                
        .sys_rst                (sys_rst                    ),//input   wire                                
        .cmd_araddr             (cmd_araddr                 ),//input   wire    [ADDR_WIDTH-1:0]            
        .cmd_arlen              (cmd_arlen                  ),//input   wire    [TLEN_WIDTH-1:0]            //256*64Byte=16384Byte=4*4096Byte
        .cmd_arvalid            (cmd_arvalid                ),//input   wire                                
        .cmd_arready            (cmd_arready                ),//output  wire                                
        .cmd_rdata              (cmd_rdata                  ),//output  wire    [DATA_WIDTH-1:0]            
        .cmd_rlast              (cmd_rlast                  ),//output  wire                                
        .cmd_rvalid             (cmd_rvalid                 ),//output  wire                                
        .cmd_rready             (cmd_rready                 ),//input   wire                                
        .axi_araddr             (adp_axi_araddr             ),//output  wire    [AXI_ADDR_WIDTH-1:0]        
        .axi_arlen              (adp_axi_arlen              ),//output  wire    [7:0]                       
        .axi_arvalid            (adp_axi_arvalid            ),//output  wire                                
        .axi_arready            (adp_axi_arready            ),//input   wire                                
        .axi_rdata              (adp_axi_rdata              ),//output  wire    [AXI_DATA_WIDTH-1:0]        
        .axi_rlast              (adp_axi_rlast              ),//output  wire                                
        .axi_rresp              (adp_axi_rresp              ),//output  wire    [1:0]                       
        .axi_rvalid             (adp_axi_rvalid             ),//output  wire                                
        .axi_rready             (adp_axi_rready             ),//input   wire                                
        .err_trig               (adp_err_trig               ),//output  wire                                
        .dfx_sta                (adp_dfx_sta                ) //output  wire    [31:0]                      
    );
//------------------------------------------------------------
//                   >>>nack request process<<<
// [align_npn           ]:
// [bitmap_hdr_mask     ]:
// [bitmap_tail_mask    ]:
// [cur_tran_len        ]:
// [judge_first_bitmap  ]:
// [judge_last_bitmap   ]:
// [nack_req_bitmap     ]:
// [nack_req_s_info     ]:
// [nack_req_npn        ]:
// [bitmap_first_mask   ]:
// [bitmap_last_mask    ]:
//------------------------------------------------------------
    wire    [31:0]          align_npn           ;
    wire    [511:0]         bitmap_hdr_mask     ;
    wire    [511:0]         bitmap_tail_mask    ;
    wire    [7:0]           cur_tran_len        ;
    wire                    judge_first_bitmap  ;
    wire                    judge_last_bitmap   ;
    wire    [511:0]         nack_req_bitmap     ;
    wire    [511:0]         nack_req_s_info     ;
    wire    [31:0]          nack_req_npn        ;
    wire    [511:0]         bitmap_first_mask   ;
    wire    [511:0]         bitmap_last_mask    ;
    assign align_npn = {bitmap_tail[31:9],9'd0};
    assign bitmap_first_mask = {512{1'b1}} << bitmap_tail[8:0];
    assign bitmap_last_mask = ~{{{511{1'b1}},1'd0} << bitmap_hdr[8:0]};
    
    assign judge_first_bitmap = cur_tran_len==0 ? 1 : 0;
    assign judge_last_bitmap  = cur_tran_len==bitmap_len ? 1 : 0;
    assign nack_req_bitmap = 
            {judge_first_bitmap,judge_last_bitmap} == 2'b10 ? (cmd_rdata & bitmap_first_mask) : 
            {judge_first_bitmap,judge_last_bitmap} == 2'b01 ? (cmd_rdata & bitmap_last_mask ) : 
            {judge_first_bitmap,judge_last_bitmap} == 2'b11 ? (cmd_rdata & bitmap_first_mask & bitmap_last_mask) : cmd_rdata ;
    assign nack_req_npn = align_npn+cur_tran_len*512;
    assign nack_req_s_info = bitmap_s_info;
//------------------------------------------------------------
// <bitmap process>
    reg     [7:0]           r_cur_tran_len=8'd0;
    wire    [7:0]           c_cur_tran_len;
    assign c_cur_tran_len = 
                r_cur_tran_len == bitmap_len && cmd_rvalid && cmd_rready ? 8'd0 :
                cmd_rvalid && cmd_rready ? r_cur_tran_len + 1 :
                r_cur_tran_len;
    always@(posedge sys_clk)
    if(sys_rst)
        r_cur_tran_len <= 8'd0;
    else
        r_cur_tran_len <= c_cur_tran_len;

    assign msg_fifo_rden = r_cur_tran_len == bitmap_len && cmd_rvalid && cmd_rready;
    assign cur_tran_len = r_cur_tran_len;
//------------------------------------------------------------
    //con to nack gen
    reg     [15:0]                              r_nackgen_sn =16'd0;//nc
    reg     [1024+32-1:0]                       r_nackgen_req=1024'd0;
    reg                                         r_nackgen_vld=1'd0;
    wire    [15:0]                              c_nackgen_sn ;
    wire    [1024+32-1:0]                       c_nackgen_req;
    wire                                        c_nackgen_vld;
    assign c_nackgen_req = {
        nack_req_npn,
        nack_req_s_info,
        nack_req_bitmap};
    assign c_nackgen_vld = cmd_rvalid && cmd_rready;

    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_nackgen_req <= 1024'd0;
            r_nackgen_vld <= 0;
        end
    else
        begin
            r_nackgen_req <= c_nackgen_req;
            r_nackgen_vld <= c_nackgen_vld;
        end

    assign o_nackgen_sn  = 16'd0;
    assign o_nackgen_req = r_nackgen_req;
    assign o_nackgen_vld = r_nackgen_vld;

//----------------------------------------------------------------------------------
//
//\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
//  <DFX Status>
//----------------------------------------------------------------------------------
    wire                    dfx_sta_clear;
    assign dfx_sta_clear = i_cfg_reg0[0];
    //------------------------------------------------------------------------------
    // alarm counter
        wire    [15:0]          c_timer_alarm_counter;
        reg     [15:0]          r_timer_alarm_counter = 16'd0;
        wire    [ 7:0]          c_chksum_failed_counter;
        reg     [ 7:0]          r_chksum_failed_counter=8'd0;
        wire    [ 7:0]          c_hitwnd_failed_counter;
        reg     [ 7:0]          r_hitwnd_failed_counter=8'd0;
        assign c_timer_alarm_counter    = dfx_sta_clear ? 16'd0 : i_timer_alarm_vld & o_timer_alarm_rdy ? r_timer_alarm_counter + 16'd1 : r_timer_alarm_counter;
        assign c_chksum_failed_counter  = dfx_sta_clear ?  8'd0 : r1_i_timer_alarm_vld && chksum_comp_failed ? r_chksum_failed_counter + 8'd1 : r_chksum_failed_counter;
        assign c_hitwnd_failed_counter  = dfx_sta_clear ?  8'd0 : r1_i_timer_alarm_vld && hit_ins_wnd_failed ? r_hitwnd_failed_counter + 8'd1 : r_hitwnd_failed_counter;
        always@(posedge sys_clk)
        if(sys_rst)
            begin
                r_timer_alarm_counter   <= 16'd0;
                r_chksum_failed_counter <= 8'd0;
                r_hitwnd_failed_counter <= 8'd0;
            end
        else
            begin
                r_timer_alarm_counter   <= c_timer_alarm_counter   ;
                r_chksum_failed_counter <= c_chksum_failed_counter ;
                r_hitwnd_failed_counter <= c_hitwnd_failed_counter ;
            end
    //------------------------------------------------------------------------------
    // reload timer counter
        wire    [15:0]          c_rldtimer_counter;
        reg     [15:0]          r_rldtimer_counter=16'd0;
        wire    [15:0]          c_rldtimer_finial_counter;
        reg     [15:0]          r_rldtimer_finial_counter=16'd0;
        assign c_rldtimer_counter       = dfx_sta_clear ? 16'd0 : r_rld_tmg_valid ? r_rldtimer_counter + 16'd1 : r_rldtimer_counter;
        assign c_rldtimer_finial_counter= dfx_sta_clear ? 16'd0 : r1_i_timer_alarm_vld && retry_last_time ? r_rldtimer_finial_counter + 16'd1 : r_rldtimer_finial_counter;
        always@(posedge sys_clk)
        if(sys_rst)
            begin
                r_rldtimer_counter          <= 16'd0;
                r_rldtimer_finial_counter   <= 16'd0;

            end
        else
            begin
                r_rldtimer_counter          <= c_rldtimer_counter          ;
                r_rldtimer_finial_counter   <= c_rldtimer_finial_counter   ;
            end
    //------------------------------------------------------------------------------
    // nack request counter
        wire    [15:0]          c_nackgen_req_counter;
        reg     [15:0]          r_nackgen_req_counter;
        assign c_nackgen_req_counter = dfx_sta_clear ? 16'd0 : o_nackgen_vld ? r_nackgen_req_counter + 16'd0 : r_nackgen_req_counter;
        always@(posedge sys_clk)
        if(sys_rst)
            r_nackgen_req_counter <= 16'd0;
        else
            r_nackgen_req_counter <= c_nackgen_req_counter;
    //------------------------------------------------------------------------------
    // axi sta counter
        wire    [7:0]           c_axi_rd_addr_counter   ;
        wire    [7:0]           c_axi_rd_data_counter   ;
        wire    [1:0]           c_axi_rd_addr_sta       ;
        wire    [1:0]           c_axi_rd_data_sta       ;
        reg     [7:0]           r_axi_rd_addr_counter   =8'd0;
        reg     [7:0]           r_axi_rd_data_counter   =8'd0;
        reg     [1:0]           r_axi_rd_addr_sta       =2'd0;
        reg     [1:0]           r_axi_rd_data_sta       =2'd0;
        assign c_axi_rd_addr_counter = dfx_sta_clear ? 16'd0 : m_axi_arvalid & m_axi_arready ? r_axi_rd_addr_counter + 8'd1 : r_axi_rd_addr_counter;
        assign c_axi_rd_data_counter = dfx_sta_clear ? 16'd0 : m_axi_rvalid & m_axi_rready & m_axi_rlast ? r_axi_rd_data_counter + 8'd1 : r_axi_rd_data_counter;
        assign c_axi_rd_addr_sta = {m_axi_arvalid,m_axi_arready};
        assign c_axi_rd_data_sta = {m_axi_rvalid ,m_axi_rready };
        always@(posedge sys_clk)
        if(sys_rst)
            begin
                r_axi_rd_addr_counter   <=8'd0;
                r_axi_rd_data_counter   <=8'd0;
                r_axi_rd_addr_sta       <=2'd0;
                r_axi_rd_data_sta       <=2'd0;
            end
        else
            begin
                r_axi_rd_addr_counter   <=c_axi_rd_addr_counter   ;
                r_axi_rd_data_counter   <=c_axi_rd_data_counter   ;
                r_axi_rd_addr_sta       <=c_axi_rd_addr_sta       ;
                r_axi_rd_data_sta       <=c_axi_rd_data_sta       ;
            end
        wire    [7:0]           c_cmd_rd_addr_counter   ;
        wire    [7:0]           c_cmd_rd_data_counter   ;
        wire    [1:0]           c_cmd_rd_addr_sta       ;
        wire    [1:0]           c_cmd_rd_data_sta       ;
        wire    [1:0]           c_cmd_rd_cache_sta      ;
        reg     [7:0]           r_cmd_rd_addr_counter   =8'd0;
        reg     [7:0]           r_cmd_rd_data_counter   =8'd0;
        reg     [1:0]           r_cmd_rd_addr_sta       =2'd0;
        reg     [1:0]           r_cmd_rd_data_sta       =2'd0;
        reg     [1:0]           r_cmd_rd_cache_sta      =2'd0;
        assign c_cmd_rd_addr_counter = dfx_sta_clear ? 16'd0 : cmd_arvalid & cmd_arready ? r_cmd_rd_addr_counter + 8'd1 : r_cmd_rd_addr_counter;
        assign c_cmd_rd_data_counter = dfx_sta_clear ? 16'd0 : cmd_rvalid & cmd_rready & cmd_rlast ? r_cmd_rd_data_counter + 8'd1 : r_cmd_rd_data_counter;
        assign c_cmd_rd_addr_sta = {cmd_arvalid,cmd_arready};
        assign c_cmd_rd_data_sta = {cmd_rvalid ,cmd_rready };
        assign c_cmd_rd_cache_sta = {cmd_fifo_empty,msg_fifo_empty};
        always@(posedge sys_clk)
        if(sys_rst)
            begin
                r_cmd_rd_addr_counter   <=8'd0;
                r_cmd_rd_data_counter   <=8'd0;
                r_cmd_rd_addr_sta       <=2'd0;
                r_cmd_rd_data_sta       <=2'd0;
                r_cmd_rd_cache_sta      <=2'd0;
            end
        else
            begin
                r_cmd_rd_addr_counter   <=c_cmd_rd_addr_counter   ;
                r_cmd_rd_data_counter   <=c_cmd_rd_data_counter   ;
                r_cmd_rd_addr_sta       <=c_cmd_rd_addr_sta       ;
                r_cmd_rd_data_sta       <=c_cmd_rd_data_sta       ;
                r_cmd_rd_cache_sta      <=c_cmd_rd_cache_sta      ;
            end
    //------------------------------------------------------------------------------
    // CON
        assign o_sta_reg0 = {
            r_timer_alarm_counter   ,
            r_chksum_failed_counter ,
            r_hitwnd_failed_counter 
        };
        assign o_sta_reg1 = {
            r_rldtimer_counter        ,
            r_rldtimer_finial_counter 
        };
        assign o_sta_reg2 = {
            r_axi_rd_addr_sta       ,
            r_axi_rd_data_sta       ,
            r_cmd_rd_addr_sta       ,
            r_cmd_rd_data_sta       ,
            r_cmd_rd_cache_sta      ,
            r_nackgen_req_counter   
        };
        assign o_sta_reg3 = {
            r_axi_rd_addr_counter   ,
            r_axi_rd_data_counter   ,
            r_cmd_rd_addr_counter   ,
            r_cmd_rd_data_counter   
        };
endmodule