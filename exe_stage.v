module exe_stage(
    input         clk,
    input         reset,
    input  ms_allow_in,
    input  ds_to_es_valid,
    output es_allow_in,
    input  [150:0]ds_es_bus,
    input   inst_bl,
    output [70:0]es_ms_bus,
    output  es_to_ms_valid,
    output        data_sram_en,
    output [ 3:0] data_sram_we,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    output es_load,
    output [37:0] es_fwd_bus,
    output reg [4:0]  es_dest
);

    reg  [31:0] es_pc;
    reg         es_valid;
    wire        es_ready_go;
    reg  [11:0] es_alu_op;
    reg         es_src1_is_pc;
    reg         es_src2_is_imm;
    reg         es_src2_is_4;
    reg         es_res_from_mem;
    reg         es_gr_we;
    reg         es_mem_we;
    reg  [31:0] es_rj_value;
    reg  [31:0] es_rkd_value;
    reg  [31:0] es_imm;
    wire [31:0] alu_result;
    reg         es_inst_bl;
    wire [31:0] alu_src1;
    wire [31:0] alu_src2;

    assign es_ready_go    = 1'b1;
    assign es_allow_in     = !es_valid || (es_ready_go && ms_allow_in);
    assign es_to_ms_valid =  es_valid && es_ready_go;

    assign es_ms_bus = {
                        es_pc,         // 70:39
                        es_gr_we,      // 38
                        es_dest,       // 37:33
                        alu_result,    // 32:1
                        es_res_from_mem// 0
    };

    assign es_fwd_bus = {
    es_gr_we & es_valid,  // 1 bit，确保无效指令不前递
    es_dest,              // 5 bit
    alu_result            // 32 bit
};

    always @(posedge clk) begin
        if (reset) begin
            es_valid <= 1'b0;
        end else if (es_allow_in) begin
            es_valid <= ds_to_es_valid;
        end

        if (ds_to_es_valid && es_allow_in) begin
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
             es_res_from_mem} <= ds_es_bus;
            es_inst_bl <= inst_bl;
        end
    end

    assign es_load = es_res_from_mem;

    alu u_alu(
        .alu_op     (es_alu_op),
        .alu_src1   (alu_src1),
        .alu_src2   (alu_src2),
        .alu_result (alu_result)
    );

    assign alu_src1 = es_src1_is_pc ? es_pc : es_rj_value;
    assign alu_src2 = es_src2_is_imm ? es_imm : (es_inst_bl ? 32'd4 : es_rkd_value);

    assign data_sram_en    = 1'b1;
    assign data_sram_we    = es_mem_we && es_valid ? 4'b1111 : 4'b0000;
    assign data_sram_addr  = alu_result;
    assign data_sram_wdata = es_rkd_value;

endmodule
/* for exp 9:
访存级结果的前递路径起点就是数据RAM返回结果
和访存级缓存所存的ALU结果经过二选一之后的结果输出处
(EXE 阶段的 ALU 输出（即这条指令刚算完）
另有写回阶段

*/