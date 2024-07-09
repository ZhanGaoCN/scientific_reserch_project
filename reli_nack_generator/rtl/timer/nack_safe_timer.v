/*
 * @Autor: Changyw
 * @Date: 2023-04-20 15:34:58
 * @LastEditors: Changyw
 * @LastEditTime: 2023-04-30 09:01:22
 */
`resetall
`timescale 1ns / 1ps
`default_nettype none 

module nack_safe_timer#(
    parameter TIMEOUT_EVENT_WIDTH = 64,
    parameter TIMEOUT_MS_WIDTH = 7,
    
    parameter TIMER_ENTRY_NUM = 512, 
    parameter TIMER_SLOT_NUM = 512,
    parameter MS_ENTRY_NUM = 8,
    parameter TIMER_START_ADDR = 33'h130000000,

    
    parameter AXI_DATA_WIDTH = 512,
    parameter AXI_ADDR_WIDTH = 33,
    parameter AXI_ID_WIDTH = 8,

    parameter CSR_ADDR_WIDTH        = 8,
    parameter CSR_DATA_WIDTH        = 32,
    parameter CSR_STRB_WIDTH        = (CSR_DATA_WIDTH/8)
)(
    /*
     * System signal
     */
    input  wire                                                 clk,
    input  wire                                                 rst,
    
    input  wire [16-1:0]                                        jump_posedge_threshold,  //200*125=25000, fit 200Mhz

    /*
     * input  timeout
     */
    input  wire [TIMEOUT_EVENT_WIDTH + TIMEOUT_MS_WIDTH-1:0]    s_timeout_eventms,
    input  wire                                                 s_timeout_valid,
    output wire                                                 s_timeout_ready,

    /*
     * output timeout
     */
    output wire [TIMEOUT_EVENT_WIDTH-1:0]                       m_timeout_event,
    output wire                                                 m_timeout_valid,
    input  wire                                                 m_timeout_ready,

    /*
     * AXI master interface
     */
    output wire [AXI_ID_WIDTH-1:0]                              m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]                            m_axi_awaddr,
    output wire [7:0]                                           m_axi_awlen,
    output wire [2:0]                                           m_axi_awsize,
    output wire [1:0]                                           m_axi_awburst,
    output wire                                                 m_axi_awlock,
    output wire [3:0]                                           m_axi_awcache,
    output wire [2:0]                                           m_axi_awprot,
    output wire [3:0]                                           m_axi_awqos,
    output wire                                                 m_axi_awvalid,
    input  wire                                                 m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]                            m_axi_wdata,
    output wire [AXI_DATA_WIDTH/8-1:0]                          m_axi_wstrb,
    output wire                                                 m_axi_wlast,
    output wire                                                 m_axi_wvalid,
    input  wire                                                 m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]                              m_axi_bid,
    input  wire [1:0]                                           m_axi_bresp,
    input  wire                                                 m_axi_bvalid,
    output wire                                                 m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]                              m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]                            m_axi_araddr,
    output wire [7:0]                                           m_axi_arlen,
    output wire [2:0]                                           m_axi_arsize,
    output wire [1:0]                                           m_axi_arburst,
    output wire                                                 m_axi_arlock,
    output wire [3:0]                                           m_axi_arcache,
    output wire [2:0]                                           m_axi_arprot,
    output wire [3:0]                                           m_axi_arqos,
    output wire                                                 m_axi_arvalid,
    input  wire                                                 m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]                              m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]                            m_axi_rdata,
    input  wire [1:0]                                           m_axi_rresp,
    input  wire                                                 m_axi_rlast,
    input  wire                                                 m_axi_rvalid,
    output wire                                                 m_axi_rready,


//csr
    input  wire [CSR_ADDR_WIDTH-1:0]        csr_wr_addr,
    input  wire [CSR_DATA_WIDTH-1:0]        csr_wr_data,
    input  wire [CSR_STRB_WIDTH-1:0]        csr_wr_strb,
    input  wire                             csr_wr_en,
    output wire                             csr_wr_wait,
    output wire                             csr_wr_ack,
    
    input  wire [CSR_ADDR_WIDTH-1:0]        csr_rd_addr,
    input  wire                             csr_rd_en,
    output wire [CSR_DATA_WIDTH-1:0]        csr_rd_data,
    output wire                             csr_rd_wait,
    output wire                             csr_rd_ack
);

localparam FIFO_DEPTH = 32;
localparam FIFO_COUNT_WIDTH = $clog2(FIFO_DEPTH+1);

localparam [2:0] IDLE = 4'd0;
localparam [2:0] C_TIMEOUT = 4'd1;  //normally, ram ++ wr_en
localparam [2:0] WRITE = 4'd2;  // to avoid read-after-write hazard, write/read must done by ourselves
localparam [2:0] SCAN_TIMEOUT = 4'd3;  // normally, nothing to do
localparam [2:0] READ = 4'd4;
localparam [2:0] RAM_INIT = 4'd5;

localparam ENTRY_ID_WIDTH = $clog2(TIMER_ENTRY_NUM);
localparam SLOT_ID_WIDTH = $clog2(TIMER_SLOT_NUM);

localparam TIMER_MEM_SIZE = TIMER_ENTRY_NUM * TIMER_SLOT_NUM * TIMEOUT_EVENT_WIDTH / 8;
localparam TIMER_MEM_WIDTH = $clog2(TIMER_MEM_SIZE);

wire [AXI_DATA_WIDTH-1:0] m_axis_adapter_tdata;
wire m_axis_adapter_tvalid;
wire m_axis_adapter_tready;
wire [AXI_DATA_WIDTH/8-1:0] m_axis_adapter_tkeep;
wire m_axis_adapter_tlast;
wire [FIFO_COUNT_WIDTH-1:0] fifo_count;

reg [2:0] state;

reg [ENTRY_ID_WIDTH-1:0] entry_id_cur;
reg [ENTRY_ID_WIDTH-1:0] entry_id;

reg [15:0] timer_counter;

reg ram_wr_en;
reg ram_rd_en;
reg [ENTRY_ID_WIDTH-1:0] ram_raddress;
reg [ENTRY_ID_WIDTH-1:0] ram_waddress;
// reg [ENTRY_ID_WIDTH+1-1:0] ram_data_in;
// wire [ENTRY_ID_WIDTH+1-1:0] ram_data_out;
reg [SLOT_ID_WIDTH+1-1:0] ram_data_in;
wire [SLOT_ID_WIDTH+1-1:0] ram_data_out;

reg [TIMEOUT_MS_WIDTH - 1:0] timeout_ms;
reg [TIMEOUT_EVENT_WIDTH - 1:0] timeout_event;

reg aw_done, w_done, b_done;

reg ar_done;

reg [SLOT_ID_WIDTH+1-1:0] event_num;

reg [AXI_DATA_WIDTH/8-1:0] input_keep;

reg [ENTRY_ID_WIDTH+1-1:0] ram_init_counter;

assign s_timeout_ready = (state == IDLE)? 1'b1:1'b0;

always@(posedge clk) begin
case(state)
IDLE: begin
    event_num <= 0;
end
SCAN_TIMEOUT: begin
    event_num <= ram_data_out;
end
default: begin
end
endcase
end

always@(posedge clk) begin
case(state)
IDLE: begin
    timeout_ms <= s_timeout_eventms[TIMEOUT_MS_WIDTH - 1:0];
end
default: begin
end
endcase
end

always@(posedge clk) begin
case(state)
IDLE: begin
    timeout_event <= s_timeout_eventms[TIMEOUT_MS_WIDTH + TIMEOUT_EVENT_WIDTH - 1:TIMEOUT_MS_WIDTH];
end
default: begin
end
endcase
end

always@(posedge clk) begin
if (rst) begin
    entry_id <= 0;
end else begin
case(state)
SCAN_TIMEOUT: begin
    if (ram_data_out == 0) begin
        entry_id <= entry_id + 1;
    end
end
READ: begin
    if (m_axi_rready && m_axi_rvalid && m_axi_rlast) begin
        entry_id <= entry_id + 1;
    end
end
default: begin
end
endcase
end
end

always@(*) begin
if (state == IDLE) begin
    if (s_timeout_valid || (entry_id != entry_id_cur)) begin
        ram_rd_en <= 1'b1;
    end else begin
        ram_rd_en <= 1'b0;
    end
end else begin
    ram_rd_en <= 1'b0;
end
end

always@(*) begin
if (rst) begin
    ram_raddress <= 0;
end else begin
case(state)
IDLE: begin
    if (s_timeout_valid) begin
        ram_raddress <= entry_id + (s_timeout_eventms[TIMEOUT_MS_WIDTH - 1:0] * MS_ENTRY_NUM);
    end else begin
        if (entry_id != entry_id_cur) begin
            ram_raddress <= entry_id;
        end else begin
            ram_raddress <= 0;
        end
    end
end
default: begin
    ram_raddress <= 0;
end
endcase
end
end

always@(posedge clk) begin
if (rst) begin
    timer_counter <= 0;
end else begin
    if (timer_counter == jump_posedge_threshold) begin
        timer_counter <= 0;
    end else begin
        timer_counter<= timer_counter + 1;
    end
end
end

always@(posedge clk) begin
if (rst) begin
    entry_id_cur <= 0;
end else begin
    if (timer_counter == jump_posedge_threshold) begin
        entry_id_cur <= entry_id_cur + 1;
    end
end
end

always@(*) begin
if (rst) begin
    ram_wr_en <= 0;
end else begin
case(state)
RAM_INIT: begin
    if (ram_init_counter < TIMER_ENTRY_NUM) begin
        ram_wr_en <= 1'b1;
    end else begin
        ram_wr_en <= 1'b0;
    end
end
C_TIMEOUT: begin
    ram_wr_en <= 1'b1;
end
READ: begin
    if (m_axi_rvalid && m_axi_rready && m_axi_rlast) begin
        ram_wr_en <= 1'b1;
    end else begin
        ram_wr_en <= 1'b0;
    end
end
default: begin
    ram_wr_en <= 1'b0;
end
endcase
end
end

always@(*) begin
if (rst) begin
    ram_waddress <= 0;
end else begin
case(state)
RAM_INIT: begin
    ram_waddress <= ram_init_counter;
end
C_TIMEOUT: begin
    ram_waddress <= entry_id + timeout_ms * MS_ENTRY_NUM;
end
READ: begin  //recover ram to zero
    ram_waddress <= entry_id;
end
default: begin
    ram_waddress <= 0;
end
endcase
end
end

always@(*) begin
case(state)
C_TIMEOUT: begin
    if (ram_data_out < TIMER_SLOT_NUM) begin
        ram_data_in <= ram_data_out + 1;
    end else begin
        ram_data_in <= ram_data_out;
    end
end
default: begin
    ram_data_in <= 0;
end
endcase
end

always@(posedge clk) begin
if (rst) begin
    ram_init_counter <= 0;
end else begin
    if (state == RAM_INIT) begin
        ram_init_counter <= ram_init_counter + 1;
    end
end
end

always@(posedge clk) begin
if (rst) begin
    state <= RAM_INIT;
end else begin
case(state)
RAM_INIT: begin
    if (ram_init_counter == TIMER_ENTRY_NUM) begin
        state <= IDLE;
    end
end
IDLE: begin
    if (s_timeout_valid) begin  // c_timeout mission first
        state <= C_TIMEOUT;
    end else begin
        if (entry_id != entry_id_cur) begin  // if entry_id_cur leading, we should chasing, maybe output timeout event and entry_id ++
            state <= SCAN_TIMEOUT;
        end
    end
end
C_TIMEOUT: begin  //maybe run out of space? todo
    if (ram_data_out < TIMER_SLOT_NUM) begin
        state <= WRITE;
    end else begin  //is full, drop timeout_event
        state <= IDLE;
    end
end
WRITE: begin
    if (aw_done && w_done && b_done) begin
        state <= IDLE;
    end
end
SCAN_TIMEOUT: begin
    if (ram_data_out == 0) begin
        state <= IDLE;
    end else begin
        if ((FIFO_DEPTH - fifo_count) >= (((ram_data_out-1) >> $clog2(AXI_DATA_WIDTH/TIMEOUT_EVENT_WIDTH)) + 1)) begin
            state <= READ;
        end
    end
end
READ: begin
    if (m_axi_rready && m_axi_rvalid && m_axi_rlast) begin
        state <= IDLE;
    end
end
default: begin
end
endcase
end
end

//aw
assign m_axi_awvalid  = ((state == WRITE) && (!aw_done))? 1'b1:1'b0;
assign m_axi_awaddr   = TIMER_START_ADDR + 
    (((timeout_ms * (MS_ENTRY_NUM * TIMER_SLOT_NUM * TIMEOUT_EVENT_WIDTH / 8)) 
    + (entry_id * (TIMER_SLOT_NUM * TIMEOUT_EVENT_WIDTH / 8)) 
    + (ram_data_out >> $clog2(AXI_DATA_WIDTH/TIMEOUT_EVENT_WIDTH))*(AXI_DATA_WIDTH/8)) & {(TIMER_MEM_WIDTH){1'b1}});
assign m_axi_awlen    = 8'b0;   
assign m_axi_awsize   = $clog2(AXI_DATA_WIDTH/8);
assign m_axi_awburst  = 2'b01;  //increment
assign m_axi_awlock   = 1'b0;
assign m_axi_awcache  = 4'd3;
assign m_axi_awprot   = 3'b0;
assign m_axi_awqos    = 4'b0;
assign m_axi_awid     = 1'b0;

//w
assign m_axi_wdata    = timeout_event << (((ram_data_out % (AXI_DATA_WIDTH/TIMEOUT_EVENT_WIDTH))) * (TIMEOUT_EVENT_WIDTH));
assign m_axi_wstrb    = {(TIMEOUT_EVENT_WIDTH/8){1'b1}} << ((ram_data_out % (AXI_DATA_WIDTH/TIMEOUT_EVENT_WIDTH)) * (TIMEOUT_EVENT_WIDTH/8));
assign m_axi_wlast    = 1'b1;
assign m_axi_wvalid   = ((state == WRITE) && (!w_done)) ? 1'b1 : 1'b0;

//b
assign m_axi_bready   = ((state == WRITE) && (!b_done)) ? 1'b1 : 1'b0;

//ar
assign m_axi_arid = 1'b0;
assign m_axi_araddr = TIMER_START_ADDR + 
    (entry_id * (TIMER_SLOT_NUM * TIMEOUT_EVENT_WIDTH / 8));
assign m_axi_arlen = 
    ram_data_out == 0? 8'b0
        :(ram_data_out - 1) >> $clog2(AXI_DATA_WIDTH/TIMEOUT_EVENT_WIDTH);
assign m_axi_arsize = $clog2(AXI_DATA_WIDTH/8);
assign m_axi_arburst = 2'b01;  //increment
assign m_axi_arcache  = 4'd3;
assign m_axi_arprot   = 3'b0;
assign m_axi_arqos    = 4'b0;
assign m_axi_arlock   = 1'b0;
assign m_axi_arvalid  = (state == READ && !ar_done)? 1'b1:1'b0;

//r
// m_axi_rready connect to fifo's ready
// avoid flow_out code is at the state of SCAN_TIMEOUT, if no enough space for 512bit, then not arvalid

always@(posedge clk) begin
case(state)
IDLE: begin
    aw_done <= 1'b0;
end
WRITE: begin
    if (m_axi_awready && m_axi_awvalid) begin
        aw_done <= 1'b1;
    end
end
default: begin
end
endcase
end

always@(posedge clk) begin
case(state)
IDLE: begin
    w_done <= 1'b0;
end
WRITE: begin
    if (m_axi_wready && m_axi_wvalid) begin
        w_done <= 1'b1;
    end
end
default: begin
end
endcase
end

always@(posedge clk) begin
case(state)
IDLE: begin
    b_done <= 1'b0;
end
WRITE: begin
    if (m_axi_bready && m_axi_bvalid) begin
        b_done <= 1'b1;
    end
end
default: begin
end
endcase
end

always@(posedge clk) begin
case(state)
IDLE: begin
    ar_done <= 1'b0;
end
READ: begin
    if (m_axi_arready && m_axi_arvalid) begin
        ar_done <= 1'b1;
    end
end
default: begin
end
endcase
end

simple_dual_port_ram #(
    .DATA_WIDTH(SLOT_ID_WIDTH+1),
    .ADDR_WIDTH(ENTRY_ID_WIDTH),
    .PIPE_DEPTH(1),
    .WRITE_PRIORITY(1)
) timeout_event_num_ram_inst (
    //input;
    .clk(clk),
    .rst(rst),

    .wren(ram_wr_en),
    .rden(ram_rd_en),
    .raddress(ram_raddress),
    .waddress(ram_waddress),
    .data_in(ram_data_in),
    
    //output;
    .data_out(ram_data_out)
);

always@(*) begin
    input_keep <= event_num%(AXI_DATA_WIDTH/TIMEOUT_EVENT_WIDTH) == 0?
                    {(AXI_DATA_WIDTH/8){1'b1}}:
                    (({(AXI_DATA_WIDTH/8){1'b1}} 
                        << ((AXI_DATA_WIDTH/TIMEOUT_EVENT_WIDTH - event_num%(AXI_DATA_WIDTH/TIMEOUT_EVENT_WIDTH)) * (TIMEOUT_EVENT_WIDTH / 8)))
                        >> ((AXI_DATA_WIDTH/TIMEOUT_EVENT_WIDTH - event_num%(AXI_DATA_WIDTH/TIMEOUT_EVENT_WIDTH)) * (TIMEOUT_EVENT_WIDTH / 8)));
end

axis_srl_fifo #(
    .DATA_WIDTH(AXI_DATA_WIDTH),
    .KEEP_ENABLE(1),
    .KEEP_WIDTH(AXI_DATA_WIDTH/8),
    .LAST_ENABLE(1),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .DEPTH(FIFO_DEPTH)
) timeout_event_fifo_inst (
    
    /*
    * System signal
    */
    .clk(clk),
    .rst(rst),

    /*
    * AXI input
    */
    .s_axis_tdata(m_axi_rdata),
    .s_axis_tkeep(m_axi_rlast?input_keep:{(AXI_DATA_WIDTH/8){1'b1}}),
    .s_axis_tvalid(m_axi_rvalid),
    .s_axis_tready(m_axi_rready),
    .s_axis_tlast(m_axi_rlast),
    .s_axis_tid(),
    .s_axis_tdest(),
    .s_axis_tuser(),

    /*
    * AXI output
    */
    .m_axis_tdata(m_axis_adapter_tdata),
    .m_axis_tkeep(m_axis_adapter_tkeep),
    .m_axis_tvalid(m_axis_adapter_tvalid),
    .m_axis_tready(m_axis_adapter_tready),
    .m_axis_tlast(m_axis_adapter_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(),

    /*
    * Status
    */
    .count(fifo_count)
);

// lut adapter
axis_adapter #(
    .S_DATA_WIDTH(AXI_DATA_WIDTH),
    .S_KEEP_ENABLE(1),
    .S_KEEP_WIDTH(AXI_DATA_WIDTH/8),
    .M_DATA_WIDTH(TIMEOUT_EVENT_WIDTH),
    .M_KEEP_ENABLE(1),  // bug warning
    .M_KEEP_WIDTH(TIMEOUT_EVENT_WIDTH/8),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0)
) axis_adapter_inst (
    /*
    * System signal
    */
    .clk(clk),
    .rst(rst),

    /*
    * AXI input
    */
    
    .s_axis_tdata(m_axis_adapter_tdata),
    .s_axis_tkeep(m_axis_adapter_tkeep),
    .s_axis_tvalid(m_axis_adapter_tvalid),
    .s_axis_tready(m_axis_adapter_tready),
    .s_axis_tlast(m_axis_adapter_tlast),
    .s_axis_tid(),
    .s_axis_tdest(),
    .s_axis_tuser(),

    /*
    * AXI output
    */
    .m_axis_tdata(m_timeout_event),
    .m_axis_tkeep(),
    .m_axis_tvalid(m_timeout_valid),
    .m_axis_tready(m_timeout_ready),
    .m_axis_tlast(),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser()
);


/*
reg                         csr_wr_ack_reg = 1'b0;
reg [CSR_DATA_WIDTH-1:0]    csr_rd_data_reg = {CSR_DATA_WIDTH{1'b0}};
reg                         csr_rd_ack_reg = 1'b0;
reg [CSR_DATA_WIDTH-1:0]    example_reg = {CSR_DATA_WIDTH{1'b0}};

reg [8:0]                      entry_id_cur_reg;
reg [8:0]                      entry_id_reg;
reg [31:0]                     awaddr_cnt_reg;
// reg [511:0]                 wdata_cnt_reg;
reg [31:0]                     araddr_cnt_reg;
reg [63:0]                     wdata_cnt_reg;
reg [63:0]                     rdata_cnt_reg;


// assign error_status = error_status_reg;

assign csr_wr_wait = 1'b0;
assign csr_wr_ack = csr_wr_ack_reg;
assign csr_rd_data = csr_rd_data_reg;
assign csr_rd_wait = 1'b0;
assign csr_rd_ack = csr_rd_ack_reg;


always @(posedge clk) begin
    // error_status_reg <= error_status_reg | interface_error;

    if (m_axi_awvalid & m_axi_awready) begin
        awaddr_cnt_reg <= m_axi_awaddr;
    end

    if (m_axi_wvalid & m_axi_wready & m_axi_wlast) begin
        wdata_cnt_reg <= m_axi_wdata;
        entry_id_cur_reg <= entry_id_cur;
    end

    if (m_axi_arvalid & m_axi_arready) begin
        araddr_cnt_reg <= m_axi_araddr;
    end
    
    if (m_axi_rvalid & m_axi_rready & m_axi_rlast) begin
        rdata_cnt_reg <= m_axi_rdata;
        entry_id_reg  <= entry_id;
    end


    if (rst) begin
        // error_status_reg          <= { 8'b0};
        entry_id_cur_reg             <= {9'b0};
        entry_id_reg                 <= {9'b0};
        awaddr_cnt_reg               <= {32'b0};
        araddr_cnt_reg               <= {32'b0};
        // wdata_cnt_reg                <= {512'b0};
        wdata_cnt_reg                <= {64'b0};
        rdata_cnt_reg                <= {64'b0};


    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        csr_wr_ack_reg <= 1'b0;
        csr_rd_ack_reg <= 1'b0;
        csr_rd_data_reg <= {CSR_DATA_WIDTH{1'b0}};
        example_reg <= 32'h2024_0101;

    end else begin
        csr_wr_ack_reg <= 1'b0;
        csr_rd_ack_reg <= 1'b0;
        csr_rd_data_reg <= {CSR_DATA_WIDTH{1'b0}};

        if (csr_wr_en && !csr_wr_ack_reg) begin
            // write operation
            csr_wr_ack_reg <= 1'b1;
            case ({csr_wr_addr >> 2, 2'b00})
                8'h00: begin
                    example_reg <= csr_wr_data;
                end
                default: csr_wr_ack_reg <= 1'b0;
            endcase
        end
        
        if (csr_rd_en && !csr_rd_ack_reg) begin	
            // read operation
            csr_rd_ack_reg <= 1'b1;
            case ({csr_rd_addr >> 2, 2'b00})
                8'h00: csr_rd_data_reg <= example_reg;
                8'h04: csr_rd_data_reg <= awaddr_cnt_reg;
                8'h08: csr_rd_data_reg <= araddr_cnt_reg;
                8'h0c: csr_rd_data_reg <= wdata_cnt_reg[31:0];               
                8'h10: csr_rd_data_reg <= wdata_cnt_reg[63:32];
                8'h14: csr_rd_data_reg <= rdata_cnt_reg[31:0];               
                8'h18: csr_rd_data_reg <= rdata_cnt_reg[63:32];
                8'h20: csr_rd_data_reg <= {entry_id_cur_reg,entry_id_reg};
                8'h24: csr_rd_data_reg <= input_keep[31:0];
                8'h28: csr_rd_data_reg <= input_keep[63:32];
                8'h2c: csr_rd_data_reg <= timeout_ms;

                8'h30: csr_rd_data_reg <= entry_id_cur;
                8'h34: csr_rd_data_reg <= entry_id;
                8'h38: csr_rd_data_reg <= ram_data_out;

                // 8'h14: csr_rd_data_reg <= wdata_cnt_reg[95:64];
                // 8'h18: csr_rd_data_reg <= wdata_cnt_reg[127:96];

                // 8'h20: csr_rd_data_reg <= wdata_cnt_reg[159:128];
                // 8'h24: csr_rd_data_reg <= wdata_cnt_reg[191:160];
                // 8'h28: csr_rd_data_reg <= wdata_cnt_reg[223:192];
                // 8'h2c: csr_rd_data_reg <= wdata_cnt_reg[255:224];

                // 8'h30: csr_rd_data_reg <= wdata_cnt_reg[287:256];
                // 8'h34: csr_rd_data_reg <= wdata_cnt_reg[319:288];
                // 8'h38: csr_rd_data_reg <= wdata_cnt_reg[351:320];
                // 8'h3c: csr_rd_data_reg <= wdata_cnt_reg[383:352];
                
                // 8'h40: csr_rd_data_reg <= wdata_cnt_reg[415:384];
                // 8'h44: csr_rd_data_reg <= wdata_cnt_reg[447:416];
                // 8'h48: csr_rd_data_reg <= wdata_cnt_reg[479:448];
                // 8'h4c: csr_rd_data_reg <= wdata_cnt_reg[511:480];
                default: csr_rd_ack_reg <= 1'b0;
            endcase
        end
    end
end
*/
endmodule
`resetall