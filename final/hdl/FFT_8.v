module FFT_8 (
    input wire clk,
    
    input wire signed [31:0] twiddle1_8_real,
    input wire signed [31:0] twiddle1_8_imag,
    input wire signed [31:0] twiddle2_8_real,
    input wire signed [31:0] twiddle2_8_imag,
    input wire signed [31:0] twiddle3_8_real,
    input wire signed [31:0] twiddle3_8_imag,

    input wire signed [31:0] xin_real0,
    input wire signed [31:0] xin_real1,
    input wire signed [31:0] xin_real2,
    input wire signed [31:0] xin_real3,
    input wire signed [31:0] xin_real4,
    input wire signed [31:0] xin_real5,
    input wire signed [31:0] xin_real6,
    input wire signed [31:0] xin_real7,
    input wire signed [31:0] xin_imag0,
    input wire signed [31:0] xin_imag1,
    input wire signed [31:0] xin_imag2,
    input wire signed [31:0] xin_imag3,
    input wire signed [31:0] xin_imag4,
    input wire signed [31:0] xin_imag5,
    input wire signed [31:0] xin_imag6,
    input wire signed [31:0] xin_imag7,

    output [31:0] Xout_real0,
    output [31:0] Xout_real1,
    output [31:0] Xout_real2,
    output [31:0] Xout_real3,
    output [31:0] Xout_real4,
    output [31:0] Xout_real5,
    output [31:0] Xout_real6,
    output [31:0] Xout_real7,
    output [31:0] Xout_imag0,
    output [31:0] Xout_imag1,
    output [31:0] Xout_imag2,
    output [31:0] Xout_imag3,
    output [31:0] Xout_imag4,
    output [31:0] Xout_imag5,
    output [31:0] Xout_imag6,
    output [31:0] Xout_imag7
);
    // ===== stage1 ===== //
    wire [31:0] stage1out_real0,stage1out_real1,stage1out_real2,stage1out_real3,stage1out_real4,stage1out_real5,stage1out_real6,stage1out_real7;
    wire [31:0] stage1out_imag0,stage1out_imag1,stage1out_imag2,stage1out_imag3,stage1out_imag4,stage1out_imag5,stage1out_imag6,stage1out_imag7;
 
    com_2pt c2_0(
    .clk(clk),
    
    .xin_real0(xin_real0),
    .xin_real1(xin_real1),
    .xin_imag0(xin_imag0),
    .xin_imag1(xin_imag1),

    .Xout_real0(stage1out_real0),
    .Xout_real1(stage1out_real1),
    .Xout_imag0(stage1out_imag0),
    .Xout_imag1(stage1out_imag1)
    );

    com_2pt c2_1(
    .clk(clk),
    
    .xin_real0(xin_real2),
    .xin_real1(xin_real3),
    .xin_imag0(xin_imag2),
    .xin_imag1(xin_imag3),

    .Xout_real0(stage1out_real2),
    .Xout_real1(stage1out_real3),
    .Xout_imag0(stage1out_imag2),
    .Xout_imag1(stage1out_imag3)
    );

    com_2pt c2_2(
    .clk(clk),
    
    .xin_real0(xin_real4),
    .xin_real1(xin_real5),
    .xin_imag0(xin_imag4),
    .xin_imag1(xin_imag5),

    .Xout_real0(stage1out_real4),
    .Xout_real1(stage1out_real5),
    .Xout_imag0(stage1out_imag4),
    .Xout_imag1(stage1out_imag5)
    );

    com_2pt c2_3(
    .clk(clk),
    
    .xin_real0(xin_real6),
    .xin_real1(xin_real7),
    .xin_imag0(xin_imag6),
    .xin_imag1(xin_imag7),

    .Xout_real0(stage1out_real6),
    .Xout_real1(stage1out_real7),
    .Xout_imag0(stage1out_imag6),
    .Xout_imag1(stage1out_imag7)
    );

    // ===== stage 2 ===== //
    wire [31:0] stage2out_real0,stage2out_real1,stage2out_real2,stage2out_real3,stage2out_real4,stage2out_real5,stage2out_real6,stage2out_real7;
    wire [31:0] stage2out_imag0,stage2out_imag1,stage2out_imag2,stage2out_imag3,stage2out_imag4,stage2out_imag5,stage2out_imag6,stage2out_imag7;

    com_4pt c4_0(
    .clk(clk),
    
    .twiddle2_8_real(twiddle2_8_real),
    .twiddle2_8_imag(twiddle2_8_imag),

    .xin_real0(stage1out_real0),
    .xin_real1(stage1out_real1),
    .xin_real2(stage1out_real2),
    .xin_real3(stage1out_real3),
    .xin_imag0(stage1out_imag0),
    .xin_imag1(stage1out_imag1),
    .xin_imag2(stage1out_imag2),
    .xin_imag3(stage1out_imag3),

    .Xout_real0(stage2out_real0),
    .Xout_real1(stage2out_real1),
    .Xout_real2(stage2out_real2),
    .Xout_real3(stage2out_real3),
    .Xout_imag0(stage2out_imag0),
    .Xout_imag1(stage2out_imag1),
    .Xout_imag2(stage2out_imag2),
    .Xout_imag3(stage2out_imag3)
    );

    com_4pt c4_1(
    .clk(clk),
    
    .twiddle2_8_real(twiddle2_8_real),
    .twiddle2_8_imag(twiddle2_8_imag),

    .xin_real0(stage1out_real4),
    .xin_real1(stage1out_real5),
    .xin_real2(stage1out_real6),
    .xin_real3(stage1out_real7),
    .xin_imag0(stage1out_imag4),
    .xin_imag1(stage1out_imag5),
    .xin_imag2(stage1out_imag6),
    .xin_imag3(stage1out_imag7),

    .Xout_real0(stage2out_real4),
    .Xout_real1(stage2out_real5),
    .Xout_real2(stage2out_real6),
    .Xout_real3(stage2out_real7),
    .Xout_imag0(stage2out_imag4),
    .Xout_imag1(stage2out_imag5),
    .Xout_imag2(stage2out_imag6),
    .Xout_imag3(stage2out_imag7)
    );

    // ===== stage 3 ===== //
    com_8pt c8_0(
    .clk(clk),
    
    .twiddle1_8_real(twiddle1_8_real),
    .twiddle1_8_imag(twiddle1_8_imag),
    .twiddle2_8_real(twiddle2_8_real),
    .twiddle2_8_imag(twiddle2_8_imag),
    .twiddle3_8_real(twiddle3_8_real),
    .twiddle3_8_imag(twiddle3_8_imag),

    .xin_real0(stage2out_real0),
    .xin_real1(stage2out_real1),
    .xin_real2(stage2out_real2),
    .xin_real3(stage2out_real3),
    .xin_real4(stage2out_real4),
    .xin_real5(stage2out_real5),
    .xin_real6(stage2out_real6),
    .xin_real7(stage2out_real7),
    .xin_imag0(stage2out_imag0),
    .xin_imag1(stage2out_imag1),
    .xin_imag2(stage2out_imag2),
    .xin_imag3(stage2out_imag3),
    .xin_imag4(stage2out_imag4),
    .xin_imag5(stage2out_imag5),
    .xin_imag6(stage2out_imag6),
    .xin_imag7(stage2out_imag7),

    .Xout_real0(Xout_real0),
    .Xout_real1(Xout_real1),
    .Xout_real2(Xout_real2),
    .Xout_real3(Xout_real3),
    .Xout_real4(Xout_real4),
    .Xout_real5(Xout_real5),
    .Xout_real6(Xout_real6),
    .Xout_real7(Xout_real7),
    .Xout_imag0(Xout_imag0),
    .Xout_imag1(Xout_imag1),
    .Xout_imag2(Xout_imag2),
    .Xout_imag3(Xout_imag3),
    .Xout_imag4(Xout_imag4),
    .Xout_imag5(Xout_imag5),
    .Xout_imag6(Xout_imag6),
    .Xout_imag7(Xout_imag7)
    );
endmodule