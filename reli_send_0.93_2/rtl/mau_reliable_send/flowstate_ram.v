/*
 * @Autor: lur
 */
`resetall
`timescale 1ns / 1ps
`default_nettype none
module flowstate_ram#(
	parameter VALUE_WIDTH = 32,
    parameter FLOWSTATE_WIDTH=32,
    parameter ADDR_WIDTH=10,
    parameter OPCODE_WIDTH=4
)(
    input  wire                     clk,
	input  wire                     rst,

    //recv broadcast new flowstate & addr
    input  wire[FLOWSTATE_WIDTH-1:0]bcd_flowstate_in,
    input  wire[ADDR_WIDTH-1:0]     bcd_addr_in,
    input  wire                     bcd_valid_in,

    input  wire                     s_mat_hit,
    input  wire [ADDR_WIDTH-1:0]    s_mat_addr,
    input  wire                     s_mat_valid,
    output wire                     s_mat_ready,

    output wire                     m_mat_hit,
	output wire [VALUE_WIDTH-1:0]   m_mat_value,
    output wire [ADDR_WIDTH-1:0]    m_mat_addr,
	output wire                     m_mat_valid,
	input  wire                     m_mat_ready,

    input  wire [ADDR_WIDTH-1:0]    s_mod_addr,
    input  wire [VALUE_WIDTH-1:0]   s_mod_data,
    input  wire [OPCODE_WIDTH-1:0]  s_mod_opcode,
    input  wire                     s_mod_valid,
    output wire                     s_mod_ready,

    output wire [VALUE_WIDTH-1:0]   m_mod_bdata,
    output wire                     m_mod_bvalid,
    input  wire                     m_mod_bready
);

wire [VALUE_WIDTH-1:0] m_mat_value_wire;
simple_dual_port_ram #(
    .DATA_WIDTH(VALUE_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) flowstate_mem_inst (
    //input;
    .clk(clk),
    .rst(rst),

    .wren((s_mod_ready && s_mod_valid && (s_mod_opcode == 4'b1101 || s_mod_opcode == 4'b1110)) || bcd_valid_in),
    .rden((s_mod_ready && s_mod_valid && s_mod_opcode == 4'b1100) || (s_mat_valid && s_mat_ready)),
    .raddress((s_mod_ready && s_mod_valid && s_mod_opcode == 4'b1100)? s_mod_addr : s_mat_addr),
    .waddress(bcd_valid_in? bcd_addr_in : s_mod_addr),
    .data_in(bcd_valid_in? bcd_flowstate_in : ((s_mod_opcode == 4'b1101)?s_mod_data:{(VALUE_WIDTH){1'b0}})),
    
    //output;
    .data_out(m_mat_value_wire)
);


//reg [FLOWSTATE_WIDTH-1:0] latest_flowstate_reg;
//reg [ADDR_WIDTH-1:0] latest_flowstate_addr;

reg [ADDR_WIDTH-1:0] m_mat_addr_reg;
reg m_mat_valid_reg;
reg m_mat_hit_reg;

reg csr_read_valid_reg;
assign m_mod_bdata = m_mat_value_wire;
assign m_mod_bvalid = csr_read_valid_reg;

reg s_mod_ready_reg;
assign s_mod_ready = s_mod_ready_reg;
always @* begin
    if (s_mod_valid && s_mod_opcode == 4'b1100) begin
        if ((s_mat_valid && s_mat_ready) || (m_mat_valid_reg)) begin
            s_mod_ready_reg = 1'b0;
        end else begin
            s_mod_ready_reg = 1'b1;
        end
    end else if (s_mod_valid && s_mod_opcode == 4'b1101) begin
        if (bcd_valid_in) begin
            s_mod_ready_reg = 1'b0;
        end else begin
            s_mod_ready_reg = 1'b1;
        end
    end else begin
        s_mod_ready_reg = 1'b1;
    end
end

always @(posedge clk) begin
    if (m_mat_ready) begin
        m_mat_valid_reg <= 1'b0;
    end

    if (m_mod_bready) begin
        csr_read_valid_reg <= 1'b0;
    end

    if (s_mat_valid && s_mat_ready) begin
        m_mat_valid_reg <= 1'b1;
        m_mat_hit_reg <= s_mat_hit;
        m_mat_addr_reg <= s_mat_addr;
    end

    if (s_mod_ready && s_mod_valid && s_mod_opcode == 4'b1100) begin
        csr_read_valid_reg <= 1'b1;
    end

    if (rst) begin
        m_mat_valid_reg <= 1'b0;
        m_mat_hit_reg <= 1'b0;
        m_mat_addr_reg <= {(ADDR_WIDTH){1'b0}};
        csr_read_valid_reg <= 1'b0;
    end
end

assign s_mat_ready = m_mat_ready || ~m_mat_valid_reg;
assign m_mat_valid = m_mat_valid_reg;
assign m_mat_hit = m_mat_hit_reg;
assign m_mat_addr = m_mat_addr_reg;
assign m_mat_value = m_mat_value_wire[VALUE_WIDTH-1:0];


endmodule
`resetall