//------------------------------------------------------------
// <ipbase_intf_axi_rd_simplified Module>
// Author: chenfeiyu
// Date. : 2024/05/30
// Func  : adapter for axi4 read interface
//                      >>Instruction<<
// Port[System]---clock and reset
// Port[read cmd]---write command
// Port[read dat]---write data
// Port[axi rd]--axi4 read port (*simplified)
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
//  *Simplify read port and process.
//  *ONLY support to process 4K-boundary.
//  *ONLY support the io port with same data width.
//  *NOT support to process dynamic size.
//  *NOT support to process dynamic burst.
//                                       @All Rights Reserved. 
//------------------------------------------------------------
module ipbase_intf_axi_rd_adapter_simplified_v0p1#(
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

    input   wire    [ADDR_WIDTH-1:0]            cmd_araddr      ,
    input   wire    [TLEN_WIDTH-1:0]            cmd_arlen       ,//256*64Byte=16384Byte=4*4096Byte
    input   wire                                cmd_arvalid     ,
    output  wire                                cmd_arready     ,
    output  wire    [DATA_WIDTH-1:0]            cmd_rdata       ,
    output  wire                                cmd_rlast       ,
    output  wire                                cmd_rvalid      ,
    input   wire                                cmd_rready      ,

    output  wire    [AXI_ADDR_WIDTH-1:0]        axi_araddr      ,
    output  wire    [7:0]                       axi_arlen       ,
    output  wire                                axi_arvalid     ,
    input   wire                                axi_arready     ,
    input   wire    [AXI_DATA_WIDTH-1:0]        axi_rdata       ,
    input   wire                                axi_rlast       ,
    input   wire    [1:0]                       axi_rresp       ,
    input   wire                                axi_rvalid      ,
    output  wire                                axi_rready      ,

    output  wire                                err_trig        ,
    output  wire    [31:0]                      dfx_sta         
);
    localparam ADDR_IDLE = 4'd0;
    localparam ADDR_TRAN = 4'd1;
    localparam ADDR_WAIT = 4'd2;
    reg     [3:0]               addr_FSM_cs=ADDR_IDLE;
    reg     [3:0]               addr_FSM_ns;
    wire    [9:0]               c_cur_tran_addr     ;
    wire    [5:0]               c_cur_tran_len      ;
    wire                        c_cur_tran_vld      ;
    wire                        c_cur_tran_rdy      ;
    reg     [9:0]               r_cur_tran_addr     =10'd0;
    reg     [5:0]               r_cur_tran_len      =6'd0;
    reg                         r_cur_tran_vld      =1'd0;
    reg                         r_cur_tran_rdy      =1'd0;
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
    assign fixed_high_addr = cmd_araddr[31:15];
    assign fixed_low_addr  = 6'd0;
    assign sour_addr    = {1'd0,cmd_araddr[14:6]};
    assign dest_addr    = sour_addr+cmd_arlen;//max=512+256 < 1024
    assign judge_cross_4k   = 
                dest_addr[9:6] != r_cur_tran_addr[9:6] ? 1 : 0;
//------------------------------------------------------------
    assign c_cur_tran_addr  = 
                addr_FSM_cs==ADDR_TRAN ? 
                    axi_arvalid && axi_arready ? r_cur_tran_addr + r_cur_tran_len + 1 :
                    r_cur_tran_addr :
                cmd_arvalid ? sour_addr :
                10'd0;
    assign c_cur_tran_len   =
                addr_FSM_cs==ADDR_TRAN ? 
                    judge_cross_4k ? ~r_cur_tran_addr[5:0] : 
                    (dest_addr[5:0]-r_cur_tran_addr[5:0]) :
                6'd0;
    assign c_cur_tran_vld   =
                addr_FSM_cs==ADDR_TRAN ?
                    judge_cross_4k ? 1 :
                    axi_arvalid && axi_arready ? 0 :
                    1 :
                0;
    assign c_cur_tran_rdy   = (addr_tran_done);
    always@(posedge sys_clk)
    if(sys_rst)
    begin
        r_cur_tran_addr     <=10'd0;
        r_cur_tran_len      <=6'd0;
        r_cur_tran_vld      <=1'd0;
        r_cur_tran_rdy      <=1'd0;
    end
    else
    begin
        r_cur_tran_addr     <=c_cur_tran_addr;
        r_cur_tran_len      <=c_cur_tran_len ;
        r_cur_tran_vld      <=c_cur_tran_vld ;
        r_cur_tran_rdy      <=c_cur_tran_rdy ;
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
        if(cmd_arvalid && ~cmd_arready)
            addr_FSM_ns=ADDR_TRAN;
        else
            addr_FSM_ns=ADDR_IDLE;
    ADDR_TRAN:
        if(addr_tran_done)
            addr_FSM_ns=ADDR_IDLE;
        else
            addr_FSM_ns=ADDR_TRAN;
    default:addr_FSM_ns=ADDR_IDLE;
    endcase
    assign addr_tran_done = addr_FSM_cs == ADDR_TRAN ? 
                                ~judge_cross_4k && axi_arvalid && axi_arready ? 1 :
                                0 :
                            0;
//------------------------------------------------------------
// OUTPUT CON
    assign axi_araddr   = {fixed_high_addr,r_cur_tran_addr[8:0],fixed_low_addr};
    assign axi_arlen    = {2'd0,r_cur_tran_len};
    assign axi_arvalid  = r_cur_tran_vld;
    assign cmd_arready  = r_cur_tran_rdy;

    assign cmd_rdata    = axi_rdata     ;
    assign cmd_rlast    = axi_rlast     ;
    assign cmd_rvalid   = axi_rvalid    ;//logic output
    assign axi_rready   = cmd_rready    ;

    assign err_trig     = axi_rvalid && (axi_rresp != 2'd0);
    assign dfx_sta      = 32'd0;
endmodule