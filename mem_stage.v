module mem_stage(
    input  wire        clk,
    input  wire        resetn,              // 异步复位信号，低电平有效
    input  wire        ws_allowin,          // WB 阶段是否允许接受数据
    input  wire        ms_allowin,          // EXE 阶段是否允许向 MEM 阶段发送数据
    input  wire [70:0] es_to_ms_bus,        // 从 EXE 阶段传来的数据总线
    input  wire [31:0] data_sram_rdata,     // 从数据 SRAM 读取的数据
    input  wire        es_to_ms_valid,      // 从 EXE 阶段传来的 valid 信号

    output wire        ms_to_ws_valid,      // 传给 WB 阶段的 valid 信号
    output wire [69:0] ms_to_ws_bus,        // 传给 WB 阶段的数据总线
    output wire [4:0]  ms_to_ds_dest,       // 当前 MEM 阶段目的寄存器编号（供 ID 阶段 hazard 判断）
    output  reg ms_valid,              // MEM 阶段是否有指令有效
    output wire [31:0] ms_forward_data, // MEM 阶段的旁路数据（供 ID 阶段 hazard 判断）
    output wire [31:0] ms_final_result      // MEM 阶段最终运算结果（供 EXE forward 使用）
);

reg         ms_valid;
reg [31:0]  ms_pc;
reg         ms_gr_we;
reg [4:0]   ms_dest;
reg [31:0]  ms_alu_result;
reg         ms_res_from_mem;
reg [31:0]  ms_data_sram_rdata;

wire        ms_ready_go;
assign      ms_ready_go    = 1'b1;
assign      ms_to_ws_valid = ms_valid && ms_ready_go;
assign      ms_to_ds_dest  = ms_dest & {5{ms_valid}};

// MEM 阶段寄存器更新
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        ms_valid <= 1'b0;
    end else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        {ms_pc,
         ms_gr_we,
         ms_dest,
         ms_alu_result,
         ms_res_from_mem} <= es_to_ms_bus;
    end
end

// 保存从 SRAM 读出的数据
always @(posedge clk) begin
    if (es_to_ms_valid && ms_allowin) begin
        ms_data_sram_rdata <= data_sram_rdata;
    end
end

assign ms_final_result = ms_res_from_mem ? ms_data_sram_rdata : ms_alu_result;

assign ms_to_ws_bus = {
    ms_pc,               // 69:38
    ms_gr_we,            // 37
    ms_dest,             // 36:32
    ms_final_result      // 31:0
};

endmodule
