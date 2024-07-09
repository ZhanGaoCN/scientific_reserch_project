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
module seanetnackgenerator_ddr_bitmapcmd_arbit#(
    parameter BITMAP_BASE_ADDR  = 32'h0000_0000         ,
    //------------------------------->>arbit config<<------------------------------
    //--------------------------------->>axi config<<------------------------------
    //AXI4 parameter
    parameter AXI_ID_WIDTH      = 4                     ,
    parameter AXI_ADDR_WIDTH    = 32                    ,
    parameter AXI_DATA_WIDTH    = 512                   ,
    parameter AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8      
)(
    input   wire                                        sys_clk         ,
    input   wire                                        sys_rst         ,
    // cmd input
    input   wire    [31:0]                              ddr_cmd_addr    ,
    input   wire    [511:0]                             ddr_cmd_data    ,
    input   wire    [7:0]                               ddr_cmd_len     ,
    input   wire    [1:0]                               ddr_cmd_type    ,//[2'b00: adapt write 0] [2'b01: adapt write 1] [2'b11:froce write 1]
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
    input  wire [31:0]                                  dfx_cfg0        ,
    output wire [31:0]                                  dfx_sta0        ,
    output wire [31:0]                                  dfx_sta1        
);
wire    [31:0]      ddr_cmd_addr_shift  ;
assign ddr_cmd_addr_shift = ddr_cmd_addr + BITMAP_BASE_ADDR;

wire    [31:0]      p0_ddr_cmd_addr     ;
wire    [511:0]     p0_ddr_cmd_data     ;
wire    [7:0]       p0_ddr_cmd_len      ;
wire    [1:0]       p0_ddr_cmd_type     ;
wire                p0_ddr_cmd_valid    ;
wire                p0_ddr_cmd_ready    ;

wire    [31:0]      p1_ddr_cmd_addr     ;
wire    [511:0]     p1_ddr_cmd_data     ;
wire    [7:0]       p1_ddr_cmd_len      ;
wire    [1:0]       p1_ddr_cmd_type     ;
wire                p1_ddr_cmd_valid    ;
wire                p1_ddr_cmd_ready    ;

seanetnackgenerator_ddr_bmpcmd_subarbit seanetnackgenerator_ddr_bmpcmd_subarbit_dut(
    .sys_clk                        (sys_clk                        ),//input   wire                                        
    .sys_rst                        (sys_rst                        ),//input   wire                                        
    // cmd input            
    .i_ddr_cmd_addr                 (ddr_cmd_addr_shift             ),//input   wire    [31:0]                              
    .i_ddr_cmd_data                 (ddr_cmd_data                   ),//input   wire    [511:0]                             
    .i_ddr_cmd_len                  (ddr_cmd_len                    ),//input   wire    [7:0]                               
    .i_ddr_cmd_type                 (ddr_cmd_type                   ),//input   wire    [1:0]                               //[2'b00: adapt write 0] [2'b01: adapt write 1] [2'b11:froce write 1]
    .i_ddr_cmd_valid                (ddr_cmd_valid                  ),//input   wire                                        
    .i_ddr_cmd_ready                (ddr_cmd_ready                  ),//output  wire                                        
    // cmd output port 0            
    .p0_ddr_cmd_addr                (p0_ddr_cmd_addr                ),//output  wire    [31:0]                              
    .p0_ddr_cmd_data                (p0_ddr_cmd_data                ),//output  wire    [511:0]                             
    .p0_ddr_cmd_len                 (p0_ddr_cmd_len                 ),//output  wire    [7:0]                               
    .p0_ddr_cmd_type                (p0_ddr_cmd_type                ),//output  wire    [1:0]                               //[2'b11:froce write 1]
    .p0_ddr_cmd_valid               (p0_ddr_cmd_valid               ),//output  wire                                        
    .p0_ddr_cmd_ready               (p0_ddr_cmd_ready               ),//input   wire                                        
    // cmd output port 1            
    .p1_ddr_cmd_addr                (p1_ddr_cmd_addr                ),//output  wire    [31:0]                              
    .p1_ddr_cmd_data                (p1_ddr_cmd_data                ),//output  wire    [511:0]                             
    .p1_ddr_cmd_len                 (p1_ddr_cmd_len                 ),//output  wire    [7:0]                               
    .p1_ddr_cmd_type                (p1_ddr_cmd_type                ),//output  wire    [1:0]                               //[2'b00: adapt write 0] [2'b01: adapt write 1]
    .p1_ddr_cmd_valid               (p1_ddr_cmd_valid               ),//output  wire                                        
    .p1_ddr_cmd_ready               (p1_ddr_cmd_ready               ),//input   wire                                        
    // connect to dfx port
    .dfx_sta0                       (),//output wire [31:0]                                  
    .dfx_sta1                       (),//output wire [31:0]                                  
    .dfx_sta2                       (),//output wire [31:0]                                  
    .dfx_sta3                       () //output wire [31:0]                                  
);
wire [AXI_ID_WIDTH-1:0]     sw_m_axi_awid                     ;
wire [AXI_ADDR_WIDTH-1:0]   sw_m_axi_awaddr                   ;
wire [7:0]                  sw_m_axi_awlen                    ;
wire [2:0]                  sw_m_axi_awsize                   ;
wire [1:0]                  sw_m_axi_awburst                  ;
wire                        sw_m_axi_awlock                   ;
wire [3:0]                  sw_m_axi_awcache                  ;
wire [2:0]                  sw_m_axi_awprot                   ;
wire                        sw_m_axi_awvalid                  ;
wire                        sw_m_axi_awready                  ;
wire [AXI_DATA_WIDTH-1:0]   sw_m_axi_wdata                    ;
wire [AXI_STRB_WIDTH-1:0]   sw_m_axi_wstrb                    ;
wire                        sw_m_axi_wlast                    ;
wire                        sw_m_axi_wvalid                   ;
wire                        sw_m_axi_wready                   ;
wire [AXI_ID_WIDTH-1:0]     sw_m_axi_bid                      ;
wire [1:0]                  sw_m_axi_bresp                    ;
wire                        sw_m_axi_bvalid                   ;
wire                        sw_m_axi_bready                   ;
seanetnackgenerator_ddr_bitmapcmd_arbit_sw#(
    //------------------------------->>arbit config<<------------------------------
    //--------------------------------->>axi config<<------------------------------
    //AXI4 parameter
    .AXI_ID_WIDTH      (4                     ),
    .AXI_ADDR_WIDTH    (32                    ),
    .AXI_DATA_WIDTH    (512                   ),
    .AXI_STRB_WIDTH    (AXI_DATA_WIDTH/8      ),
    .AXI_ID_SET        (4                     )
)seanetnackgenerator_ddr_bitmapcmd_arbit_sw_dut(
    .sys_clk                        (sys_clk                            ),//input   wire                                        
    .sys_rst                        (sys_rst                            ),//input   wire                                        
    // cmd input
    .ddr_cmd_addr                   (p0_ddr_cmd_addr                   ),//input   wire    [31:0]                              
    .ddr_cmd_data                   (p0_ddr_cmd_data                   ),//input   wire    [511:0]                             
    .ddr_cmd_len                    (p0_ddr_cmd_len                    ),//input   wire    [7:0]                               //256*64Byte = 16384Byte. need to deal with 4K-boundary.
    .ddr_cmd_valid                  (p0_ddr_cmd_valid                  ),//input   wire                                        
    .ddr_cmd_ready                  (p0_ddr_cmd_ready                  ),//output  wire                                        
    // axi4 
    .m_axi_awid                     (sw_m_axi_awid                     ),//output wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_awaddr                   (sw_m_axi_awaddr                   ),//output wire [AXI_ADDR_WIDTH-1:0]                    
    .m_axi_awlen                    (sw_m_axi_awlen                    ),//output wire [7:0]                                   
    .m_axi_awsize                   (sw_m_axi_awsize                   ),//output wire [2:0]                                   
    .m_axi_awburst                  (sw_m_axi_awburst                  ),//output wire [1:0]                                       
    .m_axi_awlock                   (sw_m_axi_awlock                   ),//output wire                                         
    .m_axi_awcache                  (sw_m_axi_awcache                  ),//output wire [3:0]                                       
    .m_axi_awprot                   (sw_m_axi_awprot                   ),//output wire [2:0]                                   
    .m_axi_awvalid                  (sw_m_axi_awvalid                  ),//output wire                                             
    .m_axi_awready                  (sw_m_axi_awready                  ),//input  wire                                             
    .m_axi_wdata                    (sw_m_axi_wdata                    ),//output wire [AXI_DATA_WIDTH-1:0]                    
    .m_axi_wstrb                    (sw_m_axi_wstrb                    ),//output wire [AXI_STRB_WIDTH-1:0]                    
    .m_axi_wlast                    (sw_m_axi_wlast                    ),//output wire                                         
    .m_axi_wvalid                   (sw_m_axi_wvalid                   ),//output wire                                         
    .m_axi_wready                   (sw_m_axi_wready                   ),//input  wire                                         
    .m_axi_bid                      (sw_m_axi_bid                      ),//input  wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_bresp                    (sw_m_axi_bresp                    ),//input  wire [1:0]                                   
    .m_axi_bvalid                   (sw_m_axi_bvalid                   ),//input  wire                                         
    .m_axi_bready                   (sw_m_axi_bready                   ),//output wire                                         
    // connect to dfx port
    .dfx_sta0                       (),//output wire [31:0]                                  
    .dfx_sta1                       (),//output wire [31:0]                                  
    .dfx_sta2                       (),//output wire [31:0]                                  
    .dfx_sta3                       () //output wire [31:0]                                  
);
wire [AXI_ID_WIDTH-1:0]         mdf_m_axi_awid                     ;
wire [AXI_ADDR_WIDTH-1:0]       mdf_m_axi_awaddr                   ;
wire [7:0]                      mdf_m_axi_awlen                    ;
wire [2:0]                      mdf_m_axi_awsize                   ;
wire [1:0]                      mdf_m_axi_awburst                  ;
wire                            mdf_m_axi_awlock                   ;
wire [3:0]                      mdf_m_axi_awcache                  ;
wire [2:0]                      mdf_m_axi_awprot                   ;
wire                            mdf_m_axi_awvalid                  ;
wire                            mdf_m_axi_awready                  ;
wire [AXI_DATA_WIDTH-1:0]       mdf_m_axi_wdata                    ;
wire [AXI_STRB_WIDTH-1:0]       mdf_m_axi_wstrb                    ;
wire                            mdf_m_axi_wlast                    ;
wire                            mdf_m_axi_wvalid                   ;
wire                            mdf_m_axi_wready                   ;
wire [AXI_ID_WIDTH-1:0]         mdf_m_axi_bid                      ;
wire [1:0]                      mdf_m_axi_bresp                    ;
wire                            mdf_m_axi_bvalid                   ;
wire                            mdf_m_axi_bready                   ;
wire [AXI_ID_WIDTH-1:0]         mdf_m_axi_arid                     ;
wire [AXI_ADDR_WIDTH-1:0]       mdf_m_axi_araddr                   ;
wire [7:0]                      mdf_m_axi_arlen                    ;
wire [2:0]                      mdf_m_axi_arsize                   ;
wire [1:0]                      mdf_m_axi_arburst                  ;
wire                            mdf_m_axi_arlock                   ;
wire [3:0]                      mdf_m_axi_arcache                  ;
wire [2:0]                      mdf_m_axi_arprot                   ;
wire                            mdf_m_axi_arvalid                  ;
wire                            mdf_m_axi_arready                  ;
wire [AXI_ID_WIDTH-1:0]         mdf_m_axi_rid                      ;
wire [AXI_DATA_WIDTH-1:0]       mdf_m_axi_rdata                    ;
wire [1:0]                      mdf_m_axi_rresp                    ;
wire                            mdf_m_axi_rlast                    ;
wire                            mdf_m_axi_rvalid                   ;
wire                            mdf_m_axi_rready                   ;
seanetnackgenerator_ddr_bmpcmd_arbit_m #(
    //------------------------------->>arbit config<<------------------------------
    //--------------------------------->>axi config<<------------------------------
    //AXI4 parameter
    .AXI_ID_WIDTH      (4                     ),
    .AXI_ADDR_WIDTH    (32                    ),
    .AXI_DATA_WIDTH    (512                   ),
    .AXI_STRB_WIDTH    (AXI_DATA_WIDTH/8      )
)seanetnackgenerator_ddr_bmpcmd_arbit_m_dut(
    .sys_clk                        (sys_clk                        ),//input   wire                                        
    .sys_rst                        (sys_rst                        ),//input   wire                                        
    // cmd input                
    .ddr_cmd_addr                   (p1_ddr_cmd_addr                   ),//input   wire    [31:0]                              
    .ddr_cmd_data                   (p1_ddr_cmd_data                   ),//input   wire    [511:0]                             
    .ddr_cmd_type                   (p1_ddr_cmd_type                   ),//input   wire    [1:0]                               //01 -> high mode / 00 -> low mode
    .ddr_cmd_len                    (p1_ddr_cmd_len                    ),//input   wire    [7:0]                               //fixed to 0
    .ddr_cmd_valid                  (p1_ddr_cmd_valid                  ),//input   wire                                        
    .ddr_cmd_ready                  (p1_ddr_cmd_ready                  ),//output  wire                                        
    // axi4                 
    .m_axi_awid                     (mdf_m_axi_awid                     ),//output wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_awaddr                   (mdf_m_axi_awaddr                   ),//output wire [AXI_ADDR_WIDTH-1:0]                    
    .m_axi_awlen                    (mdf_m_axi_awlen                    ),//output wire [7:0]                                   
    .m_axi_awsize                   (mdf_m_axi_awsize                   ),//output wire [2:0]                                   
    .m_axi_awburst                  (mdf_m_axi_awburst                  ),//output wire [1:0]                                       
    .m_axi_awlock                   (mdf_m_axi_awlock                   ),//output wire                                         
    .m_axi_awcache                  (mdf_m_axi_awcache                  ),//output wire [3:0]                                       
    .m_axi_awprot                   (mdf_m_axi_awprot                   ),//output wire [2:0]                                   
    .m_axi_awvalid                  (mdf_m_axi_awvalid                  ),//output wire                                             
    .m_axi_awready                  (mdf_m_axi_awready                  ),//input  wire                                             
    .m_axi_wdata                    (mdf_m_axi_wdata                    ),//output wire [AXI_DATA_WIDTH-1:0]                    
    .m_axi_wstrb                    (mdf_m_axi_wstrb                    ),//output wire [AXI_STRB_WIDTH-1:0]                    
    .m_axi_wlast                    (mdf_m_axi_wlast                    ),//output wire                                         
    .m_axi_wvalid                   (mdf_m_axi_wvalid                   ),//output wire                                         
    .m_axi_wready                   (mdf_m_axi_wready                   ),//input  wire                                         
    .m_axi_bid                      (mdf_m_axi_bid                      ),//input  wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_bresp                    (mdf_m_axi_bresp                    ),//input  wire [1:0]                                   
    .m_axi_bvalid                   (mdf_m_axi_bvalid                   ),//input  wire                                         
    .m_axi_bready                   (mdf_m_axi_bready                   ),//output wire                                         
    .m_axi_arid                     (mdf_m_axi_arid                     ),//output wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_araddr                   (mdf_m_axi_araddr                   ),//output wire [AXI_ADDR_WIDTH-1:0]                    
    .m_axi_arlen                    (mdf_m_axi_arlen                    ),//output wire [7:0]                                   
    .m_axi_arsize                   (mdf_m_axi_arsize                   ),//output wire [2:0]                                   
    .m_axi_arburst                  (mdf_m_axi_arburst                  ),//output wire [1:0]                                       
    .m_axi_arlock                   (mdf_m_axi_arlock                   ),//output wire                                         
    .m_axi_arcache                  (mdf_m_axi_arcache                  ),//output wire [3:0]                                       
    .m_axi_arprot                   (mdf_m_axi_arprot                   ),//output wire [2:0]                                   
    .m_axi_arvalid                  (mdf_m_axi_arvalid                  ),//output wire                                             
    .m_axi_arready                  (mdf_m_axi_arready                  ),//input  wire                                             
    .m_axi_rid                      (mdf_m_axi_rid                      ),//input  wire [AXI_ID_WIDTH-1:0]                      
    .m_axi_rdata                    (mdf_m_axi_rdata                    ),//input  wire [AXI_DATA_WIDTH-1:0]                    
    .m_axi_rresp                    (mdf_m_axi_rresp                    ),//input  wire [1:0]                                   
    .m_axi_rlast                    (mdf_m_axi_rlast                    ),//input  wire                                         
    .m_axi_rvalid                   (mdf_m_axi_rvalid                   ),//input  wire                                         
    .m_axi_rready                   (mdf_m_axi_rready                   ),//output wire                                         
    // connect to dfx port
    .dfx_sta0                       (),//output wire [31:0]                                  
    .dfx_sta1                       (),//output wire [31:0]                                  
    .dfx_sta2                       (),//output wire [31:0]                                  
    .dfx_sta3                       () //output wire [31:0]                                  
);

ipbase_intf_axi_arbit2to1prio_simplified#(
    //------------------------------->>arbit config<<------------------------------
    //--------------------------------->>axi config<<------------------------------
    //AXI4 parameter
    .AXI_ID_WIDTH      (AXI_ID_WIDTH      ),
    .AXI_ADDR_WIDTH    (AXI_ADDR_WIDTH    ),
    .AXI_DATA_WIDTH    (AXI_DATA_WIDTH    ),
    .AXI_STRB_WIDTH    (AXI_STRB_WIDTH    )
)ipbase_intf_axi_arbit2to1prio_simplified_dut(
    .sys_clk             (sys_clk),//input   wire                                        
    .sys_rst             (sys_rst),//input   wire                                        
    //s00
    .s00_axi_awid        (mdf_m_axi_awid            ),//input  wire [AXI_ID_WIDTH-1:0]                      
    .s00_axi_awaddr      (mdf_m_axi_awaddr          ),//input  wire [AXI_ADDR_WIDTH-1:0]                    
    .s00_axi_awlen       (mdf_m_axi_awlen           ),//input  wire [7:0]                                   
    .s00_axi_awsize      (mdf_m_axi_awsize          ),//input  wire [2:0]                                   
    .s00_axi_awburst     (mdf_m_axi_awburst         ),//input  wire [1:0]                                       
    .s00_axi_awlock      (mdf_m_axi_awlock          ),//input  wire                                         
    .s00_axi_awcache     (mdf_m_axi_awcache         ),//input  wire [3:0]                                       
    .s00_axi_awprot      (mdf_m_axi_awprot          ),//input  wire [2:0]                                   
    .s00_axi_awvalid     (mdf_m_axi_awvalid         ),//input  wire                                             
    .s00_axi_awready     (mdf_m_axi_awready         ),//output wire                                             
    .s00_axi_wdata       (mdf_m_axi_wdata           ),//input  wire [AXI_DATA_WIDTH-1:0]                    
    .s00_axi_wstrb       (mdf_m_axi_wstrb           ),//input  wire [AXI_STRB_WIDTH-1:0]                    
    .s00_axi_wlast       (mdf_m_axi_wlast           ),//input  wire                                         
    .s00_axi_wvalid      (mdf_m_axi_wvalid          ),//input  wire                                         
    .s00_axi_wready      (mdf_m_axi_wready          ),//output wire                                         
    .s00_axi_bid         (mdf_m_axi_bid             ),//output wire [AXI_ID_WIDTH-1:0]                      
    .s00_axi_bresp       (mdf_m_axi_bresp           ),//output wire [1:0]                                   
    .s00_axi_bvalid      (mdf_m_axi_bvalid          ),//output wire                                         
    .s00_axi_bready      (mdf_m_axi_bready          ),//input  wire                                         
    .s00_axi_arid        (mdf_m_axi_arid            ),//input  wire [AXI_ID_WIDTH-1:0]                      
    .s00_axi_araddr      (mdf_m_axi_araddr          ),//input  wire [AXI_ADDR_WIDTH-1:0]                    
    .s00_axi_arlen       (mdf_m_axi_arlen           ),//input  wire [7:0]                                   
    .s00_axi_arsize      (mdf_m_axi_arsize          ),//input  wire [2:0]                                   
    .s00_axi_arburst     (mdf_m_axi_arburst         ),//input  wire [1:0]                                       
    .s00_axi_arlock      (mdf_m_axi_arlock          ),//input  wire                                         
    .s00_axi_arcache     (mdf_m_axi_arcache         ),//input  wire [3:0]                                       
    .s00_axi_arprot      (mdf_m_axi_arprot          ),//input  wire [2:0]                                   
    .s00_axi_arvalid     (mdf_m_axi_arvalid         ),//input  wire                                             
    .s00_axi_arready     (mdf_m_axi_arready         ),//output wire                                             
    .s00_axi_rid         (mdf_m_axi_rid             ),//output wire [AXI_ID_WIDTH-1:0]                      
    .s00_axi_rdata       (mdf_m_axi_rdata           ),//output wire [AXI_DATA_WIDTH-1:0]                    
    .s00_axi_rresp       (mdf_m_axi_rresp           ),//output wire [1:0]                                   
    .s00_axi_rlast       (mdf_m_axi_rlast           ),//output wire                                         
    .s00_axi_rvalid      (mdf_m_axi_rvalid          ),//output wire                                         
    .s00_axi_rready      (mdf_m_axi_rready          ),//input  wire                                         
    //s01
    .s01_axi_awid        (sw_m_axi_awid                     ),//input  wire [AXI_ID_WIDTH-1:0]                      
    .s01_axi_awaddr      (sw_m_axi_awaddr                   ),//input  wire [AXI_ADDR_WIDTH-1:0]                    
    .s01_axi_awlen       (sw_m_axi_awlen                    ),//input  wire [7:0]                                   
    .s01_axi_awsize      (sw_m_axi_awsize                   ),//input  wire [2:0]                                   
    .s01_axi_awburst     (sw_m_axi_awburst                  ),//input  wire [1:0]                                       
    .s01_axi_awlock      (sw_m_axi_awlock                   ),//input  wire                                         
    .s01_axi_awcache     (sw_m_axi_awcache                  ),//input  wire [3:0]                                       
    .s01_axi_awprot      (sw_m_axi_awprot                   ),//input  wire [2:0]                                   
    .s01_axi_awvalid     (sw_m_axi_awvalid                  ),//input  wire                                             
    .s01_axi_awready     (sw_m_axi_awready                  ),//output wire                                             
    .s01_axi_wdata       (sw_m_axi_wdata                    ),//input  wire [AXI_DATA_WIDTH-1:0]                    
    .s01_axi_wstrb       (sw_m_axi_wstrb                    ),//input  wire [AXI_STRB_WIDTH-1:0]                    
    .s01_axi_wlast       (sw_m_axi_wlast                    ),//input  wire                                         
    .s01_axi_wvalid      (sw_m_axi_wvalid                   ),//input  wire                                         
    .s01_axi_wready      (sw_m_axi_wready                   ),//output wire                                         
    .s01_axi_bid         (sw_m_axi_bid                      ),//output wire [AXI_ID_WIDTH-1:0]                      
    .s01_axi_bresp       (sw_m_axi_bresp                    ),//output wire [1:0]                                   
    .s01_axi_bvalid      (sw_m_axi_bvalid                   ),//output wire                                         
    .s01_axi_bready      (sw_m_axi_bready                   ),//input  wire                                         
    .s01_axi_arid        ({AXI_ID_WIDTH{1'b0}}),//input  wire [AXI_ID_WIDTH-1:0]                      
    .s01_axi_araddr      ({AXI_ADDR_WIDTH{1'b0}}),//input  wire [AXI_ADDR_WIDTH-1:0]                    
    .s01_axi_arlen       (8'd0),//input  wire [7:0]                                   
    .s01_axi_arsize      (3'd0),//input  wire [2:0]                                   
    .s01_axi_arburst     (2'd0),//input  wire [1:0]                                       
    .s01_axi_arlock      (0),//input  wire                                         
    .s01_axi_arcache     (4'd0),//input  wire [3:0]                                       
    .s01_axi_arprot      (3'd0),//input  wire [2:0]                                   
    .s01_axi_arvalid     (0),//input  wire                                             
    .s01_axi_arready     (),//output wire                                             
    .s01_axi_rid         (),//output wire [AXI_ID_WIDTH-1:0]                      
    .s01_axi_rdata       (),//output wire [AXI_DATA_WIDTH-1:0]                    
    .s01_axi_rresp       (),//output wire [1:0]                                   
    .s01_axi_rlast       (),//output wire                                         
    .s01_axi_rvalid      (),//output wire                                         
    .s01_axi_rready      (0),//input  wire                                         
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

//----------------------------------------------------------------------------------
//
//\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
//  <DFX Status>
//----------------------------------------------------------------------------------
    wire                    dfx_sta_clear;
    assign dfx_sta_clear = dfx_cfg0[0];
    //------------------------------------------------------------------------------
    // axi sta counter
        //master read
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
        //master write
        wire    [7:0]           c_m_axi_wr_addr_counter   ;
        wire    [7:0]           c_m_axi_wr_data_counter   ;
        wire    [7:0]           c_m_axi_wr_resp_counter   ;
        wire    [1:0]           c_m_axi_wr_addr_sta       ;
        wire    [1:0]           c_m_axi_wr_data_sta       ;
        reg     [7:0]           r_m_axi_wr_addr_counter   =8'd0;
        reg     [7:0]           r_m_axi_wr_data_counter   =8'd0;
        reg     [7:0]           r_m_axi_wr_resp_counter   =8'd0;
        reg     [1:0]           r_m_axi_wr_addr_sta       =2'd0;
        reg     [1:0]           r_m_axi_wr_data_sta       =2'd0;
        assign c_m_axi_wr_addr_counter = dfx_sta_clear ? 16'd0 : m_axi_awvalid & m_axi_awready ? r_m_axi_wr_addr_counter + 8'd1 : r_m_axi_wr_addr_counter;
        assign c_m_axi_wr_data_counter = dfx_sta_clear ? 16'd0 : m_axi_wvalid & m_axi_wready & m_axi_wlast ? r_m_axi_wr_data_counter + 8'd1 : r_m_axi_wr_data_counter;
        assign c_m_axi_wr_resp_counter = dfx_sta_clear ? 16'd0 : m_axi_bvalid & m_axi_bready ? r_m_axi_wr_resp_counter + 8'd1 : r_m_axi_wr_resp_counter;
        assign c_m_axi_wr_addr_sta = {m_axi_awvalid,m_axi_awready};
        assign c_m_axi_wr_data_sta = {m_axi_wvalid ,m_axi_wready };
        always@(posedge sys_clk)
        if(sys_rst)
            begin
                r_m_axi_wr_addr_counter   <=8'd0;
                r_m_axi_wr_data_counter   <=8'd0;
                r_m_axi_wr_resp_counter   <=8'd0;
                r_m_axi_wr_addr_sta       <=2'd0;
                r_m_axi_wr_data_sta       <=2'd0;
            end
        else
            begin
                r_m_axi_wr_addr_counter   <=c_m_axi_wr_addr_counter   ;
                r_m_axi_wr_data_counter   <=c_m_axi_wr_data_counter   ;
                r_m_axi_wr_resp_counter   <=c_m_axi_wr_resp_counter   ;
                r_m_axi_wr_addr_sta       <=c_m_axi_wr_addr_sta       ;
                r_m_axi_wr_data_sta       <=c_m_axi_wr_data_sta       ;
            end
        //slave sta
        wire    [15:0]          c_axi_slave_sta;
        reg     [15:0]          r_axi_slave_sta=16'd0;
        assign c_axi_slave_sta = {
            4'd0,
            sw_m_axi_awvalid ,
            sw_m_axi_awready ,
            sw_m_axi_wvalid  ,
            sw_m_axi_wready  ,
            mdf_m_axi_awvalid,
            mdf_m_axi_awready,
            mdf_m_axi_wvalid ,
            mdf_m_axi_wready ,
            mdf_m_axi_arvalid,
            mdf_m_axi_arready,
            mdf_m_axi_rvalid ,
            mdf_m_axi_rready 
        };
        always@(posedge sys_clk)
        if(sys_rst)
            r_axi_slave_sta <= 16'd0;
        else
            r_axi_slave_sta <= c_axi_slave_sta;
    //------------------------------------------------------------------------------
    // CON
        assign dfx_sta0 = {
            r_m_axi_wr_addr_counter     ,
            r_m_axi_wr_data_counter     ,
            r_m_axi_rd_addr_counter     ,
            r_m_axi_rd_data_counter      
        };
        assign dfx_sta1 = {
            r_axi_slave_sta       ,
            r_m_axi_rd_addr_sta   ,
            r_m_axi_rd_data_sta   ,
            r_m_axi_wr_addr_sta   ,
            r_m_axi_wr_data_sta   ,
            r_m_axi_wr_resp_counter   
        };

endmodule