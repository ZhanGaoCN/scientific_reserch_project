//------------------------------------------------------------
// <ipbase_intf_axi_arbit2to1_rd_chn_simplified_v0p1 Module>
// Author: chenfeiyu
// Date. : 2024/05/30
// Func  : Eq-Arbit for axi4-rd interface
//                      >>Instruction<<
// Port[System]---clock and reset
// Port[axi-Master]--axi4 port (*simplified)
// Port[axi-Slave*2]--axi4 port (*simplified)
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
//  *ONLY support the io port with same data width.
//  *NOT support to process dynamic size.
//  *NOT support to process dynamic burst.
//  *NO any buffer in the version. Slave(s00-s01) MUST ins-resp.
//                                       @All Rights Reserved. 
//------------------------------------------------------------
module ipbase_intf_axi_arbit2to1_rd_chn_simplified_v0p1#(
    //------------------------------->>arbit config<<------------------------------
    parameter S00_AXI_ID_SET = 0    ,
    parameter S01_AXI_ID_SET = 1    ,
    //--------------------------------->>axi config<<------------------------------
    //AXI4 parameter
    parameter AXI_ID_WIDTH      = 4                     ,
    parameter AXI_ADDR_WIDTH    = 64                    ,
    parameter AXI_DATA_WIDTH    = 512                   ,
    parameter AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8      
)(
    input   wire                                        sys_clk             ,
    input   wire                                        sys_rst             ,
    //s00(id0)
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
    //s01(id1)
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
    // axi4 master
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
    input  wire [31:0]                                  dfx_cfg0            ,
    output wire [31:0]                                  dfx_sta0            ,
    output wire [31:0]                                  dfx_sta1            ,
    output wire [31:0]                                  dfx_sta2            ,
    output wire [31:0]                                  dfx_sta3            
);
//request 2to1(base on AXI-id)
    wire    [1:0]           rd_chn_vld;
    assign rd_chn_vld = {s01_axi_arvalid,s00_axi_arvalid};
//------------------------------------------------------------
//read chn
    wire    [1:0]       rdchn_req;
    wire    [1:0]       rdchn_gnt;
    wire    [43:0]      rdchn_pp_id    ;
    wire                rdchn_pp_id_vld;
    wire                rdchn_pp_id_rdy;
    wire    [43:0]      rdchn_pp_od    ;
    wire                rdchn_pp_od_vld;
    wire                rdchn_pp_od_rdy;
    wire    [3:0]       rdchn_id    ;
    wire    [7:0]       rdchn_len   ;
    wire    [31:0]      rdchn_addr  ;
    reg     [1:0]       r0_rdchn_gnt;
    always@(posedge sys_clk)
    if(sys_rst)
        r0_rdchn_gnt <= 2'd0;
    else    
        r0_rdchn_gnt <= rdchn_gnt;

    assign rdchn_req = rdchn_pp_id_rdy ? rd_chn_vld : 2'd0;

    assign rdchn_gnt = 
                r0_rdchn_gnt[0] ?
                    rdchn_req[1] ? 2'b10 :
                    rdchn_req[0] ? 2'b01 : 
                    2'b00 :
                r0_rdchn_gnt[1] ?
                    rdchn_req[0] ? 2'b01 :
                    rdchn_req[1] ? 2'b10 : 
                    2'b00 :
                rdchn_req[0] ? 2'b01 :
                rdchn_req[1] ? 2'b10 : 
                2'b00 ;
    assign {s01_axi_arready,s00_axi_arready}=rdchn_gnt;
    assign rdchn_id     = 
                rdchn_gnt[0] ? s00_axi_arid :
                rdchn_gnt[1] ? s01_axi_arid : 4'd0;
    assign rdchn_len    = 
                rdchn_gnt[0] ? s00_axi_arlen :
                rdchn_gnt[1] ? s01_axi_arlen : 8'd0;
    assign rdchn_addr   = 
                rdchn_gnt[0] ? s00_axi_araddr :
                rdchn_gnt[1] ? s01_axi_araddr :  32'd0;
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
//resp chn
    //response 1to2(base on AXI-id)
    assign s00_axi_rid         = m_axi_rid      ;
    assign s00_axi_rdata       = m_axi_rdata    ;
    assign s00_axi_rresp       = m_axi_rresp    ;
    assign s00_axi_rlast       = m_axi_rlast    ;
    assign s00_axi_rvalid      = m_axi_rid == S00_AXI_ID_SET ? m_axi_rvalid : 0;

    assign s01_axi_rid         = m_axi_rid      ;
    assign s01_axi_rdata       = m_axi_rdata    ;
    assign s01_axi_rresp       = m_axi_rresp    ;
    assign s01_axi_rlast       = m_axi_rlast    ;
    assign s01_axi_rvalid      = m_axi_rid == S01_AXI_ID_SET ? m_axi_rvalid : 0;
    assign m_axi_rready        = 
                m_axi_rid == S00_AXI_ID_SET ? s00_axi_rready : 
                m_axi_rid == S01_AXI_ID_SET ? s01_axi_rready : 0;

//----------------------------------------------------------------------------------
//
//\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
//  <DFX Status>
//----------------------------------------------------------------------------------
    wire                    dfx_sta_clear;
    assign dfx_sta_clear = dfx_cfg0[0];
    //------------------------------------------------------------------------------
    // axi sta counter
        //master
        wire    [7:0]           c_m_axi_rd_addr_counter   ;
        wire    [7:0]           c_m_axi_rd_data_counter   ;
        wire    [1:0]           c_m_axi_rd_addr_sta       ;
        wire    [1:0]           c_m_axi_rd_data_sta       ;
        reg     [7:0]           r_m_axi_rd_addr_counter   =8'd0;
        reg     [7:0]           r_m_axi_rd_data_counter   =8'd0;
        reg     [1:0]           r_m_axi_rd_addr_sta       =2'd0;
        reg     [1:0]           r_m_axi_rd_data_sta       =2'd0;
        assign c_m_axi_rd_addr_counter = dfx_sta_clear ? 16'd0 : m_axi_arvalid & m_axi_arready ? r_m_axi_rd_addr_counter + 8'd1 : r_m_axi_rd_addr_counter;
        assign c_m_axi_rd_data_counter = dfx_sta_clear ? 16'd0 : m_axi_rvalid & m_axi_rready & m_axi_rlast ? r_m_axi_rd_data_counter + 8'd1 : r_m_axi_rd_data_counter;
        assign c_m_axi_rd_addr_sta = {m_axi_arvalid,m_axi_arready};
        assign c_m_axi_rd_data_sta = {m_axi_rvalid ,m_axi_rready };
        always@(posedge sys_clk)
        if(sys_rst)
            begin
                r_m_axi_rd_addr_counter   <=8'd0;
                r_m_axi_rd_data_counter   <=8'd0;
                r_m_axi_rd_addr_sta       <=2'd0;
                r_m_axi_rd_data_sta       <=2'd0;
            end
        else
            begin
                r_m_axi_rd_addr_counter   <=c_m_axi_rd_addr_counter   ;
                r_m_axi_rd_data_counter   <=c_m_axi_rd_data_counter   ;
                r_m_axi_rd_addr_sta       <=c_m_axi_rd_addr_sta       ;
                r_m_axi_rd_data_sta       <=c_m_axi_rd_data_sta       ;
            end
        //slave 00 
        wire    [7:0]           c_s_axi00_rd_addr_counter   ;
        wire    [7:0]           c_s_axi00_rd_data_counter   ;
        wire    [1:0]           c_s_axi00_rd_addr_sta       ;
        wire    [1:0]           c_s_axi00_rd_data_sta       ;
        reg     [7:0]           r_s_axi00_rd_addr_counter   =8'd0;
        reg     [7:0]           r_s_axi00_rd_data_counter   =8'd0;
        reg     [1:0]           r_s_axi00_rd_addr_sta       =2'd0;
        reg     [1:0]           r_s_axi00_rd_data_sta       =2'd0;
        assign c_s_axi00_rd_addr_counter = dfx_sta_clear ? 16'd0 : s00_axi_arvalid & s00_axi_arready ? r_s_axi00_rd_addr_counter + 8'd1 : r_s_axi00_rd_addr_counter;
        assign c_s_axi00_rd_data_counter = dfx_sta_clear ? 16'd0 : s00_axi_rvalid & s00_axi_rready & s00_axi_rlast ? r_s_axi00_rd_data_counter + 8'd1 : r_s_axi00_rd_data_counter;
        assign c_s_axi00_rd_addr_sta = {s00_axi_arvalid,s00_axi_arready};
        assign c_s_axi00_rd_data_sta = {s00_axi_rvalid ,s00_axi_rready };
        always@(posedge sys_clk)
        if(sys_rst)
            begin
                r_s_axi00_rd_addr_counter   <=8'd0;
                r_s_axi00_rd_data_counter   <=8'd0;
                r_s_axi00_rd_addr_sta       <=2'd0;
                r_s_axi00_rd_data_sta       <=2'd0;
            end
        else
            begin
                r_s_axi00_rd_addr_counter   <=c_s_axi00_rd_addr_counter   ;
                r_s_axi00_rd_data_counter   <=c_s_axi00_rd_data_counter   ;
                r_s_axi00_rd_addr_sta       <=c_s_axi00_rd_addr_sta       ;
                r_s_axi00_rd_data_sta       <=c_s_axi00_rd_data_sta       ;
            end
        //slave 01
        wire    [7:0]           c_s_axi01_rd_addr_counter   ;
        wire    [7:0]           c_s_axi01_rd_data_counter   ;
        wire    [1:0]           c_s_axi01_rd_addr_sta       ;
        wire    [1:0]           c_s_axi01_rd_data_sta       ;
        reg     [7:0]           r_s_axi01_rd_addr_counter   =8'd0;
        reg     [7:0]           r_s_axi01_rd_data_counter   =8'd0;
        reg     [1:0]           r_s_axi01_rd_addr_sta       =2'd0;
        reg     [1:0]           r_s_axi01_rd_data_sta       =2'd0;
        assign c_s_axi01_rd_addr_counter = dfx_sta_clear ? 16'd0 : s01_axi_arvalid & s01_axi_arready ? r_s_axi01_rd_addr_counter + 8'd1 : r_s_axi01_rd_addr_counter;
        assign c_s_axi01_rd_data_counter = dfx_sta_clear ? 16'd0 : s01_axi_rvalid & s01_axi_rready & s01_axi_rlast ? r_s_axi01_rd_data_counter + 8'd1 : r_s_axi01_rd_data_counter;
        assign c_s_axi01_rd_addr_sta = {s01_axi_arvalid,s01_axi_arready};
        assign c_s_axi01_rd_data_sta = {s01_axi_rvalid ,s01_axi_rready };
        always@(posedge sys_clk)
        if(sys_rst)
            begin
                r_s_axi01_rd_addr_counter   <=8'd0;
                r_s_axi01_rd_data_counter   <=8'd0;
                r_s_axi01_rd_addr_sta       <=2'd0;
                r_s_axi01_rd_data_sta       <=2'd0;
            end
        else
            begin
                r_s_axi01_rd_addr_counter   <=c_s_axi01_rd_addr_counter   ;
                r_s_axi01_rd_data_counter   <=c_s_axi01_rd_data_counter   ;
                r_s_axi01_rd_addr_sta       <=c_s_axi01_rd_addr_sta       ;
                r_s_axi01_rd_data_sta       <=c_s_axi01_rd_data_sta       ;
            end
    //------------------------------------------------------------------------------
    // CON
        assign dfx_sta0 = {
            r_s_axi00_rd_addr_sta       ,
            r_s_axi00_rd_data_sta       ,
            r_s_axi01_rd_addr_sta       ,
            r_s_axi01_rd_data_sta       ,
            r_m_axi_rd_addr_sta         ,
            r_m_axi_rd_data_sta         ,
            r_m_axi_rd_addr_counter     ,
            r_m_axi_rd_data_counter      
        };
        assign dfx_sta1 = {
            r_s_axi00_rd_addr_counter   ,
            r_s_axi00_rd_data_counter   ,
            r_s_axi01_rd_addr_counter   ,
            r_s_axi01_rd_data_counter   
        };
endmodule

