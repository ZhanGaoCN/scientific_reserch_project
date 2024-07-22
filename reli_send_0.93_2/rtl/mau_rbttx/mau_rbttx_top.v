
module mau_rbttx_top #(
    parameter ADDR_WIDTH = 11,// HASH   table 1024 entries, so addr width is log2(2048)
    parameter KEY_WIDTH = 256,//RSIP 128bit + Dstip 128bit
    // parameter MASK_WIDTH = 256,
    parameter VALUE_WIDTH = 32,
    parameter OPCODE_WIDTH = 4,

    parameter PHV_B_COUNT = 7,
    parameter PHV_H_COUNT = 2,
    parameter PHV_W_COUNT = 10,
    parameter PHV_WIDTH = 408,

    parameter CSR_ADDR_WIDTH = 12,
    parameter CSR_DATA_WIDTH = 32,
    parameter CSR_STRB_WIDTH = CSR_DATA_WIDTH / 8
) (
    input wire clk,
    input wire rst,

    //flowmod

    // csr interface
    input  wire [CSR_ADDR_WIDTH-1:0]                    ctrl_reg_app_wr_addr,
    input  wire [CSR_DATA_WIDTH-1:0]                    ctrl_reg_app_wr_data,
    input  wire [CSR_STRB_WIDTH-1:0]                    ctrl_reg_app_wr_strb,
    input  wire                                         ctrl_reg_app_wr_en,
    output wire                                         ctrl_reg_app_wr_wait,
    output wire                                         ctrl_reg_app_wr_ack,

    input  wire [CSR_ADDR_WIDTH-1:0]                    ctrl_reg_app_rd_addr,
    input  wire                                         ctrl_reg_app_rd_en,
    output wire [CSR_DATA_WIDTH-1:0]                    ctrl_reg_app_rd_data,
    output wire                                         ctrl_reg_app_rd_wait,
    output wire                                         ctrl_reg_app_rd_ack,

    input  wire                       		s_phv_valid,
    output wire                       		s_phv_ready,
    input  wire [PHV_WIDTH-1:0]      		s_phv_info,

    output wire                       		m_phv_valid,
    input  wire                       		m_phv_ready,
    output wire [PHV_WIDTH-1:0]      		m_phv_info
);

 // table size parameter
localparam FLOWSTATE_WIDTH = 32; //RPN 32bit
localparam PHV_DEPTH = 8; //em 5clock 

wire reliable_enable;

/*
KEY SELECTOR
*/
wire  								m_key_valid;
wire  								m_key_ready;
wire [KEY_WIDTH-1:0]     	        m_key_info;

wire  	                            s_key_selector_phv_ready;
wire  	                            s_srl_fifo_phv_ready;

assign s_phv_ready = s_key_selector_phv_ready & s_srl_fifo_phv_ready;

localparam FLOWMOD_CONTROLLER_ADDR_WIDTH = 24;

wire [FLOWMOD_CONTROLLER_ADDR_WIDTH-1:0] m_mod_addr_wire;
wire [FLOWMOD_CONTROLLER_DATA_WIDTH:0] m_mod_data_wire;
wire [OPCODE_WIDTH-1:0] m_mod_opcode_wire;
wire m_mod_valid_wire;
wire m_mod_ready_wire;

wire [FLOWMOD_CONTROLLER_DATA_WIDTH:0] s_mod_bdata_wire;
wire s_mod_bvalid_wire;
wire s_mod_bready_wire;
wire csr_wr_ack_rbtrx,csr_rd_ack_rbtrx;
wire [CSR_DATA_WIDTH-1:0]csr_rd_data_rbtrx;




key_selector_rbttx #(
	.KEY_WIDTH						(KEY_WIDTH),
	.PHV_WIDTH						(PHV_WIDTH),
    .PHV_B_COUNT				    (PHV_B_COUNT),
    .PHV_H_COUNT					(PHV_H_COUNT),
    .PHV_W_COUNT					(PHV_W_COUNT)
) key_selector_inst (
	.clk							(clk),
	.rst							(rst),

	.s_phv_valid					(s_phv_valid & s_phv_ready),
	.s_phv_ready					(s_key_selector_phv_ready),
	.s_phv_info						(s_phv_info),

	.m_key_valid					(m_key_valid),
	.m_key_ready					(m_key_ready),
	.m_key_info						(m_key_info)
);

/*
FIFO
*/
wire                       		s_phv_valid_fifo;
wire                       		s_phv_ready_fifo;
wire [PHV_WIDTH-1:0]      		s_phv_info_fifo;

axis_srl_fifo #(
    .DEPTH              (PHV_DEPTH),
    .DATA_WIDTH         (PHV_WIDTH),
    .KEEP_ENABLE        (0),
    .LAST_ENABLE        (0),
    .ID_ENABLE          (0),
    .DEST_ENABLE        (0),
    .USER_ENABLE        (0)
)
phv_axis_fifo_inst (
    .clk                (clk),
    .rst                (rst),

    .s_axis_tdata       (s_phv_info),
    .s_axis_tvalid      (s_phv_valid & s_phv_ready),
    .s_axis_tready      (s_srl_fifo_phv_ready),
    .s_axis_tkeep       (0),
    .s_axis_tlast       (0),
    .s_axis_tuser       (0),

	.m_axis_tdata       (s_phv_info_fifo),
	.m_axis_tvalid      (s_phv_valid_fifo),
	.m_axis_tready      (s_phv_ready_fifo),
    .m_axis_tkeep       (),
    .m_axis_tlast       (),
    .m_axis_tuser       (),
	
	.count              ()
);



/*
EM TABLE
*/
wire 								match_valid;
wire 								match_ready;
wire                    			match_hit;
wire [ADDR_WIDTH-1:0] 		        match_addr;
               
// ########################################### new table ##########################################

localparam FLOWMOD_CONTROLLER_DATA_WIDTH = KEY_WIDTH ;
wire m_mod_ready_em_wire;
wire [FLOWMOD_CONTROLLER_DATA_WIDTH:0] s_mod_bdata_em_wire;
wire s_mod_bvalid_em_wire;
em_table_sub4#(
    .DATA_WIDTH(FLOWMOD_CONTROLLER_DATA_WIDTH),
    .KEY_WIDTH(KEY_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .VALUE_WIDTH(VALUE_WIDTH),
    .OP_WIDTH(OPCODE_WIDTH) 
) em_table_sub4_inst(
    //system signals
    .clk(clk),
    .rst(rst),

    //flowmod
    .s_mod_addr(m_mod_addr_wire),    
    .s_mod_data(m_mod_data_wire),
    .s_mod_opcode(m_mod_opcode_wire),
    .s_mod_valid(m_mod_valid_wire && m_mod_opcode_wire[3:2]!=2'b11),
    .s_mod_ready(m_mod_ready_em_wire),

   //match key
    .s_mat_key(m_key_info),
    .s_mat_valid(m_key_valid),
    .s_mat_ready(m_key_ready),

   //match result
    .m_mat_ready(match_ready),
    .m_mat_valid(match_valid),
    .m_mat_hit(match_hit),
    .m_mat_value(),
    .m_mat_addr(match_addr),

    //read back
    .m_mod_bdata(s_mod_bdata_em_wire),
    .m_mod_bvalid(s_mod_bvalid_em_wire),
    .m_mod_bready(s_mod_bready_wire) 
);



/*
ACTION UNIT
*/
wire m_mod_ready_state_wire;
wire [FLOWMOD_CONTROLLER_DATA_WIDTH:0] s_mod_bdata_state_wire;
wire s_mod_bvalid_state_wire;
reliable_send_action_core #(
	.VALUE_WIDTH					(FLOWSTATE_WIDTH),
	.ADDR_WIDTH						(ADDR_WIDTH),
    .FLOWSTATE_WIDTH                (FLOWSTATE_WIDTH),

    .PHV_B_COUNT                    (PHV_B_COUNT),    
	.PHV_H_COUNT                    (PHV_H_COUNT),
	.PHV_W_COUNT                    (PHV_W_COUNT),

	.PHV_WIDTH						(PHV_WIDTH)
) action_unit_inst (
	.clk							(clk),
	.rst							(rst),
    .reliable_enable                (reliable_enable),

    .s_mod_addr                     (m_mod_addr_wire),                     
    .s_mod_data                     (m_mod_data_wire),                 
    .s_mod_opcode                   (m_mod_opcode_wire),                   
    .s_mod_valid                    (m_mod_valid_wire && m_mod_opcode_wire[3:2]==2'b11),                    
    .s_mod_ready                    (m_mod_ready_state_wire), 

    .m_mod_bdata                    (s_mod_bdata_state_wire),
    .m_mod_bvalid                   (s_mod_bvalid_state_wire),
    .m_mod_bready                   (s_mod_bready_wire), 

	.s_phv_valid					(s_phv_valid_fifo),
	.s_phv_ready					(s_phv_ready_fifo),
	.s_phv_info						(s_phv_info_fifo),

    .s_mat_ready    				(match_ready),      
    .s_mat_valid    				(match_valid),      
    .s_mat_hit         				(match_hit),      
    // .s_mat_value    				(match_value),      
    .s_mat_addr     				(match_addr),

	.m_phv_valid					(m_phv_valid),
	.m_phv_ready					(m_phv_ready),
	.m_phv_info						(m_phv_info)
);


// ############################################  new control #################################################


flowmod_controller#(
    .AXIL_CTRL_ADDR_WIDTH(CSR_ADDR_WIDTH),
    .AXIL_CTRL_DATA_WIDTH(CSR_DATA_WIDTH),
    .AXIL_CTRL_STRB_WIDTH(CSR_STRB_WIDTH),
    .ADDR_WIDTH(FLOWMOD_CONTROLLER_ADDR_WIDTH),
    .DATA_WIDTH(FLOWMOD_CONTROLLER_DATA_WIDTH+1),
    .OPCODE_WIDTH(OPCODE_WIDTH),
    .CTRL_REG_ADDR(12'h800)
) flowmod_controller_inst (
    // system signal
    .clk(clk),
    .rst(rst),

    // csr interface
    .ctrl_reg_app_wr_addr(ctrl_reg_app_wr_addr),
    .ctrl_reg_app_wr_data(ctrl_reg_app_wr_data),
    .ctrl_reg_app_wr_strb(ctrl_reg_app_wr_strb),
    .ctrl_reg_app_wr_en(ctrl_reg_app_wr_en),
    .ctrl_reg_app_wr_wait(ctrl_reg_app_wr_wait),
    .ctrl_reg_app_wr_ack(csr_wr_ack_rbtrx),
    .ctrl_reg_app_rd_addr(ctrl_reg_app_rd_addr),
    .ctrl_reg_app_rd_en(ctrl_reg_app_rd_en),
    .ctrl_reg_app_rd_data(csr_rd_data_rbtrx),
    .ctrl_reg_app_rd_wait(ctrl_reg_app_rd_wait),
    .ctrl_reg_app_rd_ack(csr_rd_ack_rbtrx),

    // flowmod
    .m_mod_addr(m_mod_addr_wire),
    .m_mod_data(m_mod_data_wire),
    .m_mod_opcode(m_mod_opcode_wire),
    .m_mod_valid(m_mod_valid_wire),
    .m_mod_ready((m_mod_opcode_wire[3:2]!=2'b11) ? m_mod_ready_em_wire : m_mod_ready_state_wire),

    // flowmod readback
    .s_mod_bdata(s_mod_bvalid_em_wire ? s_mod_bdata_em_wire : s_mod_bdata_state_wire),
    .s_mod_bvalid(s_mod_bvalid_em_wire ||s_mod_bvalid_state_wire),
    .s_mod_bready(s_mod_bready_wire)
);

reg reliable_ctl_reg=1'b1;
reg csr_rd_ack_reg,csr_wr_ack_reg;
reg  [CSR_DATA_WIDTH-1:0]   csr_rd_data_reg;


assign ctrl_reg_app_rd_ack=csr_rd_ack_reg |csr_rd_ack_rbtrx;
assign ctrl_reg_app_wr_ack=csr_wr_ack_reg |csr_wr_ack_rbtrx;
assign ctrl_reg_app_rd_data=csr_rd_data_reg |csr_rd_data_rbtrx;
assign reliable_enable=reliable_ctl_reg;

always @(posedge clk) begin
    csr_wr_ack_reg <= 1'b0;
    csr_rd_data_reg <= {CSR_DATA_WIDTH{1'b0}};
    csr_rd_ack_reg <= 1'b0;

    if (ctrl_reg_app_wr_en && !csr_wr_ack_reg) begin
        // write operation
        csr_wr_ack_reg <= 1'b1;
        case ({ctrl_reg_app_wr_addr >> 2, 2'b00})
            12'h000: reliable_ctl_reg <= ctrl_reg_app_wr_data[0];

            default: csr_wr_ack_reg <= 1'b0;
        endcase
    end

    if (ctrl_reg_app_rd_en && !csr_rd_ack_reg) begin
        // read operation
        csr_rd_ack_reg <= 1'b1;
        case ({ctrl_reg_app_rd_addr >> 2, 2'b00})
            12'h000: csr_rd_data_reg <= {{(CSR_DATA_WIDTH-1){1'b0}},reliable_ctl_reg};
            default: csr_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst ) begin
        csr_wr_ack_reg <= 1'b0;
        csr_rd_ack_reg <= 1'b0;
        reliable_ctl_reg <= 1'b1;
    end
end

endmodule