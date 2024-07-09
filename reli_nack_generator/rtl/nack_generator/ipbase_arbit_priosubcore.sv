//------------------------------------------------------------
// <ipbase_arbit_priosubcore Module>
// Author: chenfeiyu
// Date. : 2022/01/01
// Func  : seq-prio cal core
//                      >>Instruction<<
// Port[iq]---req
// Port[prio]---one-hot seq-prio
// Port[og]---gnt
//                       >>>Mention<<<
// Private Code Repositories
// NO Unauthorized Use.
// Unexpected usage will lead to ERROR.
//                      >>Version Log<<
//  [*]Full Version. Developed by chenfeiyu.
//                                       @All Rights Reserved. 
//------------------------------------------------------------
module ipbase_arbit_priosubcore#(
    parameter NUM = 4
)(
    input   wire        [NUM-1:0]       iq  ,
    input   wire        [NUM-1:0]       prio,//one-hot seq-prio
    output  wire        [NUM-1:0]       og   
);
    wire    [NUM*2-1:0]     iq_copy;
    assign iq_copy = {iq,iq};
    wire    [NUM*2-1:0]     og_cal;
    assign og_cal = iq_copy & (~(iq_copy-prio));
    wire    [NUM-1:0]       og_or;
    assign og_or    = og_cal[NUM*2-1:NUM] | og_cal[NUM-1:0];

    assign og = og_or;
endmodule