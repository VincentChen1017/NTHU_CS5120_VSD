module pe#(
    parameter PARAM_BIT = 8,
    parameter KERNEL_SIZE = 5,  // one row of kernel weight
    parameter PARTIAL_BIT = 25,   // 25~26
    parameter LAST_CYCLE = 5'd10
)
(
input wire clk,
input wire rst_n,

// input ifmap, load 5x5 ifmap to do conv
input [PARAM_BIT*KERNEL_SIZE-1:0] ifmap_in,
input [PARAM_BIT*KERNEL_SIZE-1:0] weight_in,
// count_last_cycle_to_write
input [5-1:0] count_last_cycle_to_write, // 0~8
output reg signed [PARTIAL_BIT-1:0] sum

);
integer i,j,k;

//================================= load the ifmap and weight =================================//
wire signed [PARAM_BIT-1:0] ifmap [0:KERNEL_SIZE-1];
wire signed  [PARAM_BIT-1:0] weight [0:KERNEL_SIZE-1];

assign {ifmap[0], ifmap[1], ifmap[2], ifmap[3], ifmap[4]} = ifmap_in;

assign {weight[0], weight[1], weight[2], weight[3], weight[4]} = weight_in;

//=================================the conv process: 25's ifmap bitwise operation =================================//
reg signed [2*PARAM_BIT-1:0] dot_product [0:KERNEL_SIZE-1];  // Max(#bit) of 8bit * 8bit = 16bits
always@* begin
    for(i=0; i<5; i=i+1) begin
        dot_product[i] = ifmap[i] * weight[i];
    end   
end

//******************************** DFF 1 *********************************************//
reg signed [2*PARAM_BIT-1:0] dot_product_n [0:KERNEL_SIZE-1];
always@(posedge clk) begin
    if(~rst_n) begin
        dot_product_n[0] <= 0;
        dot_product_n[1] <= 0;
        dot_product_n[2] <= 0;
        dot_product_n[3] <= 0;
        dot_product_n[4] <= 0;
    end
    else begin
        dot_product_n[0] <= dot_product[0];
        dot_product_n[1] <= dot_product[1];
        dot_product_n[2] <= dot_product[2];
        dot_product_n[3] <= dot_product[3];
        dot_product_n[4] <= dot_product[4];
    end
end

//================================= output =================================//
reg signed [PARTIAL_BIT-1:0] sum_tmp;
always@* begin
    sum_tmp = sum + dot_product_n[0]+ dot_product_n[1] + dot_product_n[2] + dot_product_n[3] + dot_product_n[4];
end

//******************************** DFF 2 *********************************************//
always@(posedge clk)
    if(~rst_n)
        sum <= 0;
    else if(count_last_cycle_to_write == LAST_CYCLE) // write data finish. next data need to start sum up from 0
        sum <= 0;
    else
        sum <= sum_tmp;    

endmodule 