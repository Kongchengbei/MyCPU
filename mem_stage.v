module mem_stage(
    input  clk,
    input  reset,
    input  ws_allow_in,
    output ms_allow_in,
    input  [70:0] es_ms_bus,
    input  [31:0] data_sram_rdata,
    input  es_to_ms_valid, 
    output ms_to_ws_valid,
    output [69:0] ms_ws_bus,
    output [ 4:0] ms_dest_reg
);

reg [31:0] ms_pc;
reg ms_res_from_mem;
reg ms_gr_we;
reg [4:0] ms_dest;
reg [31:0] ms_alu_result;
wire [31:0] ms_final_result;
wire [31:0] ms_result;

reg ms_valid;
wire ms_ready_go;
assign ms_ready_go    = 1'b1;
assign ms_allow_in     = !ms_valid || ms_ready_go && ws_allow_in;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
assign ms_dest_reg = ms_dest & {5{ms_valid}};

always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end else if (ms_allow_in) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allow_in) begin
        {ms_pc,
         ms_gr_we,
         ms_dest,
         ms_alu_result,
         ms_res_from_mem} <= es_ms_bus;
    end
end

assign ms_result = data_sram_rdata;
assign ms_final_result = ms_res_from_mem ? ms_result : ms_alu_result;
assign ms_ws_bus = {
    ms_pc,            // 69:38
    ms_gr_we,         // 37
    ms_dest,          // 36:32
    ms_final_result   // 31:0
};

endmodule
