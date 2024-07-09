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
module seanetnackgenerator_stream_manager_v0p1(
    input   wire                                        sys_clk         ,
    input   wire                                        sys_rst         ,
    // connect to upstream port
    input   wire     [511:0]                            i_s_info        ,
    input   wire     [15:0]                             i_s_id          ,//only support 0-1023 value
    input   wire     [95:0]                             i_key_msg       ,
    input   wire     [1:0]                              i_type          ,//01:normal 10:nack reply 11:reset
    input   wire                                        i_valid         ,
    output  wire                                        o_ready         ,
    // connect to window manager
    output  wire    [15:0]                              o_wnd_sn        ,
    output  wire    [31:0]                              o_wnd_chksum    ,
    output  wire    [95:0]                              o_wnd_key_msg   ,
    output  wire    [1 :0]                              o_wnd_tpye      ,//01:normal 10:nack reply 11:reset
    output  wire                                        o_wnd_valid     ,
    input   wire                                        i_wnd_ready     ,
    // connect to timer manager
    output  wire    [31:0]                              o_tmg_chksum	,
    output  wire    [511:0]                             o_tmg_s_info	,
    output  wire                                        o_tmg_valid	    ,
    input   wire                                        i_tmg_ready	    ,
    input   wire    [15:0]                              i_tmg_req_sn	,
    input   wire                                        i_tmg_req_valid	,
    output  wire                                        o_tmg_req_ready	,
    // connect to dfx port
    input   wire    [31:0]                              i_cfg_reg0      ,
    output  wire    [31:0]                              o_sta_reg0      ,          
    output  wire    [31:0]                              o_sta_reg1                 
);
// init
    wire                sys_rst_d9;
    reg     [15:0]      sys_rst_d={16{1'd1}};
    always@(posedge sys_clk)
    if(sys_rst)
        sys_rst_d <= {16{1'd1}};
    else
        sys_rst_d <= {sys_rst_d[14:0],1'd0};
    assign sys_rst_d9 = sys_rst_d[9];
    //ram init 
    reg     [9:0]       init_addr=10'd0;
    always@(posedge sys_clk)
    if(sys_rst_d9)
        init_addr <= 10'd0;
    else if(init_addr < 10'h3FF)
        init_addr <= init_addr + 1;
    else
        init_addr <= init_addr;
    reg                 init_done=0;
    always@(posedge sys_clk)
    if(sys_rst_d9)
        init_done <= 0;
    else if(init_addr == 10'h3FF)
        init_done <= 1;
    else
        init_done <= 0;
// pipeline
    reg      [511:0]                            r0_i_s_info        = 512'd0;
    reg      [15:0]                             r0_i_s_id          = 16'd0;
    reg      [95:0]                             r0_i_key_msg       = 96'd0;
    reg      [1:0]                              r0_i_type          = 2'd0;
    reg                                         r0_i_valid         = 1'd0;
    reg      [511:0]                            r1_i_s_info        = 512'd0;
    reg      [15:0]                             r1_i_s_id          = 16'd0;
    reg      [95:0]                             r1_i_key_msg       = 96'd0;
    reg      [1:0]                              r1_i_type          = 2'd0;
    reg                                         r1_i_valid         = 1'd0;
    reg     [15:0]                              r_wnd_sn                    ;
    reg     [31:0]                              r_wnd_chksum                ;
    reg     [95:0]                              r_wnd_key_msg               ;
    reg     [1 :0]                              r_wnd_tpye                  ;//01:normal 10:nack reply 11:reset
    reg                                         r_wnd_valid                 ;
    wire    [15:0]                              c_wnd_sn                    ;
    wire    [31:0]                              c_wnd_chksum                ;
    wire    [95:0]                              c_wnd_key_msg               ;
    wire    [1 :0]                              c_wnd_tpye                  ;//01:normal 10:nack reply 11:reset
    wire                                        c_wnd_valid                 ;
    wire                                        crc32_clk                   ;
    wire    [511:0]                             crc32_din                   ;
    wire    [31:0]                              crc32_cyc                   ;
    wire    [31:0]                              crc32_dout                  ;
    wire    [31:0]                              crc32_chksum                ;
    reg     [31:0]                              r_crc32_chksum=32'd0        ;
    wire    [31:0]                              c_crc32_chksum              ;
    reg     [31:0]                              r1_crc32_chksum=32'd0       ;
    wire    [31:0]                              cached_comp_checksum        ;
    wire                                        c_comp_checksum_success     ;
    reg                                         r_comp_checksum_success=0   ;//sync with r2

    always@(posedge sys_clk)
    begin
        r0_i_s_info  <= i_s_info            ;
        r0_i_s_id    <= i_s_id              ;
        r0_i_key_msg <= i_key_msg           ;
        r0_i_type    <= i_type              ;
        r0_i_valid   <= i_valid & o_ready   ;
    end
    
    always@(posedge sys_clk)
    begin
        r1_i_s_info  <= r0_i_s_info        ;
        r1_i_s_id    <= r0_i_s_id          ;
        r1_i_key_msg <= r0_i_key_msg       ;
        r1_i_type    <= r0_i_type          ;
        r1_i_valid   <= r0_i_valid         ;
    end

    assign c_wnd_sn        = r1_i_s_id;
    assign c_wnd_chksum    = r1_crc32_chksum;
    assign c_wnd_key_msg   = r1_i_key_msg;
    assign c_wnd_tpye      = 
                r1_i_type == 2'b01 &&  c_comp_checksum_success ? 2'b01 :
                r1_i_type == 2'b01 && ~c_comp_checksum_success ? 2'b11 : 
                r1_i_type;
                //01:normal 10:nack reply 11:reset
    assign c_wnd_valid     = 
                r1_i_type == 2'b01 && r1_i_valid ? 1 :
                r1_i_type == 2'b10 && r1_i_valid && c_comp_checksum_success ? 1 :
                0;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_wnd_sn     <= 16'd0;
            r_wnd_chksum <= 32'd0;
            r_wnd_key_msg<= 96'd0;
            r_wnd_tpye   <= 2'd0;
            r_wnd_valid  <= 0;
        end
    else
        begin
            r_wnd_sn     <= c_wnd_sn     ;
            r_wnd_chksum <= c_wnd_chksum ;
            r_wnd_key_msg<= c_wnd_key_msg;
            r_wnd_tpye   <= c_wnd_tpye   ;
            r_wnd_valid  <= c_wnd_valid  ;
        end
    assign o_wnd_sn      = r_wnd_sn     ;//early 2 tap tran ?
    assign o_wnd_chksum  = r_wnd_chksum ;
    assign o_wnd_key_msg = r_wnd_key_msg;
    assign o_wnd_tpye    = r_wnd_tpye   ;
    assign o_wnd_valid   = r_wnd_valid  ;
    // ready logic must have 2 tap idle
    
    localparam FLOWCTRL_CYCLE = 4'd4;
    reg     [3:0]           cyc_flowctrl_cnt=4'd0;
    always@(posedge sys_clk)
    if(sys_rst)
        cyc_flowctrl_cnt <= 4'd0;
    else if(cyc_flowctrl_cnt == FLOWCTRL_CYCLE || (~init_done))
        cyc_flowctrl_cnt <= 0;
    else
        cyc_flowctrl_cnt <= cyc_flowctrl_cnt + 1;
    reg                     cyc_flowctrl_nenb=0;
    always@(posedge sys_clk)
    if(sys_rst)
        cyc_flowctrl_nenb <= 0;
    else if(cyc_flowctrl_cnt == FLOWCTRL_CYCLE)
        cyc_flowctrl_nenb <= 1;
    else
        cyc_flowctrl_nenb <= 0;
    assign o_ready       = cyc_flowctrl_nenb && i_wnd_ready;
//------------------------------------------------------------
// s_info ram
    wire                bram_s_info_clka    ;
    wire    [9:0]       bram_s_info_addra   ;
    wire    [511:0]     bram_s_info_dina    ;
    wire                bram_s_info_ena     ;
    wire                bram_s_info_wea     ;
    wire                bram_s_info_clkb    ;
    wire    [9:0]       bram_s_info_addrb   ;
    wire    [511:0]     bram_s_info_doutb   ;
    wire                bram_s_info_enb     ;
    wire                bram_s_info_rstb    ;
        //`define XILINX_SIM
        `ifdef XILINX_SIM
        sdpram_512w1024d_2tap bram_s_info_512w1024d (
            .clka(bram_s_info_clka),    // input wire clka
            .wea(bram_s_info_wea),      // input wire [0 : 0] wea
            .addra(bram_s_info_addra),  // input wire [9 : 0] addra
            .dina(bram_s_info_dina),    // input wire [511 : 0] dina
            .clkb(bram_s_info_clkb),    // input wire clkb
            .addrb(bram_s_info_addrb),  // input wire [9 : 0] addrb
            .doutb(bram_s_info_doutb)  // output wire [511 : 0] doutb
        );
        `else
        (*DONT_TOUCH = "TRUE"*)ipbase_sdpram_sync#(
            .MEMORY_PRIMITIVE                ("block"       ),//auto, block, distributed, mixed, ultra
            .MEMORY_SIZE                     (512*1024      ),// DECIMAL
            .ADDR_WIDTH_A                    (10            ),// DECIMAL
            .ADDR_WIDTH_B                    (10            ),// DECIMAL
            .WRITE_DATA_WIDTH_A              (512           ),// DECIMAL
            .BYTE_WRITE_WIDTH_A              (512           ),// DECIMAL
            .READ_DATA_WIDTH_B               (512           ),// DECIMAL
            .READ_LATENCY_B                  (2             ),// DECIMAL
            .READ_RESET_VALUE_B              ("0"           ),// String
            .WRITE_MODE_B                    ("read_first"  ),// String
            .WRITE_PROTECT                   (0             ) // DECIMAL
        )bram_s_info_512w1024d(
            .clka               (bram_s_info_clka               ),//input   wire                                                
            .addra              (bram_s_info_addra              ),//input   wire    [ADDR_WIDTH_A-1:0]                          
            .dina               (bram_s_info_dina               ),//input   wire    [WRITE_DATA_WIDTH_A-1:0]                    
            .ena                (bram_s_info_ena                ),//input   wire                                                
            .wea                (bram_s_info_wea                ),//input   wire    [WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-1:0] 

            .clkb               (bram_s_info_clkb               ),//input   wire                                                
            .addrb              (bram_s_info_addrb              ),//input   wire    [ADDR_WIDTH_B-1:0]                          
            .doutb              (bram_s_info_doutb              ),//output  wire    [READ_DATA_WIDTH_B-1:0]                    
            .enb                (bram_s_info_enb                ),//input   wire                                                

            .dbiterrb           (),//output  wire                                                
            .sbiterrb           (),//output  wire                                                
            .injectdbiterra     (0),//input   wire                                                
            .injectsbiterra     (0),//input   wire                                                
            .regceb             (1),//input   wire                                                
            .rstb               (bram_s_info_rstb               ),//input   wire                                                
            .sleep              (0) //input   wire                                                
        );
        `endif
    assign bram_s_info_clka     = sys_clk;
    assign bram_s_info_addra    = r0_i_s_id[9:0];
    assign bram_s_info_dina     = r0_i_s_info;
    assign bram_s_info_ena      = 1;
    assign bram_s_info_wea      = r0_i_valid && (r0_i_type==2'b01 || r0_i_type==2'b11);

    assign bram_s_info_clkb     = sys_clk;
    assign bram_s_info_addrb    = i_tmg_req_sn[9:0];  
    assign bram_s_info_enb      = 1;
    assign bram_s_info_rstb     = sys_rst;
    wire    [511:0]         cached_s_info;
    assign cached_s_info = bram_s_info_doutb;

    reg             r0_i_tmg_req_valid=0;
    reg             r1_i_tmg_req_valid=0;
    always@(posedge sys_clk)
    if(sys_rst)
    begin
        r0_i_tmg_req_valid <= 0;
        r1_i_tmg_req_valid <= 0;
    end
    else
    begin
        r0_i_tmg_req_valid <=    i_tmg_req_valid;
        r1_i_tmg_req_valid <= r0_i_tmg_req_valid;
    end
//------------------------------------------------------------
// checksum ram0
    wire                bram_chksum0_clka    ;
    wire    [9:0]       bram_chksum0_addra   ;
    wire    [31 :0]     bram_chksum0_dina    ;
    wire                bram_chksum0_ena     ;
    wire                bram_chksum0_wea     ;
    wire                bram_chksum0_clkb    ;
    wire    [9:0]       bram_chksum0_addrb   ;
    wire    [31 :0]     bram_chksum0_doutb   ;
    wire                bram_chksum0_enb     ;
    wire                bram_chksum0_rstb    ;
    ipbase_sdpram_sync#(
        .MEMORY_PRIMITIVE                ("block"       ),//auto, block, distributed, mixed, ultra
        .MEMORY_SIZE                     (32*1024       ),// DECIMAL
        .ADDR_WIDTH_A                    (10            ),// DECIMAL
        .ADDR_WIDTH_B                    (10            ),// DECIMAL
        .WRITE_DATA_WIDTH_A              (32            ),// DECIMAL
        .BYTE_WRITE_WIDTH_A              (32            ),// DECIMAL
        .READ_DATA_WIDTH_B               (32            ),// DECIMAL
        .READ_LATENCY_B                  (2             ),// DECIMAL
        .READ_RESET_VALUE_B              ("0"           ),// String
        .WRITE_MODE_B                    ("read_first"  ),// String
        .WRITE_PROTECT                   (0             ) // DECIMAL
    )bram_chksum0_32w1024d(
        .clka               (bram_chksum0_clka               ),//input   wire                                                
        .addra              (bram_chksum0_addra              ),//input   wire    [ADDR_WIDTH_A-1:0]                          
        .dina               (bram_chksum0_dina               ),//input   wire    [WRITE_DATA_WIDTH_A-1:0]                    
        .ena                (bram_chksum0_ena                ),//input   wire                                                
        .wea                (bram_chksum0_wea                ),//input   wire    [WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-1:0] 

        .clkb               (bram_chksum0_clkb               ),//input   wire                                                
        .addrb              (bram_chksum0_addrb              ),//input   wire    [ADDR_WIDTH_B-1:0]                          
        .doutb              (bram_chksum0_doutb              ),//output  wire    [READ_DATA_WIDTH_B-1:0]                    
        .enb                (bram_chksum0_enb                ),//input   wire                                                

        .dbiterrb           (),//output  wire                                                
        .sbiterrb           (),//output  wire                                                
        .injectdbiterra     (0),//input   wire                                                
        .injectsbiterra     (0),//input   wire                                                
        .regceb             (1),//input   wire                                                
        .rstb               (bram_chksum0_rstb               ),//input   wire                                                
        .sleep              (0) //input   wire                                                
    );
    assign bram_chksum0_clka    = sys_clk;
    assign bram_chksum0_addra   = init_done ? r0_i_s_id[9:0] : init_addr;
    assign bram_chksum0_dina    = init_done ? crc32_chksum   : 32'd0;
    assign bram_chksum0_ena     = 1;
    assign bram_chksum0_wea     = init_done ? r0_i_valid && (r0_i_type==2'b01 || r0_i_type==2'b11) : 1;
    
    assign bram_chksum0_clkb    = sys_clk;
    assign bram_chksum0_addrb   = i_s_id;
    assign bram_chksum0_enb     = 1;
    assign bram_chksum0_rstb    = sys_rst;

    assign cached_comp_checksum = bram_chksum0_doutb;//2tap lantency
    assign c_comp_checksum_success = cached_comp_checksum == r1_crc32_chksum;
    always@(posedge sys_clk)
    if(sys_rst)
        r_comp_checksum_success <= 0;
    else
        r_comp_checksum_success <= c_comp_checksum_success;
        
//------------------------------------------------------------
// checksum ram1
    wire                bram_chksum1_clka    ;
    wire    [9:0]       bram_chksum1_addra   ;
    wire    [31 :0]     bram_chksum1_dina    ;
    wire                bram_chksum1_ena     ;
    wire                bram_chksum1_wea     ;
    wire                bram_chksum1_clkb    ;
    wire    [9:0]       bram_chksum1_addrb   ;
    wire    [31 :0]     bram_chksum1_doutb   ;
    wire                bram_chksum1_enb     ;
    wire                bram_chksum1_rstb    ;
    ipbase_sdpram_sync#(
        .MEMORY_PRIMITIVE                ("block"       ),//auto, block, distributed, mixed, ultra
        .MEMORY_SIZE                     (32*1024       ),// DECIMAL
        .ADDR_WIDTH_A                    (10            ),// DECIMAL
        .ADDR_WIDTH_B                    (10            ),// DECIMAL
        .WRITE_DATA_WIDTH_A              (32            ),// DECIMAL
        .BYTE_WRITE_WIDTH_A              (32            ),// DECIMAL
        .READ_DATA_WIDTH_B               (32            ),// DECIMAL
        .READ_LATENCY_B                  (2             ),// DECIMAL
        .READ_RESET_VALUE_B              ("0"           ),// String
        .WRITE_MODE_B                    ("read_first"  ),// String
        .WRITE_PROTECT                   (0             ) // DECIMAL
    )bram_chksum1_32w1024d(
        .clka               (bram_chksum1_clka               ),//input   wire                                                
        .addra              (bram_chksum1_addra              ),//input   wire    [ADDR_WIDTH_A-1:0]                          
        .dina               (bram_chksum1_dina               ),//input   wire    [WRITE_DATA_WIDTH_A-1:0]                    
        .ena                (bram_chksum1_ena                ),//input   wire                                                
        .wea                (bram_chksum1_wea                ),//input   wire    [WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-1:0] 

        .clkb               (bram_chksum1_clkb               ),//input   wire                                                
        .addrb              (bram_chksum1_addrb              ),//input   wire    [ADDR_WIDTH_B-1:0]                          
        .doutb              (bram_chksum1_doutb              ),//output  wire    [READ_DATA_WIDTH_B-1:0]                    
        .enb                (bram_chksum1_enb                ),//input   wire                                                

        .dbiterrb           (),//output  wire                                                
        .sbiterrb           (),//output  wire                                                
        .injectdbiterra     (0),//input   wire                                                
        .injectsbiterra     (0),//input   wire                                                
        .regceb             (1),//input   wire                                                
        .rstb               (bram_chksum1_rstb               ),//input   wire                                                
        .sleep              (0) //input   wire                                                
    );
    assign bram_chksum1_clka    = sys_clk;
    assign bram_chksum1_addra   = r0_i_s_id[9:0];
    assign bram_chksum1_dina    = crc32_chksum;
    assign bram_chksum1_ena     = 1;
    assign bram_chksum1_wea     = r0_i_valid && (r0_i_type==2'b01 || r0_i_type==2'b11);
    
    assign bram_chksum1_clkb    = sys_clk;
    assign bram_chksum1_addrb   = i_tmg_req_sn[9:0];  
    assign bram_chksum1_enb     = 1;
    assign bram_chksum1_rstb    = sys_rst;
//------------------------------------------------------------
// crc32
    ipbase_chksum32_w512 ipbase_chksum32_w512_dut(
        .clk                    (crc32_clk ),
        .din                    (crc32_din ),
        .cyc                    (crc32_cyc ),
        .dout                   (crc32_dout)
    );

    assign crc32_clk   = sys_clk    ;
    assign crc32_din   = i_s_info   ;
    assign crc32_cyc   = 32'd0      ;

    assign c_crc32_chksum= crc32_dout ;
    always@(posedge sys_clk)
    if(sys_rst)
        r_crc32_chksum <= 32'd0;
    else
        r_crc32_chksum <= c_crc32_chksum;
    assign crc32_chksum = r_crc32_chksum;
    
    always@(posedge sys_clk)
    if(sys_rst)
        r1_crc32_chksum <= 32'd0;
    else
        r1_crc32_chksum <= r_crc32_chksum;

    assign o_tmg_chksum = bram_chksum1_doutb;
    assign o_tmg_s_info = bram_s_info_doutb;
    assign o_tmg_valid	= r1_i_tmg_req_valid;
    assign o_tmg_req_ready = 1;

//----------------------------------------------------------------------------------
//
//\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
//  <DFX Status>
//----------------------------------------------------------------------------------
    wire                    dfx_sta_clear;
    assign dfx_sta_clear = i_cfg_reg0[0];
    //------------------------------------------------------------------------------
    // input counter
    //01:normal 10:nack reply 11:reset
    wire    [15:0]          c_req_in_counter    ;
    wire    [15:0]          c_req01_out_counter ;
    wire    [15:0]          c_req10_out_counter ;
    wire    [15:0]          c_req11_out_counter ;

    reg     [15:0]          r_req_in_counter    =16'd0;
    reg     [15:0]          r_req01_out_counter =16'd0;
    reg     [15:0]          r_req10_out_counter =16'd0;
    reg     [15:0]          r_req11_out_counter =16'd0;
    assign c_req_in_counter    = dfx_sta_clear ? 16'd0 : r0_i_valid ? r_req_in_counter + 16'd1 : r_req_in_counter;
    assign c_req01_out_counter = dfx_sta_clear ? 16'd0 : r_wnd_valid && r_wnd_tpye == 2'b01 ? r_req01_out_counter + 16'd1 : r_req01_out_counter;
    assign c_req10_out_counter = dfx_sta_clear ? 16'd0 : r_wnd_valid && r_wnd_tpye == 2'b10 ? r_req10_out_counter + 16'd1 : r_req10_out_counter;
    assign c_req11_out_counter = dfx_sta_clear ? 16'd0 : r_wnd_valid && r_wnd_tpye == 2'b11 ? r_req11_out_counter + 16'd1 : r_req11_out_counter;
    always@(posedge sys_clk)
    if(sys_rst)
        begin
            r_req_in_counter    <= 16'd0;
            r_req01_out_counter <= 16'd0;
            r_req10_out_counter <= 16'd0;
            r_req11_out_counter <= 16'd0;
        end
    else
        begin
            r_req_in_counter    <= c_req_in_counter   ;
            r_req01_out_counter <= c_req01_out_counter;
            r_req10_out_counter <= c_req10_out_counter;
            r_req11_out_counter <= c_req11_out_counter;
        end
    //------------------------------------------------------------------------------
    // CON
        assign o_sta_reg0 = {
            r_req_in_counter    ,
            r_req01_out_counter 
        };
        assign o_sta_reg1 = {
            r_req10_out_counter ,
            r_req11_out_counter 
        };

endmodule