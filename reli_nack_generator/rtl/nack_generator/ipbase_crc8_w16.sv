//------------------------------------------------------------
// <ipbase_crc8_w16 Module>
// Author: chenfeiyu
// Date. : 2022/01/01
// Func  : crc calculator with 16bit parallel
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
module ipbase_crc8_w16(
    input   wire                    clk     ,
    input   wire    [15:0]          din     ,
    input   wire    [7 :0]          cyc     ,
    output  wire    [7 :0]          dout    
);
assign dout[7] =cyc[7]^cyc[6]^cyc[4]^cyc[1]^din[15]^din[14]^din[12]^din[9]^din[5]^din[4]^din[3];
assign dout[6] =cyc[7]^cyc[6]^cyc[5]^cyc[3]^cyc[0]^din[15]^din[14]^din[13]^din[11]^din[8]^din[4]^din[3]^din[2];
assign dout[5] =cyc[6]^cyc[5]^cyc[4]^cyc[2]^din[14]^din[13]^din[12]^din[10]^din[7]^din[3]^din[2]^din[1];
assign dout[4] =cyc[5]^cyc[4]^cyc[3]^cyc[1]^din[13]^din[12]^din[11]^din[9]^din[6]^din[2]^din[1]^din[0];
assign dout[3] =cyc[7]^cyc[6]^cyc[3]^cyc[2]^cyc[1]^cyc[0]^din[15]^din[14]^din[11]^din[10]^din[9]^din[8]^din[4]^din[3]^din[1]^din[0];
assign dout[2] =cyc[5]^cyc[4]^cyc[2]^cyc[0]^din[13]^din[12]^din[10]^din[8]^din[7]^din[5]^din[4]^din[2]^din[0];
assign dout[1] =cyc[6]^cyc[3]^din[14]^din[11]^din[7]^din[6]^din[5]^din[1];
assign dout[0] =cyc[7]^cyc[5]^cyc[2]^din[15]^din[13]^din[10]^din[6]^din[5]^din[4]^din[0];
endmodule