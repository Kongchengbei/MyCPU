module if_stage(
    input  clk,
    input  reset,
    input  ds_allow_in,
    input  [33:0] br_bus,//分支判断模块信号（33+1）
    output        inst_sram_en,
    output [ 3:0] inst_sram_we,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    output [63:0] fs_ds_bus,
    output        fs_to_ds_valid
);

wire br_stall;//分支等待信号，表示分支相关逻辑正在 stall（比如等待跳转目标地址）
wire br_taken;//是否采取分支跳转:是否要跳转到br_target
wire [31:0] br_target;//若跳转，下一条指令地址就是这个
wire [31:0] fs_inst;//当前取指阶段(从存储器中）取回的指令
reg  [31:0] fs_pc;
wire [31:0] seq_pc;//不跳转的情况下的顺序pc（pc+4）
wire [31:0] nextpc;//下一条 PC，考虑了跳转、stall等情况
wire pre_fs_ready_go;
wire fs_ready_go;
wire fs_allow_in;//防止同时写入 fs_pc 和发出新的 fetch 导致状态错乱。必须保证前一级、后一级都准备好了，才能推进流水线
wire to_fs_valid;
reg  fs_valid;//因为 IF 到 ID 是流水线传递，如果 ID 阶段堵住（比如 decode 不了）
//IF 不能丢掉自己刚刚取的指令，要保持住

assign {br_stall, br_taken, br_target} = br_bus;

assign pre_fs_ready_go = ~br_stall;
assign to_fs_valid     = ~reset && pre_fs_ready_go;
assign fs_ready_go     = 1'b1;
assign fs_allow_in     = !fs_valid || (fs_ready_go && ds_allow_in);
assign fs_to_ds_valid  = fs_valid && fs_ready_go;
assign fs_ds_bus       = {fs_pc, fs_inst};

always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allow_in) begin
        fs_valid <= to_fs_valid;
    end
end

always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'h1bfffffc;
    end else if (to_fs_valid && fs_allow_in) begin
        fs_pc <= nextpc;
    end
end

assign seq_pc        = fs_pc + 3'h4;
assign nextpc        = br_taken ? br_target : seq_pc;
assign inst_sram_en  = to_fs_valid && (fs_allow_in || br_stall);
assign inst_sram_addr = nextpc;
assign fs_inst       = inst_sram_rdata;
assign inst_sram_we  = 4'b0000;
assign inst_sram_wdata = 32'b0;

endmodule
/*接收分支预测结果（是否跳转、跳到哪）

根据是否跳转/stall 计算下一条指令地址（nextpc）

向指令存储器发出请求（inst_sram_en = 1）

从 inst_sram_rdata 取回 32 位指令

将 fs_pc 和 fs_inst 通过 fs_ds_bus 送给解码阶段

使用 fs_valid 和 fs_to_ds_valid 控制握手*/
