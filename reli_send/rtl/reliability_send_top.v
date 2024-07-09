/*
 * Created on 20230531
 *
 * Copyright (c) 2023 IOA UCAS
 *
 * @Filename:   reliability_send_top.v
 * @Author:     songmg
 * @Last edit:
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

module reliability_send_top # (
    parameter DATA_WIDTH            = 128,
    parameter KEEP_ENABLE           = 1,
    parameter KEEP_WIDTH            = DATA_WIDTH/8,
    parameter LAST_ENABLE           = 1,
    parameter ID_WIDTH              = 8,
    parameter DEST_WIDTH            = 4,
    parameter USER_ENABLE           = 1,
    parameter S_USER_WIDTH          = 64,      
    parameter M_USER_WIDTH          = 88,   
    parameter MAX_MTU               = 8192,

    parameter RELI_SEND_DEPTH       = 1024,

    parameter TID_WIDTH             = 8,
    parameter ADDR_WIDTH            = $clog2(RELI_SEND_DEPTH*2),
    parameter KEY_WIDTH             = 256,
    parameter MASK_WIDTH            = KEY_WIDTH,
    parameter VALUE_WIDTH           = 0,
    parameter STATE_WIDTH           = 32,
    parameter OPCODE_WIDTH          = 4,

    parameter FLOWSTATE_WIDTH       = 32,

    parameter CSR_ADDR_WIDTH        = 16,
    parameter CSR_DATA_WIDTH        = 32,
    parameter CSR_STRB_WIDTH        = CSR_DATA_WIDTH/8,

    parameter PIPELINE_OUTPUT       = 2,
    parameter FRAME_FIFO            = 0,
    parameter USER_BAD_FRAME_VALUE  = 1'b1,
    parameter USER_BAD_FRAME_MASK   = 1'b1,
    parameter DROP_OVERSIZE_FRAME   = FRAME_FIFO,
    parameter DROP_BAD_FRAME        = 0,
    parameter DROP_WHEN_FULL        = 0,

    parameter PHV_B_COUNT           = 7,
    parameter PHV_H_COUNT           = 2,
    parameter PHV_W_COUNT           = 10,
    parameter PHV_B_LEN             = 8,
    parameter PHV_H_LEN             = 16,
    parameter PHV_W_LEN             = 32,
    parameter PHV_B_OFFSET          = 0,
    parameter PHV_H_OFFSET          = PHV_B_OFFSET + PHV_B_COUNT*PHV_B_LEN,
    parameter PHV_W_OFFSET          = PHV_H_OFFSET + PHV_H_COUNT*PHV_H_LEN,
    parameter PHV_WIDTH             = PHV_B_COUNT*PHV_B_LEN + PHV_H_COUNT*PHV_H_LEN + PHV_W_COUNT*PHV_W_LEN
) (
    input  wire clk,
    input  wire rst,

    input  wire [DATA_WIDTH-1:0]                s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]                s_axis_tkeep,
    input  wire                                 s_axis_tvalid,
    output wire                                 s_axis_tready,
    input  wire                                 s_axis_tlast,
    input  wire [S_USER_WIDTH-1:0]              s_axis_tuser,

    output wire [DATA_WIDTH-1:0]                m_axis_tdata,
    output wire [KEEP_WIDTH-1:0]                m_axis_tkeep,
    output wire                                 m_axis_tvalid,
    input  wire                                 m_axis_tready,
    output wire                                 m_axis_tlast,
    output wire [M_USER_WIDTH-1:0]              m_axis_tuser,

    input  wire [CSR_ADDR_WIDTH-1:0]            ctrl_reg_app_wr_addr,
    input  wire [CSR_DATA_WIDTH-1:0]            ctrl_reg_app_wr_data,
    input  wire [CSR_STRB_WIDTH-1:0]            ctrl_reg_app_wr_strb,
    input  wire                                 ctrl_reg_app_wr_en,
    output wire                                 ctrl_reg_app_wr_wait,
    output wire                                 ctrl_reg_app_wr_ack,

    input  wire [CSR_ADDR_WIDTH-1:0]            ctrl_reg_app_rd_addr,
    input  wire                                 ctrl_reg_app_rd_en,
    output wire [CSR_DATA_WIDTH-1:0]            ctrl_reg_app_rd_data,
    output wire                                 ctrl_reg_app_rd_wait,
    output wire                                 ctrl_reg_app_rd_ack
);



wire [PHV_WIDTH-1:0] phv_info;
wire                 phv_valid;
wire                 phv_ready;
/*
 * 1. Parser
 */
wire [DATA_WIDTH-1:0]           axis_psr_tdata;
wire [KEEP_WIDTH-1:0]           axis_psr_tkeep;
wire                            axis_psr_tvalid;
wire                            axis_psr_tready;
wire                            axis_psr_tlast;
wire [S_USER_WIDTH-1:0]         axis_psr_tuser;

wire                            csr_psr_wr_wait;
wire                            csr_psr_wr_ack;
wire [CSR_DATA_WIDTH-1:0]       csr_psr_rd_data;
wire                            csr_psr_rd_wait;
wire                            csr_psr_rd_ack;

rbt_s_parser_top #(
    .DATA_WIDTH                 (DATA_WIDTH),
    .KEEP_WIDTH                 (KEEP_WIDTH),
    .USER_WIDTH                 (S_USER_WIDTH),
    .PHV_B_NUM                  (PHV_B_COUNT),
    .PHV_H_NUM                  (PHV_H_COUNT),
    .PHV_W_NUM                  (PHV_W_COUNT),
    .PHV_WIDTH                  (PHV_WIDTH),
    .DEPTH                      (MAX_MTU)
) parser_inst(
    .clk                        (clk),
    .rst                        (rst),

    .s_axis_tdata               (s_axis_tdata),
    .s_axis_tkeep               (s_axis_tkeep),
    .s_axis_tvalid              (s_axis_tvalid),
    .s_axis_tready              (s_axis_tready),
    .s_axis_tlast               (s_axis_tlast),
    .s_axis_tuser               (s_axis_tuser),

    .m_axis_tdata               (axis_psr_tdata),
    .m_axis_tkeep               (axis_psr_tkeep),
    .m_axis_tvalid              (axis_psr_tvalid),
    .m_axis_tready              (axis_psr_tready),
    .m_axis_tlast               (axis_psr_tlast),
    .m_axis_tuser               (axis_psr_tuser),

    .csr_wr_addr                (ctrl_reg_app_wr_addr),
    .csr_wr_data                (ctrl_reg_app_wr_data),
    .csr_wr_strb                (ctrl_reg_app_wr_strb),
    .csr_wr_en                  (ctrl_reg_app_wr_en && ((ctrl_reg_app_wr_addr >> 12) == 16'h1)),
    .csr_wr_wait                (csr_psr_wr_wait),
    .csr_wr_ack                 (csr_psr_wr_ack),

    .csr_rd_addr                (ctrl_reg_app_rd_addr),
    .csr_rd_en                  (ctrl_reg_app_rd_en && ((ctrl_reg_app_rd_addr >> 12) == 16'h1)),
    .csr_rd_wait                (csr_psr_rd_wait),
    .csr_rd_data                (csr_psr_rd_data),
    .csr_rd_ack                 (csr_psr_rd_ack),
    
    .m_phv_info                 (phv_info),
    .m_phv_valid                (phv_valid),
    .m_phv_ready                (phv_ready)
);

/*
 * 1.1. AXIS_FIFO
 */
wire [DATA_WIDTH-1:0]           axis_fifo_tdata;
wire [KEEP_WIDTH-1:0]           axis_fifo_tkeep;
wire                            axis_fifo_tvalid;
wire                            axis_fifo_tready;
wire                            axis_fifo_tlast;
wire [S_USER_WIDTH-1:0]         axis_fifo_tuser;

axis_fifo #(
    .DEPTH(MAX_MTU),
    .DATA_WIDTH(DATA_WIDTH),
    .KEEP_ENABLE(KEEP_ENABLE),
    .KEEP_WIDTH(KEEP_WIDTH),
    .LAST_ENABLE(LAST_ENABLE),
    .ID_ENABLE(0),
    .ID_WIDTH(ID_WIDTH),
    .DEST_ENABLE(0),
    .DEST_WIDTH(DEST_WIDTH),
    .USER_ENABLE(USER_ENABLE),
    .USER_WIDTH(S_USER_WIDTH),
    .PIPELINE_OUTPUT(PIPELINE_OUTPUT),
    .FRAME_FIFO(FRAME_FIFO),
    .USER_BAD_FRAME_VALUE(USER_BAD_FRAME_VALUE),
    .USER_BAD_FRAME_MASK(USER_BAD_FRAME_MASK),
    .DROP_OVERSIZE_FRAME(DROP_OVERSIZE_FRAME),
    .DROP_BAD_FRAME(DROP_BAD_FRAME),
    .DROP_WHEN_FULL(DROP_WHEN_FULL)
)
axis_fifo_inst (
    .clk(clk),
    .rst(rst),

    .s_axis_tdata(axis_psr_tdata),
    .s_axis_tvalid(axis_psr_tvalid),
    .s_axis_tready(axis_psr_tready),
    .s_axis_tkeep(axis_psr_tkeep),
    .s_axis_tlast(axis_psr_tlast),
    .s_axis_tuser(axis_psr_tuser),

	.m_axis_tdata(axis_fifo_tdata),
	.m_axis_tvalid(axis_fifo_tvalid),
	.m_axis_tready(axis_fifo_tready),
    .m_axis_tkeep(axis_fifo_tkeep),
    .m_axis_tlast(axis_fifo_tlast),
    .m_axis_tuser(axis_fifo_tuser),
	
	.status_overflow(),
	.status_bad_frame(),
	.status_good_frame()
);

/*
 * 1.2 rbttx_table 
 */


wire [PHV_WIDTH-1:0] phv_mau_info;
wire                 phv_mau_valid;
wire                 phv_mau_ready;

// ####################################### new flowmod ######################################

wire                        csr_mau_wr_wait;
wire                        csr_mau_wr_ack;
wire [CSR_DATA_WIDTH-1:0]   csr_mau_rd_data;
wire                        csr_mau_rd_wait;
wire                        csr_mau_rd_ack;

mau_rbttx_top #(
    .KEY_WIDTH                     (KEY_WIDTH),
    .VALUE_WIDTH                   (VALUE_WIDTH),
    .OPCODE_WIDTH                  (OPCODE_WIDTH),
    .ADDR_WIDTH                    (ADDR_WIDTH),
    .PHV_B_COUNT                   (PHV_B_COUNT),
    .PHV_H_COUNT                   (PHV_H_COUNT),
    .PHV_W_COUNT                   (PHV_W_COUNT),
    .PHV_WIDTH                     (PHV_WIDTH)
) mau_rbttx_inst (
    .clk                    (clk),
    .rst                    (rst),

    .ctrl_reg_app_wr_addr            (ctrl_reg_app_wr_addr),
    .ctrl_reg_app_wr_data            (ctrl_reg_app_wr_data),
    .ctrl_reg_app_wr_strb            (ctrl_reg_app_wr_strb),
    .ctrl_reg_app_wr_en              (ctrl_reg_app_wr_en && ((ctrl_reg_app_wr_addr >> 12) == 16'h2) || ((ctrl_reg_app_wr_addr >> 12) == 16'h7)),
    .ctrl_reg_app_wr_wait            (csr_mau_wr_wait),
    .ctrl_reg_app_wr_ack             (csr_mau_wr_ack),

    .ctrl_reg_app_rd_addr            (ctrl_reg_app_rd_addr),
    .ctrl_reg_app_rd_en              (ctrl_reg_app_rd_en && ((ctrl_reg_app_rd_addr >> 12) == 16'h2) || ((ctrl_reg_app_wr_addr >> 12) == 16'h7)),
    .ctrl_reg_app_rd_wait            (csr_mau_rd_wait),
    .ctrl_reg_app_rd_data            (csr_mau_rd_data),
    .ctrl_reg_app_rd_ack             (csr_mau_rd_ack),

    .s_phv_info                     (phv_info       ),
    .s_phv_valid                    (phv_valid      ),
    .s_phv_ready                    (phv_ready      ),

    .m_phv_info                     (phv_mau_info       ),
    .m_phv_valid                    (phv_mau_valid      ),
    .m_phv_ready                    (phv_mau_ready      )
);


/*
 * 1.3. deparser
*/
wire csr_deparser_wr_wait;
wire csr_deparser_wr_ack;
wire [CSR_DATA_WIDTH-1:0] csr_deparser_rd_data;
wire csr_deparser_rd_wait;
wire csr_deparser_rd_ack;
seanet_rbttx_deparser_top # (
    .DATA_WIDTH                 (DATA_WIDTH),
    .KEEP_WIDTH                 (KEEP_WIDTH),
    .S_USER_WIDTH               (S_USER_WIDTH),
    .M_USER_WIDTH               (M_USER_WIDTH),

    .PHV_B_COUNT                (PHV_B_COUNT),
    .PHV_H_COUNT                (PHV_H_COUNT),
    .PHV_W_COUNT                (PHV_W_COUNT),
    .PHV_WIDTH                  (PHV_WIDTH)
) seanet_deparser_inst (
    .clk(clk),
    .rst(rst),

    .csr_wr_addr            (ctrl_reg_app_wr_addr),
    .csr_wr_data            (ctrl_reg_app_wr_data),
    .csr_wr_strb            (ctrl_reg_app_wr_strb),
    .csr_wr_en              (ctrl_reg_app_wr_en && ((ctrl_reg_app_wr_addr >> 12) == 16'h7)),
    .csr_wr_wait            (csr_deparser_wr_wait),
    .csr_wr_ack             (csr_deparser_wr_ack),

    .csr_rd_addr            (ctrl_reg_app_rd_addr),
    .csr_rd_en              (ctrl_reg_app_rd_en && ((ctrl_reg_app_rd_addr >> 12) == 16'h7)),
    .csr_rd_wait            (csr_deparser_rd_wait),
    .csr_rd_data            (csr_deparser_rd_data),
    .csr_rd_ack             (csr_deparser_rd_ack),

    .s_phv_info                 (phv_mau_info),
    .s_phv_valid                (phv_mau_valid),
    .s_phv_ready                (phv_mau_ready),

    .s_axis_tdata               (axis_fifo_tdata),
    .s_axis_tkeep               (axis_fifo_tkeep),
    .s_axis_tvalid              (axis_fifo_tvalid),
    .s_axis_tready              (axis_fifo_tready),
    .s_axis_tlast               (axis_fifo_tlast),
    .s_axis_tuser               (axis_fifo_tuser),

    .m_axis_tdata               (m_axis_tdata),
    .m_axis_tkeep               (m_axis_tkeep),
    .m_axis_tvalid              (m_axis_tvalid),
    .m_axis_tready              (m_axis_tready),
    .m_axis_tlast               (m_axis_tlast),
    .m_axis_tuser               (m_axis_tuser)

);

/*
 * a. Control Status Registers (CSR) implementation.
 */
//reg                       csr_wr_wait_reg;
reg                         csr_wr_ack_reg;
reg  [CSR_DATA_WIDTH-1:0]   csr_rd_data_reg;
//reg                       csr_rd_wait_reg;
reg                         csr_rd_ack_reg;

assign ctrl_reg_app_wr_wait  = 1'b0            | csr_psr_wr_wait | csr_mau_wr_wait | csr_deparser_wr_wait;
assign ctrl_reg_app_wr_ack   = csr_wr_ack_reg  | csr_psr_wr_ack  | csr_mau_wr_ack  | csr_deparser_wr_ack ;
assign ctrl_reg_app_rd_data  = csr_rd_data_reg | csr_psr_rd_data | csr_mau_rd_data | csr_deparser_rd_data;
assign ctrl_reg_app_rd_wait  = 1'b0            | csr_psr_rd_wait | csr_mau_rd_wait | csr_deparser_rd_wait;
assign ctrl_reg_app_rd_ack   = csr_rd_ack_reg  | csr_psr_rd_ack  | csr_mau_rd_ack  | csr_deparser_rd_ack ;
  
reg [CSR_DATA_WIDTH-1:0] csr_example_reg;
reg csr_rst_reg;
reg csr_clear_reg;

reg [CSR_DATA_WIDTH-1:0] csr_rbttx_in_count_reg;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_out_count_reg;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_in_tuser_reg;
reg [M_USER_WIDTH-1:0]   csr_rbttx_out_tuser_reg;

//`ifdef TB
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_b_0_1_4_5;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_b_6_7_8_9;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_h;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_w_0;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_w_1;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_w_2;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_w_3;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_w_4;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_w_5;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_w_6;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_w_7;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_w_8;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_w_9;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_w_10;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_w_11;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_w_12;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_in_w_13;

reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_b_0_1_4_5;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_b_6_7_8_9;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_h;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_w_0;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_w_1;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_w_2;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_w_3;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_w_4;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_w_5;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_w_6;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_w_7;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_w_8;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_w_9;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_w_10;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_w_11;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_w_12;
reg [CSR_DATA_WIDTH-1:0] csr_rbttx_phv_out_w_13;
//`else
//
//`endif 

always@(posedge clk) begin
    if (rst) begin
        csr_rbttx_in_count_reg <= 0;
        csr_rbttx_in_tuser_reg <= 0;
    end else begin
        if (s_axis_tvalid && s_axis_tready && s_axis_tlast) begin
            csr_rbttx_in_count_reg <= csr_rbttx_in_count_reg + 1;
            csr_rbttx_in_tuser_reg <= s_axis_tuser[31:0];
        end else begin
            csr_rbttx_in_count_reg <= csr_rbttx_in_count_reg;
            csr_rbttx_in_tuser_reg <= csr_rbttx_in_tuser_reg;
        end
    end
end

always@(posedge clk) begin
    if (rst) begin
        csr_rbttx_out_count_reg <= 0;
        csr_rbttx_out_tuser_reg <= 0;
    end else begin
        if (m_axis_tvalid && m_axis_tready && m_axis_tlast) begin
            csr_rbttx_out_count_reg <= csr_rbttx_out_count_reg + 1;
            csr_rbttx_out_tuser_reg <= m_axis_tuser;
        end else begin
            csr_rbttx_out_count_reg <= csr_rbttx_out_count_reg;
            csr_rbttx_out_tuser_reg <= csr_rbttx_out_tuser_reg;
        end
    end
end
`ifdef TB
always@(posedge clk) begin
    if (phv_mau_valid && phv_mau_ready) begin
        csr_rbttx_phv_out_b_0_1_4_5 <= {phv_mau_info[47:40],phv_mau_info[39:32],phv_mau_info[15:0],phv_mau_info[7:0]};
        csr_rbttx_phv_out_b_6_7_8_9 <= phv_mau_info[79:48];
        csr_rbttx_phv_out_h <= phv_mau_info[111:80];
        csr_rbttx_phv_out_w_0 <= phv_mau_info[143:112];
        csr_rbttx_phv_out_w_1 <= phv_mau_info[175:144];
        csr_rbttx_phv_out_w_2 <= phv_mau_info[207:176];
        csr_rbttx_phv_out_w_3 <= phv_mau_info[239:208];
        csr_rbttx_phv_out_w_4 <= phv_mau_info[271:240];
        csr_rbttx_phv_out_w_5 <= phv_mau_info[303:272];
        csr_rbttx_phv_out_w_6 <= phv_mau_info[335:304];
        csr_rbttx_phv_out_w_7 <= phv_mau_info[367:336];
        csr_rbttx_phv_out_w_8 <= phv_mau_info[399:368];
        csr_rbttx_phv_out_w_9 <= phv_mau_info[431:400];
        csr_rbttx_phv_out_w_10 <= phv_mau_info[463:432];
        csr_rbttx_phv_out_w_11 <= phv_mau_info[495:464];
        csr_rbttx_phv_out_w_12 <= phv_mau_info[527:496];
        csr_rbttx_phv_out_w_13 <= phv_mau_info[559:528];
    end

    if (rst) begin
        csr_rbttx_phv_out_b_0_1_4_5 <= 0;
        csr_rbttx_phv_out_b_6_7_8_9 <= 0;
        csr_rbttx_phv_out_h <= 0;
        csr_rbttx_phv_out_w_0 <= 0;
        csr_rbttx_phv_out_w_1 <= 0;
        csr_rbttx_phv_out_w_2 <= 0;
        csr_rbttx_phv_out_w_3 <= 0;
        csr_rbttx_phv_out_w_4 <= 0;
        csr_rbttx_phv_out_w_5 <= 0;
        csr_rbttx_phv_out_w_6 <= 0;
        csr_rbttx_phv_out_w_7 <= 0;
        csr_rbttx_phv_out_w_8 <= 0;
        csr_rbttx_phv_out_w_9 <= 0;
        csr_rbttx_phv_out_w_10 <= 0;
        csr_rbttx_phv_out_w_11 <= 0;
        csr_rbttx_phv_out_w_12 <= 0;
        csr_rbttx_phv_out_w_13 <= 0;
    end
end
`else
//
`endif 

always @(posedge clk) begin
    csr_wr_ack_reg <= 1'b0;
    csr_rd_data_reg <= {CSR_DATA_WIDTH{1'b0}};
    csr_rd_ack_reg <= 1'b0;

    if (ctrl_reg_app_wr_en && !csr_wr_ack_reg) begin
        // write operation
        csr_wr_ack_reg <= 1'b1;
        case ({ctrl_reg_app_wr_addr >> 2, 2'b00})
            16'h0000: csr_example_reg           <= ctrl_reg_app_wr_data;
            16'h0004: csr_rst_reg               <= ctrl_reg_app_wr_data;
            16'h0008: csr_clear_reg             <= ctrl_reg_app_wr_data;

            default: csr_wr_ack_reg <= 1'b0;
        endcase
    end

    if (ctrl_reg_app_rd_en && !csr_rd_ack_reg) begin
        // read operation
        csr_rd_ack_reg <= 1'b1;
        case ({ctrl_reg_app_rd_addr >> 2, 2'b00})
            16'h0000: csr_rd_data_reg <= csr_example_reg;
            16'h0004: csr_rd_data_reg <= csr_rst_reg;
            16'h0008: csr_rd_data_reg <= csr_clear_reg;

            16'h0010: csr_rd_data_reg <= csr_rbttx_in_count_reg;
            16'h0014: csr_rd_data_reg <= csr_rbttx_in_tuser_reg;
            16'h0018: csr_rd_data_reg <= csr_rbttx_out_count_reg;
            16'h001c: csr_rd_data_reg <= csr_rbttx_out_tuser_reg[31:0];

            16'h0020: csr_rd_data_reg <= csr_rbttx_out_tuser_reg[63:32];
            16'h0024: csr_rd_data_reg <= {phv_ready, phv_mau_ready,axis_psr_tready, axis_fifo_tready, s_axis_tready, m_axis_tready};
            `ifdef TB
            16'h0028: csr_rd_data_reg <= csr_rbttx_phv_in_b_0_1_4_5;
            16'h002c: csr_rd_data_reg <= csr_rbttx_phv_in_b_6_7_8_9;

            16'h0030: csr_rd_data_reg <= csr_rbttx_phv_in_h;
            16'h0034: csr_rd_data_reg <= csr_rbttx_phv_in_w_0;
            16'h0038: csr_rd_data_reg <= csr_rbttx_phv_in_w_1;
            16'h003c: csr_rd_data_reg <= csr_rbttx_phv_in_w_2;

            16'h0040: csr_rd_data_reg <= csr_rbttx_phv_in_w_3;
            16'h0044: csr_rd_data_reg <= csr_rbttx_phv_in_w_4;
            16'h0048: csr_rd_data_reg <= csr_rbttx_phv_in_w_5;
            16'h004c: csr_rd_data_reg <= csr_rbttx_phv_in_w_6;

            16'h0050: csr_rd_data_reg <= csr_rbttx_phv_in_w_7;
            16'h0054: csr_rd_data_reg <= csr_rbttx_phv_in_w_8;
            16'h0058: csr_rd_data_reg <= csr_rbttx_phv_in_w_9;
            16'h005c: csr_rd_data_reg <= csr_rbttx_phv_in_w_10;

            16'h0060: csr_rd_data_reg <= csr_rbttx_phv_in_w_11;
            16'h0064: csr_rd_data_reg <= csr_rbttx_phv_in_w_12;
            16'h0068: csr_rd_data_reg <= csr_rbttx_phv_in_w_13;
            16'h006c: csr_rd_data_reg <= csr_rbttx_phv_out_b_0_1_4_5;

            16'h0070: csr_rd_data_reg <= csr_rbttx_phv_out_b_6_7_8_9;
            16'h0074: csr_rd_data_reg <= csr_rbttx_phv_out_h;
            16'h0078: csr_rd_data_reg <= csr_rbttx_phv_out_w_0;
            16'h007c: csr_rd_data_reg <= csr_rbttx_phv_out_w_1;

            16'h0080: csr_rd_data_reg <= csr_rbttx_phv_out_w_2;
            16'h0084: csr_rd_data_reg <= csr_rbttx_phv_out_w_3;
            16'h0088: csr_rd_data_reg <= csr_rbttx_phv_out_w_4;
            16'h008c: csr_rd_data_reg <= csr_rbttx_phv_out_w_5;

            16'h0090: csr_rd_data_reg <= csr_rbttx_phv_out_w_6;
            16'h0094: csr_rd_data_reg <= csr_rbttx_phv_out_w_7;
            16'h0098: csr_rd_data_reg <= csr_rbttx_phv_out_w_8;
            16'h009c: csr_rd_data_reg <= csr_rbttx_phv_out_w_9;

            16'h00a0: csr_rd_data_reg <= csr_rbttx_phv_out_w_10;
            16'h00a4: csr_rd_data_reg <= csr_rbttx_phv_out_w_11;
            16'h00a8: csr_rd_data_reg <= csr_rbttx_phv_out_w_12;
            16'h00ac: csr_rd_data_reg <= csr_rbttx_phv_out_w_13;
            `else
            //
            `endif 

            default: csr_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst || csr_rst_reg || csr_clear_reg) begin
        csr_wr_ack_reg <= 1'b0;
        csr_rd_ack_reg <= 1'b0;
        csr_clear_reg <= 1'b0;
        csr_rst_reg <= 1'b0;
        csr_example_reg <= 'h12345678;
    end
end

endmodule

`resetall
