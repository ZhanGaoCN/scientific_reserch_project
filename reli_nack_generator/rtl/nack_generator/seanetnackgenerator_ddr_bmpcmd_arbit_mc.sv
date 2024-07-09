//------------------------------------------------------------
// <seanetnackgenerator Module>
// Author: chenfeiyu@seanet.com.cn
// Date. : 2024/05/27
// Func  : seanetnackgenerator
//                      >>Instruction<<
// Port[System]---clock and reset
// Port[]---dma data cache
// Port[]---AXI4 port
// Port[Dfx]---DFX Port
//                       >>>Mention<<<
// Only used in SEANet PRJ.
// Unexpected usage will lead to ERROR.
//                      >>Version Log<<
//  [v0.1]
//      
//                                       @All Rights Reserved. 
//------------------------------------------------------------
module seanetnackgenerator_ddr_bmpcmd_arbit_mc #(
    //------------------------------->>arbit config<<------------------------------
    //--------------------------------->>axi config<<------------------------------
    //AXI4 parameter
    parameter AXI_ID_WIDTH      = 4                     ,
    parameter AXI_ADDR_WIDTH    = 64                    ,
    parameter AXI_DATA_WIDTH    = 512                   ,
    parameter AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8      ,
    parameter AXI_ID_SET        = 0                     
) (
    input   wire                                        sys_clk         ,
    input   wire                                        sys_rst         ,
    // cmd input
    input   wire    [31:0]                              ddr_cmd_addr    ,
    input   wire    [511:0]                             ddr_cmd_data    ,
    input   wire    [1:0]                               ddr_cmd_type    ,//01 -> high mode / 00 -> low mode
    input   wire    [7:0]                               ddr_cmd_len     ,//fixed to 0
    input   wire                                        ddr_cmd_valid   ,
    output  wire                                        ddr_cmd_ready   ,
    // axi4 
    output wire [AXI_ID_WIDTH-1:0]                      m_axi_awid      ,
    output wire [AXI_ADDR_WIDTH-1:0]                    m_axi_awaddr    ,
    output wire [7:0]                                   m_axi_awlen     ,
    output wire [2:0]                                   m_axi_awsize    ,
    output wire [1:0]                                   m_axi_awburst   ,    
    output wire                                         m_axi_awlock    ,
    output wire [3:0]                                   m_axi_awcache   ,    
    output wire [2:0]                                   m_axi_awprot    ,
    output wire                                         m_axi_awvalid   ,    
    input  wire                                         m_axi_awready   ,    
    output wire [AXI_DATA_WIDTH-1:0]                    m_axi_wdata     ,
    output wire [AXI_STRB_WIDTH-1:0]                    m_axi_wstrb     ,
    output wire                                         m_axi_wlast     ,
    output wire                                         m_axi_wvalid    ,
    input  wire                                         m_axi_wready    ,
    input  wire [AXI_ID_WIDTH-1:0]                      m_axi_bid       ,
    input  wire [1:0]                                   m_axi_bresp     ,
    input  wire                                         m_axi_bvalid    ,
    output wire                                         m_axi_bready    ,

    output wire [AXI_ID_WIDTH-1:0]                      m_axi_arid      ,
    output wire [AXI_ADDR_WIDTH-1:0]                    m_axi_araddr    ,
    output wire [7:0]                                   m_axi_arlen     ,
    output wire [2:0]                                   m_axi_arsize    ,
    output wire [1:0]                                   m_axi_arburst   ,    
    output wire                                         m_axi_arlock    ,
    output wire [3:0]                                   m_axi_arcache   ,    
    output wire [2:0]                                   m_axi_arprot    ,
    output wire                                         m_axi_arvalid   ,    
    input  wire                                         m_axi_arready   ,    
    input  wire [AXI_ID_WIDTH-1:0]                      m_axi_rid       ,
    input  wire [AXI_DATA_WIDTH-1:0]                    m_axi_rdata     ,
    input  wire [1:0]                                   m_axi_rresp     ,
    input  wire                                         m_axi_rlast     ,
    input  wire                                         m_axi_rvalid    ,
    output wire                                         m_axi_rready    ,
    // connect to dfx port
    output wire [31:0]                                  dfx_sta0        ,
    output wire [31:0]                                  dfx_sta1        ,
    output wire [31:0]                                  dfx_sta2        ,
    output wire [31:0]                                  dfx_sta3        
);
    localparam MDF_IDLE         = 4'd0;
    localparam MDF_READ         = 4'd1;
    localparam MDF_READ_RESP    = 4'd2;
    localparam MDF_WRITE        = 4'd3;
    localparam MDF_WRITE_RESP   = 4'd4;
    reg     [3:0]                       mdf_FSM_cs=MDF_IDLE;
    reg     [3:0]                       mdf_FSM_ns;
    wire                                write_done;

    wire    [511:0]                 rdcmd_data     ;
    wire    [31 :0]                 rdcmd_addr     ;
    wire    [1  :0]                 rdcmd_type     ;
    reg                             r_w_vld=0;
    wire                            c_w_vld;
    reg     [511:0]                 r_wdata=512'd0;
    wire    [511:0]                 c_wdata;
    reg                             r_aw_vld=0;
    wire                            c_aw_vld;
    reg                     [1:0]   r_write_done=2'd0;
    wire                    [1:0]   c_write_done;
//------------------------------------------------------------
// cmd fifo
    localparam GENCMD_FIFO_WIDTH = 512+32+2;
    wire                            cmd_fifo_clk    ;
    wire                            cmd_fifo_rst    ;
    wire                            cmd_fifo_wren   ;
    wire    [GENCMD_FIFO_WIDTH-1:0] cmd_fifo_wrdat  ;
    wire    [GENCMD_FIFO_WIDTH-1:0] cmd_fifo_rddat  ;
    wire                            cmd_fifo_rden   ;
    wire                            cmd_fifo_empty  ;
    wire                            cmd_fifo_pempty ;
    wire                            cmd_fifo_full   ;
    wire                            cmd_fifo_pfull  ;
    ipbase_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("distribute"), // String
        .FIFO_READ_LATENCY(1),     // DECIMAL
        .FIFO_WRITE_DEPTH(16),   // DECIMAL
        .FULL_RESET_VALUE(1),      // DECIMAL
        .PROG_EMPTY_THRESH(5),    // DECIMAL
        .PROG_FULL_THRESH(11),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(4),   // DECIMAL
        .READ_DATA_WIDTH(GENCMD_FIFO_WIDTH),      // DECIMAL
        .READ_MODE("std"),         // String
        .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0707"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(GENCMD_FIFO_WIDTH),     // DECIMAL
        .WR_DATA_COUNT_WIDTH(4)    // DECIMAL
    )
    cmd_fifo_16d (
        .almost_empty     (),
        .almost_full      (),
        .data_valid       (),
        .dbiterr          (),
        .dout             (cmd_fifo_rddat     ),
        .empty            (cmd_fifo_empty     ),
        .full             (cmd_fifo_full      ),
        .overflow         (),
        .prog_empty       (cmd_fifo_pempty    ),
        .prog_full        (cmd_fifo_pfull     ),
        .rd_data_count    (),
        .rd_rst_busy      (),
        .sbiterr          (),
        .underflow        (),
        .wr_ack           (),
        .wr_data_count    (),
        .wr_rst_busy      (),
        .din              (cmd_fifo_wrdat     ),
        .injectdbiterr    (),
        .injectsbiterr    (),
        .rd_en            (cmd_fifo_rden      ),
        .rst              (cmd_fifo_rst       ),
        .sleep            (),
        .wr_clk           (cmd_fifo_clk       ),
        .wr_en            (cmd_fifo_wren      )                     
   );
    assign cmd_fifo_clk = sys_clk;
    assign cmd_fifo_rst = sys_rst;
    assign cmd_fifo_wren    = ddr_cmd_valid & ddr_cmd_ready;
    assign cmd_fifo_wrdat   = {
        ddr_cmd_type,
        ddr_cmd_addr,
        ddr_cmd_data
    };
    reg                             r0_cmd_fifo_rden=0;
    always@(posedge sys_clk)
    if(sys_rst)
        r0_cmd_fifo_rden <= 0;
    else
        r0_cmd_fifo_rden <= cmd_fifo_rden;
    assign cmd_fifo_rden = (mdf_FSM_cs==MDF_IDLE) && (~cmd_fifo_empty) && ~r0_cmd_fifo_rden;
    reg     [GENCMD_FIFO_WIDTH-1:0] cmd_fifo_rddat_lock={GENCMD_FIFO_WIDTH{1'b0}};
    always@(posedge sys_clk)
    if(sys_rst)
        cmd_fifo_rddat_lock<={GENCMD_FIFO_WIDTH{1'b0}};
    else if(r0_cmd_fifo_rden)
        cmd_fifo_rddat_lock<=cmd_fifo_rddat;
    else
        cmd_fifo_rddat_lock<=cmd_fifo_rddat_lock;

    reg r0_cmd_fifo_pfull=1;
    always@(posedge sys_clk)
    if(sys_rst)
        r0_cmd_fifo_pfull <= 1;
    else
        r0_cmd_fifo_pfull <= cmd_fifo_pfull;
    assign ddr_cmd_ready = ~r0_cmd_fifo_pfull;
//------------------------------------------------------------
// FSM
// read---read resp---write---write resp---Next
//
    always@(posedge sys_clk)
    if(sys_rst)
        mdf_FSM_cs <= MDF_IDLE;
    else
        mdf_FSM_cs <= mdf_FSM_ns;
    always@(*)
    case(mdf_FSM_cs)
    MDF_IDLE:
        if(r0_cmd_fifo_rden)
            mdf_FSM_ns=MDF_READ;
        else
            mdf_FSM_ns=mdf_FSM_cs;
    MDF_READ:
        if(m_axi_arready && m_axi_arvalid)
            mdf_FSM_ns=MDF_READ_RESP;
        else
            mdf_FSM_ns=mdf_FSM_cs;
    MDF_READ_RESP:
        if(m_axi_rvalid && m_axi_rready && (m_axi_rid == AXI_ID_SET))
            mdf_FSM_ns=MDF_WRITE;
        else
            mdf_FSM_ns=mdf_FSM_cs;
    MDF_WRITE:
        if(write_done)
            mdf_FSM_ns=MDF_WRITE_RESP;
        else
            mdf_FSM_ns=mdf_FSM_cs;
    MDF_WRITE_RESP:
        if(m_axi_bready && m_axi_bvalid && (m_axi_bid == AXI_ID_SET))
            mdf_FSM_ns=MDF_IDLE;
        else
            mdf_FSM_ns=mdf_FSM_cs;
    default:mdf_FSM_ns=MDF_IDLE;
    endcase
//------------------------------------------------------------
// read command gen
    assign {
        rdcmd_type,
        rdcmd_addr,
        rdcmd_data
    } = cmd_fifo_rddat_lock;
    assign m_axi_araddr     = rdcmd_addr;
    assign m_axi_arid       = AXI_ID_SET;
    assign m_axi_arlen      = 0;
    assign m_axi_arsize     = 3'b110;
    assign m_axi_arburst    = 2'b01;
    assign m_axi_arlock     = 0;
    assign m_axi_arcache    = 0;
    assign m_axi_arprot     = 0;
    assign m_axi_arvalid    = mdf_FSM_cs == MDF_READ;
    assign m_axi_rready     = 1;
//------------------------------------------------------------
// readback data
    reg     [511:0]                 r_rdback_data=512'd0;
    wire    [511:0]                 c_rdback_data;
    always@(posedge sys_clk)
    if(sys_rst)
        r_rdback_data <= 512'd0;
    else
        r_rdback_data <= c_rdback_data;
    assign c_rdback_data = m_axi_rvalid && m_axi_rready && (m_axi_rid == AXI_ID_SET) ? m_axi_rdata : r_rdback_data;
//------------------------------------------------------------
// write command gen
    assign m_axi_bready     = 1;
    assign m_axi_awid       = AXI_ID_SET;
    assign m_axi_awaddr     = rdcmd_addr;
    assign m_axi_awlen      = 0;
    assign m_axi_awsize     = 3'b110;
    assign m_axi_awburst    = 2'b01;
    assign m_axi_awlock     = 0;
    assign m_axi_awcache    = 0;
    assign m_axi_awprot     = 0;
    assign m_axi_awvalid    = r_aw_vld;
    assign c_aw_vld = 
                mdf_FSM_cs == MDF_READ_RESP && m_axi_rvalid && m_axi_rready && (m_axi_rid == AXI_ID_SET) ? 1 :
                m_axi_awvalid && m_axi_awready ? 0 :
                r_aw_vld;
    always@(posedge sys_clk)
    if(sys_rst)
        r_aw_vld <= 0;
    else
        r_aw_vld <= c_aw_vld;

    assign c_wdata = 
                    m_axi_rvalid && m_axi_rready && (m_axi_rid == AXI_ID_SET) ? 
                        rdcmd_type == 2'b00 ? m_axi_rdata & (~rdcmd_data) :
                        rdcmd_type == 2'b01 ? m_axi_rdata | rdcmd_data :
                        m_axi_rdata :
                    r_wdata;
    always@(posedge sys_clk)
    if(sys_rst)
        r_wdata <= 512'd0;
    else
        r_wdata <= c_wdata;
    assign m_axi_wdata      = r_wdata;
    assign m_axi_wstrb      = {64{1'd1}};
    assign m_axi_wlast      = 1;
    assign m_axi_wvalid     = r_w_vld;
    assign c_w_vld = 
                mdf_FSM_cs == MDF_READ_RESP && m_axi_rvalid && m_axi_rready && (m_axi_rid == AXI_ID_SET) ? 1 :
                m_axi_wvalid && m_axi_wready ? 0 :
                r_w_vld;
    always@(posedge sys_clk)
    if(sys_rst)
        r_w_vld <= 0;
    else
        r_w_vld <= c_w_vld;
    assign c_write_done = 
                r_write_done == 2'b00 ?
                    m_axi_wvalid && m_axi_wready && m_axi_awvalid && m_axi_awready ? 2'b10 :
                    m_axi_wvalid && m_axi_wready ? 2'b01 :
                    m_axi_awvalid && m_axi_awready ? 2'b01 :
                    r_write_done :
                r_write_done == 2'b01 ?
                    m_axi_wvalid && m_axi_wready ? 2'b10 :
                    m_axi_awvalid && m_axi_awready ? 2'b10 :
                    r_write_done :
                2'b00;
    always@(posedge sys_clk)
    if(sys_rst)
        r_write_done <= 2'd0;
    else
        r_write_done <= c_write_done;
    assign write_done = r_write_done[1];

endmodule