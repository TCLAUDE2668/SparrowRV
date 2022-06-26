`include "defines.v"
module sram (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low

    //AXI4-Lite总线接口 Slave
    //AW写地址
    input wire [`MemAddrBus]    sram_axi_awaddr ,//写地址
    input wire [2:0]            sram_axi_awprot ,//写保护类型，恒为0
    input wire                  sram_axi_awvalid,//写地址有效
    output reg                  sram_axi_awready,//写地址准备好
    //W写数据
    input wire [`MemBus]        sram_axi_wdata  ,//写数据
    input wire [3:0]            sram_axi_wstrb  ,//写数据选通
    input wire                  sram_axi_wvalid ,//写数据有效
    output reg                  sram_axi_wready ,//写数据准备好
    //B写响应
    output reg [1:0]            sram_axi_bresp  ,//写响应
    output reg                  sram_axi_bvalid ,//写响应有效
    input wire                  sram_axi_bready ,//写响应准备好
    //AR读地址
    input wire [`MemAddrBus]    sram_axi_araddr ,//读地址
    input wire [2:0]            sram_axi_arprot ,//读保护类型，恒为0
    input wire                  sram_axi_arvalid,//读地址有效
    output reg                  sram_axi_arready,//读地址准备好
    //R读数据
    output reg [`MemBus]        sram_axi_rdata  ,//读数据
    output reg [1:0]            sram_axi_rresp  ,//读响应
    output reg                  sram_axi_rvalid ,//读数据有效
    input wire                  sram_axi_rready //读数据准备好
	
);


//AXI4L总线交互
reg [clogb2(`SRamSize-1)-1:0]addr;
reg we,en;
reg [3:0] wem;
reg [`MemBus]dout;
reg [`MemBus]din;
wire axi_whsk = sram_axi_awvalid & sram_axi_wvalid;//写通道握手
wire axi_rhsk = sram_axi_arvalid & ~sram_axi_rvalid;//读通道握手,没有读响应

always @(posedge clk or negedge rst_n)//写响应控制
if (~rst_n)
    sram_axi_bvalid <=1'b0;
else begin
    if (axi_whsk)//写握手
        sram_axi_bvalid <=1'b1;
    else if (sram_axi_bvalid & sram_axi_bready)//写响应握手
        sram_axi_bvalid <=1'b0;
    else//等待响应
        sram_axi_bvalid <= sram_axi_bvalid;
end

always @(posedge clk or negedge rst_n)//读响应控制
if (~rst_n)
    sram_axi_rvalid <=1'b0;
else begin
    if (axi_rhsk)
        sram_axi_rvalid <=1'b1;
    else if (sram_axi_rvalid & sram_axi_rready)
        sram_axi_rvalid <=1'b0;
    else
        sram_axi_rvalid <= sram_axi_rvalid;
end

always @(*) begin
    sram_axi_awready = axi_whsk;//写地址数据同时准备好
    sram_axi_wready = axi_whsk;//写地址数据同时准备好
    sram_axi_rdata = dout;//读数据
    sram_axi_arready = axi_rhsk;//读地址握手
    sram_axi_bresp = 2'b00;//响应
    sram_axi_rresp = 2'b00;//响应
    if(axi_whsk) begin//写握手
        addr = sram_axi_awaddr[clogb2(`SRamSize-1)+1:2];
        we = 1;
    end
    else begin
        if (axi_rhsk) begin//读握手
            addr = sram_axi_araddr[clogb2(`SRamSize-1)+1:2];
            we = 0;
        end
        else begin
            addr = 0;
            we = 0;
        end
    end
    din = sram_axi_wdata;
    en = axi_whsk | axi_rhsk;
    wem = sram_axi_wstrb;
end

localparam RAM_DEPTH = `SRamSize;//SRAM存储器深度
localparam RAM_WIDTH = 32;//位宽

reg [RAM_WIDTH-1:0] BRAM [0:RAM_DEPTH-1];

always @(posedge clk)
    if (en) begin//en则可读可写
        dout <= BRAM[addr];
        if (we) begin//写使能
            if(wem[0])//写选通
                BRAM[addr][7:0] <= din[7:0];
            if(wem[1])//写选通
                BRAM[addr][15:8] <= din[15:8];
            if(wem[2])//写选通
                BRAM[addr][23:16] <= din[23:16];
            if(wem[3])//写选通
                BRAM[addr][31:24] <= din[31:24];
        end
    end


function integer clogb2;
    input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
            depth = depth >> 1;
endfunction

endmodule