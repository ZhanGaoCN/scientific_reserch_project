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
module seanetnackgenerator_ddr_bmpcmd_arbit_m #(
    //------------------------------->>arbit config<<------------------------------
    //--------------------------------->>axi config<<------------------------------
    //AXI4 parameter
    parameter AXI_ID_WIDTH      = 4                     ,
    parameter AXI_ADDR_WIDTH    = 32                    ,
    parameter AXI_DATA_WIDTH    = 512                   ,
    parameter AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8                    
) (
    input   wire                                        sys_clk         ,
    input   wire                                        sys_rst         ,
    // cmd input
    input   wire    [31:0]                              ddr_cmd_addr    ,
    input   wire    [511:0]                             ddr_cmd_data    ,
    input   wire    [1:0]                               ddr_cmd_type    ,//11 -> cover mode / 01 -> high mode / 00 -> low mode
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
wire    [31:0]                      c_ddr_cmd_addr      [3:0];
wire    [511:0]                     c_ddr_cmd_data      [3:0];
wire    [1:0]                       c_ddr_cmd_type      [3:0];
wire    [7:0]                       c_ddr_cmd_len       [3:0];
wire                                c_ddr_cmd_valid     [3:0];
wire                                c_ddr_cmd_ready     [3:0];




wire    [AXI_ID_WIDTH-1:0]          c_m_axi_awid        [3:0];
wire    [AXI_ADDR_WIDTH-1:0]        c_m_axi_awaddr      [3:0];
wire    [7:0]                       c_m_axi_awlen       [3:0];
wire    [2:0]                       c_m_axi_awsize      [3:0];
wire    [1:0]                       c_m_axi_awburst     [3:0];
wire                                c_m_axi_awlock      [3:0];
wire    [3:0]                       c_m_axi_awcache     [3:0];
wire    [2:0]                       c_m_axi_awprot      [3:0];
wire                                c_m_axi_awvalid     [3:0];
wire                                c_m_axi_awready     [3:0];
wire    [AXI_DATA_WIDTH-1:0]        c_m_axi_wdata       [3:0];
wire    [AXI_STRB_WIDTH-1:0]        c_m_axi_wstrb       [3:0];
wire                                c_m_axi_wlast       [3:0];
wire                                c_m_axi_wvalid      [3:0];
wire                                c_m_axi_wready      [3:0];
wire    [AXI_ID_WIDTH-1:0]          c_m_axi_bid         [3:0];
wire    [1:0]                       c_m_axi_bresp       [3:0];
wire                                c_m_axi_bvalid      [3:0];
wire                                c_m_axi_bready      [3:0];
wire    [AXI_ID_WIDTH-1:0]          c_m_axi_arid        [3:0];
wire    [AXI_ADDR_WIDTH-1:0]        c_m_axi_araddr      [3:0];
wire    [7:0]                       c_m_axi_arlen       [3:0];
wire    [2:0]                       c_m_axi_arsize      [3:0];
wire    [1:0]                       c_m_axi_arburst     [3:0];
wire                                c_m_axi_arlock      [3:0];
wire    [3:0]                       c_m_axi_arcache     [3:0];
wire    [2:0]                       c_m_axi_arprot      [3:0];
wire                                c_m_axi_arvalid     [3:0];
wire                                c_m_axi_arready     [3:0];
wire    [AXI_ID_WIDTH-1:0]          c_m_axi_rid         [3:0];
wire    [AXI_DATA_WIDTH-1:0]        c_m_axi_rdata       [3:0];
wire    [1:0]                       c_m_axi_rresp       [3:0];
wire                                c_m_axi_rlast       [3:0];
wire                                c_m_axi_rvalid      [3:0];
wire                                c_m_axi_rready      [3:0];
//localparam [1:0]    GEN_CONST[3:0] = {2'd3,2'd2,2'd1,2'd0};
//assign ddr_cmd_ready         = 
//            {ddr_cmd_addr[15],ddr_cmd_addr[6]} == GEN_CONST[0] ? c_ddr_cmd_ready[0] :
//            {ddr_cmd_addr[15],ddr_cmd_addr[6]} == GEN_CONST[1] ? c_ddr_cmd_ready[1] :
//            {ddr_cmd_addr[15],ddr_cmd_addr[6]} == GEN_CONST[2] ? c_ddr_cmd_ready[2] :
//            {ddr_cmd_addr[15],ddr_cmd_addr[6]} == GEN_CONST[3] ? c_ddr_cmd_ready[3] : 0;

assign ddr_cmd_ready         = 
            {ddr_cmd_addr[15],ddr_cmd_addr[6]} == 2'd0 ? c_ddr_cmd_ready[0] :
            {ddr_cmd_addr[15],ddr_cmd_addr[6]} == 2'd1 ? c_ddr_cmd_ready[1] :
            {ddr_cmd_addr[15],ddr_cmd_addr[6]} == 2'd2 ? c_ddr_cmd_ready[2] :
            {ddr_cmd_addr[15],ddr_cmd_addr[6]} == 2'd3 ? c_ddr_cmd_ready[3] : 0;
genvar i;
generate
    for(i=0;i<4;i=i+1)
    begin:seanetnackgenerator_ddr_bmpcmd_arbit_mc_inst
    assign c_ddr_cmd_addr    [i] = ddr_cmd_addr    ;
    assign c_ddr_cmd_data    [i] = ddr_cmd_data    ;
    assign c_ddr_cmd_type    [i] = ddr_cmd_type    ;
    assign c_ddr_cmd_len     [i] = ddr_cmd_len     ;
    //assign c_ddr_cmd_valid   [i] = {ddr_cmd_addr[15],ddr_cmd_addr[6]} == GEN_CONST[i] ? ddr_cmd_valid : 0;
    assign c_ddr_cmd_valid   [i] = {ddr_cmd_addr[15],ddr_cmd_addr[6]} == i ? ddr_cmd_valid : 0;
    
    seanetnackgenerator_ddr_bmpcmd_arbit_mc #(
        //------------------------------->>arbit config<<------------------------------
        //--------------------------------->>axi config<<------------------------------
        //AXI4 parameter
        .AXI_ID_WIDTH     (AXI_ID_WIDTH      ),
        .AXI_ADDR_WIDTH   (AXI_ADDR_WIDTH    ),
        .AXI_DATA_WIDTH   (AXI_DATA_WIDTH    ),
        .AXI_STRB_WIDTH   (AXI_STRB_WIDTH    ),
        .AXI_ID_SET       (i                 )
    )seanetnackgenerator_ddr_bmpcmd_arbit_mc_inst(
        .sys_clk         (sys_clk               ),//input   wire                                        
        .sys_rst         (sys_rst               ),//input   wire                                        
        // cmd input
        .ddr_cmd_addr    (c_ddr_cmd_addr    [i]),//input   wire    [31:0]                              
        .ddr_cmd_data    (c_ddr_cmd_data    [i]),//input   wire    [511:0]                             
        .ddr_cmd_type    (c_ddr_cmd_type    [i]),//input   wire    [1:0]                               //01 -> high mode / 00 -> low mode
        .ddr_cmd_len     (c_ddr_cmd_len     [i]),//input   wire    [7:0]                               //fixed to 0
        .ddr_cmd_valid   (c_ddr_cmd_valid   [i]),//input   wire                                        
        .ddr_cmd_ready   (c_ddr_cmd_ready   [i]),//output  wire                                        
        // axi4 
        .m_axi_awid      (c_m_axi_awid        [i]),//output wire [AXI_ID_WIDTH-1:0]                      
        .m_axi_awaddr    (c_m_axi_awaddr      [i]),//output wire [AXI_ADDR_WIDTH-1:0]                    
        .m_axi_awlen     (c_m_axi_awlen       [i]),//output wire [7:0]                                   
        .m_axi_awsize    (c_m_axi_awsize      [i]),//output wire [2:0]                                   
        .m_axi_awburst   (c_m_axi_awburst     [i]),//output wire [1:0]                                       
        .m_axi_awlock    (c_m_axi_awlock      [i]),//output wire                                         
        .m_axi_awcache   (c_m_axi_awcache     [i]),//output wire [3:0]                                       
        .m_axi_awprot    (c_m_axi_awprot      [i]),//output wire [2:0]                                   
        .m_axi_awvalid   (c_m_axi_awvalid     [i]),//output wire                                             
        .m_axi_awready   (c_m_axi_awready     [i]),//input  wire                                             
        .m_axi_wdata     (c_m_axi_wdata       [i]),//output wire [AXI_DATA_WIDTH-1:0]                    
        .m_axi_wstrb     (c_m_axi_wstrb       [i]),//output wire [AXI_STRB_WIDTH-1:0]                    
        .m_axi_wlast     (c_m_axi_wlast       [i]),//output wire                                         
        .m_axi_wvalid    (c_m_axi_wvalid      [i]),//output wire                                         
        .m_axi_wready    (c_m_axi_wready      [i]),//input  wire                                         
        .m_axi_bid       (c_m_axi_bid         [i]),//input  wire [AXI_ID_WIDTH-1:0]                      
        .m_axi_bresp     (c_m_axi_bresp       [i]),//input  wire [1:0]                                   
        .m_axi_bvalid    (c_m_axi_bvalid      [i]),//input  wire                                         
        .m_axi_bready    (c_m_axi_bready      [i]),//output wire                                         
        .m_axi_arid      (c_m_axi_arid        [i]),//output wire [AXI_ID_WIDTH-1:0]                      
        .m_axi_araddr    (c_m_axi_araddr      [i]),//output wire [AXI_ADDR_WIDTH-1:0]                    
        .m_axi_arlen     (c_m_axi_arlen       [i]),//output wire [7:0]                                   
        .m_axi_arsize    (c_m_axi_arsize      [i]),//output wire [2:0]                                   
        .m_axi_arburst   (c_m_axi_arburst     [i]),//output wire [1:0]                                       
        .m_axi_arlock    (c_m_axi_arlock      [i]),//output wire                                         
        .m_axi_arcache   (c_m_axi_arcache     [i]),//output wire [3:0]                                       
        .m_axi_arprot    (c_m_axi_arprot      [i]),//output wire [2:0]                                   
        .m_axi_arvalid   (c_m_axi_arvalid     [i]),//output wire                                             
        .m_axi_arready   (c_m_axi_arready     [i]),//input  wire                                             
        .m_axi_rid       (c_m_axi_rid         [i]),//input  wire [AXI_ID_WIDTH-1:0]                      
        .m_axi_rdata     (c_m_axi_rdata       [i]),//input  wire [AXI_DATA_WIDTH-1:0]                    
        .m_axi_rresp     (c_m_axi_rresp       [i]),//input  wire [1:0]                                   
        .m_axi_rlast     (c_m_axi_rlast       [i]),//input  wire                                         
        .m_axi_rvalid    (c_m_axi_rvalid      [i]),//input  wire                                         
        .m_axi_rready    (c_m_axi_rready      [i]),//output wire                                         
        // connect to dfx port
        .dfx_sta0        (),//output wire [31:0]                                  
        .dfx_sta1        (),//output wire [31:0]                                  
        .dfx_sta2        (),//output wire [31:0]                                  
        .dfx_sta3        () //output wire [31:0]                                  
    );
    end
endgenerate


ipbase_intf_axi_arbit4to1robin_simplified #(
    //------------------------------->>arbit config<<------------------------------
    //--------------------------------->>axi config<<------------------------------
    //AXI4 parameter
        .AXI_ID_WIDTH     (AXI_ID_WIDTH      ),
        .AXI_ADDR_WIDTH   (AXI_ADDR_WIDTH    ),
        .AXI_DATA_WIDTH   (AXI_DATA_WIDTH    ),
        .AXI_STRB_WIDTH   (AXI_STRB_WIDTH    ) 
)ipbase_intf_axi_arbit4to1robin_simplified_dut(
    .sys_clk             (sys_clk),//input   wire                                        
    .sys_rst             (sys_rst),//input   wire                                        
    //s00
    .s00_axi_awid        (c_m_axi_awid        [0]),//input  wire [AXI_ID_WIDTH-1:0]                      
    .s00_axi_awaddr      (c_m_axi_awaddr      [0]),//input  wire [AXI_ADDR_WIDTH-1:0]                    
    .s00_axi_awlen       (c_m_axi_awlen       [0]),//input  wire [7:0]                                   
    .s00_axi_awsize      (c_m_axi_awsize      [0]),//input  wire [2:0]                                   
    .s00_axi_awburst     (c_m_axi_awburst     [0]),//input  wire [1:0]                                       
    .s00_axi_awlock      (c_m_axi_awlock      [0]),//input  wire                                         
    .s00_axi_awcache     (c_m_axi_awcache     [0]),//input  wire [3:0]                                       
    .s00_axi_awprot      (c_m_axi_awprot      [0]),//input  wire [2:0]                                   
    .s00_axi_awvalid     (c_m_axi_awvalid     [0]),//input  wire                                             
    .s00_axi_awready     (c_m_axi_awready     [0]),//output wire                                             
    .s00_axi_wdata       (c_m_axi_wdata       [0]),//input  wire [AXI_DATA_WIDTH-1:0]                    
    .s00_axi_wstrb       (c_m_axi_wstrb       [0]),//input  wire [AXI_STRB_WIDTH-1:0]                    
    .s00_axi_wlast       (c_m_axi_wlast       [0]),//input  wire                                         
    .s00_axi_wvalid      (c_m_axi_wvalid      [0]),//input  wire                                         
    .s00_axi_wready      (c_m_axi_wready      [0]),//output wire                                         
    .s00_axi_bid         (c_m_axi_bid         [0]),//output wire [AXI_ID_WIDTH-1:0]                      
    .s00_axi_bresp       (c_m_axi_bresp       [0]),//output wire [1:0]                                   
    .s00_axi_bvalid      (c_m_axi_bvalid      [0]),//output wire                                         
    .s00_axi_bready      (c_m_axi_bready      [0]),//input  wire                                         
    .s00_axi_arid        (c_m_axi_arid        [0]),//input  wire [AXI_ID_WIDTH-1:0]                      
    .s00_axi_araddr      (c_m_axi_araddr      [0]),//input  wire [AXI_ADDR_WIDTH-1:0]                    
    .s00_axi_arlen       (c_m_axi_arlen       [0]),//input  wire [7:0]                                   
    .s00_axi_arsize      (c_m_axi_arsize      [0]),//input  wire [2:0]                                   
    .s00_axi_arburst     (c_m_axi_arburst     [0]),//input  wire [1:0]                                       
    .s00_axi_arlock      (c_m_axi_arlock      [0]),//input  wire                                         
    .s00_axi_arcache     (c_m_axi_arcache     [0]),//input  wire [3:0]                                       
    .s00_axi_arprot      (c_m_axi_arprot      [0]),//input  wire [2:0]                                   
    .s00_axi_arvalid     (c_m_axi_arvalid     [0]),//input  wire                                             
    .s00_axi_arready     (c_m_axi_arready     [0]),//output wire                                             
    .s00_axi_rid         (c_m_axi_rid         [0]),//output wire [AXI_ID_WIDTH-1:0]                      
    .s00_axi_rdata       (c_m_axi_rdata       [0]),//output wire [AXI_DATA_WIDTH-1:0]                    
    .s00_axi_rresp       (c_m_axi_rresp       [0]),//output wire [1:0]                                   
    .s00_axi_rlast       (c_m_axi_rlast       [0]),//output wire                                         
    .s00_axi_rvalid      (c_m_axi_rvalid      [0]),//output wire                                         
    .s00_axi_rready      (c_m_axi_rready      [0]),//input  wire                                         
    //s01
    .s01_axi_awid        (c_m_axi_awid        [1]),//input  wire [AXI_ID_WIDTH-1:0]                      
    .s01_axi_awaddr      (c_m_axi_awaddr      [1]),//input  wire [AXI_ADDR_WIDTH-1:0]                    
    .s01_axi_awlen       (c_m_axi_awlen       [1]),//input  wire [7:0]                                   
    .s01_axi_awsize      (c_m_axi_awsize      [1]),//input  wire [2:0]                                   
    .s01_axi_awburst     (c_m_axi_awburst     [1]),//input  wire [1:0]                                       
    .s01_axi_awlock      (c_m_axi_awlock      [1]),//input  wire                                         
    .s01_axi_awcache     (c_m_axi_awcache     [1]),//input  wire [3:0]                                       
    .s01_axi_awprot      (c_m_axi_awprot      [1]),//input  wire [2:0]                                   
    .s01_axi_awvalid     (c_m_axi_awvalid     [1]),//input  wire                                             
    .s01_axi_awready     (c_m_axi_awready     [1]),//output wire                                             
    .s01_axi_wdata       (c_m_axi_wdata       [1]),//input  wire [AXI_DATA_WIDTH-1:0]                    
    .s01_axi_wstrb       (c_m_axi_wstrb       [1]),//input  wire [AXI_STRB_WIDTH-1:0]                    
    .s01_axi_wlast       (c_m_axi_wlast       [1]),//input  wire                                         
    .s01_axi_wvalid      (c_m_axi_wvalid      [1]),//input  wire                                         
    .s01_axi_wready      (c_m_axi_wready      [1]),//output wire                                         
    .s01_axi_bid         (c_m_axi_bid         [1]),//output wire [AXI_ID_WIDTH-1:0]                      
    .s01_axi_bresp       (c_m_axi_bresp       [1]),//output wire [1:0]                                   
    .s01_axi_bvalid      (c_m_axi_bvalid      [1]),//output wire                                         
    .s01_axi_bready      (c_m_axi_bready      [1]),//input  wire                                         
    .s01_axi_arid        (c_m_axi_arid        [1]),//input  wire [AXI_ID_WIDTH-1:0]                      
    .s01_axi_araddr      (c_m_axi_araddr      [1]),//input  wire [AXI_ADDR_WIDTH-1:0]                    
    .s01_axi_arlen       (c_m_axi_arlen       [1]),//input  wire [7:0]                                   
    .s01_axi_arsize      (c_m_axi_arsize      [1]),//input  wire [2:0]                                   
    .s01_axi_arburst     (c_m_axi_arburst     [1]),//input  wire [1:0]                                       
    .s01_axi_arlock      (c_m_axi_arlock      [1]),//input  wire                                         
    .s01_axi_arcache     (c_m_axi_arcache     [1]),//input  wire [3:0]                                       
    .s01_axi_arprot      (c_m_axi_arprot      [1]),//input  wire [2:0]                                   
    .s01_axi_arvalid     (c_m_axi_arvalid     [1]),//input  wire                                             
    .s01_axi_arready     (c_m_axi_arready     [1]),//output wire                                             
    .s01_axi_rid         (c_m_axi_rid         [1]),//output wire [AXI_ID_WIDTH-1:0]                      
    .s01_axi_rdata       (c_m_axi_rdata       [1]),//output wire [AXI_DATA_WIDTH-1:0]                    
    .s01_axi_rresp       (c_m_axi_rresp       [1]),//output wire [1:0]                                   
    .s01_axi_rlast       (c_m_axi_rlast       [1]),//output wire                                         
    .s01_axi_rvalid      (c_m_axi_rvalid      [1]),//output wire                                         
    .s01_axi_rready      (c_m_axi_rready      [1]),//input  wire                                         
    //s02
    .s02_axi_awid        (c_m_axi_awid        [2]),//input  wire [AXI_ID_WIDTH-1:0]                      
    .s02_axi_awaddr      (c_m_axi_awaddr      [2]),//input  wire [AXI_ADDR_WIDTH-1:0]                    
    .s02_axi_awlen       (c_m_axi_awlen       [2]),//input  wire [7:0]                                   
    .s02_axi_awsize      (c_m_axi_awsize      [2]),//input  wire [2:0]                                   
    .s02_axi_awburst     (c_m_axi_awburst     [2]),//input  wire [1:0]                                       
    .s02_axi_awlock      (c_m_axi_awlock      [2]),//input  wire                                         
    .s02_axi_awcache     (c_m_axi_awcache     [2]),//input  wire [3:0]                                       
    .s02_axi_awprot      (c_m_axi_awprot      [2]),//input  wire [2:0]                                   
    .s02_axi_awvalid     (c_m_axi_awvalid     [2]),//input  wire                                             
    .s02_axi_awready     (c_m_axi_awready     [2]),//output wire                                             
    .s02_axi_wdata       (c_m_axi_wdata       [2]),//input  wire [AXI_DATA_WIDTH-1:0]                    
    .s02_axi_wstrb       (c_m_axi_wstrb       [2]),//input  wire [AXI_STRB_WIDTH-1:0]                    
    .s02_axi_wlast       (c_m_axi_wlast       [2]),//input  wire                                         
    .s02_axi_wvalid      (c_m_axi_wvalid      [2]),//input  wire                                         
    .s02_axi_wready      (c_m_axi_wready      [2]),//output wire                                         
    .s02_axi_bid         (c_m_axi_bid         [2]),//output wire [AXI_ID_WIDTH-1:0]                      
    .s02_axi_bresp       (c_m_axi_bresp       [2]),//output wire [1:0]                                   
    .s02_axi_bvalid      (c_m_axi_bvalid      [2]),//output wire                                         
    .s02_axi_bready      (c_m_axi_bready      [2]),//input  wire                                         
    .s02_axi_arid        (c_m_axi_arid        [2]),//input  wire [AXI_ID_WIDTH-1:0]                      
    .s02_axi_araddr      (c_m_axi_araddr      [2]),//input  wire [AXI_ADDR_WIDTH-1:0]                    
    .s02_axi_arlen       (c_m_axi_arlen       [2]),//input  wire [7:0]                                   
    .s02_axi_arsize      (c_m_axi_arsize      [2]),//input  wire [2:0]                                   
    .s02_axi_arburst     (c_m_axi_arburst     [2]),//input  wire [1:0]                                       
    .s02_axi_arlock      (c_m_axi_arlock      [2]),//input  wire                                         
    .s02_axi_arcache     (c_m_axi_arcache     [2]),//input  wire [3:0]                                       
    .s02_axi_arprot      (c_m_axi_arprot      [2]),//input  wire [2:0]                                   
    .s02_axi_arvalid     (c_m_axi_arvalid     [2]),//input  wire                                             
    .s02_axi_arready     (c_m_axi_arready     [2]),//output wire                                             
    .s02_axi_rid         (c_m_axi_rid         [2]),//output wire [AXI_ID_WIDTH-1:0]                      
    .s02_axi_rdata       (c_m_axi_rdata       [2]),//output wire [AXI_DATA_WIDTH-1:0]                    
    .s02_axi_rresp       (c_m_axi_rresp       [2]),//output wire [1:0]                                   
    .s02_axi_rlast       (c_m_axi_rlast       [2]),//output wire                                         
    .s02_axi_rvalid      (c_m_axi_rvalid      [2]),//output wire                                         
    .s02_axi_rready      (c_m_axi_rready      [2]),//input  wire                                         
    //s03
    .s03_axi_awid        (c_m_axi_awid        [3]),//input  wire [AXI_ID_WIDTH-1:0]                      
    .s03_axi_awaddr      (c_m_axi_awaddr      [3]),//input  wire [AXI_ADDR_WIDTH-1:0]                    
    .s03_axi_awlen       (c_m_axi_awlen       [3]),//input  wire [7:0]                                   
    .s03_axi_awsize      (c_m_axi_awsize      [3]),//input  wire [2:0]                                   
    .s03_axi_awburst     (c_m_axi_awburst     [3]),//input  wire [1:0]                                       
    .s03_axi_awlock      (c_m_axi_awlock      [3]),//input  wire                                         
    .s03_axi_awcache     (c_m_axi_awcache     [3]),//input  wire [3:0]                                       
    .s03_axi_awprot      (c_m_axi_awprot      [3]),//input  wire [2:0]                                   
    .s03_axi_awvalid     (c_m_axi_awvalid     [3]),//input  wire                                             
    .s03_axi_awready     (c_m_axi_awready     [3]),//output wire                                             
    .s03_axi_wdata       (c_m_axi_wdata       [3]),//input  wire [AXI_DATA_WIDTH-1:0]                    
    .s03_axi_wstrb       (c_m_axi_wstrb       [3]),//input  wire [AXI_STRB_WIDTH-1:0]                    
    .s03_axi_wlast       (c_m_axi_wlast       [3]),//input  wire                                         
    .s03_axi_wvalid      (c_m_axi_wvalid      [3]),//input  wire                                         
    .s03_axi_wready      (c_m_axi_wready      [3]),//output wire                                         
    .s03_axi_bid         (c_m_axi_bid         [3]),//output wire [AXI_ID_WIDTH-1:0]                      
    .s03_axi_bresp       (c_m_axi_bresp       [3]),//output wire [1:0]                                   
    .s03_axi_bvalid      (c_m_axi_bvalid      [3]),//output wire                                         
    .s03_axi_bready      (c_m_axi_bready      [3]),//input  wire                                         
    .s03_axi_arid        (c_m_axi_arid        [3]),//input  wire [AXI_ID_WIDTH-1:0]                      
    .s03_axi_araddr      (c_m_axi_araddr      [3]),//input  wire [AXI_ADDR_WIDTH-1:0]                    
    .s03_axi_arlen       (c_m_axi_arlen       [3]),//input  wire [7:0]                                   
    .s03_axi_arsize      (c_m_axi_arsize      [3]),//input  wire [2:0]                                   
    .s03_axi_arburst     (c_m_axi_arburst     [3]),//input  wire [1:0]                                       
    .s03_axi_arlock      (c_m_axi_arlock      [3]),//input  wire                                         
    .s03_axi_arcache     (c_m_axi_arcache     [3]),//input  wire [3:0]                                       
    .s03_axi_arprot      (c_m_axi_arprot      [3]),//input  wire [2:0]                                   
    .s03_axi_arvalid     (c_m_axi_arvalid     [3]),//input  wire                                             
    .s03_axi_arready     (c_m_axi_arready     [3]),//output wire                                             
    .s03_axi_rid         (c_m_axi_rid         [3]),//output wire [AXI_ID_WIDTH-1:0]                      
    .s03_axi_rdata       (c_m_axi_rdata       [3]),//output wire [AXI_DATA_WIDTH-1:0]                    
    .s03_axi_rresp       (c_m_axi_rresp       [3]),//output wire [1:0]                                   
    .s03_axi_rlast       (c_m_axi_rlast       [3]),//output wire                                         
    .s03_axi_rvalid      (c_m_axi_rvalid      [3]),//output wire                                         
    .s03_axi_rready      (c_m_axi_rready      [3]),//input  wire                                         
    // axi4 master
    .m_axi_awid          (m_axi_awid          ),//output wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_awaddr        (m_axi_awaddr        ),//output wire [AXI_ADDR_WIDTH-1:0]                    
    .m_axi_awlen         (m_axi_awlen         ),//output wire [7:0]                                   
    .m_axi_awsize        (m_axi_awsize        ),//output wire [2:0]                                   
    .m_axi_awburst       (m_axi_awburst       ),//output wire [1:0]                                       
    .m_axi_awlock        (m_axi_awlock        ),//output wire                                         
    .m_axi_awcache       (m_axi_awcache       ),//output wire [3:0]                                       
    .m_axi_awprot        (m_axi_awprot        ),//output wire [2:0]                                   
    .m_axi_awvalid       (m_axi_awvalid       ),//output wire                                             
    .m_axi_awready       (m_axi_awready       ),//input  wire                                             
    .m_axi_wdata         (m_axi_wdata         ),//output wire [AXI_DATA_WIDTH-1:0]                    
    .m_axi_wstrb         (m_axi_wstrb         ),//output wire [AXI_STRB_WIDTH-1:0]                    
    .m_axi_wlast         (m_axi_wlast         ),//output wire                                         
    .m_axi_wvalid        (m_axi_wvalid        ),//output wire                                         
    .m_axi_wready        (m_axi_wready        ),//input  wire                                         
    .m_axi_bid           (m_axi_bid           ),//input  wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_bresp         (m_axi_bresp         ),//input  wire [1:0]                                   
    .m_axi_bvalid        (m_axi_bvalid        ),//input  wire                                         
    .m_axi_bready        (m_axi_bready        ),//output wire                                         
    .m_axi_arid          (m_axi_arid          ),//output wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_araddr        (m_axi_araddr        ),//output wire [AXI_ADDR_WIDTH-1:0]                    
    .m_axi_arlen         (m_axi_arlen         ),//output wire [7:0]                                   
    .m_axi_arsize        (m_axi_arsize        ),//output wire [2:0]                                   
    .m_axi_arburst       (m_axi_arburst       ),//output wire [1:0]                                       
    .m_axi_arlock        (m_axi_arlock        ),//output wire                                         
    .m_axi_arcache       (m_axi_arcache       ),//output wire [3:0]                                       
    .m_axi_arprot        (m_axi_arprot        ),//output wire [2:0]                                   
    .m_axi_arvalid       (m_axi_arvalid       ),//output wire                                             
    .m_axi_arready       (m_axi_arready       ),//input  wire                                             
    .m_axi_rid           (m_axi_rid           ),//input  wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_rdata         (m_axi_rdata         ),//input  wire [AXI_DATA_WIDTH-1:0]                    
    .m_axi_rresp         (m_axi_rresp         ),//input  wire [1:0]                                   
    .m_axi_rlast         (m_axi_rlast         ),//input  wire                                         
    .m_axi_rvalid        (m_axi_rvalid        ),//input  wire                                         
    .m_axi_rready        (m_axi_rready        ),//output wire                                         
    // connect to dfx port  
    .dfx_sta0            (),//output wire [31:0]                                  
    .dfx_sta1            (),//output wire [31:0]                                  
    .dfx_sta2            (),//output wire [31:0]                                  
    .dfx_sta3            () //output wire [31:0]                                  
);

endmodule