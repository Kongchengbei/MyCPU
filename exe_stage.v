module exe_stage(
    input         clk,
    input         resetn,              // 异步复位信号，低电平有效
    input         ms_allowin,          // MEM 阶段是否允许接受数据
    input         ds_to_es_valid,      // ID 阶段传来的指令是否有效
    output        es_allowin,          // EXE 阶段是否允许接受下一条指令
    input  [150:0] ds_to_es_bus,       // 从 ID 阶段传来的总线数据

    output [70:0]  es_to_ms_bus,       // 传给 MEM 阶段的数据
    output        es_to_ms_valid,      // 传给 MEM 阶段的 valid 信号
    output        data_sram_en,        // 数据 SRAM 使能
    output [ 3:0] data_sram_we,        // 数据 SRAM 写使能
    output [31:0] data_sram_addr,      // 数据 SRAM 地址
    output [31:0] data_sram_wdata,     // 数据 SRAM 写入数据
    //output [5:0] es_to_ds_bus,      // 传给 ID 阶段的旁路数据
    output        es_valid_out,        // 当前 EXE 阶段是否有指令有效（供 ID 阶段判断）
    output [31:0] es_alu_result,       // EXE 阶段的 ALU 运算结果
    output        es_to_ds_load_op,    // 是否是 load 指令（供 ID 阶段 hazard 判断）
    output [4:0]  es_to_ds_dest        // 当前 EXE 阶段的目的寄存器编号（供 ID 阶段 hazard 判断）
);

reg         es_valid;
reg [31:0]  es_pc;
reg [11:0]  es_alu_op;
reg         es_src1_is_pc;
reg         es_src2_is_imm;
reg         es_src2_is_4;
reg         es_res_from_mem;
reg         es_gr_we;
reg         es_mem_we;
reg [ 4:0]  es_dest;
reg [31:0]  es_rj_value;
reg [31:0]  es_rkd_value;
reg [31:0]  es_imm;

wire [31:0] alu_result;
wire [31:0] alu_src1;
wire [31:0] alu_src2;

wire        es_ready_go;
assign      es_ready_go    = 1'b1;
assign      es_allowin     = !es_valid || (es_ready_go && ms_allowin);
assign      es_to_ms_valid = es_valid && es_ready_go;

// EXE 阶段控制信号与操作数寄存器的寄存器保持
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        es_valid <= 1'b0;
    end else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (!resetn) begin
        es_pc <= 32'b0;
        es_alu_op <= 12'b0;
        es_src2_is_4 <= 1'b0;
        es_src1_is_pc <= 1'b0;
        es_src2_is_imm <= 1'b0;
        es_gr_we <= 1'b0;
        es_mem_we <= 1'b0;
        es_dest <= 5'b0;
        es_imm <= 32'b0;
        es_rj_value <= 32'b0;
        es_rkd_value <= 32'b0;
        es_res_from_mem <= 1'b0;
    end else if (ds_to_es_valid && es_allowin) begin
        {es_pc,
         es_alu_op,
         es_src2_is_4,
         es_src1_is_pc,
         es_src2_is_imm,
         es_gr_we,
         es_mem_we,
         es_dest,
         es_imm,
         es_rj_value,
         es_rkd_value,
         es_res_from_mem} <= ds_to_es_bus;
    end
end
/*----exp8改动点
 bl 本身也带了立即数，所以 es_src2_is_imm = 1。
如果优先判断 es_src2_is_imm，
那就会错误地选用 es_imm → 变成了 PC + offset，而不是 PC + 4！*/

assign alu_src1 = es_src1_is_pc ? es_pc : es_rj_value;
assign alu_src2 = es_src2_is_4 ? 32'd4 : (es_src2_is_imm ? es_imm : es_rkd_value);
                    // 如果是 bl 指令，则 src2 是 4；
                     //如果是立即数，则 src2 是立即数，
                     //否则是寄存器值
alu u_alu (
    .alu_op     (es_alu_op),
    .alu_src1   (alu_src1),
    .alu_src2   (alu_src2),
    .alu_result (alu_result)
);

assign es_alu_result = alu_result;

// 数据存储器接口
assign data_sram_en    = 1'b1;
assign data_sram_we    = es_mem_we && es_valid ? 4'b1111 : 4'b0000;
assign data_sram_addr  = alu_result;
assign data_sram_wdata = es_rkd_value;

// 传给 MEM 阶段的数据总线
assign es_to_ms_bus = {
    es_pc,             // 70:39
    es_gr_we,          // 38
    es_dest,           // 37:33
    alu_result,        // 32:1
    es_res_from_mem    // 0
};
/*assign es_to_ds_bus = {
    es_res_from_mem, // bit 5
    es_dest          // bit [4:0]
};*/


// 用于旁路与 load-use hazard 的信号
assign es_to_ds_dest    = es_dest & {5{es_valid}};
assign es_to_ds_load_op = es_res_from_mem & es_valid;
assign es_valid_out     = es_valid;

endmodule
