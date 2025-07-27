module exe_stage(
    input         clk,
    input         resetn,              
    input         ms_allowin,
    input         ds_to_es_valid,
    input         es_allowin,
    input  [150:0] ds_to_es_bus,
    output [70:0]  es_to_ms_bus,
    output        es_to_ms_valid,
    output        data_sram_en,
    output [ 3:0] data_sram_we,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    output        es_valid_out,
    output wire [31:0] es_alu_result, // EXE 阶段的 ALU 结果
    output [5:0]  es_to_ds_bus, // 用于判断alter指令是否需要阻塞
    output [4:0]  es_to_ds_dest  // 给 ID 阶段用：当前 EXE 的写寄存器编号
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
    reg         es_inst_bl;

    wire [31:0] alu_result;
    wire [31:0] alu_src1;
    wire [31:0] alu_src2;

    wire        es_ready_go;
    assign      es_ready_go    = 1'b1;
    assign      es_allowin     = !es_valid || (es_ready_go && ms_allowin);
    assign      es_to_ms_valid = es_valid && es_ready_go;
    reg [70:0] es_to_ms_bus_r;


    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            es_valid <= 1'b0;
        end
        else if (es_allowin) begin
            es_valid <= ds_to_es_valid;
        end

        if (!resetn) begin
            es_inst_bl <= 1'b0;
        end
        else if (ds_to_es_valid && es_allowin) begin
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
             es_res_from_mem,
             es_inst_bl} <= ds_to_es_bus;
        end
    end

    assign alu_src1 = es_src1_is_pc ? es_pc : es_rj_value;

 /*----exp8改动点
 bl 本身也带了立即数，所以 es_src2_is_imm = 1。
如果优先判断 es_src2_is_imm，
那就会错误地选用 es_imm → 变成了 PC + offset，而不是 PC + 4！*/
    assign alu_src2 = es_inst_bl ? 32'd4 :
                     es_src2_is_imm ? es_imm : es_rkd_value;
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
        always @(posedge clk or negedge resetn) begin
        if (!resetn)
            es_to_ms_bus_r <= 70'b0;
        else if (es_valid && ms_allowin && es_ready_go) begin
            es_to_ms_bus_r <= {
                es_pc,
                es_gr_we,
                es_dest,
                alu_result,
                es_res_from_mem
            };
        end
    end
    assign      es_to_ms_bus = es_to_ms_bus_r;
    assign es_to_ds_dest = es_dest & {5{es_valid}}; 
     // 如果 es_valid 为 1，输出 es_dest；否则输出 0（表示无效）
    assign es_to_ds_bus = {
    es_res_from_mem,   // 1
    es_dest                  // 5 
};
    assign es_valid_out = es_valid;
    assign data_sram_en    = 1'b1;
    assign data_sram_we    = es_mem_we && es_valid ? 4'b1111 : 4'b0000;
    assign data_sram_addr  = alu_result;
    assign data_sram_wdata = es_rkd_value;

endmodule
