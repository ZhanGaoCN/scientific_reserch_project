`timescale 1ns / 1ps
`default_nettype none

/*
 * recv and parse proto header, transfer into pkt info(metadata/phv)
 * input
 * 1, axis start from proto(eth) header
 * output
 * 1, axis start from proto(eth) header, without cutoff
 * 2, pkt info(metadata/phv)
 */
module rbt_s_parser_top #
(
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 512,
    // Propagate tkeep signal
    // If disabled, tkeep assumed to be 1'b1
    parameter KEEP_ENABLE = (DATA_WIDTH>8),
    // tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = (DATA_WIDTH/8),
 //width of route
    // parameter ROUTE_OFFSET = 0,
    // parameter ROUTE_WIDTH = 8,
    // //width of START_TABLE
    // parameter START_TABLE_OFFSET = ROUTE_OFFSET + 2*ROUTE_WIDTH,
    // parameter START_TABLE_WIDTH = 8,
    // //width of PKT_PROPERTY
    // parameter PKT_PROPERTY_OFFSET = ROUTE_OFFSET + 2*ROUTE_WIDTH +START_TABLE_WIDTH,
    // parameter PKT_PROPERTY_WIDTH = 8, 

    // //width of PKT_LENGTH
    // parameter PKT_LENGTH_OFFSET = ROUTE_OFFSET + 2*ROUTE_WIDTH +START_TABLE_WIDTH + PKT_PROPERTY_WIDTH,
    // parameter PKT_LENGTH_WIDTH = 16,       

    parameter USER_ENABLE = 1,
    parameter USER_WIDTH =64,

    // transfer metadata to MAT
    parameter HEADER_WIDTH = 2048,
    parameter PHV_WIDTH = 408, //modified to 0.93
    parameter PHV_B_LEN = 8,
    parameter PHV_H_LEN = 16,
    parameter PHV_W_LEN = 32,
    parameter PHV_B_NUM = 7,
    parameter PHV_H_NUM = 2,
    parameter PHV_W_NUM = 10,
    parameter PHV_B_OFFSET = 0,
    parameter PHV_H_OFFSET = PHV_B_OFFSET + PHV_B_NUM*PHV_B_LEN,
    parameter PHV_W_OFFSET = PHV_H_OFFSET + PHV_H_NUM*PHV_H_LEN,

    //pkt_hdr data


    parameter CSR_ADDR_WIDTH        = 8,
    parameter CSR_DATA_WIDTH        = 32,
    parameter CSR_STRB_WIDTH        = CSR_DATA_WIDTH/8,

    parameter DEPTH = 8192,
    parameter LAST_ENABLE = 1,
    parameter ID_ENABLE = 0,
    parameter ID_WIDTH = 8,
    parameter DEST_ENABLE = 0,
    parameter DEST_WIDTH = 8,
    parameter PIPELINE_OUTPUT = 2,
    parameter FRAME_FIFO = 0,
    parameter USER_BAD_FRAME_VALUE = 1'b1,
    parameter USER_BAD_FRAME_MASK = 1'b1,
    parameter DROP_OVERSIZE_FRAME = FRAME_FIFO,
    parameter DROP_BAD_FRAME = 0,
    parameter DROP_WHEN_FULL = 0
)
(
    input  wire                     clk,
    input  wire                     rst,
    
    /*
     * AXIS input
     */
    input  wire [DATA_WIDTH-1:0]    s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]    s_axis_tkeep,
    input  wire                     s_axis_tvalid,
    output wire                     s_axis_tready,
    input  wire                     s_axis_tlast,
    input  wire [USER_WIDTH-1:0]    s_axis_tuser,
    /*
     * AXIS payload output
     */
    output wire [DATA_WIDTH-1:0]    m_axis_tdata,
    output wire [KEEP_WIDTH-1:0]    m_axis_tkeep,
    output wire                     m_axis_tvalid,
    input  wire                     m_axis_tready,
    output wire                     m_axis_tlast,
    output wire [USER_WIDTH-1:0]    m_axis_tuser,

    /*
     * Control register interface
     */
    input  wire [CSR_ADDR_WIDTH-1:0]            csr_wr_addr,
    input  wire [CSR_DATA_WIDTH-1:0]            csr_wr_data,
    input  wire [CSR_STRB_WIDTH-1:0]            csr_wr_strb,
    input  wire                                 csr_wr_en,
    output wire                                 csr_wr_wait,
    output wire                                 csr_wr_ack,

    input  wire [CSR_ADDR_WIDTH-1:0]            csr_rd_addr,
    input  wire                                 csr_rd_en,
    output wire                                 csr_rd_wait,
    output wire [CSR_DATA_WIDTH-1:0]            csr_rd_data,
    output wire                                 csr_rd_ack,     /* FIXME: no backpressure. */

    /*
     * pkt info output
     */
    output wire                             m_phv_valid,
    input  wire                             m_phv_ready,
    output wire [PHV_WIDTH-1:0]             m_phv_info
);
`define SEAID_160

// bus width assertions
initial begin
    if (KEEP_WIDTH * 8 != DATA_WIDTH) begin
        $error("Error: AXI stream interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end
end


wire [DATA_WIDTH-1:0]            m_axis_extract_tdata;
wire [KEEP_WIDTH-1:0]            m_axis_extract_tkeep;
wire                             m_axis_extract_tvalid;
wire                             m_axis_extract_tready;
wire                             m_axis_extract_tlast;
wire [USER_WIDTH-1:0]            m_axis_extract_tuser;

wire                             extract_proto_hdr_valid;
wire                             extract_proto_hdr_ready;
wire [15:0]                      extract_proto_hdr_length;
wire [15:0]                      extract_proto_hdr_pktlen;
wire [HEADER_WIDTH-1:0]          extract_proto_hdr_data;
wire [USER_WIDTH-1:0]            extract_proto_hdr_tuser;


wire                        status_overflow;
wire                        status_bad_frame;
wire                        status_good_frame;



parser_extract_header #(
    .DATA_WIDTH(DATA_WIDTH),
    .USER_ENABLE(USER_ENABLE),
    .USER_WIDTH(USER_WIDTH),
    .HEADER_WIDTH(HEADER_WIDTH)
)
rbt_s_idp_extract_header_inst (
    .clk(clk),
    .rst(rst),

    .s_axis_tdata(s_axis_tdata),
    .s_axis_tkeep(s_axis_tkeep),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tuser(s_axis_tuser),
    
    .m_axis_tdata(m_axis_extract_tdata),
    .m_axis_tkeep(m_axis_extract_tkeep),
    .m_axis_tvalid(m_axis_extract_tvalid),
    .m_axis_tready(m_axis_extract_tready),
    .m_axis_tlast(m_axis_extract_tlast),
    .m_axis_tuser(m_axis_extract_tuser),  

    .m_proto_hdr_valid(extract_proto_hdr_valid),
    .m_proto_hdr_ready(extract_proto_hdr_ready),
    .m_proto_hdr_data(extract_proto_hdr_data),
    .m_proto_hdr_length(extract_proto_hdr_length),
    .m_proto_hdr_pktlen(extract_proto_hdr_pktlen),
    .m_proto_hdr_tuser(extract_proto_hdr_tuser),

    .busy(),
    .error_header_early_termination()
);

assign m_axis_tdata  = m_axis_extract_tdata;
assign m_axis_tkeep  = m_axis_extract_tkeep;
assign m_axis_tvalid = m_axis_extract_tvalid;
assign m_axis_extract_tready = m_axis_tready;
assign m_axis_tlast  = m_axis_extract_tlast;
assign m_axis_tuser  = 0;


wire                    idp_phv_init_valid;
wire                    idp_phv_init_ready;
wire [HEADER_WIDTH-1:0] idp_phv_init_data;
wire [PHV_WIDTH-1:0]    idp_phv_init_phv;
wire [15:0]             idp_phv_init_length;

rbt_s_pre_parser #(
    .HEADER_WIDTH(HEADER_WIDTH),
    .META_WIDTH(32),
    .USER_WIDTH(USER_WIDTH),
    .PHV_WIDTH(PHV_WIDTH),
    .PHV_B_NUM(PHV_B_NUM),
    .PHV_H_NUM(PHV_H_NUM),
    .PHV_W_NUM(PHV_W_NUM)
)
rbt_s_pre_parser_inst (
    .clk(clk),
    .rst(rst),

    .in_proto_hdr_valid (extract_proto_hdr_valid),
    .in_proto_hdr_ready (extract_proto_hdr_ready),
    .in_proto_hdr_data  (extract_proto_hdr_data),
    .in_proto_hdr_length(extract_proto_hdr_length),
    .in_proto_hdr_pktlen(extract_proto_hdr_pktlen),
    .in_proto_hdr_tuser (extract_proto_hdr_tuser),
    .in_proto_hdr_meta  (csr_device_id_reg),

    .out_proto_hdr_valid   (idp_phv_init_valid),
    .out_proto_hdr_ready   (idp_phv_init_ready),
    .out_proto_hdr_data    (idp_phv_init_data),
    .out_proto_hdr_length  (idp_phv_init_length),
    .out_proto_hdr_phv     (idp_phv_init_phv)
);


wire                    eth_out_hdr_valid;
wire                    eth_out_hdr_ready;
wire [HEADER_WIDTH-1:0] eth_out_hdr_data;
wire [PHV_WIDTH-1:0]    eth_out_hdr_phv;
wire [15:0]             eth_out_hdr_length;

// maybe need syn the header and phv input

rbt_s_eth_parser #(
    .HEADER_WIDTH(HEADER_WIDTH),
    .PHV_WIDTH(PHV_WIDTH),
    .PHV_B_NUM(PHV_B_NUM),
    .PHV_H_NUM(PHV_H_NUM),
    .PHV_W_NUM(PHV_W_NUM)
)
rbt_s_eth_parser_inst (
    .clk(clk),
    .rst(rst),

    .in_proto_hdr_valid (idp_phv_init_valid),
    .in_proto_hdr_ready (idp_phv_init_ready),
    .in_proto_hdr_data  (idp_phv_init_data),
    .in_proto_hdr_length(idp_phv_init_length),
    .in_proto_hdr_phv   (idp_phv_init_phv),

    .out_proto_hdr_valid   (eth_out_hdr_valid),
    .out_proto_hdr_ready   (eth_out_hdr_ready),
    .out_proto_hdr_data    (eth_out_hdr_data),
    .out_proto_hdr_length  (eth_out_hdr_length),
    .out_proto_hdr_phv     (eth_out_hdr_phv)
    // .debug_PHV_PROTO_ETH(debug_PHV_PROTO_ETH),
    // .debug_ETH_type (debug_ETH_type)
);


wire                    vlan_out_hdr_valid;
wire                    vlan_out_hdr_ready;
wire [HEADER_WIDTH-1:0] vlan_out_hdr_data;
wire [PHV_WIDTH-1:0]    vlan_out_hdr_phv;
wire [15:0]             vlan_out_hdr_length;

rbt_s_vlan_parser #(
    .HEADER_WIDTH(HEADER_WIDTH),
    .PHV_WIDTH(PHV_WIDTH),
    .PHV_B_NUM(PHV_B_NUM),
    .PHV_H_NUM(PHV_H_NUM),
    .PHV_W_NUM(PHV_W_NUM)
)
rbt_s_vlan_parser_inst (
    .clk(clk),
    .rst(rst),

    .in_proto_hdr_valid (eth_out_hdr_valid),
    .in_proto_hdr_ready (eth_out_hdr_ready),
    .in_proto_hdr_data  (eth_out_hdr_data),
    .in_proto_hdr_length(eth_out_hdr_length),
    .in_proto_hdr_phv   (eth_out_hdr_phv),

    .out_proto_hdr_valid   (vlan_out_hdr_valid),
    .out_proto_hdr_ready   (vlan_out_hdr_ready),
    .out_proto_hdr_data    (vlan_out_hdr_data),
    .out_proto_hdr_length  (vlan_out_hdr_length),
    .out_proto_hdr_phv     (vlan_out_hdr_phv)
);

wire                    ipv6_out_hdr_valid;
wire                    ipv6_out_hdr_ready;
wire [HEADER_WIDTH-1:0] ipv6_out_hdr_data;
wire [PHV_WIDTH-1:0]    ipv6_out_hdr_phv;
wire [15:0]             ipv6_out_hdr_length;

rbt_s_ipv6_parser #(
    .HEADER_WIDTH(HEADER_WIDTH),
    .PHV_WIDTH(PHV_WIDTH),
    .PHV_B_NUM(PHV_B_NUM),
    .PHV_H_NUM(PHV_H_NUM),
    .PHV_W_NUM(PHV_W_NUM)
)
rbt_s_ipv6_parser_inst (
    .clk(clk),
    .rst(rst),

    .in_proto_hdr_valid (vlan_out_hdr_valid),
    .in_proto_hdr_ready (vlan_out_hdr_ready),
    .in_proto_hdr_data  (vlan_out_hdr_data),
    .in_proto_hdr_length(vlan_out_hdr_length),
    .in_proto_hdr_phv   (vlan_out_hdr_phv),

    .out_proto_hdr_valid   (ipv6_out_hdr_valid),
    .out_proto_hdr_ready   (ipv6_out_hdr_ready),
    .out_proto_hdr_data    (ipv6_out_hdr_data),
    .out_proto_hdr_length  (ipv6_out_hdr_length),
    .out_proto_hdr_phv     (ipv6_out_hdr_phv)
);

wire                    idp_fix_out_hdr_valid;
wire                    idp_fix_out_hdr_ready;
wire [HEADER_WIDTH-1:0] idp_fix_out_hdr_data;
wire [PHV_WIDTH-1:0]    idp_fix_out_hdr_phv;
wire [15:0]             idp_fix_out_hdr_length;

rbt_s_idp_fix_parser #(
    .HEADER_WIDTH(HEADER_WIDTH),
    .PHV_WIDTH(PHV_WIDTH),
    .PHV_B_NUM(PHV_B_NUM),
    .PHV_H_NUM(PHV_H_NUM),
    .PHV_W_NUM(PHV_W_NUM)
)
rbt_s_idp_fix_parser_inst (
    .clk(clk),
    .rst(rst),

    .in_proto_hdr_valid (ipv6_out_hdr_valid),
    .in_proto_hdr_ready (ipv6_out_hdr_ready),
    .in_proto_hdr_data  (ipv6_out_hdr_data),
    .in_proto_hdr_length(ipv6_out_hdr_length),
    .in_proto_hdr_phv   (ipv6_out_hdr_phv),

    .out_proto_hdr_valid (idp_fix_out_hdr_valid),
    .out_proto_hdr_ready (idp_fix_out_hdr_ready),
    .out_proto_hdr_data  (idp_fix_out_hdr_data),
    .out_proto_hdr_length(idp_fix_out_hdr_length),
    .out_proto_hdr_phv   (idp_fix_out_hdr_phv)
);

wire                    transport_layer_opt_out_hdr_valid;
wire                    transport_layer_opt_out_hdr_ready;
wire [HEADER_WIDTH-1:0] transport_layer_opt_out_hdr_data;
wire [PHV_WIDTH-1:0]    transport_layer_opt_out_hdr_phv;
wire [15:0]             transport_layer_opt_out_hdr_length;

rbt_s_transport_layer_optional_parser #(
    .HEADER_WIDTH(HEADER_WIDTH),
    .PHV_WIDTH(PHV_WIDTH),
    .PHV_B_NUM(PHV_B_NUM),
    .PHV_H_NUM(PHV_H_NUM),
    .PHV_W_NUM(PHV_W_NUM)
) 
rbt_s_transport_layer_optional_parser_inst (
    .clk(clk),
    .rst(rst),

    .in_proto_hdr_valid (idp_fix_out_hdr_valid),
    .in_proto_hdr_ready (idp_fix_out_hdr_ready),
    .in_proto_hdr_data  (idp_fix_out_hdr_data),
    .in_proto_hdr_length(idp_fix_out_hdr_length),
    .in_proto_hdr_phv   (idp_fix_out_hdr_phv),

    .out_proto_hdr_valid (transport_layer_opt_out_hdr_valid),
    .out_proto_hdr_ready (transport_layer_opt_out_hdr_ready),
    .out_proto_hdr_data  (transport_layer_opt_out_hdr_data),
    .out_proto_hdr_length(transport_layer_opt_out_hdr_length),
    .out_proto_hdr_phv   (transport_layer_opt_out_hdr_phv)
);

rbt_s_transport_layer_parser #(
    .HEADER_WIDTH(HEADER_WIDTH),
    .PHV_WIDTH(PHV_WIDTH),
    .PHV_B_NUM(PHV_B_NUM),
    .PHV_H_NUM(PHV_H_NUM),
    .PHV_W_NUM(PHV_W_NUM)
)
rbt_s_transport_layer_parser_inst (
    .clk(clk),
    .rst(rst),

    .in_proto_hdr_valid (transport_layer_opt_out_hdr_valid),
    .in_proto_hdr_ready (transport_layer_opt_out_hdr_ready),
    .in_proto_hdr_data  (transport_layer_opt_out_hdr_data),
    .in_proto_hdr_length(transport_layer_opt_out_hdr_length),
    .in_proto_hdr_phv   (transport_layer_opt_out_hdr_phv),

    .out_proto_hdr_valid (transport_layer_out_hdr_valid),
    .out_proto_hdr_ready (transport_layer_out_hdr_ready),
    .out_proto_hdr_data  (transport_layer_out_hdr_data),
    .out_proto_hdr_length(transport_layer_out_hdr_length),
    .out_proto_hdr_phv   (transport_layer_out_hdr_phv)
);

wire                    transport_layer_out_hdr_valid;
wire                    transport_layer_out_hdr_ready;
wire [HEADER_WIDTH-1:0] transport_layer_out_hdr_data;
wire [PHV_WIDTH-1:0]    transport_layer_out_hdr_phv;
wire [15:0]             transport_layer_out_hdr_length;


wire                    idp_phv_finish_valid;
wire                    idp_phv_finish_ready;
wire [HEADER_WIDTH-1:0] idp_phv_finish_data;
wire [PHV_WIDTH-1:0]    idp_phv_finish_phv;
wire [15:0]             idp_phv_finish_length;

rbt_s_post_parser #(
    .HEADER_WIDTH(HEADER_WIDTH),
    .PHV_WIDTH(PHV_WIDTH),
    .PHV_B_NUM(PHV_B_NUM),
    .PHV_H_NUM(PHV_H_NUM),
    .PHV_W_NUM(PHV_W_NUM)
)
rbt_s_post_parser_inst (
    .clk(clk),
    .rst(rst),

    .in_proto_hdr_valid (transport_layer_out_hdr_valid),
    .in_proto_hdr_ready (transport_layer_out_hdr_ready),
    .in_proto_hdr_data  (transport_layer_out_hdr_data),
    .in_proto_hdr_length(transport_layer_out_hdr_length),
    .in_proto_hdr_phv   (transport_layer_out_hdr_phv),

    .out_proto_hdr_valid (idp_phv_finish_valid),
    .out_proto_hdr_ready (idp_phv_finish_ready),
    .out_proto_hdr_data  (idp_phv_finish_data),
    .out_proto_hdr_length(idp_phv_finish_length),
    .out_proto_hdr_phv   (idp_phv_finish_phv)
);


assign m_phv_valid = idp_phv_finish_valid;
assign idp_phv_finish_ready = m_phv_ready;
assign m_phv_info = idp_phv_finish_phv;


//todo
//debug csr

/*
 * a. Control Status Registers (CSR) implementation.
 */
reg                         csr_wr_wait_reg = 1'b0;
reg                         csr_wr_ack_reg = 1'b0;
reg  [CSR_DATA_WIDTH-1:0]   csr_rd_data_reg = {CSR_DATA_WIDTH{1'b0}};
reg                         csr_rd_wait_reg = 1'b0;
reg                         csr_rd_ack_reg = 1'b0;

assign csr_wr_wait  = 0;     //eliminate test XXX state
assign csr_wr_ack   = csr_wr_ack_reg;
assign csr_rd_data  = csr_rd_data_reg;
assign csr_rd_wait  = 0;    //eliminate test XXX state
assign csr_rd_ack   = csr_rd_ack_reg;

reg [CSR_DATA_WIDTH-1:0] csr_example_reg = 0;
reg [31:0] csr_device_id_reg = 0;

reg csr_rst_reg = 1'b0;
reg csr_clear_reg = 1'b0;

reg [CSR_DATA_WIDTH-1:0] csr_idp_in_count_reg = 0, csr_idp_in_count_next;
reg [CSR_DATA_WIDTH-1:0] csr_idp_out_count_reg = 0, csr_idp_out_count_next;



always @(*) begin
    csr_idp_in_count_next = csr_idp_in_count_reg;
    csr_idp_out_count_next = csr_idp_out_count_reg;


    if (s_axis_tvalid & s_axis_tready & s_axis_tlast) begin
        csr_idp_in_count_next = csr_idp_in_count_reg + 1;
    end
    if (m_axis_tvalid & m_axis_tready & m_axis_tlast) begin
        csr_idp_out_count_next = csr_idp_out_count_reg + 1;
    end
end

always @(posedge clk) begin
    csr_idp_in_count_reg <= csr_idp_in_count_next;
    csr_idp_out_count_reg <= csr_idp_out_count_next;

    if (rst | csr_rst_reg | csr_clear_reg) begin
        csr_idp_in_count_reg <= 0;
        csr_idp_out_count_reg <= 0;
    end
end

always @(posedge clk) begin
    csr_wr_ack_reg <= 1'b0;
    csr_rd_data_reg <= {CSR_DATA_WIDTH{1'b0}};
    csr_rd_ack_reg <= 1'b0;

    if (csr_wr_en && !csr_wr_ack_reg) begin
        // write operation
        csr_wr_ack_reg <= 1'b1;
        case ({csr_wr_addr >> 2, 2'b00})
            8'h00: csr_example_reg           <= csr_wr_data;
            8'h04: csr_rst_reg               <= csr_wr_data;
            8'h08: csr_clear_reg             <= csr_wr_data;

            8'h10: csr_device_id_reg         <= csr_wr_data;

            default: csr_wr_ack_reg <= 1'b0;
        endcase
    end

    if (csr_rd_en && !csr_rd_ack_reg) begin
        // read operation
        csr_rd_ack_reg <= 1'b1;
        case ({csr_rd_addr >> 2, 2'b00})
            8'h00: csr_rd_data_reg <= csr_idp_in_count_reg;
            8'h04: csr_rd_data_reg <= csr_idp_out_count_reg;
            8'h08: csr_rd_data_reg <= m_phv_info[3]; //protocol
            8'h0c: csr_rd_data_reg <= {{(CSR_DATA_WIDTH-6){1'b0}}, s_axis_tvalid, s_axis_tready, m_axis_tvalid, m_axis_tready, m_phv_valid, m_phv_ready};

            8'h10: csr_rd_data_reg <= csr_device_id_reg; //device id

            default: csr_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst || csr_rst_reg || csr_clear_reg) begin
        csr_wr_ack_reg <= 1'b0;
        csr_rd_ack_reg <= 1'b0;
        csr_clear_reg <= 1'b0;
    end
end

// //debug signal
// wire [7:0] debug_PHV_PROTO_ETH;
// wire [15:0] debug_ETH_type;

endmodule

`resetall

