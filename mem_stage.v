module mem_stage(
    input         clk,
    input         resetn,
    input         ws_allowin,
    output        ms_allowin,
    input  [70:0] es_to_ms_bus,
    input  [31:0] data_sram_rdata,
    input         es_to_ms_valid,    
    output        ms_to_ws_valid,
    output [69:0] ms_to_ws_bus,
    output wire [31:0] ms_final_result,
    output wire        ms_valid,
    output [4:0] ms_to_ds_dest // 给 ID 阶段用：当前 MEM 的写寄存器编号
);

    reg         ms_valid_r;
    reg [31:0]  ms_pc;
    reg         ms_res_from_mem;
    reg         ms_gr_we;
    reg [4:0]   ms_dest;
    reg [31:0]  ms_alu_result;

    wire [31:0] ms_result;
    wire [31:0] ms_final_result;

    wire        ms_ready_go;
    assign      ms_ready_go    = 1'b1;
    assign      ms_allowin     = !ms_valid_r || (ms_ready_go && ws_allowin);
    assign      ms_to_ws_valid = ms_valid_r && ms_ready_go;

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            ms_valid_r <= 1'b0;
        else if (ms_allowin)
            ms_valid_r <= es_to_ms_valid;

        if (!resetn) begin
            ms_pc            <= 32'b0;
            ms_gr_we         <= 1'b0;
            ms_dest          <= 5'b0;
            ms_alu_result    <= 32'b0;
            ms_res_from_mem  <= 1'b0;
        end
        else if (es_to_ms_valid && ms_allowin) begin
            {ms_pc,
             ms_gr_we,
             ms_dest,
             ms_alu_result,
             ms_res_from_mem} <= es_to_ms_bus;
        end
    end
    assign ms_to_ds_dest = ms_dest & {5{ms_valid_r}};// 给 ID 阶段用：当前 MEM 的写寄存器编号
    assign ms_result         = data_sram_rdata;
    assign ms_final_result   = ms_res_from_mem ? ms_result : ms_alu_result;
    reg [69:0] ms_to_ws_bus_r;
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            ms_to_ws_bus_r <= 70'b0;
        else if (ms_to_ws_valid && ms_allowin)
            ms_to_ws_bus_r <= {
                ms_pc,
                ms_gr_we,
                ms_dest,
                ms_final_result
            };
    end 
    assign ms_to_ws_bus      = ms_to_ws_bus_r;
    assign ms_final_result = ms_res_from_mem ? ms_result : ms_alu_result;
    assign ms_valid        = ms_valid_r; 
endmodule
