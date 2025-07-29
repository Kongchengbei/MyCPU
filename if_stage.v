module if_stage(
    input  clk,
    input  reset,
    input  ds_allow_in,
    input  [33:0] br_bus,
    output        inst_sram_en,
    output [ 3:0] inst_sram_we,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    output [63:0] fs_ds_bus,
    output        fs_to_ds_valid
);

wire br_stall;
wire br_taken;
wire [31:0] br_target;
wire [31:0] fs_inst;
reg  [31:0] fs_pc;
wire [31:0] seq_pc;
wire [31:0] nextpc;
wire pre_fs_ready_go;
wire fs_ready_go;
wire fs_allow_in;
wire to_fs_valid;
reg  fs_valid;

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
