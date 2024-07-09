//------------------------------------------------------------
// <ipbase_sdpram_sync Module>
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
module ipbase_sdpram_sync#(
    parameter CASCADE_HEIGHT                  =0,// DECIMAL
    parameter CLOCKING_MODE                   ="common_clock",// String
    parameter ECC_MODE                        ="no_ecc",// String
    parameter MEMORY_INIT_FILE                ="none",// String
    parameter MEMORY_INIT_PARAM               ="0",// String
    parameter MEMORY_OPTIMIZATION             ="true",// String
    parameter MEMORY_PRIMITIVE                ="auto",// String
    parameter MESSAGE_CONTROL                 =0,// DECIMAL
    parameter RST_MODE_A                      ="SYNC",// String
    parameter RST_MODE_B                      ="SYNC",// String
    parameter SIM_ASSERT_CHK                  =0,// DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    parameter USE_EMBEDDED_CONSTRAINT         =0,// DECIMAL
    parameter USE_MEM_INIT                    =1,// DECIMAL
    parameter USE_MEM_INIT_MMI                =0,// DECIMAL
    parameter WAKEUP_TIME                     ="disable_sleep",// String
    parameter AUTO_SLEEP_TIME                 =0,// DECIMAL
    parameter MEMORY_SIZE                     =2048,// DECIMAL
    parameter ADDR_WIDTH_A                    =6,// DECIMAL
    parameter ADDR_WIDTH_B                    =6,// DECIMAL
    parameter WRITE_DATA_WIDTH_A              =32,// DECIMAL
    parameter BYTE_WRITE_WIDTH_A              =32,// DECIMAL
    parameter READ_DATA_WIDTH_B               =32,// DECIMAL
    parameter READ_LATENCY_B                  =2,// DECIMAL
    parameter READ_RESET_VALUE_B              ="0",// String
    parameter WRITE_MODE_B                    ="no_change",// String
    parameter WRITE_PROTECT                   =1// DECIMAL
   )(
        input   wire                                                clka    ,
        input   wire    [ADDR_WIDTH_A-1:0]                          addra   ,
        input   wire    [WRITE_DATA_WIDTH_A-1:0]                    dina    ,
        input   wire                                                ena     ,
        input   wire    [WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-1:0] wea     ,

        input   wire                                                clkb    ,
        input   wire    [ADDR_WIDTH_B-1:0]                          addrb   ,
        output  wire    [READ_DATA_WIDTH_B-1:0]                     doutb   ,
        input   wire                                                enb     ,

        output  wire                                                dbiterrb        ,
        output  wire                                                sbiterrb        ,
        input   wire                                                injectdbiterra  ,
        input   wire                                                injectsbiterra  ,
        input   wire                                                regceb          ,
        input   wire                                                rstb            ,
        input   wire                                                sleep            
);

`ifdef COCOTB_SIM
    initial begin
        if (ADDR_WIDTH_A != ADDR_WIDTH_B) begin
            $error("[%s %0d-%0d] ADDR_WIDTH_A(%0b) != ADDR_WIDTH_B(%0b). Not Support!", "COCOTB_SIM", 1, 1, ADDR_WIDTH_A, ADDR_WIDTH_B);
            $finish;
        end
        if (READ_LATENCY_B == 0) begin
            $error("[%s %0d-%0d] READ_LATENCY_B == %0d. Not Support!", "COCOTB_SIM", 1, 2, READ_LATENCY_B);
            $finish;
        end
    end
    simple_dual_port_ram #
    (   .DATA_WIDTH (WRITE_DATA_WIDTH_A),
        .ADDR_WIDTH (ADDR_WIDTH_A),
        .PIPE_DEPTH (READ_LATENCY_B),
        .WRITE_PRIORITY (0)
    )simple_dual_port_ram_dut(
        //input;
        .clk(clka),
        .rst(rstb),  // reset for data out
        .wren(wea), //write high enable;
        .rden(enb),
        .raddress(addrb),
        .waddress(addra),
        .data_in(dina),
        //output;
        .data_out(doutb) 
    );
`else
    xilinx_xpm_memory_sdpram#(
      .CASCADE_HEIGHT                  (CASCADE_HEIGHT                  ),// DECIMAL
      .CLOCKING_MODE                   (CLOCKING_MODE                   ),// DECIMAL
      .ECC_MODE                        (ECC_MODE                        ),// DECIMAL
      .MEMORY_INIT_FILE                (MEMORY_INIT_FILE                ),// DECIMAL
      .MEMORY_INIT_PARAM               (MEMORY_INIT_PARAM               ),// DECIMAL
      .MEMORY_OPTIMIZATION             (MEMORY_OPTIMIZATION             ),// String
      .MEMORY_PRIMITIVE                (MEMORY_PRIMITIVE                ),// String
      .MESSAGE_CONTROL                 (MESSAGE_CONTROL                 ),// String
      .RST_MODE_A                      (RST_MODE_A                      ),// String
      .RST_MODE_B                      (RST_MODE_B                      ),// String
      .SIM_ASSERT_CHK                  (SIM_ASSERT_CHK                  ),// String
      .USE_EMBEDDED_CONSTRAINT         (USE_EMBEDDED_CONSTRAINT         ),// DECIMAL
      .USE_MEM_INIT                    (USE_MEM_INIT                    ),// DECIMAL
      .USE_MEM_INIT_MMI                (USE_MEM_INIT_MMI                ),// DECIMAL
      .WAKEUP_TIME                     (WAKEUP_TIME                     ),// DECIMAL
      .AUTO_SLEEP_TIME                 (AUTO_SLEEP_TIME                 ),// String
      .MEMORY_SIZE                     (MEMORY_SIZE                     ),// String
      .ADDR_WIDTH_A                    (ADDR_WIDTH_A                    ),// String
      .ADDR_WIDTH_B                    (ADDR_WIDTH_B                    ),// DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .WRITE_DATA_WIDTH_A              (WRITE_DATA_WIDTH_A              ),// DECIMAL
      .BYTE_WRITE_WIDTH_A              (BYTE_WRITE_WIDTH_A              ),// DECIMAL
      .READ_DATA_WIDTH_B               (READ_DATA_WIDTH_B               ),// DECIMAL
      .READ_LATENCY_B                  (READ_LATENCY_B                  ),// String
      .READ_RESET_VALUE_B              (READ_RESET_VALUE_B              ),// DECIMAL
      .WRITE_MODE_B                    (WRITE_MODE_B                    ),// String
      .WRITE_PROTECT                   (WRITE_PROTECT                   ) // DECIMAL
    )xilinx_xpm_memory_sdpram_dut(
        .clka               (clka               ),//input   wire                                                
        .addra              (addra              ),//input   wire    [ADDR_WIDTH_A-1:0]                          
        .dina               (dina               ),//input   wire    [WRITE_DATA_WIDTH_A-1:0]                    
        .ena                (ena                ),//input   wire                                                
        .wea                (wea                ),//input   wire    [WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-1:0] 

        .clkb               (clkb               ),//input   wire                                                
        .addrb              (addrb              ),//input   wire    [ADDR_WIDTH_B-1:0]                          
        .doutb              (doutb              ),//output  wire    [READ_DATA_WIDTH_B-1:0]                    
        .enb                (enb                ),//input   wire                                                

        .dbiterrb           (dbiterrb           ),//output  wire                                                
        .sbiterrb           (sbiterrb           ),//output  wire                                                
        .injectdbiterra     (injectdbiterra     ),//input   wire                                                
        .injectsbiterra     (injectsbiterra     ),//input   wire                                                
        .regceb             (regceb             ),//input   wire                                                
        .rstb               (rstb               ),//input   wire                                                
        .sleep              (sleep              ) //input   wire                                                
    );
`endif


endmodule