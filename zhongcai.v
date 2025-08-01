module z_stage(
    input wire clk,
    input wire reset,
//if
    input wire inst_sram_en,
    input wire [31:0]inst_sram_addr,
    output reg [31:0]inst_sram_rdata, 
    output reg  [3:0]   inst_sram_we,
    output reg  [31:0]  inst_sram_wdata,

//mem
    input  wire         data_sram_en,
    input  wire [3:0]   data_sram_we,
    input  wire [31:0]  data_sram_addr,    
    input  wire [31:0]  data_sram_wdata, 
    output reg  [31:0]  data_sram_rdata,

//out
    //output is_write,
    output is_mem_read,
    output is_if_read,
);

reg read_ready_go;//是否有读请求
reg [31:0] ready_addr; //当前准备处理的地址
reg from_if;//挂起请求是否来自if
//成立状态，阻塞需要取反
wire is_write     = data_sram_en && (|data_sram_we);
assign is_mem_read  = ~is_write && data_sram_en && ~(|data_sram_we);
assign  is_if_read   = ~is_write && ~is_mem_read && inst_sram_en;
//放进去例化,top中只保留各个阶段的传输


endmodule