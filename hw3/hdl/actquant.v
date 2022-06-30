module actquant #(
    parameter PARAM_BIT = 8,
    parameter PARTIAL_BIT = 25 
)
(
    input signed [16-1:0] scale,
    input signed [PARTIAL_BIT-1:0] act_in,
    input clk,
    input rst_n,
    output reg signed [PARAM_BIT-1:0] act_out
);



//================================== quantize =================================//
//================ shift 16 bits and clip the act return to 8bit =================//
//reg signed_bit;
reg signed [PARAM_BIT-1:0] act_scaled_n;
reg signed[40-1:0] tmp;
always@* begin
    //signed_bit = act_scaled_n[31];  // {signed_bit, act_scaled_n[31:16]} or   >>> 16 (>>> means signed shift)   
    tmp = ((act_in*scale) >>> 16);
end

/************************************* DFF1 **************************************/
reg signed[47-1:0] tmp_n;
always@(posedge clk) begin
    if(~rst_n)
        tmp_n <= 0;
    else
        tmp_n <= tmp;
end

always@* begin
    if( tmp_n  < -128)
        act_scaled_n = -128;
    else if(tmp_n > 127)
        act_scaled_n = 127;
    else
        act_scaled_n = tmp_n;
end

/************************************* DFF2 **************************************/
always@(posedge clk) begin
    if(~rst_n)
        act_out <= 0;
    else
        act_out <= act_scaled_n;
end


/////////////////////// WRONG WAY !!!!!!!!!!!!!!!!!!! /////////////////////////////////
/*
wire signed [31:0] act_scaled;
assign act_scaled = act_in * scale;


reg signed [31:0] act_scaled_n;
always@(posedge clk) begin
    if(~rst_n)
        act_scaled_n <= 0;
    else
        act_scaled_n <= act_scaled;
end


reg signed_bit;
always@* begin
    //signed_bit = act_scaled_n[31];
    act_out = act_scaled_n >>> 16;    // {signed_bit, act_scaled_n[31:16]} or   >>> 16 (>>> means signed shift) ? 
    if(act_out < -128)
        act_out = -128;
    else if(act_out > 127)
        act_out = 127;
end*/

endmodule