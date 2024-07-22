/*
 * Created on 20230531
 *
 * Copyright (c) 2022 IOA UCAS
 *
 * @Filename:     reli_buf_demux.v
 * @Author:       liyf
 * @Last edit:    20230531
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none
module reli_demux #
(
    parameter AXIS_DATA_WIDTH = 128,
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    parameter AXIS_USER_WIDTH = 8+8+8+8+16+16+8        // 72
)
(

    input  wire clk,
    input  wire rst,

    input  wire [AXIS_DATA_WIDTH-1:0]     s_axis_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]     s_axis_tkeep,
    input  wire                           s_axis_tvalid,
    output wire                           s_axis_tready,
    input  wire                           s_axis_tlast,
    input  wire [AXIS_USER_WIDTH-1:0]     s_axis_tuser,


    output wire [AXIS_DATA_WIDTH-1:0]     m_axis_to_mac_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]     m_axis_to_mac_tkeep,
    output wire                           m_axis_to_mac_tvalid,
    input  wire                           m_axis_to_mac_tready,
    output wire                           m_axis_to_mac_tlast,
    output wire [AXIS_USER_WIDTH-1:0]     m_axis_to_mac_tuser,

    output wire [AXIS_DATA_WIDTH-1:0]     m_axis_to_ctl_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]     m_axis_to_ctl_tkeep,
    output wire                           m_axis_to_ctl_tvalid,
    input  wire                           m_axis_to_ctl_tready,
    output wire                           m_axis_to_ctl_tlast,
    output wire [AXIS_USER_WIDTH-1:0]     m_axis_to_ctl_tuser,

    output wire [AXIS_DATA_WIDTH-1:0]     m_axis_to_buf_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]     m_axis_to_buf_tkeep,
    output wire                           m_axis_to_buf_tvalid,
    input  wire                           m_axis_to_buf_tready,
    output wire                           m_axis_to_buf_tlast,
    output wire [AXIS_USER_WIDTH-1:0]     m_axis_to_buf_tuser

);

localparam PORT_WIDTH           = 8;
localparam IP_OFFSET_WIDTH      = 8;
localparam PKT_PROPERTY_WIDTH   = 8;
localparam PKT_VALID_WIDTH      = 8;
localparam PKT_LENGTH_WIDTH     = 16;
localparam FLOW_INDEX_WIDTH     = 16;
localparam SEATP_OFFSET_WIDTH   = 8;


localparam PKT_PROPERTY_OFFSET  = 0;
localparam PKT_VALID_OFFSET  = PKT_PROPERTY_WIDTH;

localparam PKT_PROP_LOCAL_NO  = 0;
localparam PKT_PROP_DAT_NO  = 2;
localparam PKT_PROP_NACK_NO  = 3;
localparam PKT_VALID_BUFFER_HIT_NO  = 3;
localparam CLONE_PKTIN_NO = 4;



reg mac_output = 0;
reg buf_output = 0;
reg ctl_output = 0;
reg grd_output = 0;
reg mac_output_last = 0;
reg buf_output_last = 0;
reg ctl_output_last = 0;
reg grd_output_last = 0;

// input datapath logic

reg s_axis_tready_reg = 1'b0, s_axis_tready_next;

// internal datapath
reg  [AXIS_DATA_WIDTH-1:0] m_axis_tdata_int;
reg  [AXIS_KEEP_WIDTH-1:0] m_axis_tkeep_int;
reg                        m_axis_tvalid_mac_int;
reg                        m_axis_tvalid_buf_int;
reg                        m_axis_tvalid_ctl_int;
reg                        m_axis_tvalid_grd_int;
reg                        m_axis_tready_int_reg = 1'b0;
reg                        m_axis_tlast_int;
reg  [AXIS_USER_WIDTH-1:0] m_axis_tuser_int;
wire                       m_axis_tready_int_early;


wire[3:0] output_key_wire;
wire clone_pktin_tag;
// {local_flag, DAT_flag, NACK_flag, cache_hit_flag}
assign output_key_wire ={m_axis_tuser_int[PKT_PROPERTY_OFFSET+PKT_PROP_LOCAL_NO] , m_axis_tuser_int[PKT_PROPERTY_OFFSET + PKT_PROP_DAT_NO] , m_axis_tuser_int[PKT_PROPERTY_OFFSET + PKT_PROP_NACK_NO], m_axis_tuser_int[PKT_VALID_OFFSET + PKT_VALID_BUFFER_HIT_NO]};
assign clone_pktin_tag = m_axis_tuser_int[PKT_VALID_OFFSET + CLONE_PKTIN_NO];
assign s_axis_tready = s_axis_tready_reg;

always @* begin
    s_axis_tready_next = 1'b0;
    mac_output = mac_output_last;
    buf_output = buf_output_last;
    ctl_output = ctl_output_last;
    grd_output = grd_output_last;

    if (s_axis_tvalid && s_axis_tready) begin
        if (!(s_axis_tready && s_axis_tvalid && s_axis_tlast)) begin
            if(clone_pktin_tag) begin
                mac_output = 1;
                buf_output = 0;
                ctl_output = 1;
                grd_output = 0;
            end else begin
                case(output_key_wire)
                    4'b0000: begin
                        mac_output = 1;
                        buf_output = 0;
                        ctl_output = 0;
                        grd_output = 0;
                    end
                    4'b1000: begin
                        mac_output = 1;
                        buf_output = 0;
                        ctl_output = 0;
                        grd_output = 0;
                    end
                    4'b0101: begin
                        mac_output = 1;
                        buf_output = 1;
                        ctl_output = 0;
                        grd_output = 0;
                    end
                    4'b1101: begin
                        mac_output = 1;
                        buf_output = 1;
                        ctl_output = 0;
                        grd_output = 0;
                    end
                    4'b0100: begin
                        mac_output = 1;
                        buf_output = 0;
                        ctl_output = 0;
                        grd_output = 0;
                    end
                    4'b1100: begin
                        mac_output = 0;
                        buf_output = 0;
                        ctl_output = 1;
                        grd_output = 0;
                    end
                    4'b0011: begin
                        mac_output = 0;
                        buf_output = 1;
                        ctl_output = 0;
                        grd_output = 0;
                    end
                    4'b1011: begin
                        mac_output = 0;
                        buf_output = 1;
                        ctl_output = 0;
                        grd_output = 0;
                    end
                    4'b0010: begin
                        mac_output = 1;
                        buf_output = 0;
                        ctl_output = 0;
                        grd_output = 0;
                    end
                    4'b1010: begin
                        mac_output = 0;
                        buf_output = 0;
                        ctl_output = 1;  //local nack unhit PKTIN 2024/4/3
                        grd_output = 0;
                    end
                    default: begin
                        mac_output = 1;
                        buf_output = 0;
                        ctl_output = 0;
                        grd_output = 0;
                    end
                endcase
            end
        end
    end

    s_axis_tready_next = m_axis_tready_int_early ;

    m_axis_tdata_int  = s_axis_tdata;
    m_axis_tkeep_int  = s_axis_tkeep;
    m_axis_tvalid_mac_int = s_axis_tvalid && s_axis_tready && mac_output;
    m_axis_tvalid_buf_int = s_axis_tvalid && s_axis_tready && buf_output;
    m_axis_tvalid_ctl_int = s_axis_tvalid && s_axis_tready && ctl_output;
    m_axis_tvalid_grd_int = s_axis_tvalid && s_axis_tready && grd_output;
    m_axis_tlast_int  = s_axis_tlast;
    m_axis_tuser_int  = s_axis_tuser; 
end

always @(posedge clk) begin
    if (rst) begin
        s_axis_tready_reg <= 1'b0;
        mac_output_last <= 1'b1;
        buf_output_last <= 1'b0;
        ctl_output_last <= 1'b0;
        grd_output_last <= 1'b0;
    end else begin
        s_axis_tready_reg <= s_axis_tready_next;
        mac_output_last <= mac_output;
        buf_output_last <= buf_output;
        ctl_output_last <= ctl_output;
        grd_output_last <= grd_output;
    end

end


// output datapath logic
reg [AXIS_DATA_WIDTH-1:0] m_axis_tdata_reg  = {AXIS_DATA_WIDTH{1'b0}};
reg [AXIS_KEEP_WIDTH-1:0] m_axis_tkeep_reg  = {AXIS_KEEP_WIDTH{1'b0}};
reg                       m_axis_tvalid_mac_reg = 1'b0, m_axis_tvalid_mac_next;
reg                       m_axis_tvalid_buf_reg = 1'b0, m_axis_tvalid_buf_next;
reg                       m_axis_tvalid_ctl_reg = 1'b0, m_axis_tvalid_ctl_next;
reg                       m_axis_tvalid_grd_reg = 1'b0, m_axis_tvalid_grd_next;
reg                       m_axis_tlast_reg  = 1'b0;
reg [AXIS_USER_WIDTH-1:0] m_axis_tuser_reg  = {AXIS_USER_WIDTH{1'b0}};

reg [AXIS_DATA_WIDTH-1:0] temp_m_axis_tdata_reg  = {AXIS_DATA_WIDTH{1'b0}};
reg [AXIS_KEEP_WIDTH-1:0] temp_m_axis_tkeep_reg  = {AXIS_KEEP_WIDTH{1'b0}};
reg                       temp_m_axis_tvalid_mac_reg = 1'b0, temp_m_axis_tvalid_mac_next;
reg                       temp_m_axis_tvalid_buf_reg = 1'b0, temp_m_axis_tvalid_buf_next;
reg                       temp_m_axis_tvalid_ctl_reg = 1'b0, temp_m_axis_tvalid_ctl_next;
reg                       temp_m_axis_tvalid_grd_reg = 1'b0, temp_m_axis_tvalid_grd_next;
reg                       temp_m_axis_tlast_reg  = 1'b0;
reg [AXIS_USER_WIDTH-1:0] temp_m_axis_tuser_reg  = {AXIS_USER_WIDTH{1'b0}};

// datapath control
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_temp_to_output;


assign m_axis_to_mac_tdata  = m_axis_tdata_reg;
assign m_axis_to_mac_tkeep  = m_axis_tkeep_reg;
assign m_axis_to_mac_tuser  = m_axis_tuser_reg;
assign m_axis_to_mac_tlast  = m_axis_tlast_reg;
assign m_axis_to_mac_tvalid = m_axis_tvalid_mac_reg;

assign m_axis_to_buf_tdata  = m_axis_tdata_reg;
assign m_axis_to_buf_tkeep  = m_axis_tkeep_reg;
assign m_axis_to_buf_tuser  = m_axis_tuser_reg;
assign m_axis_to_buf_tlast  = m_axis_tlast_reg;
assign m_axis_to_buf_tvalid = m_axis_tvalid_buf_reg;

assign m_axis_to_ctl_tdata  = m_axis_tdata_reg;
assign m_axis_to_ctl_tkeep  = m_axis_tkeep_reg;
assign m_axis_to_ctl_tuser  = m_axis_tuser_reg;
assign m_axis_to_ctl_tlast  = m_axis_tlast_reg;
assign m_axis_to_ctl_tvalid = m_axis_tvalid_ctl_reg;

wire m_axis_tready_wire;
assign m_axis_tready_wire = m_axis_to_mac_tready;
wire m_axis_tvalid_wire;
assign m_axis_tvalid_wire = m_axis_tvalid_mac_reg || m_axis_tvalid_buf_reg || m_axis_tvalid_ctl_reg || m_axis_tvalid_grd_reg;
wire m_axis_tlast_wire;
assign m_axis_tlast_wire  = m_axis_tlast_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign m_axis_tready_int_early = (m_axis_to_mac_tready) ||
                                 (!(temp_m_axis_tvalid_mac_reg || temp_m_axis_tvalid_buf_reg || temp_m_axis_tvalid_ctl_reg || temp_m_axis_tvalid_grd_reg) && (!m_axis_tvalid_wire || !(m_axis_tvalid_mac_int || m_axis_tvalid_buf_int || m_axis_tvalid_ctl_int || m_axis_tvalid_grd_int)));


always @* begin
    // transfer sink ready state to source
    m_axis_tvalid_mac_next = m_axis_tvalid_mac_reg;
    m_axis_tvalid_buf_next = 0;
    m_axis_tvalid_ctl_next = 0;
    m_axis_tvalid_grd_next = 0;
    temp_m_axis_tvalid_mac_next = temp_m_axis_tvalid_mac_reg;
    temp_m_axis_tvalid_buf_next = temp_m_axis_tvalid_buf_reg;
    temp_m_axis_tvalid_ctl_next = temp_m_axis_tvalid_ctl_reg;
    temp_m_axis_tvalid_grd_next = temp_m_axis_tvalid_grd_reg;

    store_axis_int_to_output = 1'b0;
    store_axis_int_to_temp = 1'b0;
    store_axis_temp_to_output = 1'b0;

    if (m_axis_tready_int_reg) begin
        // input is ready
        if ((m_axis_to_mac_tready & m_axis_to_mac_tvalid) || !m_axis_to_mac_tvalid) begin
            // output is ready or currently not valid, transfer data to output
            m_axis_tvalid_mac_next = m_axis_tvalid_mac_int;
            m_axis_tvalid_buf_next = m_axis_tvalid_buf_int;
            m_axis_tvalid_ctl_next = m_axis_tvalid_ctl_int;
            m_axis_tvalid_grd_next = m_axis_tvalid_grd_int;
            store_axis_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axis_tvalid_mac_next = m_axis_tvalid_mac_int;
            temp_m_axis_tvalid_buf_next = m_axis_tvalid_buf_int;
            temp_m_axis_tvalid_ctl_next = m_axis_tvalid_ctl_int;
            temp_m_axis_tvalid_grd_next = m_axis_tvalid_grd_int;
            store_axis_int_to_temp = 1'b1;
        end
    end else if (m_axis_to_mac_tready & m_axis_to_mac_tvalid) begin
        // input is not ready, but output is ready
        m_axis_tvalid_mac_next = temp_m_axis_tvalid_mac_reg;
        m_axis_tvalid_buf_next = temp_m_axis_tvalid_buf_reg;
        m_axis_tvalid_ctl_next = temp_m_axis_tvalid_ctl_reg;
        m_axis_tvalid_grd_next = temp_m_axis_tvalid_grd_reg;
        temp_m_axis_tvalid_mac_next = 1'b0;
        temp_m_axis_tvalid_buf_next = 1'b0;
        temp_m_axis_tvalid_ctl_next = 1'b0;
        temp_m_axis_tvalid_grd_next = 1'b0;
        store_axis_temp_to_output = 1'b1;
    end
end



always @(posedge clk) begin
    if (rst) begin
        m_axis_tvalid_mac_reg <= 1'b0;
        m_axis_tvalid_buf_reg <= 1'b0;
        m_axis_tvalid_ctl_reg <= 1'b0;
        m_axis_tvalid_grd_reg <= 1'b0;
        m_axis_tready_int_reg <= 1'b0;
        temp_m_axis_tvalid_mac_reg <= 1'b0;
        temp_m_axis_tvalid_buf_reg <= 1'b0;
        temp_m_axis_tvalid_ctl_reg <= 1'b0;
    end else begin
        m_axis_tvalid_mac_reg <= m_axis_tvalid_mac_next;
        m_axis_tvalid_buf_reg <= m_axis_tvalid_buf_next;
        m_axis_tvalid_ctl_reg <= m_axis_tvalid_ctl_next;
        m_axis_tvalid_grd_reg <= m_axis_tvalid_grd_next;
        m_axis_tready_int_reg <= m_axis_tready_int_early;
        temp_m_axis_tvalid_mac_reg <= temp_m_axis_tvalid_mac_next;
        temp_m_axis_tvalid_buf_reg <= temp_m_axis_tvalid_buf_next;
        temp_m_axis_tvalid_ctl_reg <= temp_m_axis_tvalid_ctl_next;
        temp_m_axis_tvalid_grd_reg <= temp_m_axis_tvalid_grd_next;
    end

    // datapath
    if (store_axis_int_to_output) begin
        m_axis_tdata_reg <= m_axis_tdata_int;
        m_axis_tkeep_reg <= m_axis_tkeep_int;
        m_axis_tlast_reg <= m_axis_tlast_int;
        m_axis_tuser_reg <= m_axis_tuser_int;
    end else if (store_axis_temp_to_output) begin
        m_axis_tdata_reg <= temp_m_axis_tdata_reg;
        m_axis_tkeep_reg <= temp_m_axis_tkeep_reg;
        m_axis_tlast_reg <= temp_m_axis_tlast_reg;
        m_axis_tuser_reg <= temp_m_axis_tuser_reg;
    end

    if (store_axis_int_to_temp) begin
        temp_m_axis_tdata_reg <= m_axis_tdata_int;
        temp_m_axis_tkeep_reg <= m_axis_tkeep_int;
        temp_m_axis_tlast_reg <= m_axis_tlast_int;
        temp_m_axis_tuser_reg <= m_axis_tuser_int;
    end
end


endmodule

`resetall
