module wb_stage(
    input  wire        clk,
    input  wire        resetn,
    output wire        ws_allowin,
    input  wire        ms_to_ws_valid,
    input  wire [69:0] ms_to_ws_bus,
    output wire [37:0] ws_to_ds_bus,
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire  [4:0] ws_to_ds_dest,  // 给 ID 阶段用：当前 WB 的写寄存器编号
    output wire [31:0] debug_wb_rf_wdata
);

    reg         ws_valid;
    reg [31:0]  ws_pc;
    reg         ws_gr_we;
    reg [4:0]   ws_dest;
    reg [31:0]  ws_final_result;

    wire        ws_ready_go;
    wire        rf_we;
    wire [4:0]  rf_waddr;
    wire [31:0] rf_wdata;

    assign ws_ready_go = 1'b1;
    assign ws_allowin  = !ws_valid || ws_ready_go;

    always @(posedge clk or negedge resetn) begin
        if (!resetn)begin
            ws_valid <= 1'b0;
            ws_pc            <= 31'b0;
            ws_gr_we         <= 0'b0;
            ws_dest          <= 4'b0;
            ws_final_result  <= 31'b0;
        end
 /*只有在 allowin 允许接受数据的那一拍，valid 和内容一起写入；

否则 valid 会早 1 拍，而数据滞后 → 导致组合逻辑提前输出无效值。*/
        else if (ws_allowin) begin
            ws_valid <= ms_to_ws_valid;
            {ws_pc,
             ws_gr_we,
             ws_dest,
             ws_final_result} <= ms_to_ws_bus;
        end
    end

    assign rf_we    = ws_gr_we && ws_valid;
    assign rf_waddr = ws_dest;
    assign rf_wdata = ws_final_result;

    assign ws_to_ds_bus = {
        rf_we,     // 37
        rf_waddr,  // 36:32
        rf_wdata   // 31:0
    };
    assign ws_to_ds_dest = ws_dest & {5{ws_valid}};
    // 给 ID 阶段用：当前 WB 的写寄存器编号
    assign debug_wb_pc       = rf_we ? ws_pc           : 32'b0;    
    assign debug_wb_rf_wnum  = rf_we ? ws_dest         : 5'd0;    
    assign debug_wb_rf_wdata = rf_we ? ws_final_result : 32'd0;
    assign debug_wb_rf_we    = {4{rf_we}};

endmodule
