module mycpu_top(
    input  wire        clk_11M0592,
    /*异步信号如果直接进入同步时序逻辑，
    会有亚稳态问题（metastability）。
    所以用一个寄存器（reset）在时钟上升沿将其采样同步化*/
    input  wire        reset_btn,//resetn 通常来自外部按键或电路，是异步信号(不受clk限制）
 /*   // inst sram interface 指令存储接口（instruction SRAM）
    output wire        inst_sram_en,//使能信号，为 1 时表示要发起一个取指请求
    output wire [ 3:0] inst_sram_we,//写使能信号，若全为0表示只读（用于取指），不为零表示要写入数据
    output wire [31:0] inst_sram_addr,//请求访问的地址，通常为PC
    output wire [31:0] inst_sram_wdata,//写入数据，通常为指令（取指阶段通常不使用）
    input  wire [31:0] inst_sram_rdata,//从SRAM读出指令数据，送给IF/ID寄存器解码器
    // data sram interface
    output wire        data_sram_en,//数据访问使能，为 1 时表示要发起一个数据访问请求
    output wire [ 3:0] data_sram_we,//数据写使能信号，若全为0表示只读（用于读数据），不为零表示要写入数据
    output wire [31:0] data_sram_addr,//要访问的内存地址
    output wire [31:0] data_sram_wdata,//要写入的数据
    input  wire [31:0] data_sram_rdata,//从SRAM（内存）读出的数据（如lw的结果）
*/ 
/* 
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
*//*
    //仲裁
    inout wire[31:0] base_ram_data,  //BaseRAM数据，低8位与CPLD串口控制器共享
    output wire[19:0] base_ram_addr, //BaseRAM地址
    output wire[3:0] base_ram_be_n,  //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire base_ram_ce_n,       //BaseRAM片选，低有效
    output wire base_ram_oe_n,       //BaseRAM读使能，低有效
    output wire base_ram_we_n,       //BaseRAM写使能，低有效
    /*
    input reg base_en,
    input reg base_we,
    input reg [31:0] base_addr,
    input reg [31:0] base_wdata,
    output wire [31:0] base_rdata,
    *//*
    //外部RAM
    inout wire[31:0] ext_ram_data,  //ExtRAM数据
    output wire[19:0] ext_ram_addr, //ExtRAM地址
    output wire[3:0] ext_ram_be_n,  //ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire ext_ram_ce_n,       //ExtRAM片选，低有效
    output wire ext_ram_oe_n,       //ExtRAM读使能，低有效
    output wire ext_ram_we_n       //ExtRAM写使能，低有效
    /*
    input reg ext_en,
    input reg ext_we,
    input reg [31:0] ext_addr,
    input reg [31:0] ext_wdata,
    output wire [31:0] ext_rdata
    */
);
/*
//异步低电平有效复位信号（resetn），同步地转化为同步高电平有效复位信号（reset）
reg         reset;
always @(posedge clk_50M) reset <= reset_btn; //resetn:低电平复位有效信号
//字节使能
assign base_ram_be_n = 4'b0000; //BaseRAM字节使能，低有效
assign ext_ram_be_n = 4'b0000; //ExtRAM字节使能，低有效
// allow_in
wire ds_allow_in;
wire es_allow_in;
wire ms_allow_in;
wire ws_allow_in;

// bus
wire [63:0] fs_ds_bus;
wire [150:0] ds_es_bus;
wire [70:0] es_ms_bus;
wire [69:0] ms_ws_bus;
wire [33:0] br_bus;
wire [37:0] ws_rf_bus;

// valid
wire fs_to_ds_valid;
wire ds_to_es_valid;
wire es_to_ms_valid;
wire ms_to_ws_valid;

// inst_bl
wire to_es_inst_bl;

// block
wire es_load;
wire [4:0] es_dest;
wire [4:0] ms_dest;
wire [4:0] ws_dest;
// Forwarding bus(前递总线)
wire [37:0] es_fwd_bus;
wire [37:0] ms_fwd_bus;
wire [37:0] ws_fwd_bus;

wire is_if_read; //仲裁器是否允许取指
wire is_mem_read; //仲裁器是否允许访问内存
//核之间传递的信号
wire [31:0] data_sram_rdata;
wire [31:0] data_sram_wdata;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_en;
wire [ 3:0] data_sram_we;
wire [31:0] inst_sram_rdata;
wire [31:0] inst_sram_wdata;
wire [31:0] inst_sram_addr;
wire [31:0] inst_sram_en;
wire [31:0] inst_sram_we;

if_stage fs(
    .clk(clk_50M),
    .reset(reset),
    .ds_allow_in(ds_allow_in),
    .br_bus(br_bus),
    .inst_sram_en(inst_sram_en),
    .inst_sram_we(inst_sram_we),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),
    .fs_ds_bus(fs_ds_bus),
    .fs_to_ds_valid(fs_to_ds_valid),
    .is_if_read(is_if_read)
);

id_stage ds(
   .clk(clk_50M),
   .reset(reset),
   .es_allow_in(es_allow_in),
   .fs_to_ds_valid(fs_to_ds_valid),
   .fs_ds_bus(fs_ds_bus),
   .ws_rf_bus(ws_rf_bus),
   .ds_allow_in(ds_allow_in),
   .br_bus(br_bus),
   .ds_es_bus(ds_es_bus),
   .ds_to_es_valid(ds_to_es_valid),
   .to_es_inst_bl(to_es_inst_bl),
   .es_dest(es_dest),
   .ws_dest(ws_dest),
   .ms_dest(ms_dest),
   .es_load(es_load),
   .es_fwd_bus    (es_fwd_bus    ),
   .ms_fwd_bus    (ms_fwd_bus    ),
   .ws_fwd_bus    (ws_fwd_bus    )
);

exe_stage es(
    .clk(clk_50M),
    .reset(reset),
    .ms_allow_in(ms_allow_in),
    .ds_to_es_valid(ds_to_es_valid),
    .es_allow_in(es_allow_in),
    .ds_es_bus(ds_es_bus),
    .inst_bl(to_es_inst_bl),
    .es_ms_bus(es_ms_bus),
    .es_to_ms_valid(es_to_ms_valid),
    .data_sram_en(data_sram_en),
    .data_sram_we(data_sram_we),
    .data_sram_addr(data_sram_addr),
    .data_sram_wdata(data_sram_wdata),
    .es_dest(es_dest),
    .es_load(es_load),
    .es_fwd_bus(es_fwd_bus)
);

mem_stage ms(
    .clk(clk_50M),
    .reset(reset),
    .ws_allow_in(ws_allow_in),
    .ms_allow_in(ms_allow_in),
    .es_ms_bus(es_ms_bus),
    .data_sram_rdata(data_sram_rdata),
    .es_to_ms_valid(es_to_ms_valid),    
    .ms_to_ws_valid(ms_to_ws_valid),
    .ms_ws_bus(ms_ws_bus),
    .ms_dest(ms_dest),
    .ms_fwd_bus(ms_fwd_bus),
    .is_mem_read(is_mem_read),
    .data_sram_en(data_sram_en),
    .data_sram_we(data_sram_we),
    .data_sram_addr(data_sram_addr),
    .data_sram_wdata(data_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata)

);

wb_stage ws(
    .clk(clk_50M),
    .reset(reset),
    .ws_allow_in(ws_allow_in),
    .ms_to_ws_valid(ms_to_ws_valid),
    .ms_ws_bus(ms_ws_bus),
    .ws_rf_bus(ws_rf_bus),
/*
    .debug_wb_pc(debug_wb_pc),
    .debug_wb_rf_we(debug_wb_rf_we),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
*//*
    .ws_dest(ws_dest),
    .ws_fwd_bus(ws_fwd_bus)
);
z_stage z_stage(
    .clk(clk_50M),
    .reset(reset),
    //if
    .inst_sram_en(inst_sram_en),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_rdata(inst_sram_rdata),
    //mem
    .data_sram_en(data_sram_en),
    .data_sram_we(data_sram_we),
    .data_sram_addr(data_sram_addr),    
    .data_sram_wdata(data_sram_wdata), 
    .data_sram_rdata(data_sram_rdata),

    //out
    .is_mem_read(is_mem_read),
    .is_if_read(is_if_read),
    //Baseram
    .base_ram_ce_n(base_ram_ce_n),
    .base_en(base_ram_oe_n),
    .base_we(base_ram_we_n),
    .base_addr(base_ram_addr),
    .base_wdata(base_ram_data),
    .base_rdata(base_ram_rdata),
    //Extram
    .ext_ram_ce_n(ext_ram_ce_n),
    .ext_en(ext_ram_oe_n),
    .ext_we(ext_ram_we_n),
    .ext_addr(ext_ram_addr),
    .ext_wdata(ext_ram_data),
    .ext_rdata(ext_ram_data)
);
//在top和仲裁器之间加一个分区
endmodule
*/
module mycpu_top(
    input  wire        clk_11M0592,
    /*异步信号如果直接进入同步时序逻辑，
    会有亚稳态问题（metastability）。
    所以用一个寄存器（reset）在时钟上升沿将其采样同步化*/
    input  wire        reset_btn,//resetn 通常来自外部按键或电路，是异步信号(不受clk限制）
 /*   // inst sram interface 指令存储接口（instruction SRAM）
    output wire        inst_sram_en,//使能信号，为 1 时表示要发起一个取指请求
    output wire [ 3:0] inst_sram_we,//写使能信号，若全为0表示只读（用于取指），不为零表示要写入数据
    output wire [31:0] inst_sram_addr,//请求访问的地址，通常为PC
    output wire [31:0] inst_sram_wdata,//写入数据，通常为指令（取指阶段通常不使用）
    input  wire [31:0] inst_sram_rdata,//从SRAM读出指令数据，送给IF/ID寄存器解码器
    // data sram interface
    output wire        data_sram_en,//数据访问使能，为 1 时表示要发起一个数据访问请求
    output wire [ 3:0] data_sram_we,//数据写使能信号，若全为0表示只读（用于读数据），不为零表示要写入数据
    output wire [31:0] data_sram_addr,//要访问的内存地址
    output wire [31:0] data_sram_wdata,//要写入的数据
    input  wire [31:0] data_sram_rdata,//从SRAM（内存）读出的数据（如lw的结果）
*/ 
/* 
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
*/
    //仲裁
    inout  wire[31:0] base_ram_data, //BaseRAM数据，低8位与CPLD串口控制器共享
    output wire[19:0] base_ram_addr,  //BaseRAM地址
    output wire[3:0]  base_ram_be_n,   //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire       base_ram_ce_n,        //BaseRAM片选，低有效
    output wire       base_ram_oe_n,        //BaseRAM读使能，低有效
    output wire       base_ram_we_n,        //BaseRAM写使能，低有效
    /*
    input reg base_en,
    input reg base_we,
    input reg [31:0] base_addr,
    input reg [31:0] base_wdata,
    output wire [31:0] base_rdata,
    */
    //外部RAM
    inout wire[31:0] ext_ram_data,  //ExtRAM数据
    output wire[19:0] ext_ram_addr, //ExtRAM地址
    output wire[3:0] ext_ram_be_n,  //ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire ext_ram_ce_n,       //ExtRAM片选，低有效
    output wire ext_ram_oe_n,       //ExtRAM读使能，低有效
    output wire ext_ram_we_n       //ExtRAM写使能，低有效
    /*
    input reg ext_en,
    input reg ext_we,
    input reg [31:0] ext_addr,
    input reg [31:0] ext_wdata,
    output wire [31:0] ext_rdata
    */
);
//异步低电平有效复位信号（resetn），同步地转化为同步高电平有效复位信号（reset）
reg         reset;
always @(posedge clk_11M0592) reset <= reset_btn; //resetn:低电平复位有效信号
//字节使能
assign base_ram_be_n = 4'b0000; //BaseRAM字节使能，低有效
assign ext_ram_be_n = 4'b0000; //ExtRAM字节使能，低有效
// allow_in
wire ds_allow_in;
wire es_allow_in;
wire ms_allow_in;
wire ws_allow_in;

// bus
wire [63:0] fs_ds_bus;
wire [150:0] ds_es_bus;
wire [70:0] es_ms_bus;
wire [69:0] ms_ws_bus;
wire [33:0] br_bus;
wire [37:0] ws_rf_bus;

// valid
wire fs_to_ds_valid;
wire ds_to_es_valid;
wire es_to_ms_valid;
wire ms_to_ws_valid;

// inst_bl
wire to_es_inst_bl;

// block
wire es_load;
wire [4:0] es_dest;
wire [4:0] ms_dest;
wire [4:0] ws_dest;
// Forwarding bus(前递总线)
wire [37:0] es_fwd_bus;
wire [37:0] ms_fwd_bus;
wire [37:0] ws_fwd_bus;

wire is_if_read; //仲裁器是否允许取指
wire is_mem_read; //仲裁器是否允许访问内存
//核之间传递的信号
wire [31:0] data_sram_rdata;
wire [31:0] data_sram_wdata;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_en;
wire [ 3:0] data_sram_we;
wire [31:0] inst_sram_rdata;
wire [31:0] inst_sram_wdata;
wire [31:0] inst_sram_addr;
wire [31:0] inst_sram_en;
wire [31:0] inst_sram_we;

if_stage fs(
    .clk            (clk_11M0592    ),
    .reset          (reset          ),
    .ds_allow_in    (ds_allow_in    ),
    .br_bus         (br_bus         ),
    .inst_sram_en   (inst_sram_en   ),
    .inst_sram_we   (inst_sram_we   ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),
    .fs_ds_bus      (fs_ds_bus      ),
    .fs_to_ds_valid (fs_to_ds_valid ),
    .is_if_read     (is_if_read     )
);

id_stage ds(
   .clk            (clk_11M0592    ),
   .reset          (reset          ),
   .es_allow_in    (es_allow_in    ),
   .fs_to_ds_valid (fs_to_ds_valid ),
   .fs_ds_bus      (fs_ds_bus      ),
   .ws_rf_bus      (ws_rf_bus      ),
   .ds_allow_in    (ds_allow_in    ),
   .br_bus         (br_bus         ),
   .ds_es_bus      (ds_es_bus      ),
   .ds_to_es_valid (ds_to_es_valid ),
   .to_es_inst_bl  (to_es_inst_bl  ),
   .es_dest        (es_dest        ),
   .ws_dest        (ws_dest        ),
   .ms_dest        (ms_dest        ),
   .es_load        (es_load        ),
   .es_fwd_bus     (es_fwd_bus     ),
   .ms_fwd_bus     (ms_fwd_bus     ),
   .ws_fwd_bus     (ws_fwd_bus     )
);

exe_stage es(
    .clk            (clk_11M0592    ),
    .reset          (reset          ),
    .ms_allow_in    (ms_allow_in    ),
    .ds_to_es_valid (ds_to_es_valid ),
    .es_allow_in    (es_allow_in    ),
    .ds_es_bus      (ds_es_bus      ),
    .inst_bl        (to_es_inst_bl  ),
    .es_ms_bus      (es_ms_bus      ),
    .es_to_ms_valid (es_to_ms_valid ),
    .data_sram_en   (data_sram_en   ),
    .data_sram_we   (data_sram_we   ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),
    .es_dest        (es_dest        ),
    .es_load        (es_load        ),
    .es_fwd_bus     (es_fwd_bus     )
);

mem_stage ms(
    .clk            (clk_11M0592    ),
    .reset          (reset          ),
    .ws_allow_in    (ws_allow_in    ),
    .ms_allow_in    (ms_allow_in    ),
    .es_ms_bus      (es_ms_bus      ),
    .data_sram_rdata(data_sram_rdata),
    .es_to_ms_valid (es_to_ms_valid ),
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_ws_bus      (ms_ws_bus      ),
    .ms_dest        (ms_dest        ),
    .ms_fwd_bus     (ms_fwd_bus     ),
    .is_mem_read    (is_mem_read    ),
    .data_sram_en   (data_sram_en   ),
    .data_sram_we   (data_sram_we   ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata)

);

wb_stage ws(
    .clk            (clk_11M0592    ),
    .reset          (reset          ),
    .ws_allow_in    (ws_allow_in    ),
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_ws_bus      (ms_ws_bus      ),
    .ws_rf_bus      (ws_rf_bus      ),
    .ws_dest        (ws_dest        ),
    .ws_fwd_bus     (ws_fwd_bus     )
/*
    .debug_wb_pc(debug_wb_pc),
    .debug_wb_rf_we(debug_wb_rf_we),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
*/
);

// inst ram <-> base ram
conver_ram inst_conver_ram(
    .clk              (my_clk   ),
    .resetn           (my_reset ),

    .cpu_sram_en      (inst_sram_en   ),
    .cpu_sram_we      (inst_sram_we   ),
    .cpu_sram_addr    (inst_sram_addr ),
    .cpu_sram_wdata   (inst_sram_wdata),
    .cpu_sram_rdata   (inst_sram_rdata),

    .ram_data         (base_ram_data ),//RAM数据，低8位与CPLD串口控制器共享
    .ram_addr         (base_ram_addr ),//RAM地址
    .ram_be_n         (base_ram_be_n ),//RAM字节使能，低有效。如果不使用字节使能，请保持为0
    .ram_ce_n         (base_ram_ce_n ),//RAM片选，低有效
    .ram_oe_n         (base_ram_oe_n ),//RAM读使能，低有效
    .ram_we_n         (base_ram_we_n ) //RAM写使能，低有效
);
// data ram <-> ext ram
conver_ram data_conver_ram(
    .clk              (my_clk    ),
    .resetn           (my_reset  ),

    .cpu_sram_en      (data_sram_en   ),
    .cpu_sram_we      (data_sram_we   ),
    .cpu_sram_addr    (data_sram_addr ),
    .cpu_sram_wdata   (data_sram_wdata),
    .cpu_sram_rdata   (data_sram_rdata),

    .ram_data         (ext_ram_data ),//RAM数据，低8位与CPLD串口控制器共享
    .ram_addr         (ext_ram_addr ),//RAM地址
    .ram_be_n         (ext_ram_be_n ),//RAM字节使能，低有效。如果不使用字节使能，请保持为0
    .ram_ce_n         (ext_ram_ce_n ),//RAM片选，低有效
    .ram_oe_n         (ext_ram_oe_n ),//RAM读使能，低有效
    .ram_we_n         (ext_ram_we_n ) //RAM写使能，低有效
);


/*
z_stage z_stage(
  .clk(clk_11M0592),
  .reset(reset),
  //if
  .inst_sram_en(inst_sram_en),
  .inst_sram_addr(inst_sram_addr),
  .inst_sram_rdata(inst_sram_rdata),
    //mem
  .data_sram_en(data_sram_en),
  .data_sram_we(data_sram_we),
  .data_sram_addr(data_sram_addr),
  .data_sram_wdata(data_sram_wdata),
  .data_sram_rdata(data_sram_rdata),

    //out
  .is_mem_read(is_mem_read),
  .is_if_read(is_if_read),
    //Baseram
  .base_ram_ce_n(base_ram_ce_n),
  .base_en(base_ram_oe_n),
  .base_we(base_ram_we_n),
  .base_addr(base_ram_addr),
  .base_wdata(base_ram_data),
  .base_rdata(base_ram_rdata),
    //Extram
  .ext_ram_ce_n(ext_ram_ce_n),
  .ext_en(ext_ram_oe_n),
  .ext_we(ext_ram_we_n),
  .ext_addr(ext_ram_addr),
  .ext_wdata(ext_ram_data),
  .ext_rdata(ext_ram_data)
);
*/

//在top和仲裁器之间加一个分区
endmodule
