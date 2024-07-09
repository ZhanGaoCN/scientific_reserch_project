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
module seanetnackgenerator_nack_generator_v0p1(
    input   wire                                        sys_clk                 ,
    input   wire                                        sys_rst                 ,
    //con to nack gen
    input   wire    [15:0]                              i_nackgen_sn            ,
    input   wire    [1024+32-1:0]                       i_nackgen_req           ,
    input   wire                                        i_nackgen_vld           ,
    output  wire                                        o_nackgen_rdy           ,
    // output
    output  wire    [511:0]                             o_nack_s_info           ,
    output  wire    [31:0]                              o_nack_npn              ,
    output  wire    [63:0]                              o_nack_bitmap           ,
    output  wire                                        o_nack_valid            ,
    input   wire                                        i_nack_ready            ,
    // connect to dfx port
    input   wire    [31:0]                              i_cfg_reg0              ,
    output  wire    [31:0]                              o_sta_reg0              ,
    output  wire    [31:0]                              o_sta_reg1               
);

    localparam FIFO_WIDTH = 1024+32;
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
        .READ_DATA_WIDTH(FIFO_WIDTH),      // DECIMAL
        .READ_MODE("fwft"),         // String
        .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0707"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(FIFO_WIDTH),     // DECIMAL
        .WR_DATA_COUNT_WIDTH(4)    // DECIMAL
   )
   cache_fifo_512d (
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
    assign fifo_wren    = i_nackgen_vld;
    assign fifo_wrdat   = {
        i_nackgen_req
    };
    assign o_nackgen_rdy = ~fifo_pfull;


    wire    [31:0]          nack_npn      ;
    wire    [511:0]         nack_s_info   ;
    wire    [511:0]         nack_bitmap   ;
    assign { 
        nack_npn    ,
        nack_s_info ,
        nack_bitmap  } = fifo_rddat;

    reg                     r_fifo_empty=1;
    always@(posedge sys_clk)
    if(sys_rst)
        r_fifo_empty <= 1;
    else
        r_fifo_empty <= fifo_empty;
//------------------------------------------------------------
//                   >>>nack generate process<<<
// [nack_sinfo          ]:
// [nack_subbitmap_0    ]:
// [nack_subbitmap_1    ]:
// [nack_subbitmap_2    ]:
// [nack_subbitmap_3    ]:
// [nack_subbitmap_4    ]:
// [nack_subbitmap_5    ]:
// [nack_subbitmap_6    ]:
// [nack_subbitmap_7    ]:
// [nack_subbitmap_vld  ]:
// [nack_npn_0          ]:
// [nack_npn_1          ]:
// [nack_npn_2          ]:
// [nack_npn_3          ]:
// [nack_npn_4          ]:
// [nack_npn_5          ]:
// [nack_npn_6          ]:
// [nack_npn_7          ]:
//------------------------------------------------------------
    wire    [511:0]         nack_sinfo          ;
    wire    [63:0]          nack_subbitmap_0    ;
    wire    [63:0]          nack_subbitmap_1    ;
    wire    [63:0]          nack_subbitmap_2    ;
    wire    [63:0]          nack_subbitmap_3    ;
    wire    [63:0]          nack_subbitmap_4    ;
    wire    [63:0]          nack_subbitmap_5    ;
    wire    [63:0]          nack_subbitmap_6    ;
    wire    [63:0]          nack_subbitmap_7    ;
    wire    [7:0]           nack_subbitmap_vld  ;
    wire    [31:0]          nack_npn_0          ;
    wire    [31:0]          nack_npn_1          ;
    wire    [31:0]          nack_npn_2          ;
    wire    [31:0]          nack_npn_3          ;
    wire    [31:0]          nack_npn_4          ;
    wire    [31:0]          nack_npn_5          ;
    wire    [31:0]          nack_npn_6          ;
    wire    [31:0]          nack_npn_7          ;
    assign nack_sinfo = nack_s_info;
    assign nack_subbitmap_0 = nack_bitmap[64*0+63:64*0];
    assign nack_subbitmap_1 = nack_bitmap[64*1+63:64*1];
    assign nack_subbitmap_2 = nack_bitmap[64*2+63:64*2];
    assign nack_subbitmap_3 = nack_bitmap[64*3+63:64*3];
    assign nack_subbitmap_4 = nack_bitmap[64*4+63:64*4];
    assign nack_subbitmap_5 = nack_bitmap[64*5+63:64*5];
    assign nack_subbitmap_6 = nack_bitmap[64*6+63:64*6];
    assign nack_subbitmap_7 = nack_bitmap[64*7+63:64*7];
    assign nack_subbitmap_vld[0] = nack_subbitmap_0 != 64'd0;
    assign nack_subbitmap_vld[1] = nack_subbitmap_1 != 64'd0;
    assign nack_subbitmap_vld[2] = nack_subbitmap_2 != 64'd0;
    assign nack_subbitmap_vld[3] = nack_subbitmap_3 != 64'd0;
    assign nack_subbitmap_vld[4] = nack_subbitmap_4 != 64'd0;
    assign nack_subbitmap_vld[5] = nack_subbitmap_5 != 64'd0;
    assign nack_subbitmap_vld[6] = nack_subbitmap_6 != 64'd0;
    assign nack_subbitmap_vld[7] = nack_subbitmap_7 != 64'd0;
    assign nack_npn_0 = nack_npn + 64*0;
    assign nack_npn_1 = nack_npn + 64*1;
    assign nack_npn_2 = nack_npn + 64*2;
    assign nack_npn_3 = nack_npn + 64*3;
    assign nack_npn_4 = nack_npn + 64*4;
    assign nack_npn_5 = nack_npn + 64*5;
    assign nack_npn_6 = nack_npn + 64*6;
    assign nack_npn_7 = nack_npn + 64*7;
//------------------------------------------------------------
// <register to logic>
    reg     [511:0]         r_nack_sinfo;
    reg     [63:0]          r_nack_subbitmap_0;
    reg     [63:0]          r_nack_subbitmap_1;
    reg     [63:0]          r_nack_subbitmap_2;
    reg     [63:0]          r_nack_subbitmap_3;
    reg     [63:0]          r_nack_subbitmap_4;
    reg     [63:0]          r_nack_subbitmap_5;
    reg     [63:0]          r_nack_subbitmap_6;
    reg     [63:0]          r_nack_subbitmap_7;
    reg     [7:0]           r_nack_subbitmap_vld;
    reg     [31:0]          r_nack_npn_0;
    reg     [31:0]          r_nack_npn_1;
    reg     [31:0]          r_nack_npn_2;
    reg     [31:0]          r_nack_npn_3;
    reg     [31:0]          r_nack_npn_4;
    reg     [31:0]          r_nack_npn_5;
    reg     [31:0]          r_nack_npn_6;
    reg     [31:0]          r_nack_npn_7;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_nack_sinfo            <= 512'd0;
            r_nack_subbitmap_0      <= 64'd0;
            r_nack_subbitmap_1      <= 64'd0;
            r_nack_subbitmap_2      <= 64'd0;
            r_nack_subbitmap_3      <= 64'd0;
            r_nack_subbitmap_4      <= 64'd0;
            r_nack_subbitmap_5      <= 64'd0;
            r_nack_subbitmap_6      <= 64'd0;
            r_nack_subbitmap_7      <= 64'd0;
            r_nack_subbitmap_vld    <= 8'd0;
            r_nack_npn_0            <= 32'd0;
            r_nack_npn_1            <= 32'd0;
            r_nack_npn_2            <= 32'd0;
            r_nack_npn_3            <= 32'd0;
            r_nack_npn_4            <= 32'd0;
            r_nack_npn_5            <= 32'd0;
            r_nack_npn_6            <= 32'd0;
            r_nack_npn_7            <= 32'd0;
        end
    else
        begin
            r_nack_sinfo            <= nack_sinfo;
            r_nack_subbitmap_0      <= nack_subbitmap_0;
            r_nack_subbitmap_1      <= nack_subbitmap_1;
            r_nack_subbitmap_2      <= nack_subbitmap_2;
            r_nack_subbitmap_3      <= nack_subbitmap_3;
            r_nack_subbitmap_4      <= nack_subbitmap_4;
            r_nack_subbitmap_5      <= nack_subbitmap_5;
            r_nack_subbitmap_6      <= nack_subbitmap_6;
            r_nack_subbitmap_7      <= nack_subbitmap_7;
            r_nack_subbitmap_vld    <= nack_subbitmap_vld;
            r_nack_npn_0            <= nack_npn_0;
            r_nack_npn_1            <= nack_npn_1;
            r_nack_npn_2            <= nack_npn_2;
            r_nack_npn_3            <= nack_npn_3;
            r_nack_npn_4            <= nack_npn_4;
            r_nack_npn_5            <= nack_npn_5;
            r_nack_npn_6            <= nack_npn_6;
            r_nack_npn_7            <= nack_npn_7;
        end
//------------------------------------------------------------
// <output FSM>
    localparam OUT_IDLE = 4'd0;
    localparam OUT_N0   = 4'd1;
    localparam OUT_N1   = 4'd2;
    localparam OUT_N2   = 4'd3;
    localparam OUT_N3   = 4'd4;
    localparam OUT_N4   = 4'd5;
    localparam OUT_N5   = 4'd6;
    localparam OUT_N6   = 4'd7;
    localparam OUT_N7   = 4'd8;
    localparam OUT_REN  = 4'd9;
    localparam OUT_REN_WT = 4'd10;
    reg     [3:0]       out_FSM_cs=OUT_IDLE;
    reg     [3:0]       out_FSM_ns;
    wire    [511:0]                             o_nack_s_info_pp   ;
    wire    [31:0]                              o_nack_npn_pp      ;
    wire    [63:0]                              o_nack_bitmap_pp   ;
    wire                                        o_nack_valid_pp    ;
    wire                                        i_nack_ready_pp    ;
    always@(posedge sys_clk)
    if(sys_rst)
        out_FSM_cs <= OUT_IDLE;
    else
        out_FSM_cs <= out_FSM_ns;
    always@(*)
    case (out_FSM_cs)
        OUT_IDLE: 
            if(~fifo_empty && ~r_fifo_empty)
                if(r_nack_subbitmap_vld[0])
                    out_FSM_ns=OUT_N0;
                else if(r_nack_subbitmap_vld[1])
                    out_FSM_ns=OUT_N1;
                else if(r_nack_subbitmap_vld[2])
                    out_FSM_ns=OUT_N2;
                else if(r_nack_subbitmap_vld[3])
                    out_FSM_ns=OUT_N3;
                else if(r_nack_subbitmap_vld[4])
                    out_FSM_ns=OUT_N4;
                else if(r_nack_subbitmap_vld[5])
                    out_FSM_ns=OUT_N5;
                else if(r_nack_subbitmap_vld[6])
                    out_FSM_ns=OUT_N6;
                else if(r_nack_subbitmap_vld[7])
                    out_FSM_ns=OUT_N7;
                else
                    out_FSM_ns=OUT_REN;
            else
                out_FSM_ns=OUT_IDLE;
        OUT_N0  : 
        if(i_nack_ready_pp)
            if(r_nack_subbitmap_vld[1])
                out_FSM_ns=OUT_N1;
            else if(r_nack_subbitmap_vld[2])
                out_FSM_ns=OUT_N2;
            else if(r_nack_subbitmap_vld[3])
                out_FSM_ns=OUT_N3;
            else if(r_nack_subbitmap_vld[4])
                out_FSM_ns=OUT_N4;
            else if(r_nack_subbitmap_vld[5])
                out_FSM_ns=OUT_N5;
            else if(r_nack_subbitmap_vld[6])
                out_FSM_ns=OUT_N6;
            else if(r_nack_subbitmap_vld[7])
                out_FSM_ns=OUT_N7;
            else
                out_FSM_ns=OUT_REN;
        else
            out_FSM_ns=out_FSM_cs;
        OUT_N1  : 
        if(i_nack_ready_pp)
            if(r_nack_subbitmap_vld[2])
                out_FSM_ns=OUT_N2;
            else if(r_nack_subbitmap_vld[3])
                out_FSM_ns=OUT_N3;
            else if(r_nack_subbitmap_vld[4])
                out_FSM_ns=OUT_N4;
            else if(r_nack_subbitmap_vld[5])
                out_FSM_ns=OUT_N5;
            else if(r_nack_subbitmap_vld[6])
                out_FSM_ns=OUT_N6;
            else if(r_nack_subbitmap_vld[7])
                out_FSM_ns=OUT_N7;
            else
                out_FSM_ns=OUT_REN;
        else
            out_FSM_ns=out_FSM_cs;
        OUT_N2  : 
        if(i_nack_ready_pp)
            if(r_nack_subbitmap_vld[3])
                out_FSM_ns=OUT_N3;
            else if(r_nack_subbitmap_vld[4])
                out_FSM_ns=OUT_N4;
            else if(r_nack_subbitmap_vld[5])
                out_FSM_ns=OUT_N5;
            else if(r_nack_subbitmap_vld[6])
                out_FSM_ns=OUT_N6;
            else if(r_nack_subbitmap_vld[7])
                out_FSM_ns=OUT_N7;
            else
                out_FSM_ns=OUT_REN;
        else
            out_FSM_ns=out_FSM_cs;
        OUT_N3  : 
        if(i_nack_ready_pp)
            if(r_nack_subbitmap_vld[4])
                out_FSM_ns=OUT_N4;
            else if(r_nack_subbitmap_vld[5])
                out_FSM_ns=OUT_N5;
            else if(r_nack_subbitmap_vld[6])
                out_FSM_ns=OUT_N6;
            else if(r_nack_subbitmap_vld[7])
                out_FSM_ns=OUT_N7;
            else
                out_FSM_ns=OUT_REN;
        else
            out_FSM_ns=out_FSM_cs;
        OUT_N4  : 
        if(i_nack_ready_pp)
            if(r_nack_subbitmap_vld[5])
                out_FSM_ns=OUT_N5;
            else if(r_nack_subbitmap_vld[6])
                out_FSM_ns=OUT_N6;
            else if(r_nack_subbitmap_vld[7])
                out_FSM_ns=OUT_N7;
            else
                out_FSM_ns=OUT_REN;
        else
            out_FSM_ns=out_FSM_cs;
        OUT_N5  : 
        if(i_nack_ready_pp)
            if(r_nack_subbitmap_vld[6])
                out_FSM_ns=OUT_N6;
            else if(r_nack_subbitmap_vld[7])
                out_FSM_ns=OUT_N7;
            else
                out_FSM_ns=OUT_REN;
        else
            out_FSM_ns=out_FSM_cs;
        OUT_N6  : 
        if(i_nack_ready_pp)
            if(r_nack_subbitmap_vld[7])
                out_FSM_ns=OUT_N7;
            else
                out_FSM_ns=OUT_REN;
        else
            out_FSM_ns=out_FSM_cs;
        OUT_N7  : 
        if(i_nack_ready_pp)
            out_FSM_ns=OUT_REN;
        else
            out_FSM_ns=out_FSM_cs;
        OUT_REN :
            out_FSM_ns=OUT_REN_WT;
        OUT_REN_WT:
            out_FSM_ns=OUT_IDLE;
        default : out_FSM_ns=OUT_IDLE;
    endcase

    assign o_nack_s_info_pp = r_nack_sinfo;
    assign o_nack_npn_pp = 
                out_FSM_cs == OUT_N0 ? r_nack_npn_0 :
                out_FSM_cs == OUT_N1 ? r_nack_npn_1 :
                out_FSM_cs == OUT_N2 ? r_nack_npn_2 :
                out_FSM_cs == OUT_N3 ? r_nack_npn_3 :
                out_FSM_cs == OUT_N4 ? r_nack_npn_4 :
                out_FSM_cs == OUT_N5 ? r_nack_npn_5 :
                out_FSM_cs == OUT_N6 ? r_nack_npn_6 :
                out_FSM_cs == OUT_N7 ? r_nack_npn_7 : 32'd0;
    assign o_nack_bitmap_pp = 
                out_FSM_cs == OUT_N0 ? r_nack_subbitmap_0 :
                out_FSM_cs == OUT_N1 ? r_nack_subbitmap_1 :
                out_FSM_cs == OUT_N2 ? r_nack_subbitmap_2 :
                out_FSM_cs == OUT_N3 ? r_nack_subbitmap_3 :
                out_FSM_cs == OUT_N4 ? r_nack_subbitmap_4 :
                out_FSM_cs == OUT_N5 ? r_nack_subbitmap_5 :
                out_FSM_cs == OUT_N6 ? r_nack_subbitmap_6 :
                out_FSM_cs == OUT_N7 ? r_nack_subbitmap_7 : 64'd0;
    assign o_nack_valid_pp = 
                out_FSM_cs == OUT_N0 ? 1 :
                out_FSM_cs == OUT_N1 ? 1 :
                out_FSM_cs == OUT_N2 ? 1 :
                out_FSM_cs == OUT_N3 ? 1 :
                out_FSM_cs == OUT_N4 ? 1 :
                out_FSM_cs == OUT_N5 ? 1 :
                out_FSM_cs == OUT_N6 ? 1 :
                out_FSM_cs == OUT_N7 ? 1 : 0;

    assign fifo_rden = out_FSM_cs == OUT_REN;

ipbase_intf_pipeline_d2#(
    .DATA_WIDTH (64+32+512)
)ipbase_intf_pipeline_d2(
    .clk     (sys_clk),//input   wire                        
    .rst     (sys_rst),//input   wire                        
    .id      ({
        o_nack_npn_pp,
        o_nack_s_info_pp,
        o_nack_bitmap_pp
    }),//input   wire    [DATA_WIDTH-1:0]    
    .id_vld  (o_nack_valid_pp),//input   wire                        
    .id_rdy  (i_nack_ready_pp),//output  wire                        
    .od      ({
        o_nack_npn,
        o_nack_s_info,
        o_nack_bitmap
    }),//output  wire    [DATA_WIDTH-1:0]    
    .od_vld  (o_nack_valid),//output  wire                        
    .od_rdy  (i_nack_ready) //input   wire                        
);
//----------------------------------------------------------------------------------
//
//\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
//  <DFX Status>
//----------------------------------------------------------------------------------
    wire                    dfx_sta_clear;
    assign dfx_sta_clear = i_cfg_reg0[0];
    // counter
    wire    [15:0]          c_nackreq_in_counter    ;
    wire    [15:0]          c_nackreq_out_counter   ;  
    reg     [15:0]          r_nackreq_in_counter    =16'd0;
    reg     [15:0]          r_nackreq_out_counter   =16'd0;  
    assign c_nackreq_in_counter = i_nackgen_vld ? r_nackreq_in_counter + 16'd1 : r_nackreq_in_counter;
    assign c_nackreq_out_counter = o_nack_valid & i_nack_ready ? r_nackreq_out_counter + 16'd1 : r_nackreq_out_counter;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_nackreq_in_counter  <= 16'd0;
            r_nackreq_out_counter <= 16'd0;
        end
    else
        begin
            r_nackreq_in_counter  <= c_nackreq_in_counter ;
            r_nackreq_out_counter <= c_nackreq_out_counter;
        end
    //sta
    wire    [31:0]          c_nackreq_sta;
    reg     [31:0]          r_nackreq_sta=32'd0;
    assign c_nackreq_sta = {
        22'd0,
        i_nackgen_vld,
        o_nackgen_rdy,
        o_nack_valid_pp,
        i_nack_ready_pp,
        o_nack_valid,
        i_nack_ready,
        out_FSM_cs
    };
    always@(posedge sys_clk)
    if(sys_rst)
        r_nackreq_sta <= 32'd0;
    else
        r_nackreq_sta <= c_nackreq_sta;


    //con
    assign o_sta_reg0 = {
        r_nackreq_in_counter ,
        r_nackreq_out_counter
    };
    assign o_sta_reg1 = {
        r_nackreq_sta
    };
endmodule