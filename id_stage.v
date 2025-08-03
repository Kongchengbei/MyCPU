module id_stage(
  input  clk,
  input  reset,
  input  es_allow_in,
  input  fs_to_ds_valid,// IF 阶段到 ID 阶段的信号（是否为有效指令）
  input  [63:0] fs_ds_bus,// IF 阶段到 ID 阶段的总线（PC + 指令）
  input  [37:0] ws_rf_bus,
  input  [ 4:0] es_dest,
  input  [ 4:0] ms_dest,
  input  [ 4:0] ws_dest,
  input  es_load,
  input [37:0] es_fwd_bus,
  input [37:0] ms_fwd_bus,
  input [37:0] ws_fwd_bus,
  output ds_allow_in,
  output [33:0] br_bus,
  output [150:0] ds_es_bus,
  output ds_to_es_valid,
  output to_es_inst_bl
);

reg  [31:0] ds_pc;
reg  [31:0] ds_inst;
reg  ds_valid;
wire ds_ready_go;
reg delay_slot;

wire [31:0] br_offs;
wire [31:0] jirl_offs;
wire        src_reg_is_rd;
wire        src_reg_is_rj;
wire        src_reg_is_rk;
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

wire rf_we;
wire [4:0] rf_waddr;
wire [31:0] rf_wdata;
wire [4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire [11:0] alu_op;
wire src1_is_pc;
wire src2_is_imm;
wire src2_is_4;
wire res_from_mem;
wire gr_we;
wire mem_we;
wire [4:0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;

wire br_stall;
wire br_taken;
wire [31:0] br_target;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [3:0]  op_21_20_d;
wire [31:0] op_19_15_d;

// 指令定义
wire inst_add_w, inst_sub_w, inst_slt, inst_sltu, inst_nor, inst_and, inst_or, inst_xor;
wire inst_slli_w, inst_srli_w, inst_srai_w, inst_addi_w, inst_ld_w, inst_st_w;
wire inst_jirl, inst_b, inst_bl, inst_beq, inst_bne, inst_lu12i_w;

wire need_ui5, need_si20, need_si26;
//wire  need_si12, need_si16;
/*
wire [31:0] alu_src1;
wire [31:0] alu_src2;
*/
assign op_31_26 = ds_inst[31:26];
assign op_25_22 = ds_inst[25:22];
assign op_21_20 = ds_inst[21:20];
assign op_19_15 = ds_inst[19:15];

assign rd = ds_inst[4:0];
assign rj = ds_inst[9:5];
assign rk = ds_inst[14:10];


/*for exp 8阻塞信号
wire same_rj = src_reg_is_rj && rj != 5'b0 && ((rj == es_dest) || (rj == ms_dest) || (rj == ws_dest));
wire same_rk = src_reg_is_rk && rk != 5'b0 && ((rk == es_dest) || (rk == ms_dest) || (rk == ws_dest));
wire same_rd = src_reg_is_rd && rd != 5'b0 && ((rd == es_dest) || (rd == ms_dest) || (rd == ws_dest));

wire block = same_rd || same_rj || same_rk;
*/
wire inst_no_dest_reg = inst_st_w | inst_b | inst_beq | inst_bne;
wire        es_rf_we;
wire [31:0] es_result;
assign {es_rf_we, es_dest, es_result} = es_fwd_bus;

wire        ms_rf_we;
wire [4:0]  ms_dest;
wire [31:0] ms_result;
assign {ms_rf_we, ms_dest, ms_result} = ms_fwd_bus;

wire        ws_rf_we;
wire [4:0]  ws_dest;
wire [31:0] ws_result;
assign {ws_rf_we, ws_dest, ws_result} = ws_fwd_bus;


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
assign alu_op[0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | inst_bl;
assign alu_op[1] = inst_sub_w;
assign alu_op[2] = inst_slt;
assign alu_op[3] = inst_sltu;
assign alu_op[4] = inst_and;
assign alu_op[5] = inst_nor;
assign alu_op[6] = inst_or;
assign alu_op[7] = inst_xor;
assign alu_op[8] = inst_slli_w;
assign alu_op[9] = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;

assign need_ui5 = inst_slli_w | inst_srli_w | inst_srai_w;
//assign need_si12 = inst_addi_w | inst_ld_w | inst_st_w;
//assign need_si16 = inst_jirl | inst_beq | inst_bne;
assign need_si20 = inst_lu12i_w;
assign need_si26 = inst_b | inst_bl;
assign src2_is_4 = inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4 :
             need_si20 ? {i20[19:0], 12'b0} :
             {{20{i12[11]}}, i12[11:0]};
assign br_offs = need_si26 ? {{4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0};
assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;
assign src_reg_is_rj = ~(inst_b | inst_bl | inst_lu12i_w);
assign src_reg_is_rk = ~(
                         inst_slli_w | 
                         inst_srli_w | 
                         inst_srai_w | 
                         inst_addi_w | 
                         inst_ld_w   | 
                         inst_st_w   | 
                         inst_jirl   |
                          inst_b     | 
                          inst_bl    | 
                        inst_beq     | 
                        inst_bne     | 
                        inst_lu12i_w
                        );
assign src1_is_pc = inst_jirl | inst_bl;
assign src2_is_imm = inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w |
                     inst_ld_w | inst_st_w | inst_lu12i_w | inst_jirl | inst_bl;
assign res_from_mem = inst_ld_w;
assign dst_is_r1 = inst_bl;
assign gr_we = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;
assign mem_we = inst_st_w;
assign dest = inst_no_dest_reg ? 5'b0 : (dst_is_r1 ? 5'd1 : rd);

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd : rk;
assign {rf_we, rf_waddr, rf_wdata} = ws_rf_bus;

regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
);

assign rj_value  = 
   (es_rf_we && (es_dest != 5'd0) && (es_dest == rj)) ? es_result :
   (ms_rf_we && (ms_dest != 5'd0) && (ms_dest == rj)) ? ms_result :
   (ws_rf_we && (ws_dest != 5'd0) && (ws_dest == rj)) ? ws_result :
    rf_rdata1;//前递路径的寄存器堆读出值1
assign rkd_value = 
   (es_rf_we && (es_dest != 5'd0) && (es_dest == rf_raddr2)) ? es_result :
    (ms_rf_we && (ms_dest != 5'd0) && (ms_dest == rf_raddr2)) ? ms_result :
    (ws_rf_we && (ws_dest != 5'd0) && (ws_dest == rf_raddr2)) ? ws_result :
    rf_rdata2;//前递路径的寄存器堆读出值2

assign ds_es_bus = {
    ds_pc,         // 150:119
    alu_op,        // 118:107
    src2_is_4,     // 106
    src1_is_pc,    // 105
    src2_is_imm,   // 104
    gr_we,         // 103
    mem_we,        // 102
    dest,          // 101:97
    imm,           // 96:65
    rj_value,      // 64:33
    rkd_value,     // 32:1
    res_from_mem   // 0
};

assign br_taken = (   inst_beq  && (rj_value == rkd_value)
                   || inst_bne  && (rj_value != rkd_value)
                   || inst_jirl || inst_bl || inst_b ) && ds_valid && !delay_slot;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (ds_pc + br_offs) :
                                                    (rj_value + jirl_offs);
assign br_stall = br_taken && es_load && ds_valid;
assign br_bus = {br_stall, br_taken, br_target};

//assign ds_ready_go = ~block;
wire raw_load_conflict =
    es_load && es_rf_we &&
    (es_dest != 5'd0) &&
    ((es_dest == rj && src_reg_is_rj) || (es_dest == rk && src_reg_is_rk));

assign ds_ready_go = ~raw_load_conflict;

assign ds_allow_in = !ds_valid || (ds_ready_go && es_allow_in);
assign ds_to_es_valid = ds_valid && ds_ready_go && !delay_slot;

always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
        delay_slot <= 1'b0;
    end else if (ds_allow_in) begin
        ds_valid <= fs_to_ds_valid;
    end

    if (fs_to_ds_valid && ds_allow_in) begin
        {ds_pc, ds_inst} <= fs_ds_bus;
        delay_slot <= br_taken ? 1'b1 : 1'b0;
    end
end

endmodule
/*for exp 9:
写回级结果的前递路径起点就是写回级将要写入到寄存器堆中的结果处
ID 阶段的寄存器堆读出后的位置
*/