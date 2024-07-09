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
module seanetnackgenerator_ddr_bmpcmd_subarbit(
    input   wire                                        sys_clk             ,
    input   wire                                        sys_rst             ,
    // cmd input
    input   wire    [31:0]                              i_ddr_cmd_addr      ,
    input   wire    [511:0]                             i_ddr_cmd_data      ,
    input   wire    [7:0]                               i_ddr_cmd_len       ,
    input   wire    [1:0]                               i_ddr_cmd_type      ,//[2'b00: adapt write 0] [2'b01: adapt write 1] [2'b11:froce write 1]
    input   wire                                        i_ddr_cmd_valid     ,
    output  wire                                        i_ddr_cmd_ready     ,
    // cmd output port 0
    output  wire    [31:0]                              p0_ddr_cmd_addr     ,
    output  wire    [511:0]                             p0_ddr_cmd_data     ,
    output  wire    [7:0]                               p0_ddr_cmd_len      ,
    output  wire    [1:0]                               p0_ddr_cmd_type     ,//[2'b11:froce write 1]
    output  wire                                        p0_ddr_cmd_valid    ,
    input   wire                                        p0_ddr_cmd_ready    ,
    // cmd output port 1
    output  wire    [31:0]                              p1_ddr_cmd_addr     ,
    output  wire    [511:0]                             p1_ddr_cmd_data     ,
    output  wire    [7:0]                               p1_ddr_cmd_len      ,
    output  wire    [1:0]                               p1_ddr_cmd_type     ,//[2'b00: adapt write 0] [2'b01: adapt write 1]
    output  wire                                        p1_ddr_cmd_valid    ,
    input   wire                                        p1_ddr_cmd_ready    ,
    // connect to dfx port
    output wire [31:0]                                  dfx_sta0            ,
    output wire [31:0]                                  dfx_sta1            ,
    output wire [31:0]                                  dfx_sta2            ,
    output wire [31:0]                                  dfx_sta3            
);

//------------------------------------------------------------
// cmd fifo
    localparam GENCMD_FIFO_WIDTH = 512+32+2+8;
    wire                            p0_cmd_fifo_clk    ;
    wire                            p0_cmd_fifo_rst    ;
    wire                            p0_cmd_fifo_wren   ;
    wire    [GENCMD_FIFO_WIDTH-1:0] p0_cmd_fifo_wrdat  ;
    wire    [GENCMD_FIFO_WIDTH-1:0] p0_cmd_fifo_rddat  ;
    wire                            p0_cmd_fifo_rden   ;
    wire                            p0_cmd_fifo_empty  ;
    wire                            p0_cmd_fifo_pempty ;
    wire                            p0_cmd_fifo_full   ;
    wire                            p0_cmd_fifo_pfull  ;
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
    p0_cmd_fifo_16d (
        .almost_empty     (),
        .almost_full      (),
        .data_valid       (),
        .dbiterr          (),
        .dout             (p0_cmd_fifo_rddat     ),
        .empty            (p0_cmd_fifo_empty     ),
        .full             (p0_cmd_fifo_full      ),
        .overflow         (),
        .prog_empty       (p0_cmd_fifo_pempty    ),
        .prog_full        (p0_cmd_fifo_pfull     ),
        .rd_data_count    (),
        .rd_rst_busy      (),
        .sbiterr          (),
        .underflow        (),
        .wr_ack           (),
        .wr_data_count    (),
        .wr_rst_busy      (),
        .din              (p0_cmd_fifo_wrdat     ),
        .injectdbiterr    (),
        .injectsbiterr    (),
        .rd_en            (p0_cmd_fifo_rden      ),
        .rst              (p0_cmd_fifo_rst       ),
        .sleep            (),
        .wr_clk           (p0_cmd_fifo_clk       ),
        .wr_en            (p0_cmd_fifo_wren      )                     
   );
    wire                            p1_cmd_fifo_clk    ;
    wire                            p1_cmd_fifo_rst    ;
    wire                            p1_cmd_fifo_wren   ;
    wire    [GENCMD_FIFO_WIDTH-1:0] p1_cmd_fifo_wrdat  ;
    wire    [GENCMD_FIFO_WIDTH-1:0] p1_cmd_fifo_rddat  ;
    wire                            p1_cmd_fifo_rden   ;
    wire                            p1_cmd_fifo_empty  ;
    wire                            p1_cmd_fifo_pempty ;
    wire                            p1_cmd_fifo_full   ;
    wire                            p1_cmd_fifo_pfull  ;
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
    p1_cmd_fifo_16d (
        .almost_empty     (),
        .almost_full      (),
        .data_valid       (),
        .dbiterr          (),
        .dout             (p1_cmd_fifo_rddat     ),
        .empty            (p1_cmd_fifo_empty     ),
        .full             (p1_cmd_fifo_full      ),
        .overflow         (),
        .prog_empty       (p1_cmd_fifo_pempty    ),
        .prog_full        (p1_cmd_fifo_pfull     ),
        .rd_data_count    (),
        .rd_rst_busy      (),
        .sbiterr          (),
        .underflow        (),
        .wr_ack           (),
        .wr_data_count    (),
        .wr_rst_busy      (),
        .din              (p1_cmd_fifo_wrdat     ),
        .injectdbiterr    (),
        .injectsbiterr    (),
        .rd_en            (p1_cmd_fifo_rden      ),
        .rst              (p1_cmd_fifo_rst       ),
        .sleep            (),
        .wr_clk           (p1_cmd_fifo_clk       ),
        .wr_en            (p1_cmd_fifo_wren      )                     
   );
    assign p0_cmd_fifo_clk = sys_clk;
    assign p0_cmd_fifo_rst = sys_rst;
    assign p0_cmd_fifo_wren    = i_ddr_cmd_ready && i_ddr_cmd_valid && i_ddr_cmd_type==2'b11;
    assign p0_cmd_fifo_wrdat   = {
        i_ddr_cmd_type,
        i_ddr_cmd_len ,
        i_ddr_cmd_addr,
        i_ddr_cmd_data
    };

    assign p1_cmd_fifo_clk = sys_clk;
    assign p1_cmd_fifo_rst = sys_rst;
    assign p1_cmd_fifo_wren    = i_ddr_cmd_ready && i_ddr_cmd_valid && (i_ddr_cmd_type == 2'b00 || i_ddr_cmd_type == 2'b01);
    assign p1_cmd_fifo_wrdat   = {
        i_ddr_cmd_type,
        i_ddr_cmd_len ,
        i_ddr_cmd_addr,
        i_ddr_cmd_data
    };
//------------------------------------------------------------
// cmd pipeline
    assign p0_cmd_fifo_rden = p0_ddr_cmd_valid & p0_ddr_cmd_ready;

    reg     [31:0]                              r_p0_ddr_cmd_addr =32'd0   ;
    reg     [511:0]                             r_p0_ddr_cmd_data =512'd0   ;
    reg     [7:0]                               r_p0_ddr_cmd_len  =8'd0   ;
    reg     [1:0]                               r_p0_ddr_cmd_type =2'd0   ;
    reg                                         r_p0_ddr_cmd_valid=1'd0   ;

    wire    [31:0]                              c_p0_ddr_cmd_addr     ;
    wire    [511:0]                             c_p0_ddr_cmd_data     ;
    wire    [7:0]                               c_p0_ddr_cmd_len      ;
    wire    [1:0]                               c_p0_ddr_cmd_type     ;
    wire                                        c_p0_ddr_cmd_valid    ;

    assign {
        c_p0_ddr_cmd_type,
        c_p0_ddr_cmd_len ,
        c_p0_ddr_cmd_addr,
        c_p0_ddr_cmd_data
    } = p0_cmd_fifo_rddat;
    assign c_p0_ddr_cmd_valid = ~p0_cmd_fifo_empty ;

    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_p0_ddr_cmd_addr  <=32'd0   ;
            r_p0_ddr_cmd_data  <=512'd0  ;
            r_p0_ddr_cmd_len   <=8'd0    ;
            r_p0_ddr_cmd_type  <=2'd0    ;
            r_p0_ddr_cmd_valid <=1'd0    ;
        end
    else
        begin
            r_p0_ddr_cmd_addr  <= c_p0_ddr_cmd_addr  ;
            r_p0_ddr_cmd_data  <= c_p0_ddr_cmd_data  ;
            r_p0_ddr_cmd_len   <= c_p0_ddr_cmd_len   ;
            r_p0_ddr_cmd_type  <= c_p0_ddr_cmd_type  ;
            r_p0_ddr_cmd_valid <= c_p0_ddr_cmd_valid ;
        end
    assign p0_ddr_cmd_addr = c_p0_ddr_cmd_addr ;
    assign p0_ddr_cmd_data = c_p0_ddr_cmd_data ;
    assign p0_ddr_cmd_len  = c_p0_ddr_cmd_len  ;
    assign p0_ddr_cmd_type = c_p0_ddr_cmd_type ;
    assign p0_ddr_cmd_valid= c_p0_ddr_cmd_valid;

    assign p1_cmd_fifo_rden = p1_ddr_cmd_valid & p1_ddr_cmd_ready;
    reg     [31:0]                              r_p1_ddr_cmd_addr =32'd0   ;
    reg     [511:0]                             r_p1_ddr_cmd_data =512'd0   ;
    reg     [7:0]                               r_p1_ddr_cmd_len  =8'd0   ;
    reg     [1:0]                               r_p1_ddr_cmd_type =2'd0   ;
    reg                                         r_p1_ddr_cmd_valid=1'd0   ;

    wire    [31:0]                              c_p1_ddr_cmd_addr     ;
    wire    [511:0]                             c_p1_ddr_cmd_data     ;
    wire    [7:0]                               c_p1_ddr_cmd_len      ;
    wire    [1:0]                               c_p1_ddr_cmd_type     ;
    wire                                        c_p1_ddr_cmd_valid    ;

    assign {
        c_p1_ddr_cmd_type,
        c_p1_ddr_cmd_len ,
        c_p1_ddr_cmd_addr,
        c_p1_ddr_cmd_data
    } = p1_cmd_fifo_rddat;
    assign c_p1_ddr_cmd_valid = ~p1_cmd_fifo_empty;

    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_p1_ddr_cmd_addr  <=32'd0   ;
            r_p1_ddr_cmd_data  <=512'd0  ;
            r_p1_ddr_cmd_len   <=8'd0    ;
            r_p1_ddr_cmd_type  <=2'd0    ;
            r_p1_ddr_cmd_valid <=1'd0    ;
        end
    else
        begin
            r_p1_ddr_cmd_addr  <= c_p1_ddr_cmd_addr  ;
            r_p1_ddr_cmd_data  <= c_p1_ddr_cmd_data  ;
            r_p1_ddr_cmd_len   <= c_p1_ddr_cmd_len   ;
            r_p1_ddr_cmd_type  <= c_p1_ddr_cmd_type  ;
            r_p1_ddr_cmd_valid <= c_p1_ddr_cmd_valid ;
        end
    assign p1_ddr_cmd_addr = c_p1_ddr_cmd_addr ;
    assign p1_ddr_cmd_data = c_p1_ddr_cmd_data ;
    assign p1_ddr_cmd_len  = c_p1_ddr_cmd_len  ;
    assign p1_ddr_cmd_type = c_p1_ddr_cmd_type ;
    assign p1_ddr_cmd_valid= c_p1_ddr_cmd_valid;

    assign i_ddr_cmd_ready = ~p0_cmd_fifo_pfull & ~p1_cmd_fifo_pfull;
endmodule