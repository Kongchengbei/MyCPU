module if_stage(
    input  wire        clk,
    input  wire        resetn,
    input  wire        ds_allowin,
    input  wire [33:0] br_bus,

    output wire        inst_sram_en,
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,

    output wire        fs_to_ds_valid,
    output wire [63:0] fs_to_ds_bus
);

    reg         fs_valid;
    reg [31:0]  fs_pc;
    wire [31:0] seq_pc;
    wire [31:0] next_pc;
    wire        fs_ready_go;
    wire        fs_allowin;
    wire [31:0] fs_inst;

    wire        br_taken;
    wire [31:0] br_target;
    wire        br_stall;

    assign {br_stall, br_taken, br_target} = br_bus;

    assign seq_pc   = fs_pc + 32'h4;
    assign next_pc  = br_taken ? br_target : seq_pc;

    assign fs_ready_go    = ~br_stall;
    assign fs_allowin     = !fs_valid || (fs_ready_go && ds_allowin);
    assign fs_to_ds_valid = fs_valid && fs_ready_go;

    assign fs_to_ds_bus = {fs_pc, fs_inst};

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            fs_valid <= 1'b0;
        else if (fs_allowin)
            fs_valid <= 1'b1;
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            fs_pc <= 32'h1bfffffc; // trick: 使得复位后一拍指向 1c000000
        else if (fs_allowin)
            fs_pc <= next_pc;
    end

    assign fs_inst         = inst_sram_rdata;
    assign inst_sram_en    = fs_allowin || br_taken; // 保证跳转指令立即取指
    assign inst_sram_we    = 4'b0;
    assign inst_sram_wdata = 32'b0;
    assign inst_sram_addr  = fs_pc;

endmodule
