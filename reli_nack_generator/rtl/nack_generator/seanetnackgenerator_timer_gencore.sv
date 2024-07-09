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
module seanetnackgenerator_timer_gencore(
    input   wire                                        sys_clk                 ,
    input   wire                                        sys_rst                 ,
    //timer request(new)
    input   wire    [15:0]                              i_new_tmg_sn	        ,
    input   wire    [31:0]                              i_new_tmg_chksum	    ,   
    input   wire    [64+384-1:0]                        i_new_tmg_gen_req	    ,    
    input   wire                                        i_new_tmg_valid	        ,
    output  wire                                        o_new_tmg_ready	        ,
    //timer request(reload)
    input   wire    [15:0]                              i_rld_tmg_sn	        ,
    input   wire    [15:0]                              i_rld_tmg_cnt           ,//rld 
    input   wire    [31:0]                              i_rld_tmg_chksum	    ,  
    input   wire    [64+384-1:0]                        i_rld_tmg_gen_req	    ,    
    input   wire                                        i_rld_tmg_valid	        ,
    output  wire                                        o_rld_tmg_ready	        ,
    //con to timer queue manager
    //////write timer
    output  wire    [512        -1:0]                   o_timer_wrreq           ,
    output  wire                                        o_timer_wrreq_vld       ,
    input   wire                                        i_timer_wrreq_rdy       ,
    // connect to dfx port      
    input   wire    [31:0]                              i_cfg_reg0              ,
    output  wire    [31:0]                              o_sta_reg0              ,                 
    output  wire    [31:0]                              o_sta_reg1              ,                
    output  wire    [31:0]                              o_sta_reg2              ,                
    output  wire    [31:0]                              o_sta_reg3                               
);
//------------------------------------------------------------
// <new timer cache>
    localparam FIFO_WIDTH = 512;
    wire                            new_timer_fifo_clk    ;
    wire                            new_timer_fifo_rst    ;
    wire                            new_timer_fifo_wren   ;
    wire    [FIFO_WIDTH-1:0]        new_timer_fifo_wrdat  ;
    wire    [FIFO_WIDTH-1:0]        new_timer_fifo_rddat  ;
    wire                            new_timer_fifo_rden   ;
    wire                            new_timer_fifo_empty  ;
    wire                            new_timer_fifo_pempty ;
    wire                            new_timer_fifo_full   ;
    wire                            new_timer_fifo_pfull  ;
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
        .READ_DATA_WIDTH(FIFO_WIDTH),      // DECIMAL
        .READ_MODE("fwft"),         // String
        .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0707"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(FIFO_WIDTH),     // DECIMAL
        .WR_DATA_COUNT_WIDTH(4)    // DECIMAL
   )
   new_timer_fifo_16d (
        .almost_empty     (),
        .almost_full      (),
        .data_valid       (),
        .dbiterr          (),
        .dout             (new_timer_fifo_rddat     ),
        .empty            (new_timer_fifo_empty     ),
        .full             (new_timer_fifo_full      ),
        .overflow         (),
        .prog_empty       (new_timer_fifo_pempty    ),
        .prog_full        (new_timer_fifo_pfull     ),
        .rd_data_count    (),
        .rd_rst_busy      (),
        .sbiterr          (),
        .underflow        (),
        .wr_ack           (),
        .wr_data_count    (),
        .wr_rst_busy      (),
        .din              (new_timer_fifo_wrdat     ),
        .injectdbiterr    (),
        .injectsbiterr    (),
        .rd_en            (new_timer_fifo_rden      ),
        .rst              (new_timer_fifo_rst       ),
        .sleep            (),
        .wr_clk           (new_timer_fifo_clk       ),
        .wr_en            (new_timer_fifo_wren      )                     
   );
    assign new_timer_fifo_clk       = sys_clk;
    assign new_timer_fifo_rst       = sys_rst;
    assign new_timer_fifo_wren      = i_new_tmg_valid;
    assign new_timer_fifo_wrdat     = {
            16'd0,
            i_new_tmg_sn,
            i_new_tmg_chksum,
            i_new_tmg_gen_req
    };
    assign o_new_tmg_ready = ~new_timer_fifo_pfull;
//------------------------------------------------------------
// <reload timer cache>
    //localparam FIFO_WIDTH = 512;
    wire                            rld_timer_fifo_clk    ;
    wire                            rld_timer_fifo_rst    ;
    wire                            rld_timer_fifo_wren   ;
    wire    [FIFO_WIDTH-1:0]        rld_timer_fifo_wrdat  ;
    wire    [FIFO_WIDTH-1:0]        rld_timer_fifo_rddat  ;
    wire                            rld_timer_fifo_rden   ;
    wire                            rld_timer_fifo_empty  ;
    wire                            rld_timer_fifo_pempty ;
    wire                            rld_timer_fifo_full   ;
    wire                            rld_timer_fifo_pfull  ;
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
        .READ_DATA_WIDTH(FIFO_WIDTH),      // DECIMAL
        .READ_MODE("fwft"),         // String
        .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0707"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(FIFO_WIDTH),     // DECIMAL
        .WR_DATA_COUNT_WIDTH(4)    // DECIMAL
   )
   rld_timer_fifo_16d (
        .almost_empty     (),
        .almost_full      (),
        .data_valid       (),
        .dbiterr          (),
        .dout             (rld_timer_fifo_rddat     ),
        .empty            (rld_timer_fifo_empty     ),
        .full             (rld_timer_fifo_full      ),
        .overflow         (),
        .prog_empty       (rld_timer_fifo_pempty    ),
        .prog_full        (rld_timer_fifo_pfull     ),
        .rd_data_count    (),
        .rd_rst_busy      (),
        .sbiterr          (),
        .underflow        (),
        .wr_ack           (),
        .wr_data_count    (),
        .wr_rst_busy      (),
        .din              (rld_timer_fifo_wrdat     ),
        .injectdbiterr    (),
        .injectsbiterr    (),
        .rd_en            (rld_timer_fifo_rden      ),
        .rst              (rld_timer_fifo_rst       ),
        .sleep            (),
        .wr_clk           (rld_timer_fifo_clk       ),
        .wr_en            (rld_timer_fifo_wren      )                     
   );
    assign rld_timer_fifo_clk       = sys_clk;
    assign rld_timer_fifo_rst       = sys_rst;
    assign rld_timer_fifo_wren      = i_rld_tmg_valid;
    assign rld_timer_fifo_wrdat     = {
            //14'd0,
            i_rld_tmg_cnt,
            i_rld_tmg_sn,
            i_rld_tmg_chksum,
            i_rld_tmg_gen_req
    };
    assign o_rld_tmg_ready = ~rld_timer_fifo_pfull;
//------------------------------------------------------------
// bad-op
    localparam OUT_IDLE     = 4'd0;
    localparam OUT_CA0      = 4'd1;
    localparam OUT_CA1      = 4'd2;

    reg     [3:0]       out_FSM_cs=OUT_IDLE;
    reg     [3:0]       out_FSM_ns;
    always@(posedge sys_clk)
    if(sys_rst)
        out_FSM_cs <= OUT_IDLE;
    else
        out_FSM_cs <= out_FSM_ns;
    always@(*)
    case(out_FSM_cs)
    OUT_IDLE : 
        if(~new_timer_fifo_empty)
            out_FSM_ns=OUT_CA0;
        else if(~rld_timer_fifo_empty)
            out_FSM_ns=OUT_CA1;
        else
            out_FSM_ns=OUT_IDLE;
    OUT_CA0:
        if(~rld_timer_fifo_empty)
            out_FSM_ns=OUT_CA1;
        else if(~new_timer_fifo_empty)
            out_FSM_ns=OUT_CA0;
        else
            out_FSM_ns=OUT_IDLE;
    OUT_CA1:
        if(~new_timer_fifo_empty)
            out_FSM_ns=OUT_CA0;
        else if(~rld_timer_fifo_empty)
            out_FSM_ns=OUT_CA1;
        else
            out_FSM_ns=OUT_IDLE;
    default:out_FSM_ns=OUT_IDLE;
    endcase

    assign o_timer_wrreq_vld = 
                (out_FSM_cs==OUT_CA0 && ~new_timer_fifo_empty) || 
                (out_FSM_cs==OUT_CA1 && ~rld_timer_fifo_empty);
    assign o_timer_wrreq     = 
                out_FSM_cs==OUT_CA0 ? new_timer_fifo_rddat :
                out_FSM_cs==OUT_CA1 ? rld_timer_fifo_rddat :
                512'd0;
    assign new_timer_fifo_rden = out_FSM_cs==OUT_CA0 && i_timer_wrreq_rdy && ~new_timer_fifo_empty;
    assign rld_timer_fifo_rden = out_FSM_cs==OUT_CA1 && i_timer_wrreq_rdy && ~rld_timer_fifo_empty;
//----------------------------------------------------------------------------------
//
//\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
//  <DFX Status>
//----------------------------------------------------------------------------------
    wire                    dfx_sta_clear;
    assign dfx_sta_clear = i_cfg_reg0[0];
    reg     [15:0]          r_newtimer_counter_in = 16'd0;
    wire    [15:0]          c_newtimer_counter_in ;
    reg     [15:0]          r_newtimer_counter_out= 16'd0;
    wire    [15:0]          c_newtimer_counter_out;
    assign c_newtimer_counter_in = dfx_sta_clear ? 16'd0 : i_new_tmg_valid ? r_newtimer_counter_in + 1 : r_newtimer_counter_in;
    assign c_newtimer_counter_out= dfx_sta_clear ? 16'd0 : new_timer_fifo_rden ? r_newtimer_counter_out + 1 : r_newtimer_counter_out;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_newtimer_counter_in <= 16'd0;
            r_newtimer_counter_out<= 16'd0;
        end
    else
        begin
            r_newtimer_counter_in <= c_newtimer_counter_in ;
            r_newtimer_counter_out<= c_newtimer_counter_out;
        end

    reg     [15:0]          r_rldtimer_counter_in = 16'd0;
    wire    [15:0]          c_rldtimer_counter_in ;
    reg     [15:0]          r_rldtimer_counter_out= 16'd0;
    wire    [15:0]          c_rldtimer_counter_out;
    assign c_rldtimer_counter_in = dfx_sta_clear ? 16'd0 : i_rld_tmg_valid ? r_rldtimer_counter_in + 1 : r_rldtimer_counter_in;
    assign c_rldtimer_counter_out= dfx_sta_clear ? 16'd0 : rld_timer_fifo_rden ? r_rldtimer_counter_out + 1 : r_rldtimer_counter_out;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_rldtimer_counter_in <= 16'd0;
            r_rldtimer_counter_out<= 16'd0;
        end
    else
        begin
            r_rldtimer_counter_in <= c_rldtimer_counter_in ;
            r_rldtimer_counter_out<= c_rldtimer_counter_out;
        end

    reg                     r_newtimer_cache_overflow=0;
    wire                    c_newtimer_cache_overflow;
    reg                     r_rldtimer_cache_overflow=0;
    wire                    c_rldtimer_cache_overflow;
    assign c_newtimer_cache_overflow = dfx_sta_clear ? 0 : new_timer_fifo_full & new_timer_fifo_wren ? 1 : r_newtimer_cache_overflow ; 
    assign c_rldtimer_cache_overflow = dfx_sta_clear ? 0 : rld_timer_fifo_full & rld_timer_fifo_wren ? 1 : r_rldtimer_cache_overflow ;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_newtimer_cache_overflow <= 0;
            r_rldtimer_cache_overflow <= 0;
        end
    else
        begin
            r_newtimer_cache_overflow <= c_newtimer_cache_overflow ;
            r_rldtimer_cache_overflow <= c_rldtimer_cache_overflow ;
        end

    reg                     r_newtimer_cache_sta=0;
    wire                    c_newtimer_cache_sta;
    reg                     r_rldtimer_cache_sta=0;
    wire                    c_rldtimer_cache_sta;     
    assign c_newtimer_cache_sta = new_timer_fifo_empty ? 1 : 0;
    assign c_rldtimer_cache_sta = rld_timer_fifo_empty ? 1 : 0;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_newtimer_cache_sta <= 0;
            r_rldtimer_cache_sta <= 0;
        end
    else
        begin
            r_newtimer_cache_sta <= c_newtimer_cache_sta;
            r_rldtimer_cache_sta <= c_rldtimer_cache_sta;
        end

    assign o_sta_reg0 = {r_newtimer_counter_in,r_newtimer_counter_out};
    assign o_sta_reg1 = {r_rldtimer_counter_in,r_rldtimer_counter_out};
    assign o_sta_reg2 = {28'd0,r_newtimer_cache_overflow,r_rldtimer_cache_overflow,r_newtimer_cache_sta,r_rldtimer_cache_sta};
    assign o_sta_reg3 = 32'd0;
endmodule   