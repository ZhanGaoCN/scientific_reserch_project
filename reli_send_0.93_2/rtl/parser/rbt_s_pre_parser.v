// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

module rbt_s_pre_parser #
(

    //width of meta (decice id)
    parameter META_WIDTH = 32,

 //width of route
    // parameter ROUTE_OFFSET = 0,
    // parameter ROUTE_WIDTH = 8,
    //width of START_TABLE
    // parameter START_TABLE_OFFSET = ROUTE_OFFSET + 2*ROUTE_WIDTH,
    // parameter START_TABLE_WIDTH = 8,
    //width of PKT_PROPERTY
    // parameter PKT_PROPERTY_OFFSET = ROUTE_OFFSET + 2*ROUTE_WIDTH +START_TABLE_WIDTH,
    // parameter PKT_PROPERTY_WIDTH = 8, 

    //width of PKT_LENGTH
    // parameter PKT_LENGTH_OFFSET = ROUTE_OFFSET + 2*ROUTE_WIDTH +START_TABLE_WIDTH + PKT_PROPERTY_WIDTH,
    // parameter PKT_LENGTH_WIDTH = 16,       

    // parameter USER_ENABLE = 1,
    // parameter USER_WIDTH = ROUTE_OFFSET + 2*ROUTE_WIDTH + START_TABLE_WIDTH + PKT_PROPERTY_WIDTH + PKT_LENGTH_WIDTH,
    parameter USER_WIDTH = 56,
    // transfer metadata to MAT
    parameter HEADER_WIDTH = 2048,
    parameter PHV_WIDTH = 408,
    parameter PHV_B_LEN = 8,
    parameter PHV_H_LEN = 16,
    parameter PHV_W_LEN = 32,
    parameter PHV_B_NUM = 7,
    parameter PHV_H_NUM = 2,
    parameter PHV_W_NUM = 10,
    parameter PHV_B_OFFSET = 0,
    parameter PHV_H_OFFSET = PHV_B_OFFSET + PHV_B_NUM*PHV_B_LEN,
    parameter PHV_W_OFFSET = PHV_H_OFFSET + PHV_H_NUM*PHV_H_LEN
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * proto header input
     */
    input  wire                      in_proto_hdr_valid,
    output wire                      in_proto_hdr_ready,
    input  wire [15:0]               in_proto_hdr_length,
    input  wire [15:0]               in_proto_hdr_pktlen,//todo
    input  wire [HEADER_WIDTH-1:0]   in_proto_hdr_data,
    input  wire [USER_WIDTH-1:0]     in_proto_hdr_tuser,
    input  wire [META_WIDTH-1:0]     in_proto_hdr_meta,

 

    /*
     * parse header output
     */
    output wire                     out_proto_hdr_valid,
    input  wire                     out_proto_hdr_ready,
    output wire [HEADER_WIDTH-1:0]  out_proto_hdr_data,
    output wire [PHV_WIDTH-1:0]     out_proto_hdr_phv,
    output wire [15:0]              out_proto_hdr_length
);


reg proto_hdr_valid_reg, proto_hdr_valid_next;
reg [HEADER_WIDTH-1:0]   proto_hdr_data_reg, proto_hdr_data_next;
reg [15:0]               proto_hdr_length_reg, proto_hdr_length_next;

assign in_proto_hdr_ready   = out_proto_hdr_ready;
assign out_proto_hdr_valid  = proto_hdr_valid_reg;
assign out_proto_hdr_data   = proto_hdr_data_reg;
assign out_proto_hdr_length = proto_hdr_length_reg;

// bus width assertions
initial begin
    if (HEADER_WIDTH % 8 != 0) begin
        $error("Error: HEADER_WIDTH requires byte (8-bit) granularity (instance %m)");
        $finish;
    end
end

//tuser input offset
localparam INPORT_OFFSET = 0;
localparam INPORT_WIDTH = 8;
localparam OUTPORT_OFFSET = INPORT_OFFSET + INPORT_WIDTH;
localparam OUTPORT_WIDTH = 8;
localparam TID_OFFSET = OUTPORT_OFFSET + OUTPORT_WIDTH;
localparam TID_WIDTH = 8;
localparam PKT_PROPERTY_OFFSET = TID_OFFSET + TID_WIDTH;
localparam PKT_PROPERTY_WIDTH = 8;
localparam PKT_VALID_OFFSET = PKT_PROPERTY_OFFSET + PKT_PROPERTY_WIDTH;
localparam PKT_VALID_WIDTH = 8;
localparam SEATL_OFFSET = PKT_VALID_OFFSET + PKT_VALID_WIDTH;
localparam SEATL_WIDTH = 8;
localparam PKTLEN_OFFSET = SEATL_OFFSET + SEATL_WIDTH;
localparam PKTLEN_WIDTH = 16;


// PHV offset

//H
localparam PKTLEN_NO = 0;

//B
localparam PKT_PROPERTY_NO = 0;
localparam PKT_VALID_NO = 1;
localparam PHV_IN_PORT_NO   = 2;
localparam PHV_OUT_PORT_NO  = 3;
localparam TID_NO  = 5;
localparam SEATL_OFFSET_NO = 6;


// PHV init
// parse tuser signal  // add timestamp // add pktlen

reg [7:0]  phv_b_reg[0:PHV_B_NUM-1];
reg [15:0] phv_h_reg[0:PHV_H_NUM-1];
reg [31:0] phv_w_reg[0:PHV_W_NUM-1];

reg [7:0]  phv_b_next[0:PHV_B_NUM-1];
reg [15:0] phv_h_next[0:PHV_H_NUM-1];
reg [31:0] phv_w_next[0:PHV_W_NUM-1];

generate
    genvar b,h,w;
    for (b = 0; b < PHV_B_NUM; b = b + 1) begin
        assign out_proto_hdr_phv[b*8 +: 8] = phv_b_reg[b];
    end
    for (h = 0; h < PHV_H_NUM; h = h + 1) begin
        assign out_proto_hdr_phv[8*PHV_B_NUM+h*16 +: 16] = phv_h_reg[h];
    end
    for (w = 0; w < PHV_W_NUM; w = w + 1) begin
        assign out_proto_hdr_phv[8*PHV_B_NUM+16*PHV_H_NUM+w*32 +: 32] = phv_w_reg[w];
    end
endgenerate



reg [63:0] timestamp_reg, timestamp_next;
integer i, j, k;



always @* begin

    for (i = 0; i < PHV_B_NUM; i = i + 1) begin
        phv_b_next[i] = phv_b_reg[i];
    end
    for (j = 0; j < PHV_H_NUM; j = j + 1) begin
        phv_h_next[j] = phv_h_reg[j];
    end
    for (k = 0; k < PHV_W_NUM; k = k + 1) begin
        phv_w_next[k] = phv_w_reg[k];
    end

    timestamp_next = timestamp_reg + 1;

    proto_hdr_valid_next = proto_hdr_valid_reg;
    proto_hdr_data_next = proto_hdr_data_reg;
    proto_hdr_length_next = proto_hdr_length_reg;


    if(out_proto_hdr_valid & out_proto_hdr_ready) begin
        proto_hdr_valid_next = 1'b0;
    end

    if(in_proto_hdr_valid & in_proto_hdr_ready) begin

        proto_hdr_valid_next = 1'b1;
        proto_hdr_data_next   = in_proto_hdr_data;
        proto_hdr_length_next = in_proto_hdr_length;

        phv_h_next[PKTLEN_NO] = in_proto_hdr_pktlen;//todo
        
        /* 
         *parse from tuser
          tuser:{pktlen,PKT_PRIORITY,TID,OUT_PORT,IN_PORT}
         */
        phv_b_next[PKT_PROPERTY_NO] = in_proto_hdr_tuser[PKT_PROPERTY_OFFSET +: PKT_PROPERTY_WIDTH];
        phv_b_next[PKT_VALID_NO] = in_proto_hdr_tuser[PKT_VALID_OFFSET +: PKT_VALID_WIDTH];
        phv_b_next[PHV_IN_PORT_NO] = in_proto_hdr_tuser[INPORT_OFFSET +: INPORT_WIDTH];
        phv_b_next[PHV_OUT_PORT_NO] = in_proto_hdr_tuser[OUTPORT_OFFSET +: OUTPORT_WIDTH];
        phv_b_next[TID_NO] = in_proto_hdr_tuser[TID_OFFSET +: TID_WIDTH];    
        //phv_b_next[SEATL_OFFSET_NO] = in_proto_hdr_tuser[SEATL_OFFSET +: SEATL_WIDTH]; 
    end
end

always @(posedge clk) begin

    proto_hdr_valid_reg  <= proto_hdr_valid_next;
    proto_hdr_data_reg   <= proto_hdr_data_next;
    proto_hdr_length_reg <= proto_hdr_length_next;

    timestamp_reg <= timestamp_next;

    for (i = 0; i < PHV_B_NUM; i = i + 1) begin
        phv_b_reg[i] <= phv_b_next[i];
    end
    for (j = 0; j < PHV_H_NUM; j = j + 1) begin
        phv_h_reg[j] <= phv_h_next[j];
    end
    for (k = 0; k < PHV_W_NUM; k = k + 1) begin
        phv_w_reg[k] <= phv_w_next[k];
    end
    
    if(rst) begin
        proto_hdr_valid_reg <= 0;
        proto_hdr_data_reg <= 0;
        proto_hdr_length_reg <= 0;

        timestamp_reg <= 0;
        for (i = 0; i < PHV_B_NUM; i = i + 1) begin
            phv_b_reg[i] <= 0;
        end
        for (j = 0; j < PHV_H_NUM; j = j + 1) begin
            phv_h_reg[j] <= 0;
        end
        for (k = 0; k < PHV_W_NUM; k = k + 1) begin
            phv_w_reg[k] <= 0;
        end
    end
end



endmodule

`resetall