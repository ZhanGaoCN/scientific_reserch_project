//------------------------------------------------------------
// <ipbase_chksum32_w512 Module>
// Author: chenfeiyu
// Date. : 2024/06/13
// Func  : checksum calculator with 512bit parallel
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
module ipbase_chksum32_w512(
    input   wire                    clk     ,
    input   wire    [511:0]         din     ,
    input   wire    [31:0]          cyc     ,
    output  wire    [31:0]          dout    
);
genvar i;
wire    [255:0]         inter_din_l1;
wire    [127:0]         inter_din_l2;
wire    [63:0]          inter_din_l3;
generate
    for (i=0;i<256;i=i+1)
    assign inter_din_l1[i] = din[i]^din[256+i];
endgenerate
assign inter_din_l2 = ~inter_din_l1[255:128]^inter_din_l1[127:0];
assign inter_din_l3 = ~inter_din_l2[31:0]^inter_din_l2[63:32];

generate for(i=0;i<4;i=i+1)
ipbase_crc8_w16 ipbase_crc8_w16(
    .clk     (clk   ),//input   wire                    
    .din     (inter_din_l3[16*i+15:16*i]   ),//input   wire    [15:0]         
    .cyc     (8'hFF ),//input   wire    [7:0]          
    .dout    (dout[8*i+7:8*i]) //output  wire    [7:0]          
);
endgenerate


endmodule