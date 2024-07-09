//------------------------------------------------------------
// <ipbase_fifo_sync Module>
// Author: chenfeiyu
// Date. : 2024/06/14
// Func  : sync fifo
//                      >>Instruction<<
// Port[System]---clock and reset
// Port[write]---write port
// Port[read]---read port
//                       >>>Mention<<<
// Private Code Repositories
// NO Unauthorized Use.
// Unexpected usage will lead to ERROR.
//                      >>Version Log<<
//  [*]Full Version. Developed by chenfeiyu.
//                                       @All Rights Reserved. 
//------------------------------------------------------------
module ipbase_fifo_sync #(
    parameter CASCADE_HEIGHT            =0          ,// DECIMAL
    parameter DOUT_RESET_VALUE          ="0"        ,// String
    parameter ECC_MODE                  ="no_ecc"   ,// String
    parameter FIFO_MEMORY_TYPE          ="auto"     ,// String
    parameter FIFO_READ_LATENCY         =0          ,// DECIMAL
    parameter FIFO_WRITE_DEPTH          =2048       ,// DECIMAL
    parameter FULL_RESET_VALUE          =1          ,// DECIMAL
    parameter PROG_EMPTY_THRESH         =10         ,// DECIMAL
    parameter PROG_FULL_THRESH          =2000       ,// DECIMAL
    parameter RD_DATA_COUNT_WIDTH       =10         ,// DECIMAL
    parameter READ_DATA_WIDTH           =16         ,// DECIMAL
    parameter READ_MODE                 ="fwft"      ,// String "std" "fwft"
    parameter SIM_ASSERT_CHK            =0          ,// DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    parameter USE_ADV_FEATURES          ="0707"     ,// String
    parameter WAKEUP_TIME               =0          ,// DECIMAL
    parameter WRITE_DATA_WIDTH          =16         ,// DECIMAL
    parameter WR_DATA_COUNT_WIDTH       =10          // DECIMAL
) (
    output  wire                                almost_empty     ,
    output  wire                                almost_full      ,
    output  wire                                data_valid       ,
    output  wire                                dbiterr          ,
    output  wire    [READ_DATA_WIDTH-1:0]       dout             ,
    output  wire                                empty            ,
    output  wire                                full             ,
    output  wire                                overflow         ,
    output  wire                                prog_empty       ,
    output  wire                                prog_full        ,
    output  wire    [RD_DATA_COUNT_WIDTH-1:0]   rd_data_count    ,
    output  wire                                rd_rst_busy      ,
    output  wire                                sbiterr          ,
    output  wire                                underflow        ,
    output  wire                                wr_ack           ,
    output  wire    [WR_DATA_COUNT_WIDTH-1:0]   wr_data_count    ,
    output  wire                                wr_rst_busy      ,
    output  wire    [WRITE_DATA_WIDTH-1:0]      din              ,
    input   wire                                injectdbiterr    ,
    input   wire                                injectsbiterr    ,
    input   wire                                rd_en            ,
    input   wire                                rst              ,
    input   wire                                sleep            ,
    input   wire                                wr_clk           ,
    input   wire                                wr_en            
);
`ifdef COCOTB_SIM
    initial begin
        if (READ_DATA_WIDTH != WRITE_DATA_WIDTH) begin
            $error("[%s %0d-%0d] READ_DATA_WIDTH(%0b) != WRITE_DATA_WIDTH(%0b). Not Support!", "COCOTB_SIM", 1, 1, READ_DATA_WIDTH, WRITE_DATA_WIDTH);
            $finish;
        end
    end
    ipbase_fifo_distribute_v1p1#(
    .FIFO_WIDTH     (READ_DATA_WIDTH     ),
    .FIFO_DEPTH     (FIFO_WRITE_DEPTH    ),
    .FIFO_PFULL     (PROG_FULL_THRESH        ),
    .FIFO_PEMPTY    (PROG_EMPTY_THRESH       ),
    .FIFO_TYPE      ("SYNC"  ),
    .FIFO_LANTENCY  (FIFO_READ_LATENCY)
    )ipbase_fifo_distribute_v1p1(
    .wr_clk      (wr_clk),//input   wire                            
    .wr_rst      (rst),//input   wire                            
    .wr_en       (wr_en),//input   wire                            
    .wr_data     (din),//input   wire    [FIFO_WIDTH-1:0]        
    .wr_full     (full),//output  wire                            
    .wr_pfull    (prog_full),//output  wire                            
    .rd_clk      (wr_clk),//input   wire                            
    .rd_rst      (rst),//input   wire                            
    .rd_en       (rd_en),//input   wire                            
    .rd_data     (dout),//output  wire    [FIFO_WIDTH-1:0]        
    .rd_empty    (empty),//output  wire                            
    .rd_pempty   (prog_empty) //output  wire                            
    );
    reg     [RD_DATA_COUNT_WIDTH-1:0]   r_rd_data_count={RD_DATA_COUNT_WIDTH{1'b0}};
    wire    [RD_DATA_COUNT_WIDTH-1:0]   c_rd_data_count;
    assign c_rd_data_count = 
                {wr_en,rd_en} == 2'b01 ? r_rd_data_count-1 : 
                {wr_en,rd_en} == 2'b10 ? r_rd_data_count+1 : r_rd_data_count;
    always@(posedge wr_clk)
    if(rst)
        r_rd_data_count <= {RD_DATA_COUNT_WIDTH{1'b0}};
    else
        r_rd_data_count <= c_rd_data_count;
    assign rd_data_count = r_rd_data_count;
`else
    xilinx_xpm_sync_fifo #(
        .CASCADE_HEIGHT            (CASCADE_HEIGHT            ),
        .DOUT_RESET_VALUE          (DOUT_RESET_VALUE          ),
        .ECC_MODE                  (ECC_MODE                  ),
        .FIFO_MEMORY_TYPE          (FIFO_MEMORY_TYPE          ),
        .FIFO_READ_LATENCY         (FIFO_READ_LATENCY         ),
        .FIFO_WRITE_DEPTH          (FIFO_WRITE_DEPTH          ),
        .FULL_RESET_VALUE          (FULL_RESET_VALUE          ),
        .PROG_EMPTY_THRESH         (PROG_EMPTY_THRESH         ),
        .PROG_FULL_THRESH          (PROG_FULL_THRESH          ),
        .RD_DATA_COUNT_WIDTH       (RD_DATA_COUNT_WIDTH       ),
        .READ_DATA_WIDTH           (READ_DATA_WIDTH           ),
        .READ_MODE                 (READ_MODE                 ),
        .SIM_ASSERT_CHK            (SIM_ASSERT_CHK            ),
        .USE_ADV_FEATURES          (USE_ADV_FEATURES          ),
        .WAKEUP_TIME               (WAKEUP_TIME               ),
        .WRITE_DATA_WIDTH          (WRITE_DATA_WIDTH          ),
        .WR_DATA_COUNT_WIDTH       (WR_DATA_COUNT_WIDTH       ) 
   )
   wr_cmd_fifo_2048d (
        .almost_empty     (almost_empty     ),
        .almost_full      (almost_full      ),
        .data_valid       (data_valid       ),
        .dbiterr          (dbiterr          ),
        .dout             (dout             ),
        .empty            (empty            ),
        .full             (full             ),
        .overflow         (overflow         ),
        .prog_empty       (prog_empty       ),
        .prog_full        (prog_full        ),
        .rd_data_count    (rd_data_count    ),
        .rd_rst_busy      (rd_rst_busy      ),
        .sbiterr          (sbiterr          ),
        .underflow        (underflow        ),
        .wr_ack           (wr_ack           ),
        .wr_data_count    (wr_data_count    ),
        .wr_rst_busy      (wr_rst_busy      ),
        .din              (din              ),
        .injectdbiterr    (injectdbiterr    ),
        .injectsbiterr    (injectsbiterr    ),
        .rd_en            (rd_en            ),
        .rst              (rst              ),
        .sleep            (sleep            ),
        .wr_clk           (wr_clk           ),
        .wr_en            (wr_en            ) 
   );
`endif
endmodule