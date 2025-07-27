module id_stage(
    input         clk,
    input         resetn,
    input         es_allowin,
    input         fs_to_ds_valid,
    input  [63:0] fs_to_ds_bus,
    input  [37:0] ws_to_ds_bus,
    input  [4:0]  es_to_ds_dest,
    input  [4:0]  ms_to_ds_dest,
    input  [4:0]  ws_to_ds_dest,
    input  [31:0] es_forward_data,
    input  [31:0] ms_forward_data,
    input         ms_valid,
    input         es_valid,
    input         es_to_ds_load_op,
    output        ds_allowin,
    output [33:0] br_bus,
    output [150:0] ds_to_es_bus,
    output        ds_to_es_valid
);

reg         ds_valid;
reg  [31:0] ds_pc;
reg  [31:0] ds_inst;
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

wire        rf_we;
wire [4:0]  rf_waddr;
wire [31:0] rf_wdata;
wire [4:0]  rf_raddr1;
wire [31:0] rf_rdata1;
wire [4:0]  rf_raddr2;
wire [31:0] rf_rdata2;

assign {rf_we, rf_waddr, rf_wdata} = ws_to_ds_bus;

wire [31:0] fs_pc;
wire [31:0] fs_inst;
assign {fs_pc, fs_inst} = fs_to_ds_bus;

assign op_31_26 = ds_inst[31:26];
assign op_25_22 = ds_inst[25:22];
assign op_21_20 = ds_inst[21:20];
assign op_19_15 = ds_inst[19:15];

wire [4:0] rd_r_type = ds_inst[4:0];
wire [4:0] rd_i_type = ds_inst[20:16];
wire [4:0] rj_r_type = ds_inst[9:5];
wire [4:0] rj_i_type = ds_inst[25:21];
assign rk = ds_inst[14:10];

assign rd = (inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | inst_beq | inst_bne | inst_lu12i_w) ? rd_i_type : rd_r_type;
assign rj = (inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | inst_beq | inst_bne) ? rj_i_type : rj_r_type;

assign i12 = ds_inst[21:10];
assign i20 = ds_inst[24:5];
assign i16 = ds_inst[25:10];
assign i26 = {ds_inst[9:0], ds_inst[25:10]};

// decoder_6_64 / 4_16 / 2_4 / 5_32 保持不变

// 控制信号 assign alu_op / need_imm / is_pc / res_from_mem / gr_we 等略，保持原有定义

assign imm = src2_is_4 ? 32'h4 :
             need_si20 ? {i20[19:0], 12'b0} :
             {{20{i12[11]}}, i12[11:0]};

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                            {{14{i16[15]}}, i16[15:0], 2'b0};
assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd : rk;

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

assign rj_value = (rj == es_to_ds_dest && es_valid) ? es_forward_data :
                  (rj == ms_to_ds_dest && ms_valid) ? ms_forward_data :
                  (rj == ws_to_ds_dest && rf_we)    ? rf_wdata :
                  rf_rdata1;

assign rkd_value = (src_reg_is_rd ? rd : rk) == es_to_ds_dest && es_valid ? es_forward_data :
                   (src_reg_is_rd ? rd : rk) == ms_to_ds_dest && ms_valid ? ms_forward_data :
                   (src_reg_is_rd ? rd : rk) == ws_to_ds_dest && rf_we    ? rf_wdata :
                   rf_rdata2;

wire src_no_rj = inst_b | inst_bl | inst_lu12i_w;
wire src_no_rk = inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl |
                 inst_b | inst_bl | inst_beq | inst_bne | inst_lu12i_w;
wire src_no_rd = ~inst_st_w & ~inst_beq & ~inst_bne;

wire rj_wait = ~src_no_rj && (rj != 5'b0) && ((rj == es_to_ds_dest) || (rj == ms_to_ds_dest) || (rj == ws_to_ds_dest));
wire rk_wait = ~src_no_rk && (rk != 5'b0) && ((rk == es_to_ds_dest) || (rk == ms_to_ds_dest) || (rk == ws_to_ds_dest));
wire rd_wait = ~src_no_rd && (rd != 5'b0) && ((rd == es_to_ds_dest) || (rd == ms_to_ds_dest) || (rd == ws_to_ds_dest));

wire no_wait = ~rj_wait && ~rk_wait && ~rd_wait;

wire load_stall = es_to_ds_load_op && ((rj == es_to_ds_dest && rj_wait) ||
                                       (rk == es_to_ds_dest && rk_wait) ||
                                       (rd == es_to_ds_dest && rd_wait));

wire br_stall = load_stall && br_taken && ds_valid;

assign br_taken = ((inst_beq && rj_value == rkd_value) ||
                   (inst_bne && rj_value != rkd_value) ||
                   inst_jirl || inst_bl || inst_b) &&
                  ds_valid && no_wait;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (ds_pc + br_offs) : (rj_value + jirl_offs);

assign br_bus = {br_stall, br_taken, br_target};

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

assign ds_ready_go    = ~load_stall;
assign ds_allowin     = !ds_valid || (ds_ready_go && es_allowin);
assign ds_to_es_valid = ds_valid && ds_ready_go && !delay_slot;

always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        ds_valid <= 1'b0;
        delay_slot <= 1'b0;
    end else if (ds_allowin) begin
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
