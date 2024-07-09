//------------------------------------------------------------
// <ipbase_crc32_w512 Module>
// Author: chenfeiyu
// Date. : 2022/01/01
// Func  : crc32 calculator with 512bit parallel
//                      >>Instruction<<
// Port[System]---clock and reset
// Port[crc_din]---data input
// Port[crc_dout]---data output
// Port[crc_cyc]---data cycle
//                       >>>Mention<<<
// Private Code Repositories
// NO Unauthorized Use.
// Unexpected usage will lead to ERROR.
//                      >>Version Log<<
//  [*]Full Version. Developed by chenfeiyu.
//                                       @All Rights Reserved. 
//------------------------------------------------------------
module ipbase_crc32_w512(
    input   wire                    clk     ,
    input   wire    [511:0]         din     ,
    input   wire    [31:0]          cyc     ,
    output  wire    [31:0]          dout    
);
    assign dout = din[31:0];
endmodule