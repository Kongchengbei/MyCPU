module mycpu_top(
    input  wire        clk,
    /*异步信号如果直接进入同步时序逻辑，
    会有亚稳态问题（metastability）。
    所以用一个寄存器（reset）在时钟上升沿将其采样同步化*/
    input  wire        resetn,//resetn 通常来自外部按键或电路，是异步信号(不受clk限制）
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
//异步低电平有效复位信号（resetn），同步地转化为同步高电平有效复位信号（reset）
reg         reset;
always @(posedge clk) reset <= ~resetn; //resetn:低电平复位有效信号

// allow_in
wire ds_allow_in;
wire es_allow_in;
wire ms_allow_in;
wire ws_allow_in;

// bus
wire [63:0] fs_ds_bus;
wire [150:0] ds_es_bus;
wire [70:0] es_ms_bus;
wire [69:0] ms_ws_bus;
wire [33:0] br_bus;
wire [37:0] ws_rf_bus;

// valid
wire fs_to_ds_valid;
wire ds_to_es_valid;
wire es_to_ms_valid;
wire ms_to_ws_valid;

// inst_bl
wire to_es_inst_bl;

// block
wire es_load;
wire [4:0] es_dest;
wire [4:0] ms_dest;
wire [4:0] ws_dest;

if_stage fs(
    .clk(clk),
    .reset(reset),
    .ds_allow_in(ds_allow_in),
    .br_bus(br_bus),
    .inst_sram_en(inst_sram_en),
    .inst_sram_we(inst_sram_we),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),
    .fs_ds_bus(fs_ds_bus),
    .fs_to_ds_valid(fs_to_ds_valid)
);

id_stage ds(
   .clk(clk),
   .reset(reset),
   .es_allow_in(es_allow_in),
   .fs_to_ds_valid(fs_to_ds_valid),
   .fs_ds_bus(fs_ds_bus),
   .ws_rf_bus(ws_rf_bus),
   .ds_allow_in(ds_allow_in),
   .br_bus(br_bus),
   .ds_es_bus(ds_es_bus),
   .ds_to_es_valid(ds_to_es_valid),
   .to_es_inst_bl(to_es_inst_bl),
   .es_dest(es_dest),
   .ws_dest(ws_dest),
   .ms_dest(ms_dest),
   .es_load(es_load)
);

exe_stage es(
    .clk(clk),
    .reset(reset),
    .ms_allow_in(ms_allow_in),
    .ds_to_es_valid(ds_to_es_valid),
    .es_allow_in(es_allow_in),
    .ds_es_bus(ds_es_bus),
    .inst_bl(to_es_inst_bl),
    .es_ms_bus(es_ms_bus),
    .es_to_ms_valid(es_to_ms_valid),
    .data_sram_en(data_sram_en),
    .data_sram_we(data_sram_we),
    .data_sram_addr(data_sram_addr),
    .data_sram_wdata(data_sram_wdata),
    .es_dest_reg(es_dest),
    .es_load(es_load)
);

mem_stage ms(
    .clk(clk),
    .reset(reset),
    .ws_allow_in(ws_allow_in),
    .ms_allow_in(ms_allow_in),
    .es_ms_bus(es_ms_bus),
    .data_sram_rdata(data_sram_rdata),
    .es_to_ms_valid(es_to_ms_valid),    
    .ms_to_ws_valid(ms_to_ws_valid),
    .ms_ws_bus(ms_ws_bus),
    .ms_dest_reg(ms_dest)
);

wb_stage ws(
    .clk(clk),
    .reset(reset),
    .ws_allow_in(ws_allow_in),
    .ms_to_ws_valid(ms_to_ws_valid),
    .ms_ws_bus(ms_ws_bus),
    .ws_rf_bus(ws_rf_bus),
    .debug_wb_pc(debug_wb_pc),
    .debug_wb_rf_we(debug_wb_rf_we),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    .ws_dest_reg(ws_dest)
);

endmodule
