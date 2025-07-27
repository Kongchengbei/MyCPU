module id_stage(
    input         clk,
    input         resetn,
    input         es_allowin,
    input         fs_to_ds_valid,
    input  [63:0] fs_to_ds_bus,
    input  [37:0] ws_to_ds_bus,
    input  [5:0] es_to_ds_bus, // 用于判断alter指令是否需要阻塞
    input es_valid, // from exe_stageexe阶段当前是否有有效指令
    input   [4:0] es_to_ds_dest, //EXE阶段目的寄存器号
    input [4:0] ms_to_ds_dest, //MEM阶段目的寄存器号
    input [4:0] ws_to_ds_dest, //WB阶段目的寄存器号(最终将写回的寄存器)
    input [31:0] es_forward_data, //EXE阶段转发数据
    input [31:0] ms_forward_data, //MEM阶段转发数据
    input        ms_valid, // MEM 阶段当前是否有有效指令
    output        ds_allowin,
    output [33:0] br_bus,
    output [150:0] ds_to_es_bus,
    output        ds_to_es_valid,
    output        to_es_inst_bl
);
wire        es_res_from_mem_out;
wire [4:0]  es_dest_out;
assign {
    es_res_from_mem_out,  // [5]
    es_dest_out           // [4:0]
} = es_to_ds_bus;
wire inst_no_dest;// 无目的寄存器写回：如 store、b、beq、bne（不写寄存器）
wire src_no_rj;// 指令不使用 rj 作为源寄存器
wire src_no_rk;// 指令不使用 rk 作为源寄存器
wire src_no_rd;// 指令不使用 rd 作为源寄存器
wire rj_wait;// rj 寄存器等待写回
wire rk_wait;// rk 寄存器等待写回
wire rd_wait;// rd 寄存器等待写回
wire no_wait;// 无寄存器等待写回
//不需要 rj 参与运算（避免误判冲突）
assign src_no_rj = inst_b | inst_bl | inst_lu12i_w;
// 不需要 rk 参与运算
assign src_no_rk = inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w |
                   inst_ld_w | inst_st_w | inst_jirl |
                   inst_b | inst_bl | inst_beq | inst_bne | inst_lu12i_w;
// 不需要 rd 参与运算（主要用于 store、beq、bne）
assign src_no_rd = ~inst_st_w & ~inst_beq & ~inst_bne;
// 判断源寄存器是否需要等待
assign rj_wait = ~src_no_rj && (rj != 5'b0) &&
                ((rj == es_to_ds_dest) || (rj == ms_to_ds_dest) || (rj == ws_to_ds_dest));

assign rk_wait = ~src_no_rk && (rk != 5'b0) &&
                ((rk == es_to_ds_dest) || (rk == ms_to_ds_dest) || (rk == ws_to_ds_dest));

assign rd_wait = ~src_no_rd && (rd != 5'b0) &&
                ((rd == es_to_ds_dest) || (rd == ms_to_ds_dest) || (rd == ws_to_ds_dest));

assign no_wait = ~rj_wait && ~rk_wait && ~rd_wait;

reg  [31:0] ds_pc;
reg  [31:0] ds_inst;
reg         ds_valid;
reg         delay_slot;
wire        ds_ready_go;

wire [31:0] br_offs;
wire [31:0] jirl_offs;
wire        src_reg_is_rd;
wire        dst_is_r1;
wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire        rf_we;
wire [4:0]  rf_waddr;
wire [31:0] rf_wdata;
wire [4:0]  rf_raddr1;
wire [31:0] rf_rdata1;
wire [4:0]  rf_raddr2;
wire [31:0] rf_rdata2;

wire [11:0] alu_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_4;
wire        res_from_mem;
wire        gr_we;
wire        mem_we;
wire [4:0]  dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;

wire        br_taken;
wire [31:0] br_target;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire inst_add_w, inst_sub_w, inst_slt, inst_sltu;
wire inst_nor, inst_and, inst_or, inst_xor;
wire inst_slli_w, inst_srli_w, inst_srai_w, inst_addi_w;
wire inst_ld_w, inst_st_w, inst_jirl, inst_b, inst_bl;
wire inst_beq, inst_bne, inst_lu12i_w;

wire need_ui5, need_si12, need_si16, need_si20, need_si26;

assign op_31_26 = ds_inst[31:26];
assign op_25_22 = ds_inst[25:22];
assign op_21_20 = ds_inst[21:20];
assign op_19_15 = ds_inst[19:15];

assign rd = ds_inst[4:0];
assign rj = ds_inst[9:5];
assign rk = ds_inst[14:10];

assign i12 = ds_inst[21:10];
assign i20 = ds_inst[24:5];
assign i16 = ds_inst[25:10];
assign i26 = {ds_inst[9:0], ds_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26), .out(op_31_26_d));
decoder_4_16 u_dec1(.in(op_25_22), .out(op_25_22_d));
decoder_2_4  u_dec2(.in(op_21_20), .out(op_21_20_d));
decoder_5_32 u_dec3(.in(op_19_15), .out(op_19_15_d));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ds_inst[25];

assign to_es_inst_bl = inst_bl;

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | inst_bl;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_slli_w;
assign alu_op[ 9] = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;

assign need_ui5   = inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  = inst_addi_w | inst_ld_w | inst_st_w;
assign need_si16  = inst_jirl | inst_beq | inst_bne;
assign need_si20  = inst_lu12i_w;
assign need_si26  = inst_b | inst_bl;
assign src2_is_4  = inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4 :
             need_si20 ? {i20[19:0], 12'b0} :
             {{20{i12[11]}}, i12[11:0]};

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                            {{14{i16[15]}}, i16[15:0], 2'b0};
assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};
assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;
assign src1_is_pc    = inst_jirl | inst_bl;
assign src2_is_imm   = inst_slli_w | inst_srli_w | inst_srai_w |
                       inst_addi_w | inst_ld_w   | inst_st_w |
                       inst_lu12i_w| inst_jirl   | inst_bl;
assign res_from_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b | inst_bl;
assign mem_we        = inst_st_w;
assign dest          = dst_is_r1 ? 5'd1 : rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd : rk;
assign {rf_we, rf_waddr, rf_wdata} = ws_to_ds_bus;

regfile u_regfile(
    .clk    (clk),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we),
    .waddr  (rf_waddr),
    .wdata  (rf_wdata)
);

assign rj_value  =     
    (rj == es_to_ds_dest && es_valid) ? es_forward_data :
    (rj == ms_to_ds_dest && ms_valid) ? ms_forward_data :
    (rj == ws_to_ds_dest && rf_we)    ? rf_wdata :
    rf_rdata1;
assign rkd_value = (src_reg_is_rd ? rd : rk) == es_to_ds_dest && es_valid ? es_forward_data :
    (src_reg_is_rd ? rd : rk) == ms_to_ds_dest && ms_valid ? ms_forward_data :
    (src_reg_is_rd ? rd : rk) == ws_to_ds_dest && rf_we    ? rf_wdata :
    rf_rdata2;

/* 如果 EXE 阶段有一条有效的 lw 指令，它的写目标是当前这条指令的读源（raddr1 或 raddr2），
那么当前这条指令就不能推进，会触发阻塞（stall)*/
wire lw_conflict;//是否存在lw_use冲突
assign lw_conflict = es_valid && es_res_from_mem_out && (es_dest_out != 5'b0) &&
                     (es_dest_out == rf_raddr1 || es_dest_out == rf_raddr2);/*如果exe阶段有lw指令且目的寄存器不为0，
                     且目的寄存器与当前指令的读源相同，则发生冲突*/

assign ds_to_es_bus = {
    ds_pc,
    alu_op,
    src2_is_4,
    src1_is_pc,
    src2_is_imm,
    gr_we,
    mem_we,
    dest,
    imm,
    rj_value,
    rkd_value,
    res_from_mem
};

assign br_taken = ((inst_beq && rj_value == rkd_value) ||
                  (inst_bne && rj_value != rkd_value) ||
                  inst_jirl || inst_bl || inst_b) &&
                  ds_valid && no_wait;//确保跳转指令源数据已就绪
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ?
                    (ds_pc + br_offs) : (rj_value + jirl_offs);
wire br_stall;// 是否需要阻塞
assign br_stall = lw_conflict && br_taken && ds_valid;
assign br_bus = {
    br_stall,             // 33,用于让IF阶段暂停，防止提前跳
    br_taken && ds_valid,  // 32
    br_target              // 31:0
};

assign ds_ready_go    = ~lw_conflict;
assign ds_allowin     = !ds_valid || (ds_ready_go && es_allowin);
assign ds_to_es_valid = ds_valid && ds_ready_go && !delay_slot;
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        ds_valid <= 1'b0;
        delay_slot <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end

    if (!resetn) begin
        ds_pc <= 32'b0;
        ds_inst <= 32'b0;
    end else if (fs_to_ds_valid && ds_allowin) begin
        {ds_pc, ds_inst} <= fs_to_ds_bus;
        if (br_taken) begin
            delay_slot <= 1'b1;
        end else begin
            delay_slot <= 1'b0;
        end
    end
end

endmodule
