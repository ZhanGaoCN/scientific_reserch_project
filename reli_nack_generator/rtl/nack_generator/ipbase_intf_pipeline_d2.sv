//------------------------------------------------------------
// <ipbase_intf_pipeline_d2 Module>
// Author: chenfeiyu
// Date. : 2022/01/01
// Func  : pipeline = fwft fifo 
//          [double the ready singal fanout to cut logic link]
//                      >>Instruction<<
// Port[id]---input data bus
// Port[od]---output data bus
//                       >>>Mention<<<
// Private Code Repositories
// NO Unauthorized Use.
// Unexpected usage will lead to ERROR.
//                      >>Version Log<<
//  [*]Full Version. Developed by chenfeiyu.
//                                       @All Rights Reserved. 
//------------------------------------------------------------
module ipbase_intf_pipeline_d2#(
    parameter DATA_WIDTH = 512
)(
    input   wire                        clk     ,
    input   wire                        rst     ,
    input   wire    [DATA_WIDTH-1:0]    id      ,
    input   wire                        id_vld  ,
    output  wire                        id_rdy  ,
    output  wire    [DATA_WIDTH-1:0]    od      ,
    output  wire                        od_vld  ,
    input   wire                        od_rdy  
);
wire    [DATA_WIDTH-1:0]                    c_d0;//data
wire    [DATA_WIDTH-1:0]                    c_d1;//data
wire    [1:0]                               c_v;//valid
reg     [DATA_WIDTH-1:0]                    r_d0={DATA_WIDTH{1'b0}};//data
reg     [DATA_WIDTH-1:0]                    r_d1={DATA_WIDTH{1'b0}};//data
reg     [1:0]                               r_v=0;//valid
assign id_rdy = ~r_v[0];
assign od = r_d1;
assign od_vld = r_v[1];

assign c_v[0] = 
            r_v[0] ?
                r_v[1] ?
                    od_rdy ? 0 :
                    1 :
                0 :
            r_v[1] ?
                od_rdy ? 0 :
                id_vld ? 1 :
                0 :
            0 ;
assign c_v[1] = 
            r_v[1] ?
                od_rdy ?
                    r_v[0] ? 1 :
                    id_vld ? 1 :
                    0 :
                1 :
            r_v[0] ? 1 :
            id_vld ? 1 :
            0;
assign c_d0 = 
            r_v[0] ?
                r_v[1] ?
                    od_rdy ? {DATA_WIDTH{1'b0}} :
                    r_d0 :
                {DATA_WIDTH{1'b0}} :
            r_v[1] ?
                od_rdy ? {DATA_WIDTH{1'b0}} :
                id_vld ? id :
                {DATA_WIDTH{1'b0}} :
            {DATA_WIDTH{1'b0}} ;
assign c_d1 = 
            r_v[1] ?
                od_rdy ?
                    r_v[0] ? r_d0 :
                    id_vld ? id :
                    {DATA_WIDTH{1'b0}} :
                r_d1 :
            r_v[0] ? r_d0 :
            id_vld ? id :
            {DATA_WIDTH{1'b0}};
always@(posedge clk)
if(rst)
    begin
        r_d0<={DATA_WIDTH{1'b0}};//data
        r_d1<={DATA_WIDTH{1'b0}};//data
        r_v <=0;//valid
    end
else
    begin
        r_d0<=c_d0;
        r_d1<=c_d1;
        r_v <=c_v ;
    end
endmodule