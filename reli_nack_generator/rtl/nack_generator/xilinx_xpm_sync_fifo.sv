module xilinx_xpm_sync_fifo #(
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
xpm_fifo_sync #(
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
endmodule