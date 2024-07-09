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
module seanetnackgenerator_ddr_bitmapcmd_arbit_sw#(
    //------------------------------->>arbit config<<------------------------------
    //--------------------------------->>axi config<<------------------------------
    //AXI4 parameter
    parameter AXI_ID_WIDTH      = 4                     ,
    parameter AXI_ADDR_WIDTH    = 64                    ,
    parameter AXI_DATA_WIDTH    = 512                   ,
    parameter AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8      ,
    parameter AXI_ID_SET        = 0                     
)(
    input   wire                                        sys_clk         ,
    input   wire                                        sys_rst         ,
    // cmd input
    input   wire    [31:0]                              ddr_cmd_addr    ,
    input   wire    [511:0]                             ddr_cmd_data    ,
    input   wire    [7:0]                               ddr_cmd_len     ,//256*64Byte = 16384Byte. need to deal with 4K-boundary.
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
    // connect to dfx port
    output wire [31:0]                                  dfx_sta0        ,
    output wire [31:0]                                  dfx_sta1        ,
    output wire [31:0]                                  dfx_sta2        ,
    output wire [31:0]                                  dfx_sta3        
);
//------------------------------------------------------------
// cmd lag(REV)
    wire    [31:0]                              c_l1_ddr_cmd_addr    ;
    wire    [511:0]                             c_l1_ddr_cmd_data    ;
    wire    [7:0]                               c_l1_ddr_cmd_len     ;
    wire                                        c_l1_ddr_cmd_valid   ;
    wire                                        c_l1_ddr_cmd_ready   ;

    reg     [31:0]                              r_l1_ddr_cmd_addr    ;
    reg     [511:0]                             r_l1_ddr_cmd_data    ;
    reg     [7:0]                               r_l1_ddr_cmd_len     ;
    reg                                         r_l1_ddr_cmd_valid   ;
    reg                                         r_l1_ddr_cmd_ready   ;

    wire    [32-1:0]                    adp_cmd_awaddr        ;
    wire    [8-1:0]                     adp_cmd_awlen         ;
    wire                                adp_cmd_awvalid       ;
    wire                                adp_cmd_awready       ;
    wire    [512-1:0]                   adp_cmd_wdata         ;
    wire                                adp_cmd_wlast         ;
    wire                                adp_cmd_wvalid        ;
    wire                                adp_cmd_wready        ;
    assign c_l1_ddr_cmd_addr = 
                r_l1_ddr_cmd_valid ?
                    adp_cmd_awready ?
                        ddr_cmd_valid ? ddr_cmd_addr :
                        32'd0 :
                    r_l1_ddr_cmd_addr :
                ddr_cmd_valid ? ddr_cmd_addr :
                32'd0;
    assign c_l1_ddr_cmd_data = 
                r_l1_ddr_cmd_valid ?
                    adp_cmd_awready ?
                        ddr_cmd_valid ? ddr_cmd_data :
                        512'd0 :
                    r_l1_ddr_cmd_data :
                ddr_cmd_valid ? ddr_cmd_data :
                512'd0;
    assign c_l1_ddr_cmd_len =
                r_l1_ddr_cmd_valid ?
                    adp_cmd_awready ?
                        ddr_cmd_valid ? ddr_cmd_len :
                        8'd0 :
                    r_l1_ddr_cmd_len :
                ddr_cmd_valid ? ddr_cmd_len :
                8'd0;
    assign c_l1_ddr_cmd_valid = 
                r_l1_ddr_cmd_valid ?
                    adp_cmd_awready ?
                        ddr_cmd_valid ? 1 :
                        0 :
                    1 :
                ddr_cmd_valid ? 1 :
                0;
    assign c_l1_ddr_cmd_ready = 
                r_l1_ddr_cmd_valid ? 
                    adp_cmd_awready ?
                        ddr_cmd_valid ? 1 :
                        0 :
                    0 :
                1;

    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_l1_ddr_cmd_addr  <= 32'd0;
            r_l1_ddr_cmd_data  <= 512'd0;
            r_l1_ddr_cmd_len   <= 8'd0;
            r_l1_ddr_cmd_valid <= 1'd0;
            r_l1_ddr_cmd_ready <= 1'd0;
        end
    else
        begin
            r_l1_ddr_cmd_addr  <= c_l1_ddr_cmd_addr  ;
            r_l1_ddr_cmd_data  <= c_l1_ddr_cmd_data  ;
            r_l1_ddr_cmd_len   <= c_l1_ddr_cmd_len   ;
            r_l1_ddr_cmd_valid <= c_l1_ddr_cmd_valid ;
            r_l1_ddr_cmd_ready <= c_l1_ddr_cmd_ready ;
        end

    assign ddr_cmd_ready    = adp_cmd_awready   ;
    assign adp_cmd_awaddr   = ddr_cmd_addr      ;
    assign adp_cmd_awlen    = ddr_cmd_len       ;
    assign adp_cmd_awvalid  = ddr_cmd_valid     ;
    assign adp_cmd_wdata    = ddr_cmd_data      ;
    assign adp_cmd_wvalid   = 0;//no used
    assign adp_cmd_wlast    = 0;//no used
    wire    [AXI_ADDR_WIDTH-1:0]        adp_axi_awaddr        ;
    wire    [7:0]                       adp_axi_awlen         ;
    wire                                adp_axi_awvalid       ;
    wire                                adp_axi_awready       ;
    wire    [AXI_DATA_WIDTH-1:0]        adp_axi_wdata         ;
    wire                                adp_axi_wlast         ;
    wire                                adp_axi_wvalid        ;
    wire                                adp_axi_wready        ;
    wire    [1:0]                       adp_axi_bresp         ;
    wire                                adp_axi_bvalid        ;
    wire                                adp_axi_bready        ;
    wire                                adp_err_trig          ;
    wire    [31:0]                      adp_dfx_sta           ;   

    assign m_axi_awid      = AXI_ID_SET;
    assign m_axi_awaddr    = adp_axi_awaddr ;
    assign m_axi_awlen     = adp_axi_awlen  ;
    assign m_axi_awsize    = 3'b110;
    assign m_axi_awburst   = 2'b01;
    assign m_axi_awlock    = 0;
    assign m_axi_awcache   = 4'd0;
    assign m_axi_awprot    = 3'd0;
    assign m_axi_awvalid   = adp_axi_awvalid;
    assign adp_axi_awready = m_axi_awready  ;
    assign m_axi_wdata     = adp_axi_wdata  ;
    assign m_axi_wstrb     = {AXI_STRB_WIDTH{1'b1}};
    assign m_axi_wlast     = adp_axi_wlast  ;
    assign m_axi_wvalid    = adp_axi_wvalid ;
    assign adp_axi_wready  = m_axi_wready   ; 
    //assign m_axi_bid       = 
    assign adp_axi_bresp   = m_axi_bresp    ; 
    assign adp_axi_bvalid  = m_axi_bvalid   ; 
    assign m_axi_bready    = 1;
ipbase_intf_axi_wr_adapter_simplified_v0p1 ipbase_intf_axi_wr_adapter_simplified_v0p1_dut(
    .sys_clk         (sys_clk               ),//input   wire                                
    .sys_rst         (sys_rst               ),//input   wire                                
    .cmd_awaddr      (adp_cmd_awaddr        ),//input   wire    [ADDR_WIDTH-1:0]            
    .cmd_awlen       (adp_cmd_awlen         ),//input   wire    [TLEN_WIDTH-1:0]            //256*64Byte=16384Byte=4*4096Byte
    .cmd_awvalid     (adp_cmd_awvalid       ),//input   wire                                
    .cmd_awready     (adp_cmd_awready       ),//output  wire                                
    .cmd_wdata       (adp_cmd_wdata         ),//input   wire    [DATA_WIDTH-1:0]            
    .cmd_wlast       (adp_cmd_wlast         ),//input   wire                                
    .cmd_wvalid      (adp_cmd_wvalid        ),//input   wire                                
    .cmd_wready      (adp_cmd_wready        ),//output  wire                                
    .axi_awaddr      (adp_axi_awaddr        ),//output  wire    [AXI_ADDR_WIDTH-1:0]        
    .axi_awlen       (adp_axi_awlen         ),//output  wire    [7:0]                       
    .axi_awvalid     (adp_axi_awvalid       ),//output  wire                                
    .axi_awready     (adp_axi_awready       ),//input   wire                                
    .axi_wdata       (adp_axi_wdata         ),//output  wire    [AXI_DATA_WIDTH-1:0]        
    .axi_wlast       (adp_axi_wlast         ),//output  wire                                
    .axi_wvalid      (adp_axi_wvalid        ),//output  wire                                
    .axi_wready      (adp_axi_wready        ),//input   wire                                
    .axi_bresp       (adp_axi_bresp         ),//input   wire    [1:0]                       
    .axi_bvalid      (adp_axi_bvalid        ),//input   wire                                
    .axi_bready      (adp_axi_bready        ),//output  wire                                
    .err_trig        (adp_err_trig          ),//output  wire                                
    .dfx_sta         (adp_dfx_sta           ) //output  wire    [31:0]                      
);
endmodule