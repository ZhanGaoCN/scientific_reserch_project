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
module seanetnackgenerator_window_calcore#(
    parameter MAX_WND_SIZE = 16'd4096
)(
    input   wire                                        sys_clk         ,
    input   wire                                        sys_rst         ,
    // current window msg
    input   wire    [31:0]                              cur_wnd_hdr     ,
    input   wire    [31:0]                              cur_wnd_tail    ,
    // current exprpn/rpn msg
    input   wire    [15:0]                              cur_wnd_sn      ,
    input   wire    [31:0]                              cur_wnd_chksum  ,
    input   wire    [95:0]                              cur_wnd_keymsg  ,
    input   wire    [1:0]                               cur_wnd_type    ,//01normal 10nackreply 11reset
    input   wire                                        cur_wnd_valid   ,
    input   wire                                        cur_wnd_otsta   ,
    output  wire                                        cur_wnd_ready   ,
    // update window msg(dir-write ram)
    output  wire    [31:0]                              new_wnd_hdr     ,
    output  wire    [31:0]                              new_wnd_tail    ,
    output  wire    [15:0]                              new_wnd_sn      ,
    output  wire                                        new_wnd_valid   ,
    // generate timer request
    output  wire    [15:0]                              timer_req_sn    ,
    output  wire    [31:0]                              timer_req_hdr   ,
    output  wire    [31:0]                              timer_req_tail  ,
    output  wire    [383:0]                             timer_req_bitmap,
    output  wire    [31:0]                              timer_req_chksum,
    output  wire                                        timer_req_valid ,
    input   wire                                        timer_req_ready ,
    // generate ddr rw cmd
    output  wire    [31:0]                              ddr_cmd_addr    ,
    output  wire    [511:0]                             ddr_cmd_data    ,
    output  wire    [7:0]                               ddr_cmd_len     ,
    output  wire    [1:0]                               ddr_cmd_type    ,//01bitmap update 
    output  wire                                        ddr_cmd_valid   ,
    input   wire                                        ddr_cmd_ready   ,
    // connect to dfx port      
    input   wire    [31:0]                              i_cfg_reg0              ,
    input   wire    [31:0]                              i_cfg_reg1              ,
    output  wire    [31:0]                              o_sta_reg0              ,                
    output  wire    [31:0]                              o_sta_reg1              ,                
    output  wire    [31:0]                              o_sta_reg2              ,                
    output  wire    [31:0]                              o_sta_reg3                
);
//------------------------------------------------------------
// <pkt demux>
    wire    [31:0]      cur_wnd_nor_exprpn  ;
    wire    [31:0]      cur_wnd_nor_rpn     ;
    wire                cur_wnd_nor_vld     ;
    assign cur_wnd_nor_exprpn   = cur_wnd_keymsg[63:32];//exp rpn
    assign cur_wnd_nor_rpn      = cur_wnd_keymsg[31:0];//rpn
    assign cur_wnd_nor_vld      = cur_wnd_type==2'b01 && cur_wnd_valid;
    wire    [63:0]      cur_wnd_nack_bitmap ;
    wire    [31:0]      cur_wnd_nack_npn    ;
    wire                cur_wnd_nack_vld    ;
    assign cur_wnd_nack_bitmap  = cur_wnd_keymsg[95:32];
    assign cur_wnd_nack_npn     = cur_wnd_keymsg[31:0];
    assign cur_wnd_nack_vld     = cur_wnd_type==2'b10 && cur_wnd_valid;
    wire    [31:0]      cur_wnd_rst_exprpn  ;
    wire    [31:0]      cur_wnd_rst_rpn     ;
    wire                cur_wnd_rst_vld     ;
    assign cur_wnd_rst_exprpn   = cur_wnd_keymsg[63:32];
    assign cur_wnd_rst_rpn      = cur_wnd_keymsg[31:0];
    assign cur_wnd_rst_vld      = cur_wnd_type==2'b11 && cur_wnd_valid;
//------------------------------------------------------------
//                   >>>window update process<<<
// [judge_old           ]:rpn is localized to hit window
// [judge_new           ]:new request coming
// [max_window_size     ]:max length of window, register drp config
// [nxt_wnd_hdr         ]:next header, based on max_window_size
// [nxt_wnd_tail        ]:next tail, based on max_window_size
// [new_req_wnd_hdr     ]:next header, based on request
// [new_req_wnd_tail    ]:next tail, based on request
// [condi_overwindow    ]:the flag describe the window cross 32bit-boundray
// [judge_hit_window    ]:rpn is localized to hit window
// [judge_cover_window  ]:new-request is covered by max_window_size
// []:
//------------------------------------------------------------
    wire                        judge_old           ;
    wire                        judge_new           ;
    wire    [31:0]              max_window_size     ;
    wire    [31:0]              nxt_wnd_hdr         ;
    wire    [31:0]              nxt_wnd_tail        ;
    wire    [31:0]              new_req_wnd_hdr     ;
    wire    [31:0]              new_req_wnd_tail    ;
    wire                        condi_overwindow    ;
    wire                        judge_hit_window    ;
    wire                        judge_cover_window  ;
    assign judge_old = 
            cur_wnd_nor_rpn < cur_wnd_nor_exprpn ?
                cur_wnd_nor_rpn < max_window_size && cur_wnd_nor_exprpn > ~max_window_size ? 0 : 
                1 :
            cur_wnd_nor_rpn > cur_wnd_nor_exprpn ?
                cur_wnd_nor_exprpn < max_window_size && cur_wnd_nor_rpn > ~max_window_size ? 1 : 
                0 :
            0;
    assign judge_new = 
            cur_wnd_nor_rpn < cur_wnd_nor_exprpn ?
                cur_wnd_nor_rpn < max_window_size && cur_wnd_nor_exprpn > ~max_window_size ? 1 : 
                0 :
            cur_wnd_nor_rpn > cur_wnd_nor_exprpn ?
                cur_wnd_nor_exprpn < max_window_size && cur_wnd_nor_rpn > ~max_window_size ? 0 : 
                1 :
            0;
    assign nxt_wnd_hdr  = cur_wnd_nor_rpn;
    assign nxt_wnd_tail = cur_wnd_nor_rpn - max_window_size;
    assign new_req_wnd_hdr = cur_wnd_nor_rpn;
    assign new_req_wnd_tail = cur_wnd_nor_exprpn;
    assign condi_overwindow = cur_wnd_hdr < cur_wnd_tail ? 1 : 0;
    assign judge_hit_window = 
            judge_old ? 
                condi_overwindow ? 
                    (cur_wnd_nor_rpn < cur_wnd_hdr || cur_wnd_nor_rpn > cur_wnd_tail) ? 1 :
                    0 :
                (cur_wnd_nor_rpn < cur_wnd_hdr && cur_wnd_nor_rpn > cur_wnd_tail) ? 1 :
                0 :
            0;
    assign judge_cover_window = 
            judge_new ? 
                nxt_wnd_hdr > cur_wnd_hdr ? 
                    cur_wnd_hdr >= cur_wnd_tail ? 
                        ((nxt_wnd_tail < cur_wnd_tail) || (nxt_wnd_tail > nxt_wnd_hdr)) ? 1 : 
                        0 :
                    cur_wnd_hdr < cur_wnd_tail ?
                        ((nxt_wnd_tail < cur_wnd_tail) && (nxt_wnd_tail > nxt_wnd_hdr)) ? 1 :
                        0 :
                    0 :
                nxt_wnd_hdr < cur_wnd_hdr ?
                    nxt_wnd_hdr < nxt_wnd_tail && nxt_wnd_tail < cur_wnd_tail ? 1 :
                    0 :
                0 :
            0;

    wire    [31:0]              inc_req_wnd_hdr;
    wire    [31:0]              inc_req_wnd_tail;
    assign inc_req_wnd_hdr = cur_wnd_nor_rpn;
    assign inc_req_wnd_tail = 
            cur_wnd_nor_rpn < cur_wnd_nor_exprpn ?
                cur_wnd_nor_rpn >= max_window_size ? cur_wnd_nor_rpn - max_window_size :
                cur_wnd_nor_rpn - max_window_size >= cur_wnd_nor_exprpn ? cur_wnd_nor_rpn - max_window_size :
                cur_wnd_nor_rpn - max_window_size <  cur_wnd_nor_exprpn ? cur_wnd_nor_exprpn :
                32'd0 :
            cur_wnd_nor_rpn > cur_wnd_nor_exprpn ?
                cur_wnd_nor_rpn >= max_window_size ?
                    cur_wnd_nor_rpn - max_window_size >= cur_wnd_nor_exprpn ? cur_wnd_nor_rpn - max_window_size :
                    cur_wnd_nor_rpn - max_window_size <  cur_wnd_nor_exprpn ? cur_wnd_nor_exprpn :
                    32'd0 :
                cur_wnd_nor_rpn < max_window_size ? cur_wnd_nor_exprpn :
                32'd0 :
            32'd0;
//------------------------------------------------------------
// <window header process>
// move condition:
//  1.new window request
//  2.stream reset
    wire    [31:0]              c_next_wnd_hdr;
    reg     [31:0]              r_next_wnd_hdr=32'd0;
    always@(posedge sys_clk)
    if(sys_rst)
        r_next_wnd_hdr <= 32'd0;
    else
        r_next_wnd_hdr <= c_next_wnd_hdr;

    assign c_next_wnd_hdr = 
                cur_wnd_nor_vld && judge_new ? nxt_wnd_hdr : 
                cur_wnd_rst_vld ? cur_wnd_rst_rpn :
                cur_wnd_hdr;
//------------------------------------------------------------
// <window tail process>
// move condition:
//  1.new window request
//  2.stream reset
    wire    [31:0]              c_next_wnd_tail;
    reg     [31:0]              r_next_wnd_tail=32'd0;
    always@(posedge sys_clk)
    if(sys_rst)
        r_next_wnd_tail <= 32'd0;
    else
        r_next_wnd_tail <= c_next_wnd_tail;

    assign c_next_wnd_tail = 
            cur_wnd_nor_vld && judge_cover_window ? cur_wnd_tail : 
            cur_wnd_rst_vld ? cur_wnd_rst_exprpn :
            nxt_wnd_tail;
//------------------------------------------------------------
// <window update process>
// move condition:
//  1.new window request
//  2.stream reset
    wire    [15:0]              c_next_wnd_sn;
    reg     [15:0]              r_next_wnd_sn=16'd0;
    always@(posedge sys_clk)
    if(sys_rst)
        r_next_wnd_sn <= 16'd0;
    else
        r_next_wnd_sn <= c_next_wnd_sn;
    assign c_next_wnd_sn = cur_wnd_sn;

    wire                        c_next_wnd_valid;
    reg                         r_next_wnd_valid=0;
    always@(posedge sys_clk)
    if(sys_rst)
        r_next_wnd_valid <= 0;
    else
        r_next_wnd_valid <= c_next_wnd_valid;
    assign c_next_wnd_valid = 
                cur_wnd_nor_vld && judge_new ? 1 :
                cur_wnd_rst_vld ? 1 :
                0;
//------------------------------------------------------------
//                   >>>timer generate process<<<
// [que_wnd_hdr             ]:
// [que_wnd_tail            ]:
// [ins_wnd_hdr             ]:
// [ins_wnd_tail            ]:
// [inc_wnd_hdr             ]:
// [inc_wnd_tail            ]:
// [que_wnd_hdr_update      ]:
// [que_wnd_tail_update     ]:
// [need_update_hdr         ]:
// [need_update_tail        ]:
// [align_ins_hdr_high      ]:
// [align_ins_tail_high     ]:
// [align_inc_hdr_high      ]:
// [align_inc_tail_high     ]:
// [timer_wnd_hdr           ]:
// [timer_wnd_tail          ]:
// [need_gen_timer          ]:
// [need_update_quewnd      ]:
// []:
//------------------------------------------------------------
    wire    [31:0]          que_wnd_hdr             ;//512 align
    wire    [31:0]          que_wnd_tail            ;
    wire    [31:0]          ins_wnd_hdr             ;
    wire    [31:0]          ins_wnd_tail            ;
    wire    [31:0]          inc_wnd_hdr             ;
    wire    [31:0]          inc_wnd_tail            ;
    wire    [31:0]          que_wnd_hdr_update      ;
    wire    [31:0]          que_wnd_tail_update     ;
    wire                    need_update_hdr         ;
    wire                    need_update_tail        ;
    wire    [22:0]          align_ins_hdr_high      ;
    wire    [22:0]          align_ins_tail_high     ;
    wire    [22:0]          align_inc_hdr_high      ;
    wire    [22:0]          align_inc_tail_high     ;
    wire    [31:0]          timer_wnd_hdr           ;
    wire    [31:0]          timer_wnd_tail          ;
    wire                    need_gen_timer          ;
    wire                    need_update_quewnd      ;    
    assign align_cur_hdr_high   = cur_wnd_hdr[31:9]-23'd1;
    assign align_cur_tail_high  = cur_wnd_tail[31:9];
    assign que_wnd_hdr          = cur_wnd_hdr[8:0] == 0 ? {align_cur_hdr_high , 9'd511} : {cur_wnd_hdr[31:9] , 9'd511};
    assign que_wnd_tail         = {align_cur_tail_high , 9'd0};
    assign ins_wnd_hdr          = c_next_wnd_hdr;
    assign ins_wnd_tail         = c_next_wnd_tail;
    assign inc_wnd_hdr          = inc_req_wnd_hdr;
    assign inc_wnd_tail         = 
                cur_wnd_hdr == cur_wnd_tail ? inc_req_wnd_tail :
                que_wnd_hdr >= inc_req_wnd_tail && inc_req_wnd_tail >= que_wnd_tail ? que_wnd_hdr+512 : 
                inc_req_wnd_tail >= que_wnd_tail && que_wnd_tail > que_wnd_hdr ? que_wnd_hdr+512 : 
                que_wnd_tail > que_wnd_hdr && que_wnd_hdr >= inc_req_wnd_tail ? que_wnd_hdr+512 : 
                inc_req_wnd_tail;

    assign align_ins_hdr_high   = ins_wnd_hdr[31:9]-23'd1;
    assign align_ins_tail_high  = ins_wnd_tail[31:9];
    assign que_wnd_hdr_update   = ins_wnd_hdr[8:0] == 0 ? {align_ins_hdr_high , 9'd511} : {ins_wnd_hdr[31:9] , 9'd511};
    assign que_wnd_tail_update  = {align_ins_tail_high,9'd0};
    assign align_inc_hdr_high   = inc_wnd_hdr[31:9]-23'd1;
    assign align_inc_tail_high  = inc_wnd_tail[31:9];
    //assign timer_wnd_hdr        = inc_wnd_hdr;
    //assign timer_wnd_tail       = inc_wnd_tail;
    assign timer_wnd_hdr        = inc_wnd_hdr[8:0] == 0 ? {align_inc_hdr_high , 9'd511} : {inc_wnd_hdr[31:9] , 9'd511};
    assign timer_wnd_tail       = {align_inc_tail_high,9'd0};
    assign need_update_hdr      = que_wnd_hdr != que_wnd_hdr_update;
    assign need_update_tail     = que_wnd_tail != que_wnd_tail_update;
    assign need_gen_timer       = need_update_hdr;
    assign need_update_quewnd   = need_update_hdr | need_update_tail;
//------------------------------------------------------------
// <timer request gen process>
// 
    reg     [15:0]              r_timer_req_sn    = 16'd0;
    reg     [31:0]              r_timer_req_hdr   = 32'd0;
    reg     [31:0]              r_timer_req_tail  = 32'd0;
    reg     [383:0]             r_timer_req_bitmap= 384'd0;
    reg     [31:0]              r_timer_req_chksum= 32'd0;
    reg                         r_timer_req_valid = 0;
    wire    [15:0]              c_timer_req_sn    ;
    wire    [31:0]              c_timer_req_hdr   ;
    wire    [31:0]              c_timer_req_tail  ;
    wire    [383:0]             c_timer_req_bitmap;
    wire    [31:0]              c_timer_req_chksum;
    wire                        c_timer_req_valid ;
    assign c_timer_req_sn     = cur_wnd_sn;
    assign c_timer_req_hdr    = timer_wnd_hdr;
    assign c_timer_req_tail   = timer_wnd_tail;
    //assign c_timer_req_bitmap = {384{1'b1}};//no used
    assign c_timer_req_bitmap = {inc_wnd_hdr,32'd0,{(384-64){1'b1}}};//used to dilv inc_wnd_hdr
    assign c_timer_req_chksum = cur_wnd_chksum;
    assign c_timer_req_valid  = 
                cur_wnd_nor_vld && judge_new ? need_gen_timer | cur_wnd_otsta : 
                cur_wnd_rst_vld ? 1 :
                0;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_timer_req_sn     <= 16'd0   ;
            r_timer_req_hdr    <= 32'd0   ;
            r_timer_req_tail   <= 32'd0   ;
            r_timer_req_bitmap <= 384'd0  ;
            r_timer_req_chksum <= 32'd0   ;
            r_timer_req_valid  <= 0       ;
        end
    else
        begin
            r_timer_req_sn     <= c_timer_req_sn    ;
            r_timer_req_hdr    <= c_timer_req_hdr   ;
            r_timer_req_tail   <= c_timer_req_tail  ;
            r_timer_req_bitmap <= c_timer_req_bitmap;
            r_timer_req_chksum <= c_timer_req_chksum;
            r_timer_req_valid  <= c_timer_req_valid ;
        end
//------------------------------------------------------------
//                   >>>bitmap cmdgen process<<<
// [cmd_type0]:xor, assert 0, one address
// [cmd_type1]:xor, assert 1, one address
// [cmd_type2]:direct, assert 0
// [cmd_type3]:direct, assert 1
//------------------------------------------------------------
    //hit window (cmd_type0,1bit)
    wire    [31:0]              gencmd_hit_window_hdr   ;
    wire    [31:0]              gencmd_hit_window_tail  ;
    wire    [15:0]              gencmd_hit_window_sn    ;
    wire    [1:0]               gencmd_hit_window_type  ;
    wire                        gencmd_hit_window_valid ;
    wire    [81+64:0]           gencmd_hit_window_cmd_pkt;
    assign gencmd_hit_window_hdr   = cur_wnd_nor_rpn+1;
    assign gencmd_hit_window_tail  = cur_wnd_nor_rpn;
    assign gencmd_hit_window_sn    = cur_wnd_sn;
    assign gencmd_hit_window_type  = 2'b00;
    assign gencmd_hit_window_valid = cur_wnd_nor_vld && judge_hit_window;
    assign gencmd_hit_window_cmd_pkt = {
        64'd0,
        gencmd_hit_window_type  ,
        gencmd_hit_window_sn    ,
        gencmd_hit_window_hdr   ,
        gencmd_hit_window_tail  
    };
    //window move (cmd_type1 + cmd_type3,random bit,0-max_window_size)
    wire    [31:0]              gencmd_move_window_hdr   ;
    wire    [31:0]              gencmd_move_window_tail  ;
    wire    [15:0]              gencmd_move_window_sn    ;
    wire    [1:0]               gencmd_move_window_type  ;
    wire                        gencmd_move_window_valid ;
    wire    [81+64:0]           gencmd_move_window_cmd_pkt;
    assign gencmd_move_window_hdr  = cur_wnd_nor_rpn;
    assign gencmd_move_window_tail = 
                cur_wnd_nor_exprpn > cur_wnd_nor_rpn ? 
                    cur_wnd_nor_rpn > nxt_wnd_tail ? nxt_wnd_tail :
                    nxt_wnd_tail > cur_wnd_nor_exprpn ? nxt_wnd_tail :
                    cur_wnd_nor_exprpn :
                cur_wnd_nor_exprpn < cur_wnd_nor_rpn ?
                    nxt_wnd_tail > cur_wnd_nor_rpn ? cur_wnd_nor_exprpn :
                    nxt_wnd_tail > cur_wnd_nor_exprpn ? nxt_wnd_tail :
                    cur_wnd_nor_exprpn :
                cur_wnd_nor_exprpn;
    assign gencmd_move_window_sn   = cur_wnd_sn;
    assign gencmd_move_window_type = cur_wnd_rst_vld ? 2'b11 : 2'b01;
    assign gencmd_move_window_valid= 
                (cur_wnd_nor_vld && judge_new) 
            || (cur_wnd_rst_vld);
    assign gencmd_move_window_cmd_pkt = {
        64'd0,
        gencmd_move_window_type  ,
        gencmd_move_window_sn    ,
        gencmd_move_window_hdr   ,
        gencmd_move_window_tail  
    };
    //nackreply(cmd_type0,64bit)
    wire    [63:0]              gencmd_nack_window_bitmap;
    wire    [31:0]              gencmd_nack_window_hdr   ;
    wire    [31:0]              gencmd_nack_window_tail  ;
    wire    [15:0]              gencmd_nack_window_sn    ;
    wire    [1:0]               gencmd_nack_window_type  ;
    wire                        gencmd_nack_window_valid ;
    wire    [81+64:0]           gencmd_nack_window_cmd_pkt;
    assign gencmd_nack_window_bitmap = cur_wnd_nack_bitmap;
    assign gencmd_nack_window_hdr  = cur_wnd_nack_npn+64;
    assign gencmd_nack_window_tail = cur_wnd_nack_npn;
    assign gencmd_nack_window_sn   = cur_wnd_sn;
    assign gencmd_nack_window_type = 2'b10;
    assign gencmd_nack_window_valid= cur_wnd_nack_vld;
    assign gencmd_nack_window_cmd_pkt = {
        gencmd_nack_window_bitmap,
        gencmd_nack_window_type  ,
        gencmd_nack_window_sn    ,
        gencmd_nack_window_hdr   ,
        gencmd_nack_window_tail  
    };
//------------------------------------------------------------
// <cmd cache>
    localparam FIFO_WIDTH = 82+64;
    wire                            fifo_clk    ;
    wire                            fifo_rst    ;
    wire                            fifo_wren   ;
    wire    [FIFO_WIDTH-1:0]        fifo_wrdat  ;
    wire    [FIFO_WIDTH-1:0]        fifo_rddat  ;
    wire                            fifo_rden   ;
    wire                            fifo_empty  ;
    wire                            fifo_pempty ;
    wire                            fifo_full   ;
    wire                            fifo_pfull  ;
    reg     [FIFO_WIDTH:0]          r_fifo_din=146'd0;
    wire    [FIFO_WIDTH:0]          c_fifo_din;
    reg                             r_fifo_wren=0;
    wire                            c_fifo_wren;
    ipbase_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("distribute"), // String
        .FIFO_READ_LATENCY(0),     // DECIMAL
        .FIFO_WRITE_DEPTH(64),   // DECIMAL
        .FULL_RESET_VALUE(1),      // DECIMAL
        .PROG_EMPTY_THRESH(10),    // DECIMAL
        .PROG_FULL_THRESH(55),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(6),   // DECIMAL
        .READ_DATA_WIDTH(FIFO_WIDTH),      // DECIMAL
        .READ_MODE("fwft"),         // String
        .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0707"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(FIFO_WIDTH),     // DECIMAL
        .WR_DATA_COUNT_WIDTH(6)    // DECIMAL
   )
   rw_cmd_fifo_64d (
        .almost_empty     (),
        .almost_full      (),
        .data_valid       (),
        .dbiterr          (),
        .dout             (fifo_rddat     ),
        .empty            (fifo_empty     ),
        .full             (fifo_full      ),
        .overflow         (),
        .prog_empty       (fifo_pempty    ),
        .prog_full        (fifo_pfull     ),
        .rd_data_count    (),
        .rd_rst_busy      (),
        .sbiterr          (),
        .underflow        (),
        .wr_ack           (),
        .wr_data_count    (),
        .wr_rst_busy      (),
        .din              (fifo_wrdat     ),
        .injectdbiterr    (),
        .injectsbiterr    (),
        .rd_en            (fifo_rden      ),
        .rst              (fifo_rst       ),
        .sleep            (),
        .wr_clk           (fifo_clk       ),
        .wr_en            (fifo_wren      )                     
   );
    assign fifo_clk = sys_clk;
    assign fifo_rst = sys_rst;
    assign fifo_wren    = r_fifo_wren;
    assign fifo_wrdat   = r_fifo_din;
    always@(posedge sys_clk)
    if(sys_rst)
        r_fifo_din <= 146'd0;
    else
        r_fifo_din <= c_fifo_din;
    always@(posedge sys_clk)
    if(sys_rst)
        r_fifo_wren <= 0;
    else
        r_fifo_wren <= c_fifo_wren;

    assign c_fifo_din = 
                gencmd_hit_window_valid  ? gencmd_hit_window_cmd_pkt  :
                gencmd_move_window_valid ? gencmd_move_window_cmd_pkt :
                gencmd_nack_window_valid ? gencmd_nack_window_cmd_pkt : 
                82'd0;
    assign c_fifo_wren = 
                gencmd_hit_window_valid  ? 1 :
                gencmd_move_window_valid ? 1 :
                gencmd_nack_window_valid ? 1 :
                0;
    reg     [81+64:0]   r_fifo_rddat_lock=146'd0;
    wire    [81+64:0]   c_fifo_rddat_lock;
    wire    [63:0]      pre_gencmd_window_bitmap;
    wire    [31:0]      pre_gencmd_window_hdr   ;
    wire    [31:0]      pre_gencmd_window_tail  ;
    wire    [15:0]      pre_gencmd_window_sn    ;
    wire    [1:0]       pre_gencmd_window_type  ;
    wire    [63:0]      gencmd_window_bitmap;
    wire    [31:0]      gencmd_window_hdr   ;
    wire    [31:0]      gencmd_window_tail  ;
    wire    [15:0]      gencmd_window_sn    ;
    wire    [1:0]       gencmd_window_type  ;
    assign c_fifo_rddat_lock = fifo_rden ? fifo_rddat : r_fifo_rddat_lock;
    always@(posedge sys_clk)
    if(sys_rst)
        r_fifo_rddat_lock <= 146'd0;
    else
        r_fifo_rddat_lock <= c_fifo_rddat_lock;
    assign {
        gencmd_window_bitmap,
        gencmd_window_type  ,
        gencmd_window_sn    ,
        gencmd_window_hdr   ,
        gencmd_window_tail  
            } = r_fifo_rddat_lock;
    assign {
        pre_gencmd_window_bitmap,
        pre_gencmd_window_type  ,
        pre_gencmd_window_sn    ,
        pre_gencmd_window_hdr   ,
        pre_gencmd_window_tail  
            } = fifo_rddat;
//------------------------------------------------------------  
// <simplify fifo read process, reduce lantency>
    wire    [8:0]       pre_window_length           ;
    wire                pre_first_tran_en           ;
    wire                pre_second_tran_en          ;
    wire                pre_third_tran_en           ;
    reg                 prelock_first_tran_en =0    ;
    reg                 prelock_second_tran_en=0    ;
    reg                 prelock_third_tran_en =0    ;
    assign pre_window_length = pre_gencmd_window_hdr[17:9] - pre_gencmd_window_tail[17:9];
    assign pre_first_tran_en = 1;
    assign pre_second_tran_en = 
            pre_gencmd_window_hdr[8:0] == 9'd0 ?
                pre_window_length == 9'd0 ? 0 :
                pre_window_length == 9'd1 ? 0 :
                1 :
            pre_gencmd_window_hdr[8:0] != 9'd0 ?
                pre_window_length == 9'd0 ? 0 :
                1 :
            0;
    assign pre_third_tran_en = 
            pre_gencmd_window_hdr[8:0] == 9'd0 ?
                pre_window_length > 9'd257 ? 1 :
                0 :
            pre_gencmd_window_hdr[8:0] != 9'd0 ?
                pre_window_length > 9'd256 ? 1 :
                0 :
            1;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            prelock_first_tran_en <= 0;
            prelock_second_tran_en<= 0;
            prelock_third_tran_en <= 0;
        end
    else if(fifo_rden)
        begin
            prelock_first_tran_en <= pre_first_tran_en ; 
            prelock_second_tran_en<= pre_second_tran_en; 
            prelock_third_tran_en <= pre_third_tran_en ; 
        end
    else
        begin
            prelock_first_tran_en <= prelock_first_tran_en ; 
            prelock_second_tran_en<= prelock_second_tran_en; 
            prelock_third_tran_en <= prelock_third_tran_en ; 
        end
//------------------------------------------------------------
// <generate ddr rw cmd>
// only need to update bitmap, not to update the window base the bitmap.
    // cmd generator FSM
    localparam CMD_IDLE         = 4'd0;
    localparam CMD_FIRST_GEN    = 4'd1;
    localparam CMD_SECOND_GEN   = 4'd2;
    localparam CMD_THIRD_GEN    = 4'd3;
    reg     [3:0]               cmd_FSM_cs=CMD_IDLE;
    reg     [3:0]               cmd_FSM_ns;
    wire                        cmd_input_rdy;
    wire                        cmd_output_rdy;
    wire                        cmd_type0_trandone;
    wire                        cmd_type1_trandone;
    wire                        cmd_trandone;
    always@(posedge sys_clk)
    if(sys_rst)
        cmd_FSM_cs <= CMD_IDLE;
    else
        cmd_FSM_cs <= cmd_FSM_ns;
    always@(*)
    case(cmd_FSM_cs)
    CMD_IDLE:
        if(cmd_input_rdy && cmd_output_rdy)
            cmd_FSM_ns=CMD_FIRST_GEN;
        else
            cmd_FSM_ns=CMD_IDLE;
    CMD_FIRST_GEN:
        if(prelock_second_tran_en)
            cmd_FSM_ns=CMD_SECOND_GEN;
        else if(cmd_input_rdy && cmd_output_rdy)
            cmd_FSM_ns=CMD_FIRST_GEN;
        else
            cmd_FSM_ns=CMD_IDLE;
    CMD_SECOND_GEN:
        if(prelock_third_tran_en)
            cmd_FSM_ns=CMD_THIRD_GEN;
        else if(cmd_input_rdy && cmd_output_rdy)
            cmd_FSM_ns=CMD_FIRST_GEN;
        else
            cmd_FSM_ns=CMD_IDLE;
    CMD_THIRD_GEN:
        if(cmd_input_rdy && cmd_output_rdy)
            cmd_FSM_ns=CMD_FIRST_GEN;
        else
            cmd_FSM_ns=CMD_IDLE;
    default:cmd_FSM_ns=CMD_IDLE;
    endcase

    assign fifo_rden = cmd_input_rdy && cmd_output_rdy ? 
                            cmd_FSM_cs == CMD_IDLE          ? 1 :
                            cmd_FSM_cs == CMD_FIRST_GEN  && ~prelock_second_tran_en ? 1 :
                            cmd_FSM_cs == CMD_SECOND_GEN && ~prelock_third_tran_en  ? 1 :
                            cmd_FSM_cs == CMD_THIRD_GEN     ? 1 :
                            0:
                        0;
    assign cmd_input_rdy = ~fifo_empty;
//------------------------------------------------------------
//                   >>>ddr rwcmd gen process<<<
// [first_tran_wnd_ptr          ]:
// [second_tran_wnd_ptr         ]:
// [first_cmd_gen_addr          ]:
// [second_cmd_gen_addr         ]:
// [third_cmd_gen_addr          ]:
// [first_tran_data_hdrptr      ]:
// [second_tran_data_hdrptr     ]:
// [third_tran_data_hdrptr      ]:
// [first_tran_data_tailptr     ]:
// [second_tran_data_tailptr    ]:
// [third_tran_data_tailptr     ]:
// [first_tran_data             ]:
// [second_tran_data            ]:
// [third_tran_data             ]:
// [first_tran_len              ]:
// [second_tran_len             ]:
// [third_tran_len              ]:
// [window_length               ]:
// [first_tran_en               ]:
// [second_tran_en              ]:
// [third_tran_en               ]:
// []:
// []:
//------------------------------------------------------------
    localparam ACTION_UNIT = {512{1'b1}};
    wire    [8:0]       first_tran_wnd_ptr          ;
    wire    [8:0]       second_tran_wnd_ptr         ;
    wire    [31:0]      first_cmd_gen_addr          ;
    wire    [31:0]      second_cmd_gen_addr         ;
    wire    [31:0]      third_cmd_gen_addr          ;
    wire    [8:0]       first_tran_data_hdrptr      ;
    wire    [8:0]       second_tran_data_hdrptr     ;
    wire    [8:0]       third_tran_data_hdrptr      ;
    wire    [8:0]       first_tran_data_tailptr     ;
    wire    [8:0]       second_tran_data_tailptr    ;
    wire    [8:0]       third_tran_data_tailptr     ;
    wire    [511:0]     first_tran_data             ;
    wire    [511:0]     second_tran_data            ;
    wire    [511:0]     third_tran_data             ;
    wire    [7:0]       first_tran_len              ;
    wire    [7:0]       second_tran_len             ;
    wire    [7:0]       third_tran_len              ;
    wire    [8:0]       window_length               ;
    wire                first_tran_en               ;
    wire                second_tran_en              ;
    wire                third_tran_en               ;
    //addr calculate
    assign first_tran_wnd_ptr   = gencmd_window_tail[17:9];
    assign second_tran_wnd_ptr  = gencmd_window_tail[17:9]+9'd1;//avoid first tran
    assign third_tran_wnd_ptr   = gencmd_window_tail[17:9]+9'd1+9'd256;//max axi4mm 8bit-brust tran-slice
    assign first_cmd_gen_addr   = {7'd0,gencmd_window_sn[9:0], first_tran_wnd_ptr,6'd0};//7+10+9+6
    assign second_cmd_gen_addr  = {7'd0,gencmd_window_sn[9:0],second_tran_wnd_ptr,6'd0};//7+10+9+6
    assign third_cmd_gen_addr   = {7'd0,gencmd_window_sn[9:0], third_tran_wnd_ptr,6'd0};//7+10+9+6
    //data calculate
    assign first_tran_data_hdrptr   = gencmd_window_hdr[8:0];
    assign first_tran_data_tailptr  = gencmd_window_tail[8:0];
    assign second_tran_data_hdrptr  = gencmd_window_hdr[8:0];
    assign second_tran_data_tailptr = 0;
    assign third_tran_data_hdrptr   = gencmd_window_hdr[8:0];
    assign third_tran_data_tailptr  = 0;
    assign first_tran_data      = gencmd_window_type == 2'b10 ? {448'd0,gencmd_window_bitmap}<<(first_tran_data_tailptr) :
            (gencmd_window_tail[17:9] == gencmd_window_hdr[17:9]) ? ~(ACTION_UNIT<<first_tran_data_hdrptr) & ACTION_UNIT<<first_tran_data_tailptr :
            ACTION_UNIT<<first_tran_data_tailptr;
    assign second_tran_data     = third_tran_en ? ACTION_UNIT : ~(ACTION_UNIT<<second_tran_data_hdrptr);
    assign third_tran_data      = ~(ACTION_UNIT<<third_tran_data_hdrptr);
    //tran length calculate
    assign window_length = gencmd_window_hdr[17:9] - gencmd_window_tail[17:9];
    assign first_tran_len   = 0;
    assign second_tran_len  = 
            gencmd_window_hdr[8:0] == 9'd0 ?
                window_length == 9'd0 ? 8'd0 :
                window_length == 9'd1 ? 8'd0 :
                window_length >= 9'd2 && window_length < 9'd257 ? window_length[7:0]-8'd2 : 
                window_length >= 9'd257 ? 8'd255 :
                8'd0 :
            gencmd_window_hdr[8:0] != 9'd0 ?
                window_length == 9'd0 ? 8'd0 :
                window_length == 9'd1 ? 8'd0 :
                window_length >= 9'd2 && window_length < 9'd256 ? window_length[7:0]-8'd1 : 
                window_length >= 9'd256 ? 8'd255 :
                8'd0 :
            8'd0;
    assign third_tran_len   =
            gencmd_window_hdr[8:0] == 9'd0 ?
                window_length > 9'd257 ? window_length[7:0] -8'd2 :
                8'd0 :
            gencmd_window_hdr[8:0] != 9'd0 ?
                window_length > 9'd256 ? window_length[7:0] -8'd1 :
                8'd0 :
            8'd0;
    assign first_tran_en = 1;
    assign second_tran_en = 
            gencmd_window_hdr[8:0] == 9'd0 ?
                window_length == 9'd0 ? 0 :
                window_length == 9'd1 ? 0 :
                1 :
            gencmd_window_hdr[8:0] != 9'd0 ?
                window_length == 9'd0 ? 0 :
                1 :
            0;
    assign third_tran_en = 
            gencmd_window_hdr[8:0] == 9'd0 ?
                window_length > 9'd257 ? 1 :
                0 :
            gencmd_window_hdr[8:0] != 9'd0 ?
                window_length > 9'd256 ? 1 :
                0 :
            1;
//------------------------------------------------------------
// <gencmd push>
    wire    [511:0]                 gencmd_data     ;
    wire    [31 :0]                 gencmd_addr     ;
    wire    [7  :0]                 gencmd_len      ;
    wire    [1  :0]                 gencmd_type     ;
    wire                            gencmd_valid    ;
    reg     [511:0]                 r_gencmd_data =512'd0;
    reg     [31 :0]                 r_gencmd_addr =32'd0;
    reg     [7  :0]                 r_gencmd_len  =8'd0;
    reg     [1  :0]                 r_gencmd_type =2'd0;
    reg                             r_gencmd_valid=1'd0;
    wire    [511:0]                 c_gencmd_data     ;
    wire    [31 :0]                 c_gencmd_addr     ;
    wire    [1  :0]                 c_gencmd_len      ;
    wire    [1  :0]                 c_gencmd_type     ;
    wire                            c_gencmd_valid    ;
    assign c_gencmd_data  = 
        cmd_FSM_cs == CMD_FIRST_GEN     ? first_tran_data   : 
        cmd_FSM_cs == CMD_SECOND_GEN    ? second_tran_data  : 
        cmd_FSM_cs == CMD_THIRD_GEN     ? third_tran_data   : 512'd0;
    assign c_gencmd_addr  = 
        cmd_FSM_cs == CMD_FIRST_GEN     ? first_cmd_gen_addr   : 
        cmd_FSM_cs == CMD_SECOND_GEN    ? second_cmd_gen_addr  : 
        cmd_FSM_cs == CMD_THIRD_GEN     ? third_cmd_gen_addr   : 32'd0;
    assign c_gencmd_type  = 
        cmd_FSM_cs == CMD_FIRST_GEN     ? 
            gencmd_window_type == 2'b00 ? 2'b00 :
            gencmd_window_type == 2'b01 ? 2'b01 :
            gencmd_window_type == 2'b10 ? 2'b00 :
            gencmd_window_type == 2'b11 ? 2'b11 :
            2'b00 :
        cmd_FSM_cs == CMD_SECOND_GEN    ? 2'b11 :
        cmd_FSM_cs == CMD_THIRD_GEN     ? 2'b11 :
        2'b00;
    assign c_gencmd_valid = 
        cmd_FSM_cs == CMD_FIRST_GEN     ? 1 : 
        cmd_FSM_cs == CMD_SECOND_GEN    ? 1 : 
        cmd_FSM_cs == CMD_THIRD_GEN     ? 1 : 0;
    assign c_gencmd_len   =
        cmd_FSM_cs == CMD_FIRST_GEN     ? first_tran_len : 
        cmd_FSM_cs == CMD_SECOND_GEN    ? second_tran_len : 
        cmd_FSM_cs == CMD_THIRD_GEN     ? third_tran_len : 8'd0;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_gencmd_data <=512'd0  ;
            r_gencmd_addr <=32'd0   ;
            r_gencmd_type <=2'd0    ;
            r_gencmd_len  <=8'd0    ;
            r_gencmd_valid<=1'd0    ;
        end
    else
        begin
            r_gencmd_data <=c_gencmd_data ;
            r_gencmd_addr <=c_gencmd_addr ;
            r_gencmd_type <=c_gencmd_type ;
            r_gencmd_len  <=c_gencmd_len  ;
            r_gencmd_valid<=c_gencmd_valid;
        end
    assign gencmd_data  = r_gencmd_data ;
    assign gencmd_addr  = r_gencmd_addr ;
    assign gencmd_type  = r_gencmd_type ;
    assign gencmd_len   = r_gencmd_len  ;
    assign gencmd_valid = r_gencmd_valid;
//------------------------------------------------------------
// <gencmd cache>
    localparam GENCMD_FIFO_WIDTH = 512+32+2+8;
    wire                            gencmd_fifo_clk    ;
    wire                            gencmd_fifo_rst    ;
    wire                            gencmd_fifo_wren   ;
    wire    [GENCMD_FIFO_WIDTH-1:0] gencmd_fifo_wrdat  ;
    wire    [GENCMD_FIFO_WIDTH-1:0] gencmd_fifo_rddat  ;
    wire                            gencmd_fifo_rden   ;
    wire                            gencmd_fifo_empty  ;
    wire                            gencmd_fifo_pempty ;
    wire                            gencmd_fifo_full   ;
    wire                            gencmd_fifo_pfull  ;
    wire    [3:0]                   gencmd_fifo_rdcnt  ;
    ipbase_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("distribute"), // String
        .FIFO_READ_LATENCY(0),     // DECIMAL
        .FIFO_WRITE_DEPTH(16),   // DECIMAL
        .FULL_RESET_VALUE(1),      // DECIMAL
        .PROG_EMPTY_THRESH(5),    // DECIMAL
        .PROG_FULL_THRESH(11),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(4),   // DECIMAL
        .READ_DATA_WIDTH(GENCMD_FIFO_WIDTH),      // DECIMAL
        .READ_MODE("fwft"),         // String
        .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0707"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(GENCMD_FIFO_WIDTH),     // DECIMAL
        .WR_DATA_COUNT_WIDTH(4)    // DECIMAL
   )
   gencmd_fifo_16d (
        .almost_empty     (),
        .almost_full      (),
        .data_valid       (),
        .dbiterr          (),
        .dout             (gencmd_fifo_rddat     ),
        .empty            (gencmd_fifo_empty     ),
        .full             (gencmd_fifo_full      ),
        .overflow         (),
        .prog_empty       (gencmd_fifo_pempty    ),
        .prog_full        (gencmd_fifo_pfull     ),
        .rd_data_count    (gencmd_fifo_rdcnt     ),
        .rd_rst_busy      (),
        .sbiterr          (),
        .underflow        (),
        .wr_ack           (),
        .wr_data_count    (),
        .wr_rst_busy      (),
        .din              (gencmd_fifo_wrdat     ),
        .injectdbiterr    (),
        .injectsbiterr    (),
        .rd_en            (gencmd_fifo_rden      ),
        .rst              (gencmd_fifo_rst       ),
        .sleep            (),
        .wr_clk           (gencmd_fifo_clk       ),
        .wr_en            (gencmd_fifo_wren      )                     
   );
    assign gencmd_fifo_clk = sys_clk;
    assign gencmd_fifo_rst = sys_rst;
    assign gencmd_fifo_wren    = gencmd_valid;
    assign gencmd_fifo_wrdat   = {
        gencmd_type,
        gencmd_len ,
        gencmd_addr,
        gencmd_data
    };
    wire    [511:0]                 ddrcmd_data     ;
    wire    [31 :0]                 ddrcmd_addr     ;
    wire    [7  :0]                 ddrcmd_len      ;
    wire    [1  :0]                 ddrcmd_type     ;
    wire                            ddrcmd_valid    ;
    assign {
        ddrcmd_type,
        ddrcmd_len ,
        ddrcmd_addr,
        ddrcmd_data
    } = gencmd_fifo_rddat;
    assign gencmd_fifo_rden = 
                ddr_cmd_valid ? 
                    ddr_cmd_ready ?
                        ~gencmd_fifo_empty ? 1 :
                        0:
                    0:
                0;
    reg r0_gencmd_fifo_pfull=1;
    always@(posedge sys_clk)
    if(sys_rst)
        r0_gencmd_fifo_pfull <= 1;
    else
        r0_gencmd_fifo_pfull <= gencmd_fifo_pfull;
    assign cmd_output_rdy = ~r0_gencmd_fifo_pfull;
//------------------------------------------------------------
//output generate
    wire    [511:0]             c_ddr_cmd_data;
    reg     [511:0]             r_ddr_cmd_data=512'd0;
    wire    [31:0]              c_ddr_cmd_addr;
    reg     [31:0]              r_ddr_cmd_addr=32'd0;
    wire    [1:0]               c_ddr_cmd_type;
    reg     [1:0]               r_ddr_cmd_type=2'd0;
    wire    [7:0]               c_ddr_cmd_len ;
    reg     [7:0]               r_ddr_cmd_len =8'd0;
    wire                        c_ddr_cmd_valid;
    reg                         r_ddr_cmd_valid=0;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_ddr_cmd_data  <= 512'd0;
            r_ddr_cmd_addr  <= 32'd0;
            r_ddr_cmd_len   <= 8'd0;
            r_ddr_cmd_type  <= 2'd0;
            r_ddr_cmd_valid <= 0;
        end
    else
        begin
            r_ddr_cmd_data  <= c_ddr_cmd_data  ;
            r_ddr_cmd_addr  <= c_ddr_cmd_addr  ;
            r_ddr_cmd_len   <= c_ddr_cmd_len   ;
            r_ddr_cmd_type  <= c_ddr_cmd_type  ;
            r_ddr_cmd_valid <= c_ddr_cmd_valid ;
        end
    assign c_ddr_cmd_data   = ddrcmd_data;
    assign c_ddr_cmd_addr   = ddrcmd_addr;
    assign c_ddr_cmd_len    = ddrcmd_len ;
    assign c_ddr_cmd_type   = ddrcmd_type;
    assign c_ddr_cmd_valid  = 
                ddr_cmd_valid ?
                    ddr_cmd_ready ? 
                        gencmd_fifo_rdcnt <= 1 ? 0 :
                        1 :
                    1 :
                ~gencmd_fifo_empty ? 1 :
                0;

    assign ddr_cmd_addr     = c_ddr_cmd_addr    ;
    assign ddr_cmd_data     = c_ddr_cmd_data    ;
    assign ddr_cmd_type     = c_ddr_cmd_type    ;
    assign ddr_cmd_len      = c_ddr_cmd_len     ;
    assign ddr_cmd_valid    = r_ddr_cmd_valid   ;

    assign new_wnd_hdr      = r_next_wnd_hdr    ;
    assign new_wnd_tail     = r_next_wnd_tail   ;
    assign new_wnd_sn       = r_next_wnd_sn     ;
    assign new_wnd_valid    = r_next_wnd_valid  ;

    // generate timer request
    assign timer_req_sn    = r_timer_req_sn     ;
    assign timer_req_hdr   = r_timer_req_hdr    ;
    assign timer_req_tail  = r_timer_req_tail   ;
    assign timer_req_inswnd={r_next_wnd_hdr,r_next_wnd_tail};
    assign timer_req_bitmap= r_timer_req_bitmap ;
    assign timer_req_chksum= r_timer_req_chksum ;
    assign timer_req_valid = r_timer_req_valid  ;
    assign cur_wnd_ready   = timer_req_ready && ~fifo_pfull   ;

//----------------------------------------------------------------------------------
//
//\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
//  <DFX Status>
//----------------------------------------------------------------------------------
    wire                    dfx_sta_clear;
    assign dfx_sta_clear = i_cfg_reg0[0];
    //------------------------------------------------------------------------------
    // input 
    wire    [15:0]          c_req_in_counter        ;
    wire    [ 7:0]          c_req_update_wnd_counter;
    wire    [ 7:0]          c_req_new_timer_counter ;
    reg     [15:0]          r_req_in_counter         = 16'd0;
    reg     [ 7:0]          r_req_update_wnd_counter =  8'd0;
    reg     [ 7:0]          r_req_new_timer_counter  =  8'd0;
    assign c_req_in_counter        = dfx_sta_clear ? 16'd0 : cur_wnd_valid ? r_req_in_counter + 16'd1 : r_req_in_counter ;
    assign c_req_update_wnd_counter= dfx_sta_clear ?  8'd0 : new_wnd_valid ? r_req_update_wnd_counter + 8'd1 : r_req_update_wnd_counter;
    assign c_req_new_timer_counter = dfx_sta_clear ?  8'd0 : timer_req_valid ? r_req_new_timer_counter + 8'd1 : r_req_new_timer_counter;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_req_in_counter         <= 16'd0;
            r_req_update_wnd_counter <=  8'd0;
            r_req_new_timer_counter  <=  8'd0;
        end
    else
        begin
            r_req_in_counter         <= c_req_in_counter        ;
            r_req_update_wnd_counter <= c_req_update_wnd_counter;
            r_req_new_timer_counter  <= c_req_new_timer_counter ;
        end
    //------------------------------------------------------------------------------
    // sta 
    wire    [31:0]          c_wnd_calcore_sta;
    reg     [31:0]          r_wnd_calcore_sta=32'd0;
    assign c_wnd_calcore_sta = {
        cur_wnd_ready       ,
        timer_req_ready     ,
        ddr_cmd_valid       ,
        ddr_cmd_ready       ,
        fifo_empty          ,
        fifo_pfull          ,
        gencmd_fifo_empty   ,
        gencmd_fifo_pfull   ,
        cmd_FSM_cs          
    };
    always@(posedge sys_clk)
    if(sys_rst) 
        r_wnd_calcore_sta <= 32'd0;
    else
        r_wnd_calcore_sta <= c_wnd_calcore_sta;
    //------------------------------------------------------------------------------
    // ddr cmd sta 
    wire    [15:0]          c_ddr_cmd_counter;
    reg     [15:0]          r_ddr_cmd_counter=16'd0;
    assign c_ddr_cmd_counter = dfx_sta_clear ? 16'd0 : ddr_cmd_valid & ddr_cmd_ready ? r_ddr_cmd_counter + 1 : r_ddr_cmd_counter;
    always@(posedge sys_clk)
    if(sys_rst)
        r_ddr_cmd_counter <= 16'd0;
    else
        r_ddr_cmd_counter <= c_ddr_cmd_counter;
    //------------------------------------------------------------------------------
    // CON
        assign o_sta_reg0 = {
            r_req_in_counter          ,
            r_req_update_wnd_counter  ,
            r_req_new_timer_counter   
        };
        assign o_sta_reg1 = {
            r_wnd_calcore_sta
        };
        assign o_sta_reg2 = {
            16'd0,
            r_ddr_cmd_counter
        };
        assign o_sta_reg3 = 32'd0;
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