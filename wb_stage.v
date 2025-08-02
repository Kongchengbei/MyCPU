module wb_stage(
  input  wire clk,
  input  wire reset,
  output wire ws_allow_in,
  input  wire ms_to_ws_valid,
  input  wire [69:0] ms_ws_bus,
  output wire [4:0] ws_dest,
  output wire [37:0] ws_rf_bus,
/*
  output wire [31:0] debug_wb_pc,
  output wire [ 3:0] debug_wb_rf_we,
  output wire [ 4:0] debug_wb_rf_wnum,
  output wire [31:0] debug_wb_rf_wdata,
*/
  output wire [37:0] ws_fwd_bus
);

  reg         ws_valid;
  reg  [31:0] ws_pc;
  reg         ws_gr_we;
  reg  [4:0]  ws_dest;
  reg  [31:0] ws_final_result;

  wire        rf_we;
  wire [4:0]  rf_waddr;
  wire [31:0] rf_wdata;
  wire        ws_ready_go;

  assign ws_ready_go  = 1'b1;
  assign ws_allow_in  = !ws_valid || ws_ready_go;

  always @(posedge clk) begin
    if (reset) begin
      ws_valid <= 1'b0;
    end else if (ws_allow_in) begin
      ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allow_in) begin
      {ws_pc, ws_gr_we, ws_dest, ws_final_result} <= ms_ws_bus;
    end
  end

  assign rf_we    = ws_gr_we && ws_valid;
  assign rf_waddr = ws_dest;
  assign rf_wdata = ws_final_result;

  assign ws_rf_bus = {rf_we, rf_waddr, rf_wdata};
  // 写回阶段前递总线输出
assign ws_fwd_bus = {
    ws_gr_we & ws_valid,  // 是否写寄存器
    ws_dest,              // 写寄存器号
    ws_final_result             // 写回结果（ALU or Load）
} ;
/*
  assign debug_wb_pc       = rf_we ? ws_pc : 32'h0;
  assign debug_wb_rf_we    = {4{rf_we}};
  assign debug_wb_rf_wnum  = ws_valid && rf_we ? ws_dest : 5'h0;
  assign debug_wb_rf_wdata = ws_valid && rf_we ? ws_final_result : 32'h0;
*/
endmodule


