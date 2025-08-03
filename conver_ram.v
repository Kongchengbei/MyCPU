module conver_ram (
    input               clk               ,
    input               resetn            ,

    // CPU RAM signal
    input              cpu_sram_en      ,
    input       [ 3:0] cpu_sram_we      ,
    input       [31:0] cpu_sram_addr    ,
    input       [31:0] cpu_sram_wdata   ,
    output reg  [31:0] cpu_sram_rdata   ,

    // BaseRAM/ExtRAM signal
    inout  wire[31:0]  ram_data,        //RAM数据，低8位与CPLD串口控制器共享
    output wire[19:0]  ram_addr,        //RAM地址
    output wire[ 3:0]  ram_be_n,        //RAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire        ram_ce_n,        //RAM片选，低有效
    output wire        ram_oe_n,        //RAM读使能，低有效
    output wire        ram_we_n         //RAM写使能，低有效
);
// most import is ram_be_n signal
// if write, cpu_we=1(high si valid), ram_be_n=0(low is valid)
// if read , ram_be_n=0000(low is valid)
// assign sram_be_n = ~(|wen&&en ? wen : 4'hf);
assign ram_be_n = ( | cpu_sram_we && cpu_sram_en) ? ~cpu_sram_we : 4'h0;
assign ram_ce_n = ~cpu_sram_en;
assign ram_we_n = ~( | cpu_sram_we && cpu_sram_en);
assign ram_oe_n = ( | cpu_sram_we && cpu_sram_en);
// 按字节寻址
assign ram_addr = cpu_sram_addr[21:2];

assign ram_data = ~ram_we_n ? cpu_sram_wdata : 32'hz;

always @(posedge clk or posedge resetn) begin
    if (resetn) begin
        cpu_sram_rdata <= 32'hz;
    end else if (~ram_oe_n) begin
        cpu_sram_rdata <= ram_data;
    end
end

endmodule
