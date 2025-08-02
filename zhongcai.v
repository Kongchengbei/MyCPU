module z_stage(
    input wire clk,
    input wire reset,
//if
    input wire inst_sram_en,
    input wire [31:0]inst_sram_addr,
    output reg [31:0]inst_sram_rdata, 

//mem
    input  wire         data_sram_en,
    input  wire [3:0]   data_sram_we,
    input  wire [31:0]  data_sram_addr,    
    input  wire [31:0]  data_sram_wdata, 
    output reg  [31:0]  data_sram_rdata,

//out
    //output is_write,
    output wire is_mem_read,
    output wire is_if_read,

//Baseram
output reg base_en,
output reg base_we,
output reg [31:0] base_addr,
output reg [31:0] base_wdata,
input wire [31:0] base_rdata,

//Extram
output reg ext_en,
output reg ext_we,
output reg [31:0] ext_addr,
output reg [31:0] ext_wdata,
input wire [31:0] ext_rdata,

);

//成立状态，阻塞需要取反
wire is_write     = data_sram_en && (|data_sram_we);
assign is_mem_read  = ~is_write && data_sram_en && ~(|data_sram_we);
assign  is_if_read   = ~is_write && ~is_mem_read && inst_sram_en;
wire [31:0] addr  = is_write    ? data_sram_addr  :
                    is_mem_read ? data_sram_addr  :
                    is_if_read  ? inst_sram_addr  : 32'b0;//地址
wire        we    = is_write;                           // 是否是写操作
wire [31:0] wdata = is_write ? data_sram_wdata : 32'b0; // 要写入的数据
//分区
wire is_base = (addr >= 32'h80000000) && (addr <= 32'h803FFFFF);
wire is_ext  = (addr >= 32'h80400000) && (addr <= 32'h807FFFFF);
//片选
assign base_ram_ce_n = ~(is_base && (is_if_read || is_mem_read || is_write));
assign ext_ram_ce_n  = ~(is_ext  && (is_if_read || is_mem_read || is_write)); 
//读使能
assign base_ram_oe_n = ~(is_base && (is_if_read || is_mem_read));
assign ext_ram_oe_n  = ~(is_ext  && (is_if_read || is_mem_read));
//写使能
assign base_ram_we_n = ~(is_base && is_write);
assign ext_ram_we_n  = ~(is_ext  && is_write);

//低有效
always @(posedge clk or posedge reset) begin
    //写
    if (reset) begin
            base_en         <= 1'b1;             
            base_we         <= 1'b1;
            base_addr       <= 32'bz;
            base_wdata      <= 32'bz;
            ext_en          <= 1'b1;
            ext_we          <= 1'b1;
            ext_addr        <= 32'bz;
            ext_wdata       <= 32'bz;
            inst_sram_rdata <= 0;
            data_sram_rdata <= 0;
    end else begin
        if (is_base) begin
            base_en    <= 1'b0;
            base_we    <= we;
            base_addr  <= addr;
            base_wdata <= wdata;
            ext_en     <= 1'b1; 
        end else if (is_ext) begin
            ext_en     <= 1'b0;
            ext_we     <= we;
            ext_addr   <= addr;
            ext_wdata  <= wdata;
            base_en    <= 1'b1;
        end else begin
            base_en    <= 1'b1;
            ext_en     <= 1'b1;
        end
    end
        //读
        if (is_if_read) begin
            inst_sram_rdata <= base_rdata; 
        end else if (is_mem_read) begin
            data_sram_rdata <= is_base ? base_rdata : ext_rdata;
        end else begin
            inst_sram_rdata <= 32'b0; 
            data_sram_rdata <= 32'b0; 
        end
end
//放进去例化,top中只保留各个阶段的传输


endmodule