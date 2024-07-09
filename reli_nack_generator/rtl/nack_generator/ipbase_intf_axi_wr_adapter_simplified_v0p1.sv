//------------------------------------------------------------
// <ipbase_intf_axi_wr_simplified Module>
// Author: chenfeiyu
// Date. : 2024/05/30
// Func  : adapter for axi4 write interface
//                      >>Instruction<<
// Port[System]---clock and reset
// Port[write cmd]---write command
// Port[write dat]---write data
// Port[axi wr]--axi4 write port (*simplified)
//                       >>>Mention<<<
// Private Code Repositories.
// NO Unauthorized Use.
// Unexpected usage will lead to ERROR.
//                      >>Version Log<<
//  [v0.1] 
//  Customized simplified revision for SEANet-PRJ, base on full version 1.0.
//  *_________________________________________________*
//  *--------------->>>>>Caution!                     *
//  *                  Fixed Param!<<<<<--------------*
//  *_________________________________________________*
//  *Simplify write port and process.
//  *ONLY support to process 4K-boundary.
//  *ONLY support the io port with same data width.
//  *NOT support to process dynamic size.
//  *NOT support to process dynamic burst.
//                                       @All Rights Reserved. 
//------------------------------------------------------------
module ipbase_intf_axi_wr_adapter_simplified_v0p1#(
    ///--->>>>Caution! FIXED PARAM!
    // adapter parameter
    parameter DATA_WIDTH        = 512                   ,
    parameter ADDR_WIDTH        = 32                    ,
    parameter TLEN_WIDTH        = 8                     ,
    // AXI4 parameter
    parameter AXI_ADDR_WIDTH    = ADDR_WIDTH            ,
    parameter AXI_DATA_WIDTH    = DATA_WIDTH             
)(
    input   wire                                sys_clk         ,
    input   wire                                sys_rst         ,

    input   wire    [ADDR_WIDTH-1:0]            cmd_awaddr      ,
    input   wire    [TLEN_WIDTH-1:0]            cmd_awlen       ,//256*64Byte=16384Byte=4*4096Byte
    input   wire                                cmd_awvalid     ,
    output  wire                                cmd_awready     ,

    input   wire    [DATA_WIDTH-1:0]            cmd_wdata       ,
    input   wire                                cmd_wlast       ,//no used
    input   wire                                cmd_wvalid      ,//no used
    output  wire                                cmd_wready      ,//no used

    output  wire    [AXI_ADDR_WIDTH-1:0]        axi_awaddr      ,
    output  wire    [7:0]                       axi_awlen       ,
    output  wire                                axi_awvalid     ,
    input   wire                                axi_awready     ,

    output  wire    [AXI_DATA_WIDTH-1:0]        axi_wdata       ,
    output  wire                                axi_wlast       ,
    output  wire                                axi_wvalid      ,
    input   wire                                axi_wready      ,

    input   wire    [1:0]                       axi_bresp       ,
    input   wire                                axi_bvalid      ,
    output  wire                                axi_bready      ,

    output  wire                                err_trig        ,
    output  wire    [31:0]                      dfx_sta         
);
    localparam ADDR_IDLE = 4'd0;
    localparam ADDR_TRAN = 4'd1;
    localparam ADDR_WAIT = 4'd2;
    localparam DATA_IDLE = 4'd0;
    localparam DATA_TRAN = 4'd1;
    localparam DATA_WAIT = 4'd2;
    reg     [3:0]               addr_FSM_cs=ADDR_IDLE;
    reg     [3:0]               addr_FSM_ns;
    reg     [3:0]               data_FSM_cs=DATA_IDLE;
    reg     [3:0]               data_FSM_ns;
    wire    [9:0]               c_cur_tran_addr     ;
    wire    [5:0]               c_cur_tran_len      ;
    wire                        c_cur_tran_vld      ;
    wire                        c_cur_tran_rdy      ;
    reg     [9:0]               r_cur_tran_addr     =10'd0;
    reg     [5:0]               r_cur_tran_len      =6'd0;
    reg                         r_cur_tran_vld      =1'd0;
    reg                         r_cur_tran_rdy      =1'd0;
    wire    [9:0]               c_cur_data_addr     ;
    wire                        c_cur_data_vld      ;
    wire                        c_cur_data_last     ;
    wire    [511:0]             c_cur_data          ;
    wire                        c_cur_data_rdy      ;
    reg     [9:0]               r_cur_data_addr     =10'd0;
    reg                         r_cur_data_vld      =1'd0;
    reg                         r_cur_data_last     =1'd0;
    reg     [511:0]             r_cur_data          =512'd0;
    reg                         r_cur_data_rdy      =1'd0;
    wire                        data_tran_done;
    wire                        addr_tran_done;
//------------------------------------------------------------
//               >>>cross 4K boundary process<<<
// [fixed_high_addr ]:
// [fixed_low_addr  ]:
// [sour_addr       ]:
// [dest_addr       ]:
// [judge_cross_4k  ]:
//------------------------------------------------------------
    wire    [16:0]              fixed_high_addr ;
    wire    [5:0]               fixed_low_addr  ;
    wire    [9:0]               sour_addr       ;
    wire    [9:0]               dest_addr       ;
    wire                        judge_cross_4k  ;
    assign fixed_high_addr = cmd_awaddr[31:15];
    assign fixed_low_addr  = 6'd0;
    assign sour_addr    = {1'd0,cmd_awaddr[14:6]};
    assign dest_addr    = sour_addr+cmd_awlen;//max=512+256 < 1024
    assign judge_cross_4k   = 
                dest_addr[9:6] != r_cur_tran_addr[9:6] ? 1 : 0;
//------------------------------------------------------------
    assign c_cur_tran_addr  = 
                addr_FSM_cs==ADDR_TRAN ? 
                    axi_awvalid && axi_awready ? r_cur_tran_addr + r_cur_tran_len + 1 :
                    r_cur_tran_addr :
                cmd_awvalid ? sour_addr :
                10'd0;
    assign c_cur_tran_len   =
                addr_FSM_cs==ADDR_TRAN ? 
                    judge_cross_4k ? ~r_cur_tran_addr[5:0] : 
                    (dest_addr[5:0]-r_cur_tran_addr[5:0]) :
                6'd0;
    assign c_cur_tran_vld   =
                addr_FSM_cs==ADDR_TRAN ?
                    judge_cross_4k ? 1 :
                    axi_awvalid && axi_awready ? 0 :
                    1 :
                0;
    assign c_cur_tran_rdy   = (addr_tran_done && data_tran_done);

    assign c_cur_data_addr  = 
                data_FSM_cs==DATA_IDLE ? 
                    cmd_awvalid ? sour_addr :
                    10'd0 :
                data_FSM_cs==DATA_TRAN ?
                    axi_wvalid && axi_wready ? r_cur_data_addr + 1 :
                    r_cur_data_addr :
                10'd0;
    //-------------------------------------------------------------------------------------------------
    //assign c_cur_data_vld   =
    //            data_FSM_cs==DATA_TRAN ? 1 :
    //                r_cur_data_vld ?
    //                    axi_wready ?
    //                        cmd_wvalid ? 1 :
    //                        0 :
    //                    1 :
    //                cmd_wvalid ? 1 :
    //                0 :
    //            0;
    //assign c_cur_data_last  =
    //            data_FSM_cs==DATA_TRAN ? 
    //                r_cur_data_vld ?
    //                    axi_wready ?
    //                        cmd_wvalid ? cmd_wlast :
    //                        1'd0 :
    //                    r_cur_data_last :
    //                cmd_wvalid ? cmd_wlast :
    //                1'd0 :
    //            1'd0;
    //assign c_cur_data       =
    //            data_FSM_cs==DATA_TRAN ? 
    //                r_cur_data_vld ?
    //                    axi_wready ?
    //                        cmd_wvalid ? cmd_wdata :
    //                        512'd0 :
    //                    r_cur_data :
    //                cmd_wvalid ? cmd_wdata :
    //                512'd0 :
    //            512'd0;
    //---------------------------------------------------------------------------------------------------
    // Modify to:
    assign c_cur_data_vld   =
                data_FSM_cs==DATA_TRAN ? 1 :
                0;
    assign c_cur_data_last  =
                data_FSM_cs==DATA_TRAN ? 
                    (r_cur_data_addr[5:0] == 6'b111110) && axi_wvalid && axi_wready ? 1 :
                    ((r_cur_data_addr+10'd1) == dest_addr) && axi_wvalid && axi_wready ? 1 :
                    (r_cur_data_addr == dest_addr) ? 1 :
                    r_cur_data_last :
                1'd0;
    assign c_cur_data       =
                data_FSM_cs==DATA_TRAN ? 
                    ((r_cur_data_addr+10'd1) == dest_addr) && axi_wvalid && axi_wready ? cmd_wdata :
                    (r_cur_data_addr == dest_addr) ? cmd_wdata :
                    {512{1'b1}} :
                1'd0;
    //---------------------------------------------------------------------------------------------------
    assign c_cur_data_rdy   = 
                data_FSM_cs==DATA_TRAN ? 
                    r_cur_data_vld ? 
                       axi_wready ? 1 : 
                       0 :
                    1 :
                0;
    always@(posedge sys_clk)
    if(sys_rst)
    begin
        r_cur_tran_addr     <=10'd0;
        r_cur_tran_len      <=6'd0;
        r_cur_tran_vld      <=1'd0;
        r_cur_tran_rdy      <=1'd0;
        r_cur_data_addr     <=10'd0;
        r_cur_data_vld      <=1'd0;
        r_cur_data_last     <=1'd0;
        r_cur_data          <=512'd0;
        r_cur_data_rdy      <=1'd0;
    end
    else
    begin
        r_cur_tran_addr     <=c_cur_tran_addr;
        r_cur_tran_len      <=c_cur_tran_len ;
        r_cur_tran_vld      <=c_cur_tran_vld ;
        r_cur_tran_rdy      <=c_cur_tran_rdy ;
        r_cur_data_addr     <=c_cur_data_addr;
        r_cur_data_vld      <=c_cur_data_vld ;
        r_cur_data_last     <=c_cur_data_last;
        r_cur_data          <=c_cur_data     ;
        r_cur_data_rdy      <=c_cur_data_rdy ;
    end
//------------------------------------------------------------
// FSM
    always@(posedge sys_clk)
    if(sys_rst)
        addr_FSM_cs <= ADDR_IDLE;
    else
        addr_FSM_cs <= addr_FSM_ns;
    always@(*)
    case(addr_FSM_cs)
    ADDR_IDLE:
        if(cmd_awvalid && ~cmd_awready)
            addr_FSM_ns=ADDR_TRAN;
        else
            addr_FSM_ns=ADDR_IDLE;
    ADDR_TRAN:
        if(addr_tran_done && data_tran_done)
            addr_FSM_ns=ADDR_IDLE;
        else if(addr_tran_done)
            addr_FSM_ns=ADDR_WAIT;
        else
            addr_FSM_ns=ADDR_TRAN;
    ADDR_WAIT:
        if(data_tran_done)
            addr_FSM_ns=ADDR_IDLE;
        else
            addr_FSM_ns=ADDR_WAIT;
    default:addr_FSM_ns=ADDR_IDLE;
    endcase
    assign addr_tran_done = addr_FSM_cs == ADDR_TRAN ? 
                                ~judge_cross_4k && axi_awvalid && axi_awready ? 1 :
                                0 :
                            addr_FSM_cs == ADDR_WAIT ? 1 :
                            0;
//------------------------------------------------------------
// FSM
    always@(posedge sys_clk)
    if(sys_rst)
        data_FSM_cs <= ADDR_IDLE;
    else
        data_FSM_cs <= data_FSM_ns;
    always@(*)
    case(data_FSM_cs)
    DATA_IDLE:
        if(cmd_awvalid && ~cmd_awready)
            data_FSM_ns=DATA_TRAN;
        else
            data_FSM_ns=DATA_IDLE;
    DATA_TRAN:
        if(addr_tran_done && data_tran_done)
            data_FSM_ns=DATA_IDLE;
        else if(data_tran_done)
            data_FSM_ns=DATA_WAIT;
        else
            data_FSM_ns=DATA_TRAN;
    DATA_WAIT:
        if(addr_tran_done)
            data_FSM_ns=DATA_IDLE;
        else
            data_FSM_ns=DATA_WAIT;
    default:data_FSM_ns=DATA_IDLE;
    endcase

    assign data_tran_done = data_FSM_cs == DATA_TRAN ? 
                                (r_cur_data_addr == dest_addr) && axi_wvalid && axi_wready ? 1 :
                                0 :
                            data_FSM_cs == DATA_WAIT ? 1 :
                            0;
//------------------------------------------------------------
// OUTPUT CON
    assign axi_awaddr   = {fixed_high_addr,r_cur_tran_addr[8:0],fixed_low_addr};
    assign axi_awlen    = {2'd0,r_cur_tran_len};
    assign axi_awvalid  = r_cur_tran_vld;
    assign cmd_awready  = r_cur_tran_rdy;

    assign axi_wvalid   = r_cur_data_vld;
    assign axi_wdata    = r_cur_data;
    assign axi_wlast    = r_cur_data_last;//logic output
    assign cmd_wready   = r_cur_data_rdy;

    assign axi_bready   = 1;
    assign err_trig     = axi_bvalid && (axi_bresp != 2'd0);
    assign dfx_sta      = 32'd0;
endmodule       