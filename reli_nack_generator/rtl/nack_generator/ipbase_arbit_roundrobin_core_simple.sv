//------------------------------------------------------------
// <ipbase_arbit_roundrobin_core_simple Module>
// Author: chenfeiyu
// Date. : 2022/01/01
// Func  : rr-arbit core(logic) ---> use adder
//                      >>Instruction<<
// Port[iq]---req
// Port[og]---gnt
//                       >>>Mention<<<
// Private Code Repositories
// NO Unauthorized Use.
// Unexpected usage will lead to ERROR.
//                      >>Version Log<<
//  [*]Full Version. Developed by chenfeiyu.
//                                       @All Rights Reserved. 
//------------------------------------------------------------
module ipbase_arbit_roundrobin_core_simple #(
    parameter NUM = 4 //MUST OVER 3
) (
    input   wire                clk     ,
    input   wire                rst     ,

    input   wire    [NUM-1:0]   iq      ,
    output  wire    [NUM-1:0]   og      
);
    
    reg     [NUM-1:0]       prio_round={{(NUM-1){1'b0}},1'b1};
    always@(posedge clk)
    if(rst)
        prio_round <= {{(NUM-1){1'b0}},1'b1};
    else if(iq != 0)
        prio_round <= {prio_round[NUM-2:0],prio_round[NUM-1]};
    else
        prio_round <= prio_round;

    ipbase_arbit_priosubcore #(
        .NUM(NUM)
    )ipbase_arbit_priosubcore_dut(
        .iq     (iq         ),
        .prio   (prio_round ),
        .og     (og         )
    );
endmodule