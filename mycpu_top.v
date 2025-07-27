module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
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

wire reset;
assign reset = ~resetn;

    // allow_in
    wire ds_allowin;
    wire es_allowin;
    wire ms_allowin;
    wire ws_allowin;

    // bus
    wire [63:0] fs_to_ds_bus;
    wire [150:0] ds_to_es_bus;
    wire [70:0] es_to_ms_bus;
    wire [5:0] es_to_ds_bus;// 用于判断alter指令是否需要阻塞

    wire [69:0] ms_to_ws_bus;
    wire [33:0] br_bus;
    wire [37:0] ws_to_ds_bus;

    // valid
    wire fs_to_ds_valid;
    wire ds_to_es_valid;
    wire es_to_ms_valid;
    wire ms_to_ws_valid;
    wire es_valid_out;// from exe_stageexe阶段当前是否有有效指令(传给id）)
    wire inst_bl;
    wire ms_valid; // MEM 阶段当前是否有有效指令
    //dest
    wire [4:0] es_to_ds_dest;
    wire [4:0] ms_to_ds_dest;
    wire [4:0] ws_to_ds_dest;

    if_stage u_if_stage(
        .clk(clk),
        .resetn(resetn),
        .ds_allowin(ds_allowin),
        .br_bus(br_bus),
        .inst_sram_en(inst_sram_en),
        .inst_sram_we(inst_sram_we),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata),
        .fs_to_ds_bus(fs_to_ds_bus),
        .fs_to_ds_valid(fs_to_ds_valid)
    );

    id_stage u_id_stage(
        .clk(clk),
        .resetn(resetn),
        .es_allowin(es_allowin),
        .fs_to_ds_valid(fs_to_ds_valid),
        .fs_to_ds_bus(fs_to_ds_bus),
        .ws_to_ds_bus(ws_to_ds_bus),
        .es_to_ds_dest(es_to_ds_dest),
        .ms_to_ds_dest(ms_to_ds_dest),
        .ws_to_ds_dest(ws_to_ds_dest),
        .es_to_ds_bus(es_to_ds_bus), // 用于判断alter指令是否需要阻塞
        .es_valid(es_valid_out),// from exe_stageexe阶段当前是否有有效指令
        .ds_allowin(ds_allowin),
        .br_bus(br_bus),
        .ds_to_es_bus(ds_to_es_bus),
        .ds_to_es_valid(ds_to_es_valid),
        .es_forward_data   (es_alu_result), // EXE 阶段转发数据
        .ms_forward_data   (ms_final_result),
        .ms_valid          (ms_valid)
    );

    exe_stage u_exe_stage(
        .clk(clk),
        .resetn(resetn),
        .ms_allowin(ms_allowin),
        .ds_to_es_valid(ds_to_es_valid),
        .es_allowin(es_allowin),
        .ds_to_es_bus(ds_to_es_bus),
        .es_to_ms_bus(es_to_ms_bus),
        .es_to_ms_valid(es_to_ms_valid),
        .data_sram_en(data_sram_en),
        .data_sram_we(data_sram_we),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .es_to_ds_bus(es_to_ds_bus), // 用于判断alter指令是否需要阻塞
        .es_to_ds_dest(es_to_ds_dest), // 给 ID 阶段用：当前 EXE 的写寄存器编号
        .es_valid_out(es_valid_out) // from exe_stageexe阶段当前是否有有效指令(传给id）
    );

    mem_stage u_mem_stage(
        .clk(clk),
        .resetn(resetn),
        .ws_allowin(ws_allowin),
        .ms_allowin(ms_allowin),
        .es_to_ms_bus(es_to_ms_bus),
        .data_sram_rdata(data_sram_rdata),
        .es_to_ms_valid(es_to_ms_valid),
        .ms_to_ws_valid(ms_to_ws_valid),
        .ms_to_ds_dest(ms_to_ds_dest), // 给 ID 阶段用：当前 MEM 的写寄存器编号 
        .ms_to_ws_bus(ms_to_ws_bus)
    );

    wb_stage u_wb_stage(
        .clk(clk),
        .resetn(resetn),
        .ws_allowin(ws_allowin),
        .ms_to_ws_valid(ms_to_ws_valid),
        .ms_to_ws_bus(ms_to_ws_bus),
        .ws_to_ds_bus(ws_to_ds_bus),
        .ws_to_ds_dest(ws_to_ds_dest), // 给 ID 阶段用：当前 WB 的写寄存器编号
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );

endmodule
