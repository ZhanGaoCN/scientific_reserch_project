/*
 * Created on 20240722
 *
 * Copyright (c) 2024 IOA UCAS
 *
 * @Filename:   reli_tx_top.v
 * @Author:     zhangao
 * @Last edit:
 */

// Language: Verilog 2001

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
    parameter USER_ENABLE = 1,
    parameter USER_WIDTH =64,

    // pkt_metadata
    parameter PKT_METADATA_WIDTH = 274,//modified

    parameter HEADER_WIDTH = 2048,

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
     * pkt_metadata output
     */
    output wire                                      m_pkt_metadata_valid,
    input  wire                                      m_pkt_metadata_ready,
    output wire [PKT_METADATA_WIDTH-1:0]             m_pkt_metadata_info,

    input wire                                       device_id
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


wire                             idp_pkt_metadata_init_valid;
wire                             idp_pkt_metadata_init_ready;
wire [HEADER_WIDTH-1:0]          idp_pkt_metadata_init_data;
wire [PKT_METADATA_WIDTH-1:0]    idp_pkt_metadata_init_pkt_metadata;
wire [15:0]                      idp_pkt_metadata_init_length;

rbt_s_pre_parser #(
    .META_WIDTH(32),
    .HEADER_WIDTH(HEADER_WIDTH),
    .USER_WIDTH(USER_WIDTH),
    .PKT_METADATA_WIDTH(PKT_METADATA_WIDTH)
)
rbt_s_pre_parser_inst (
    .clk(clk),
    .rst(rst),

    .in_proto_hdr_valid             (extract_proto_hdr_valid),
    .in_proto_hdr_ready             (extract_proto_hdr_ready),
    .in_proto_hdr_data              (extract_proto_hdr_data),
    .in_proto_hdr_length            (extract_proto_hdr_length),
    .in_proto_hdr_pktlen            (extract_proto_hdr_pktlen),
    .in_proto_hdr_tuser             (extract_proto_hdr_tuser),
    .in_proto_hdr_meta              (device_id),

    .out_proto_hdr_valid            (idp_pkt_metadata_init_valid),
    .out_proto_hdr_ready            (idp_pkt_metadata_init_ready),
    .out_proto_hdr_data             (idp_pkt_metadata_init_data),
    .out_proto_hdr_length           (idp_pkt_metadata_init_length),
    .out_proto_hdr_pkt_metadata     (idp_pkt_metadata_init_pkt_metadata)
);


wire                             eth_out_hdr_valid;
wire                             eth_out_hdr_ready;
wire [HEADER_WIDTH-1:0]          eth_out_hdr_data;
wire [PKT_METADATA_WIDTH-1:0]    eth_out_hdr_pkt_metadata;
wire [15:0]                      eth_out_hdr_length;

// maybe need syn the header and phv input

rbt_s_eth_parser #(
    .HEADER_WIDTH(HEADER_WIDTH),
    .PKT_METADATA_WIDTH(PKT_METADATA_WIDTH)
)
rbt_s_eth_parser_inst (
    .clk(clk),
    .rst(rst),

    .in_proto_hdr_valid          (idp_pkt_metadata_init_valid),
    .in_proto_hdr_ready          (idp_pkt_metadata_init_ready),
    .in_proto_hdr_data           (idp_pkt_metadata_init_data),
    .in_proto_hdr_length         (idp_pkt_metadata_init_length),
    .in_proto_hdr_pkt_metadata   (idp_pkt_metadata_init_pkt_metadata),

    .out_proto_hdr_valid            (eth_out_hdr_valid),
    .out_proto_hdr_ready            (eth_out_hdr_ready),
    .out_proto_hdr_data             (eth_out_hdr_data),
    .out_proto_hdr_length           (eth_out_hdr_length),
    .out_proto_hdr_pkt_metadata     (eth_out_hdr_pkt_metadata)
);


wire                             vlan_out_hdr_valid;
wire                             vlan_out_hdr_ready;
wire [HEADER_WIDTH-1:0]          vlan_out_hdr_data;
wire [PKT_METADATA_WIDTH-1:0]    vlan_out_hdr_pkt_metadata;
wire [15:0]                      vlan_out_hdr_length;

rbt_s_vlan_parser #(
    .HEADER_WIDTH(HEADER_WIDTH),
    .PKT_METADATA_WIDTH(PKT_METADATA_WIDTH)
)
rbt_s_vlan_parser_inst (
    .clk(clk),
    .rst(rst),

    .in_proto_hdr_valid          (eth_out_hdr_valid),
    .in_proto_hdr_ready          (eth_out_hdr_ready),
    .in_proto_hdr_data           (eth_out_hdr_data),
    .in_proto_hdr_length         (eth_out_hdr_length),
    .in_proto_hdr_pkt_metadata   (eth_out_hdr_pkt_metadata),

    .out_proto_hdr_valid            (vlan_out_hdr_valid),
    .out_proto_hdr_ready            (vlan_out_hdr_ready),
    .out_proto_hdr_data             (vlan_out_hdr_data),
    .out_proto_hdr_length           (vlan_out_hdr_length),
    .out_proto_hdr_pkt_metadata     (vlan_out_hdr_pkt_metadata)
);

wire                             ipv6_out_hdr_valid;
wire                             ipv6_out_hdr_ready;
wire [HEADER_WIDTH-1:0]          ipv6_out_hdr_data;
wire [PKT_METADATA_WIDTH-1:0]    ipv6_out_hdr_pkt_metadata;
wire [15:0]                      ipv6_out_hdr_length;

rbt_s_ipv6_parser #(
    .HEADER_WIDTH(HEADER_WIDTH),
    .PKT_METADATA_WIDTH(PKT_METADATA_WIDTH)
)
rbt_s_ipv6_parser_inst (
    .clk(clk),
    .rst(rst),

    .in_proto_hdr_valid          (vlan_out_hdr_valid),
    .in_proto_hdr_ready          (vlan_out_hdr_ready),
    .in_proto_hdr_data           (vlan_out_hdr_data),
    .in_proto_hdr_length         (vlan_out_hdr_length),
    .in_proto_hdr_pkt_metadata   (vlan_out_hdr_pkt_metadata),

    .out_proto_hdr_valid            (ipv6_out_hdr_valid),
    .out_proto_hdr_ready            (ipv6_out_hdr_ready),
    .out_proto_hdr_data             (ipv6_out_hdr_data),
    .out_proto_hdr_length           (ipv6_out_hdr_length),
    .out_proto_hdr_pkt_metadata     (ipv6_out_hdr_pkt_metadata)
);

wire                             idp_fix_out_hdr_valid;
wire                             idp_fix_out_hdr_ready;
wire [HEADER_WIDTH-1:0]          idp_fix_out_hdr_data;
wire [PKT_METADATA_WIDTH-1:0]    idp_fix_out_hdr_pkt_metadata;
wire [15:0]                      idp_fix_out_hdr_length;

rbt_s_idp_fix_parser #(
    .HEADER_WIDTH(HEADER_WIDTH),
    .PKT_METADATA_WIDTH(PKT_METADATA_WIDTH)
)
rbt_s_idp_fix_parser_inst (
    .clk(clk),
    .rst(rst),

    .in_proto_hdr_valid          (ipv6_out_hdr_valid),
    .in_proto_hdr_ready          (ipv6_out_hdr_ready),
    .in_proto_hdr_data           (ipv6_out_hdr_data),
    .in_proto_hdr_length         (ipv6_out_hdr_length),
    .in_proto_hdr_pkt_metadata   (ipv6_out_hdr_pkt_metadata),

    .out_proto_hdr_valid          (idp_fix_out_hdr_valid),
    .out_proto_hdr_ready          (idp_fix_out_hdr_ready),
    .out_proto_hdr_data           (idp_fix_out_hdr_data),
    .out_proto_hdr_length         (idp_fix_out_hdr_length),
    .out_proto_hdr_pkt_metadata   (idp_fix_out_hdr_pkt_metadata)
);

wire                             transport_layer_opt_out_hdr_valid;
wire                             transport_layer_opt_out_hdr_ready;
wire [HEADER_WIDTH-1:0]          transport_layer_opt_out_hdr_data;
wire [PKT_METADATA_WIDTH-1:0]    transport_layer_opt_out_hdr_pkt_metadata; 
wire [15:0]                      transport_layer_opt_out_hdr_length;

rbt_s_transport_layer_optional_parser #(
    .HEADER_WIDTH(HEADER_WIDTH),
    .PKT_METADATA_WIDTH(PKT_METADATA_WIDTH)
) 
rbt_s_transport_layer_optional_parser_inst (
    .clk(clk),
    .rst(rst),

    .in_proto_hdr_valid          (idp_fix_out_hdr_valid),
    .in_proto_hdr_ready          (idp_fix_out_hdr_ready),
    .in_proto_hdr_data           (idp_fix_out_hdr_data),
    .in_proto_hdr_length         (idp_fix_out_hdr_length),
    .in_proto_hdr_pkt_metadata   (idp_fix_out_hdr_pkt_metadata),

    .out_proto_hdr_valid          (transport_layer_opt_out_hdr_valid),
    .out_proto_hdr_ready          (transport_layer_opt_out_hdr_ready),
    .out_proto_hdr_data           (transport_layer_opt_out_hdr_data),
    .out_proto_hdr_length         (transport_layer_opt_out_hdr_length),
    .out_proto_hdr_pkt_metadata   (transport_layer_opt_out_hdr_pkt_metadata)
);

wire                             transport_layer_out_hdr_valid;
wire                             transport_layer_out_hdr_ready;
wire [HEADER_WIDTH-1:0]          transport_layer_out_hdr_data;
wire [PKT_METADATA_WIDTH-1:0]    transport_layer_out_hdr_pkt_metadata;
wire [15:0]                      transport_layer_out_hdr_length;


rbt_s_transport_layer_parser #(
    .HEADER_WIDTH(HEADER_WIDTH),
    .PKT_METADATA_WIDTH(PKT_METADATA_WIDTH)
)
rbt_s_transport_layer_parser_inst (
    .clk(clk),
    .rst(rst),

    .in_proto_hdr_valid          (transport_layer_opt_out_hdr_valid),
    .in_proto_hdr_ready          (transport_layer_opt_out_hdr_ready),
    .in_proto_hdr_data           (transport_layer_opt_out_hdr_data),
    .in_proto_hdr_length         (transport_layer_opt_out_hdr_length),
    .in_proto_hdr_pkt_metadata   (transport_layer_opt_out_hdr_pkt_metadata),

    .out_proto_hdr_valid          (transport_layer_out_hdr_valid),
    .out_proto_hdr_ready          (transport_layer_out_hdr_ready),
    .out_proto_hdr_data           (transport_layer_out_hdr_data),
    .out_proto_hdr_length         (transport_layer_out_hdr_length),
    .out_proto_hdr_pkt_metadata   (transport_layer_out_hdr_pkt_metadata)
);

wire                             idp_pkt_metadata_finish_valid;
wire                             idp_pkt_metadata_finish_ready;
wire [HEADER_WIDTH-1:0]          idp_pkt_metadata_finish_data;
wire [PKT_METADATA_WIDTH-1:0]    idp_pkt_metadata_finish_pkt_metadata;
wire [15:0]                      idp_pkt_metadata_finish_length;

rbt_s_post_parser #(
    .HEADER_WIDTH(HEADER_WIDTH),
    .PKT_METADATA_WIDTH(PKT_METADATA_WIDTH)
)
rbt_s_post_parser_inst (
    .clk(clk),
    .rst(rst),

    .in_proto_hdr_valid          (transport_layer_out_hdr_valid),
    .in_proto_hdr_ready          (transport_layer_out_hdr_ready),
    .in_proto_hdr_data           (transport_layer_out_hdr_data),
    .in_proto_hdr_length         (transport_layer_out_hdr_length),
    .in_proto_hdr_pkt_metadata   (transport_layer_out_hdr_pkt_metadata),

    .out_proto_hdr_valid          (idp_pkt_metadata_finish_valid),
    .out_proto_hdr_ready          (idp_pkt_metadata_finish_ready),
    .out_proto_hdr_data           (idp_pkt_metadata_finish_data),
    .out_proto_hdr_length         (idp_pkt_metadata_finish_length),
    .out_proto_hdr_pkt_metadata   (idp_pkt_metadata_finish_pkt_metadata)
);


assign m_pkt_metadata_valid = idp_pkt_metadata_finish_valid;
assign idp_pkt_metadata_finish_ready = m_pkt_metadata_ready;
assign m_pkt_metadata_info = idp_pkt_metadata_finish_pkt_metadata;


endmodule

`resetall

