//------------------------------------------------------------
// <ipbase_intf_axi_arbit4to1robin_simplified Module>
// Author: chenfeiyu
// Date. : 2024/05/30
// Func  : Robin-Arbit for axi4 interface
//                      >>Instruction<<
// Port[System]---clock and reset
// Port[axi-Master]--axi4 port (*simplified)
// Port[axi-Slave*4]--axi4 port (*simplified)
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
//  *Simplify port and process.
//  *ONLY support len =0
//  *ONLY support the io port with same data width.
//  *NOT support to process dynamic size.
//  *NOT support to process dynamic burst.
//  *NO any buffer in the version. Slave(s00-s03) MUST ins-resp.
//                                       @All Rights Reserved. 
//------------------------------------------------------------
module ipbase_intf_axi_arbit4to1robin_simplified #(
    //------------------------------->>arbit config<<------------------------------
    //--------------------------------->>axi config<<------------------------------
    //AXI4 parameter
    parameter AXI_ID_WIDTH      = 4                     ,
    parameter AXI_ADDR_WIDTH    = 32                    ,
    parameter AXI_DATA_WIDTH    = 512                   ,
    parameter AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8      
) (
    input   wire                                        sys_clk             ,
    input   wire                                        sys_rst             ,
    //s00
    input  wire [AXI_ID_WIDTH-1:0]                      s00_axi_awid        ,
    input  wire [AXI_ADDR_WIDTH-1:0]                    s00_axi_awaddr      ,
    input  wire [7:0]                                   s00_axi_awlen       ,
    input  wire [2:0]                                   s00_axi_awsize      ,
    input  wire [1:0]                                   s00_axi_awburst     ,    
    input  wire                                         s00_axi_awlock      ,
    input  wire [3:0]                                   s00_axi_awcache     ,    
    input  wire [2:0]                                   s00_axi_awprot      ,
    input  wire                                         s00_axi_awvalid     ,    
    output wire                                         s00_axi_awready     ,    
    input  wire [AXI_DATA_WIDTH-1:0]                    s00_axi_wdata       ,
    input  wire [AXI_STRB_WIDTH-1:0]                    s00_axi_wstrb       ,
    input  wire                                         s00_axi_wlast       ,
    input  wire                                         s00_axi_wvalid      ,
    output wire                                         s00_axi_wready      ,
    output wire [AXI_ID_WIDTH-1:0]                      s00_axi_bid         ,
    output wire [1:0]                                   s00_axi_bresp       ,
    output wire                                         s00_axi_bvalid      ,
    input  wire                                         s00_axi_bready      ,
    input  wire [AXI_ID_WIDTH-1:0]                      s00_axi_arid        ,
    input  wire [AXI_ADDR_WIDTH-1:0]                    s00_axi_araddr      ,
    input  wire [7:0]                                   s00_axi_arlen       ,
    input  wire [2:0]                                   s00_axi_arsize      ,
    input  wire [1:0]                                   s00_axi_arburst     ,    
    input  wire                                         s00_axi_arlock      ,
    input  wire [3:0]                                   s00_axi_arcache     ,    
    input  wire [2:0]                                   s00_axi_arprot      ,
    input  wire                                         s00_axi_arvalid     ,    
    output wire                                         s00_axi_arready     ,    
    output wire [AXI_ID_WIDTH-1:0]                      s00_axi_rid         ,
    output wire [AXI_DATA_WIDTH-1:0]                    s00_axi_rdata       ,
    output wire [1:0]                                   s00_axi_rresp       ,
    output wire                                         s00_axi_rlast       ,
    output wire                                         s00_axi_rvalid      ,
    input  wire                                         s00_axi_rready      ,
    //s01
    input  wire [AXI_ID_WIDTH-1:0]                      s01_axi_awid        ,
    input  wire [AXI_ADDR_WIDTH-1:0]                    s01_axi_awaddr      ,
    input  wire [7:0]                                   s01_axi_awlen       ,
    input  wire [2:0]                                   s01_axi_awsize      ,
    input  wire [1:0]                                   s01_axi_awburst     ,    
    input  wire                                         s01_axi_awlock      ,
    input  wire [3:0]                                   s01_axi_awcache     ,    
    input  wire [2:0]                                   s01_axi_awprot      ,
    input  wire                                         s01_axi_awvalid     ,    
    output wire                                         s01_axi_awready     ,    
    input  wire [AXI_DATA_WIDTH-1:0]                    s01_axi_wdata       ,
    input  wire [AXI_STRB_WIDTH-1:0]                    s01_axi_wstrb       ,
    input  wire                                         s01_axi_wlast       ,
    input  wire                                         s01_axi_wvalid      ,
    output wire                                         s01_axi_wready      ,
    output wire [AXI_ID_WIDTH-1:0]                      s01_axi_bid         ,
    output wire [1:0]                                   s01_axi_bresp       ,
    output wire                                         s01_axi_bvalid      ,
    input  wire                                         s01_axi_bready      ,
    input  wire [AXI_ID_WIDTH-1:0]                      s01_axi_arid        ,
    input  wire [AXI_ADDR_WIDTH-1:0]                    s01_axi_araddr      ,
    input  wire [7:0]                                   s01_axi_arlen       ,
    input  wire [2:0]                                   s01_axi_arsize      ,
    input  wire [1:0]                                   s01_axi_arburst     ,    
    input  wire                                         s01_axi_arlock      ,
    input  wire [3:0]                                   s01_axi_arcache     ,    
    input  wire [2:0]                                   s01_axi_arprot      ,
    input  wire                                         s01_axi_arvalid     ,    
    output wire                                         s01_axi_arready     ,    
    output wire [AXI_ID_WIDTH-1:0]                      s01_axi_rid         ,
    output wire [AXI_DATA_WIDTH-1:0]                    s01_axi_rdata       ,
    output wire [1:0]                                   s01_axi_rresp       ,
    output wire                                         s01_axi_rlast       ,
    output wire                                         s01_axi_rvalid      ,
    input  wire                                         s01_axi_rready      ,
    //s02
    input  wire [AXI_ID_WIDTH-1:0]                      s02_axi_awid        ,
    input  wire [AXI_ADDR_WIDTH-1:0]                    s02_axi_awaddr      ,
    input  wire [7:0]                                   s02_axi_awlen       ,
    input  wire [2:0]                                   s02_axi_awsize      ,
    input  wire [1:0]                                   s02_axi_awburst     ,    
    input  wire                                         s02_axi_awlock      ,
    input  wire [3:0]                                   s02_axi_awcache     ,    
    input  wire [2:0]                                   s02_axi_awprot      ,
    input  wire                                         s02_axi_awvalid     ,    
    output wire                                         s02_axi_awready     ,    
    input  wire [AXI_DATA_WIDTH-1:0]                    s02_axi_wdata       ,
    input  wire [AXI_STRB_WIDTH-1:0]                    s02_axi_wstrb       ,
    input  wire                                         s02_axi_wlast       ,
    input  wire                                         s02_axi_wvalid      ,
    output wire                                         s02_axi_wready      ,
    output wire [AXI_ID_WIDTH-1:0]                      s02_axi_bid         ,
    output wire [1:0]                                   s02_axi_bresp       ,
    output wire                                         s02_axi_bvalid      ,
    input  wire                                         s02_axi_bready      ,
    input  wire [AXI_ID_WIDTH-1:0]                      s02_axi_arid        ,
    input  wire [AXI_ADDR_WIDTH-1:0]                    s02_axi_araddr      ,
    input  wire [7:0]                                   s02_axi_arlen       ,
    input  wire [2:0]                                   s02_axi_arsize      ,
    input  wire [1:0]                                   s02_axi_arburst     ,    
    input  wire                                         s02_axi_arlock      ,
    input  wire [3:0]                                   s02_axi_arcache     ,    
    input  wire [2:0]                                   s02_axi_arprot      ,
    input  wire                                         s02_axi_arvalid     ,    
    output wire                                         s02_axi_arready     ,    
    output wire [AXI_ID_WIDTH-1:0]                      s02_axi_rid         ,
    output wire [AXI_DATA_WIDTH-1:0]                    s02_axi_rdata       ,
    output wire [1:0]                                   s02_axi_rresp       ,
    output wire                                         s02_axi_rlast       ,
    output wire                                         s02_axi_rvalid      ,
    input  wire                                         s02_axi_rready      ,
    //s03
    input  wire [AXI_ID_WIDTH-1:0]                      s03_axi_awid        ,
    input  wire [AXI_ADDR_WIDTH-1:0]                    s03_axi_awaddr      ,
    input  wire [7:0]                                   s03_axi_awlen       ,
    input  wire [2:0]                                   s03_axi_awsize      ,
    input  wire [1:0]                                   s03_axi_awburst     ,    
    input  wire                                         s03_axi_awlock      ,
    input  wire [3:0]                                   s03_axi_awcache     ,    
    input  wire [2:0]                                   s03_axi_awprot      ,
    input  wire                                         s03_axi_awvalid     ,    
    output wire                                         s03_axi_awready     ,    
    input  wire [AXI_DATA_WIDTH-1:0]                    s03_axi_wdata       ,
    input  wire [AXI_STRB_WIDTH-1:0]                    s03_axi_wstrb       ,
    input  wire                                         s03_axi_wlast       ,
    input  wire                                         s03_axi_wvalid      ,
    output wire                                         s03_axi_wready      ,
    output wire [AXI_ID_WIDTH-1:0]                      s03_axi_bid         ,
    output wire [1:0]                                   s03_axi_bresp       ,
    output wire                                         s03_axi_bvalid      ,
    input  wire                                         s03_axi_bready      ,
    input  wire [AXI_ID_WIDTH-1:0]                      s03_axi_arid        ,
    input  wire [AXI_ADDR_WIDTH-1:0]                    s03_axi_araddr      ,
    input  wire [7:0]                                   s03_axi_arlen       ,
    input  wire [2:0]                                   s03_axi_arsize      ,
    input  wire [1:0]                                   s03_axi_arburst     ,    
    input  wire                                         s03_axi_arlock      ,
    input  wire [3:0]                                   s03_axi_arcache     ,    
    input  wire [2:0]                                   s03_axi_arprot      ,
    input  wire                                         s03_axi_arvalid     ,    
    output wire                                         s03_axi_arready     ,    
    output wire [AXI_ID_WIDTH-1:0]                      s03_axi_rid         ,
    output wire [AXI_DATA_WIDTH-1:0]                    s03_axi_rdata       ,
    output wire [1:0]                                   s03_axi_rresp       ,
    output wire                                         s03_axi_rlast       ,
    output wire                                         s03_axi_rvalid      ,
    input  wire                                         s03_axi_rready      ,
    // axi4 master
    output wire [AXI_ID_WIDTH-1:0]                      m_axi_awid          ,
    output wire [AXI_ADDR_WIDTH-1:0]                    m_axi_awaddr        ,
    output wire [7:0]                                   m_axi_awlen         ,
    output wire [2:0]                                   m_axi_awsize        ,
    output wire [1:0]                                   m_axi_awburst       ,    
    output wire                                         m_axi_awlock        ,
    output wire [3:0]                                   m_axi_awcache       ,    
    output wire [2:0]                                   m_axi_awprot        ,
    output wire                                         m_axi_awvalid       ,    
    input  wire                                         m_axi_awready       ,    
    output wire [AXI_DATA_WIDTH-1:0]                    m_axi_wdata         ,
    output wire [AXI_STRB_WIDTH-1:0]                    m_axi_wstrb         ,
    output wire                                         m_axi_wlast         ,
    output wire                                         m_axi_wvalid        ,
    input  wire                                         m_axi_wready        ,
    input  wire [AXI_ID_WIDTH-1:0]                      m_axi_bid           ,
    input  wire [1:0]                                   m_axi_bresp         ,
    input  wire                                         m_axi_bvalid        ,
    output wire                                         m_axi_bready        ,
    output wire [AXI_ID_WIDTH-1:0]                      m_axi_arid          ,
    output wire [AXI_ADDR_WIDTH-1:0]                    m_axi_araddr        ,
    output wire [7:0]                                   m_axi_arlen         ,
    output wire [2:0]                                   m_axi_arsize        ,
    output wire [1:0]                                   m_axi_arburst       ,    
    output wire                                         m_axi_arlock        ,
    output wire [3:0]                                   m_axi_arcache       ,    
    output wire [2:0]                                   m_axi_arprot        ,
    output wire                                         m_axi_arvalid       ,    
    input  wire                                         m_axi_arready       ,    
    input  wire [AXI_ID_WIDTH-1:0]                      m_axi_rid           ,
    input  wire [AXI_DATA_WIDTH-1:0]                    m_axi_rdata         ,
    input  wire [1:0]                                   m_axi_rresp         ,
    input  wire                                         m_axi_rlast         ,
    input  wire                                         m_axi_rvalid        ,
    output wire                                         m_axi_rready        ,
    // connect to dfx port  
    output wire [31:0]                                  dfx_sta0            ,
    output wire [31:0]                                  dfx_sta1            ,
    output wire [31:0]                                  dfx_sta2            ,
    output wire [31:0]                                  dfx_sta3            
);

    //request 4to1(base on AXI-id)
    wire    [3:0]           rd_chn_vld;
    assign rd_chn_vld = {s03_axi_arvalid,s02_axi_arvalid,s01_axi_arvalid,s00_axi_arvalid};
    wire    [3:0]           wr_chn_vld;
    assign wr_chn_vld = {s03_axi_awvalid,s02_axi_awvalid,s01_axi_awvalid,s00_axi_awvalid};
    wire    [3:0]           wr_dat_vld;
    assign wr_dat_vld = {s03_axi_wvalid,s02_axi_wvalid,s01_axi_wvalid,s00_axi_wvalid};
//------------------------------------------------------------
//read chn
    wire    [3:0]       rdchn_req;
    wire    [3:0]       rdchn_gnt;
    wire    [43:0]      rdchn_pp_id    ;
    wire                rdchn_pp_id_vld;
    wire                rdchn_pp_id_rdy;
    wire    [43:0]      rdchn_pp_od    ;
    wire                rdchn_pp_od_vld;
    wire                rdchn_pp_od_rdy;
    wire    [3:0]       rdchn_id    ;
    wire    [7:0]       rdchn_len   ;
    wire    [31:0]      rdchn_addr  ;
    assign rdchn_req = rdchn_pp_id_rdy ? rd_chn_vld : 4'd0;
    ipbase_arbit_roundrobin_core_simple #(
        .NUM(4)
    )arbiter_rr_axi_rdreq(
        .clk     (sys_clk),
        .rst     (sys_rst),
        .iq      (rdchn_req),
        .og      (rdchn_gnt)
    );
    assign {s03_axi_arready,s02_axi_arready,s01_axi_arready,s00_axi_arready}=rdchn_gnt;
    assign rdchn_id     = 
                rdchn_gnt[0] ? 4'd0 :
                rdchn_gnt[1] ? 4'd1 :
                rdchn_gnt[2] ? 4'd2 :
                rdchn_gnt[3] ? 4'd3 : 4'd0;
    assign rdchn_len    = 
                rdchn_gnt[0] ? s00_axi_arlen :
                rdchn_gnt[1] ? s01_axi_arlen :
                rdchn_gnt[2] ? s02_axi_arlen :
                rdchn_gnt[3] ? s03_axi_arlen : 8'd0;
    assign rdchn_addr   = 
                rdchn_gnt[0] ? s00_axi_araddr :
                rdchn_gnt[1] ? s01_axi_araddr :
                rdchn_gnt[2] ? s02_axi_araddr :
                rdchn_gnt[3] ? s03_axi_araddr : 32'd0;
    assign rdchn_pp_id_vld    =
                |rdchn_gnt;
    assign rdchn_pp_id = {
        rdchn_id    ,
        rdchn_len   ,
        rdchn_addr  
    };
    //read chn pipeline
    ipbase_intf_pipeline_d2#(
        .DATA_WIDTH (4+8+32)
    )pipeline_rdchn(
        .clk     (sys_clk),
        .rst     (sys_rst),
        .id      (rdchn_pp_id    ),
        .id_vld  (rdchn_pp_id_vld),
        .id_rdy  (rdchn_pp_id_rdy),
        .od      (rdchn_pp_od    ),
        .od_vld  (rdchn_pp_od_vld),
        .od_rdy  (rdchn_pp_od_rdy)
    );
    assign { 
        m_axi_arid      ,
        m_axi_arlen     ,
        m_axi_araddr    }=rdchn_pp_od;
    assign m_axi_arsize     = 3'b110;
    assign m_axi_arburst    = 2'b01;
    assign m_axi_arlock     = 0;
    assign m_axi_arcache    = 0;
    assign m_axi_arprot     = 0;
    assign m_axi_arvalid    = rdchn_pp_od_vld;
    assign rdchn_pp_od_rdy  = m_axi_arready;
//------------------------------------------------------------
//write req chn
    wire    [3:0]       wrchn_req;
    wire    [3:0]       wrchn_gnt;
    wire    [43:0]      wrchn_pp_id    ;
    wire                wrchn_pp_id_vld;
    wire                wrchn_pp_id_rdy;
    wire    [43:0]      wrchn_pp_od    ;
    wire                wrchn_pp_od_vld;
    wire                wrchn_pp_od_rdy;
    wire    [3:0]       wrchn_id    ;
    wire    [7:0]       wrchn_len   ;
    wire    [31:0]      wrchn_addr  ;
    assign wrchn_req = wrchn_pp_id_rdy ? wr_chn_vld : 4'd0;
    ipbase_arbit_roundrobin_core_simple #(
        .NUM(4)
    )arbiter_rr_axi_wrreq(
        .clk     (sys_clk),
        .rst     (sys_rst),
        .iq      (wrchn_req),
        .og      (wrchn_gnt)
    );
    assign {s03_axi_awready,s02_axi_awready,s01_axi_awready,s00_axi_awready}=wrchn_gnt;
    assign wrchn_id     = 
                wrchn_gnt[0] ? 4'd0 :
                wrchn_gnt[1] ? 4'd1 :
                wrchn_gnt[2] ? 4'd2 :
                wrchn_gnt[3] ? 4'd3 : 4'd0;
    assign wrchn_len    = 
                wrchn_gnt[0] ? s00_axi_awlen :
                wrchn_gnt[1] ? s01_axi_awlen :
                wrchn_gnt[2] ? s02_axi_awlen :
                wrchn_gnt[3] ? s03_axi_awlen : 8'd0;
    assign wrchn_addr   = 
                wrchn_gnt[0] ? s00_axi_awaddr :
                wrchn_gnt[1] ? s01_axi_awaddr :
                wrchn_gnt[2] ? s02_axi_awaddr :
                wrchn_gnt[3] ? s03_axi_awaddr : 32'd0;
    assign wrchn_pp_id_vld    =
                |wrchn_gnt;
    assign wrchn_pp_id = {
        wrchn_id    ,
        wrchn_len   ,
        wrchn_addr   
    };
    //write chn pipeline
    ipbase_intf_pipeline_d2#(
        .DATA_WIDTH (4+8+32)
    )pipeline_wrchn(
        .clk     (sys_clk),
        .rst     (sys_rst),
        .id      (wrchn_pp_id    ),
        .id_vld  (wrchn_pp_id_vld),
        .id_rdy  (wrchn_pp_id_rdy),
        .od      (wrchn_pp_od    ),
        .od_vld  (wrchn_pp_od_vld),
        .od_rdy  (wrchn_pp_od_rdy)
    );
    assign { 
        m_axi_awid      ,
        m_axi_awlen     ,
        m_axi_awaddr    }=wrchn_pp_od;
    assign m_axi_awsize     = 3'b110;
    assign m_axi_awburst    = 2'b01;
    assign m_axi_awlock     = 0;
    assign m_axi_awcache    = 0;
    assign m_axi_awprot     = 0;
    assign m_axi_awvalid    = wrchn_pp_od_vld;
    assign wrchn_pp_od_rdy  = m_axi_awready;
//------------------------------------------------------------
//write dat chn
    wire    [3:0]       wrdat_req       ;
    wire    [3:0]       wrdat_gnt       ;
    wire    [515:0]     wrdat_pp_id     ;
    wire                wrdat_pp_id_vld ;
    wire                wrdat_pp_id_rdy ;
    wire    [515:0]     wrdat_pp_od     ;
    wire                wrdat_pp_od_vld ;
    wire                wrdat_pp_od_rdy ;
    wire    [3:0]       wrdat_id    ;
    wire    [511:0]     wrdat_data  ;
    assign wrdat_req = wrdat_pp_id_rdy ? wr_dat_vld : 4'd0;
    ipbase_arbit_roundrobin_core_simple #(
        .NUM(4)
    )arbiter_rr_axi_wrdat(
        .clk     (sys_clk),
        .rst     (sys_rst),
        .iq      (wrdat_req),
        .og      (wrdat_gnt)
    );
    assign {s03_axi_wready,s02_axi_wready,s01_axi_wready,s00_axi_wready}=wrdat_gnt;
    assign wrdat_id     = 
                wrdat_gnt[0] ? 4'd0 :
                wrdat_gnt[1] ? 4'd1 :
                wrdat_gnt[2] ? 4'd2 :
                wrdat_gnt[3] ? 4'd3 : 4'd0;
    assign wrdat_data    = 
                wrdat_gnt[0] ? s00_axi_wdata :
                wrdat_gnt[1] ? s01_axi_wdata :
                wrdat_gnt[2] ? s02_axi_wdata :
                wrdat_gnt[3] ? s03_axi_wdata : 512'd0;
    assign wrdat_pp_id_vld    =
                |wrdat_gnt;
    assign wrdat_pp_id = {
        wrdat_id    ,
        wrdat_data   
    };
    //write chn pipeline
    ipbase_intf_pipeline_d2#(
        .DATA_WIDTH (4+512)
    )pipeline_wrdat(
        .clk     (sys_clk),
        .rst     (sys_rst),
        .id      (wrdat_pp_id    ),
        .id_vld  (wrdat_pp_id_vld),
        .id_rdy  (wrdat_pp_id_rdy),
        .od      (wrdat_pp_od    ),
        .od_vld  (wrdat_pp_od_vld),
        .od_rdy  (wrdat_pp_od_rdy)
    );
    assign m_axi_wdata      = wrdat_pp_od;
    assign m_axi_wstrb      = {64{1'b1}};
    assign m_axi_wlast      = 1;
    assign m_axi_wvalid     = wrdat_pp_od_vld;
    assign wrdat_pp_od_rdy  = m_axi_wready;
//------------------------------------------------------------
//resp chn
    //response 1to4(base on AXI-id)
    assign s00_axi_bid         = m_axi_bid    ;
    assign s00_axi_bresp       = m_axi_bresp  ;
    assign s00_axi_bvalid      = m_axi_bvalid ;
    assign s01_axi_bid         = m_axi_bid    ;
    assign s01_axi_bresp       = m_axi_bresp  ;
    assign s01_axi_bvalid      = m_axi_bvalid ;
    assign s02_axi_bid         = m_axi_bid    ;
    assign s02_axi_bresp       = m_axi_bresp  ;
    assign s02_axi_bvalid      = m_axi_bvalid ;
    assign s03_axi_bid         = m_axi_bid    ;
    assign s03_axi_bresp       = m_axi_bresp  ;
    assign s03_axi_bvalid      = m_axi_bvalid ;
    assign m_axi_bready        = 
                m_axi_bid == 4'd0 ? s00_axi_bready : 
                m_axi_bid == 4'd1 ? s01_axi_bready : 
                m_axi_bid == 4'd2 ? s02_axi_bready : 
                m_axi_bid == 4'd3 ? s03_axi_bready : 0;
    assign s00_axi_rid         = m_axi_rid      ;
    assign s00_axi_rdata       = m_axi_rdata    ;
    assign s00_axi_rresp       = m_axi_rresp    ;
    assign s00_axi_rlast       = m_axi_rlast    ;
    assign s00_axi_rvalid      = m_axi_rvalid   ;
    assign s01_axi_rid         = m_axi_rid      ;
    assign s01_axi_rdata       = m_axi_rdata    ;
    assign s01_axi_rresp       = m_axi_rresp    ;
    assign s01_axi_rlast       = m_axi_rlast    ;
    assign s01_axi_rvalid      = m_axi_rvalid   ;
    assign s02_axi_rid         = m_axi_rid      ;
    assign s02_axi_rdata       = m_axi_rdata    ;
    assign s02_axi_rresp       = m_axi_rresp    ;
    assign s02_axi_rlast       = m_axi_rlast    ;
    assign s02_axi_rvalid      = m_axi_rvalid   ;
    assign s03_axi_rid         = m_axi_rid      ;
    assign s03_axi_rdata       = m_axi_rdata    ;
    assign s03_axi_rresp       = m_axi_rresp    ;
    assign s03_axi_rlast       = m_axi_rlast    ;
    assign s03_axi_rvalid      = m_axi_rvalid   ;
    assign m_axi_rready        = 
                m_axi_rid == 4'd0 ? s00_axi_rready : 
                m_axi_rid == 4'd1 ? s01_axi_rready : 
                m_axi_rid == 4'd2 ? s02_axi_rready : 
                m_axi_rid == 4'd3 ? s03_axi_rready : 0;
endmodule