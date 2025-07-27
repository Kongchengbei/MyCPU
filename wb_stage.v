module wb_stage(
    input  wire        clk,
    input  wire        resetn,              // 异步复位信号，低电平有效
    input  wire        ms_to_ws_valid,      // 来自 MEM 阶段的 valid 信号
    input  wire [69:0] ms_to_ws_bus,        // 来自 MEM 阶段的数据总线
    output wire        ws_allowin,          // WB 阶段是否允许接受数据
    output wire [37:0] ws_to_ds_bus,        // 传给 ID 阶段的写回信息（旁路）
    output wire [4:0]  ws_to_ds_dest,       // 当前 WB 阶段目的寄存器编号（供 ID 阶段 hazard 判断）

    // DEBUG 信号输出
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

reg         ws_valid;
reg [31:0]  ws_pc;
reg         ws_gr_we;
reg [4:0]   ws_dest;
reg [31:0]  ws_final_result;

wire        rf_we;
wire [4:0]  rf_waddr;
wire [31:0] rf_wdata;

assign ws_allowin  = !ws_valid || 1'b1;  // WB 阶段默认总是 ready

// WB 阶段寄存器更新
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        ws_valid        <= 1'b0;
        ws_pc           <= 32'b0;
        ws_gr_we        <= 1'b0;
        ws_dest         <= 5'b0;
        ws_final_result <= 32'b0;
    end else if (ws_allowin) begin
        ws_valid        <= ms_to_ws_valid;
        {ws_pc, ws_gr_we, ws_dest, ws_final_result} <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we && ws_valid;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;

// 旁路总线发给 ID 阶段
assign ws_to_ds_bus = {
    rf_we,      // 37:37 写使能
    rf_waddr,   // 36:32 写寄存器编号
    rf_wdata    // 31:0 写数据
};
assign ws_to_ds_dest = ws_dest & {5{ws_valid}};

// DEBUG 信号赋值
assign debug_wb_pc       = rf_we ? ws_pc           : 32'b0;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_we ? ws_dest         : 5'b0;
assign debug_wb_rf_wdata = rf_we ? ws_final_result : 32'b0;

endmodule
