module com_8pt (
    input wire clk,
    
    input wire signed  [31:0] twiddle1_8_real,
    input wire signed  [31:0] twiddle1_8_imag,
    input wire signed  [31:0] twiddle2_8_real,
    input wire signed  [31:0] twiddle2_8_imag,
    input wire signed  [31:0] twiddle3_8_real,
    input wire signed  [31:0] twiddle3_8_imag,

    input wire signed  [31:0] xin_real0,
    input wire signed  [31:0] xin_real1,
    input wire signed  [31:0] xin_real2,
    input wire signed  [31:0] xin_real3,
    input wire signed  [31:0] xin_real4,
    input wire signed  [31:0] xin_real5,
    input wire signed  [31:0] xin_real6,
    input wire signed  [31:0] xin_real7,
    input wire signed  [31:0] xin_imag0,
    input wire signed  [31:0] xin_imag1,
    input wire signed  [31:0] xin_imag2,
    input wire signed  [31:0] xin_imag3,
    input wire signed  [31:0] xin_imag4,
    input wire signed  [31:0] xin_imag5,
    input wire signed  [31:0] xin_imag6,
    input wire signed  [31:0] xin_imag7,

    output reg [31:0] Xout_real0,
    output reg [31:0] Xout_real1,
    output reg [31:0] Xout_real2,
    output reg [31:0] Xout_real3,
    output reg [31:0] Xout_real4,
    output reg [31:0] Xout_real5,
    output reg [31:0] Xout_real6,
    output reg [31:0] Xout_real7,
    output reg [31:0] Xout_imag0,
    output reg [31:0] Xout_imag1,
    output reg [31:0] Xout_imag2,
    output reg [31:0] Xout_imag3,
    output reg [31:0] Xout_imag4,
    output reg [31:0] Xout_imag5,
    output reg [31:0] Xout_imag6,
    output reg [31:0] Xout_imag7
);
    // ===== real part ===== //
    reg signed [31:0] xin_real0_FF,xin_real1_FF,xin_real2_FF,xin_real3_FF,xin_real4_FF;
    reg signed [64:0] xin_real0_FF2,xin_real1_FF2,xin_real2_FF2,xin_real3_FF2,xin_real4_FF2;
    wire [64:0] xin_real5_FF2,xin_real6_FF2,xin_real7_FF2;
    reg signed [64:0] Xout_real0_next,Xout_real1_next,Xout_real2_next,Xout_real3_next,Xout_real4_next,Xout_real5_next,Xout_real6_next,Xout_real7_next;
    wire [64:0] xin_imag5_FF2,xin_imag6_FF2,xin_imag7_FF2;

    always @(posedge clk) begin
        xin_real0_FF <= xin_real0;
        xin_real1_FF <= xin_real1;
        xin_real2_FF <= xin_real2;
        xin_real3_FF <= xin_real3;
        xin_real4_FF <= xin_real4;
    end

    always @(posedge clk) begin
        xin_real0_FF2 <= xin_real0_FF <<< 23;
        xin_real1_FF2 <= xin_real1_FF <<< 23;
        xin_real2_FF2 <= xin_real2_FF <<< 23;
        xin_real3_FF2 <= xin_real3_FF <<< 23;
        xin_real4_FF2 <= xin_real4_FF <<< 23;
    end


    complex_mul m1(
    .clk(clk),
    .xin_real0(xin_real5),
    .xin_real1(twiddle1_8_real),
    .xin_imag0(xin_imag5),
    .xin_imag1(twiddle1_8_imag),
    .Xout_real(xin_real5_FF2),
    .Xout_imag(xin_imag5_FF2)
    );

    complex_mul m2(
    .clk(clk),
    .xin_real0(xin_real6),
    .xin_real1(twiddle2_8_real),
    .xin_imag0(xin_imag6),
    .xin_imag1(twiddle2_8_imag),
    .Xout_real(xin_real6_FF2),
    .Xout_imag(xin_imag6_FF2)
    );

    complex_mul m3(
    .clk(clk),
    .xin_real0(xin_real7),
    .xin_real1(twiddle3_8_real),
    .xin_imag0(xin_imag7),
    .xin_imag1(twiddle3_8_imag),
    .Xout_real(xin_real7_FF2),
    .Xout_imag(xin_imag7_FF2)
    );

    always @(posedge clk) begin
        Xout_real0 <= Xout_real0_next[0+:32];
        Xout_real1 <= Xout_real1_next[0+:32];
        Xout_real2 <= Xout_real2_next[0+:32];
        Xout_real3 <= Xout_real3_next[0+:32];
        Xout_real4 <= Xout_real4_next[0+:32];
        Xout_real5 <= Xout_real5_next[0+:32];
        Xout_real6 <= Xout_real6_next[0+:32];
        Xout_real7 <= Xout_real7_next[0+:32];
    end

    always @(*) begin
        Xout_real0_next = xin_real0_FF2 + xin_real4_FF2;
        Xout_real1_next = xin_real1_FF2 + xin_real5_FF2;
        Xout_real2_next = xin_real2_FF2 + xin_real6_FF2;
        Xout_real3_next = xin_real3_FF2 + xin_real7_FF2;

        Xout_real4_next = xin_real0_FF2 - xin_real4_FF2;
        Xout_real5_next = xin_real1_FF2 - xin_real5_FF2;
        Xout_real6_next = xin_real2_FF2 - xin_real6_FF2;
        Xout_real7_next = xin_real3_FF2 - xin_real7_FF2;

        Xout_real0_next = Xout_real0_next >>> 23;
        Xout_real1_next = Xout_real1_next >>> 23;
        Xout_real2_next = Xout_real2_next >>> 23;
        Xout_real3_next = Xout_real3_next >>> 23;

        Xout_real4_next = Xout_real4_next >>> 23;
        Xout_real5_next = Xout_real5_next >>> 23;
        Xout_real6_next = Xout_real6_next >>> 23;
        Xout_real7_next = Xout_real7_next >>> 23;

        if (Xout_real0_next > 2**31-1) begin
            Xout_real0_next = 2**31-1;
        end
        else if (Xout_real0_next < -2**31) begin
            Xout_real0_next = -2**31;
        end

        if (Xout_real1_next > 2**31-1) begin
            Xout_real1_next = 2**31-1;
        end
        else if (Xout_real1_next < -2**31) begin
            Xout_real1_next = -2**31;
        end

        if (Xout_real2_next > 2**31-1) begin
            Xout_real2_next = 2**31-1;
        end
        else if (Xout_real2_next < -2**31) begin
            Xout_real2_next = -2**31;
        end

        if (Xout_real3_next > 2**31-1) begin
            Xout_real3_next = 2**31-1;
        end
        else if (Xout_real3_next < -2**31) begin
            Xout_real3_next = -2**31;
        end

        if (Xout_real4_next > 2**31-1) begin
            Xout_real4_next = 2**31-1;
        end
        else if (Xout_real4_next < -2**31) begin
            Xout_real4_next = -2**31;
        end

        if (Xout_real5_next > 2**31-1) begin
            Xout_real5_next = 2**31-1;
        end
        else if (Xout_real5_next < -2**31) begin
            Xout_real5_next = -2**31;
        end

        if (Xout_real6_next > 2**31-1) begin
            Xout_real6_next = 2**31-1;
        end
        else if (Xout_real6_next < -2**31) begin
            Xout_real6_next = -2**31;
        end

        if (Xout_real7_next > 2**31-1) begin
            Xout_real7_next = 2**31-1;
        end
        else if (Xout_real7_next < -2**31) begin
            Xout_real7_next = -2**31;
        end
    end

    // ===== imag part ===== //
    reg signed [31:0] xin_imag0_FF,xin_imag1_FF,xin_imag2_FF,xin_imag3_FF,xin_imag4_FF;
    reg signed [64:0] xin_imag0_FF2,xin_imag1_FF2,xin_imag2_FF2,xin_imag3_FF2,xin_imag4_FF2;
    reg signed [64:0] Xout_imag0_next,Xout_imag1_next,Xout_imag2_next,Xout_imag3_next,Xout_imag4_next,Xout_imag5_next,Xout_imag6_next,Xout_imag7_next;

    always @(posedge clk) begin
        xin_imag0_FF <= xin_imag0;
        xin_imag1_FF <= xin_imag1;
        xin_imag2_FF <= xin_imag2;
        xin_imag3_FF <= xin_imag3;
        xin_imag4_FF <= xin_imag4;
    end

    always @(posedge clk) begin
        xin_imag0_FF2 <= xin_imag0_FF <<< 23;
        xin_imag1_FF2 <= xin_imag1_FF <<< 23;
        xin_imag2_FF2 <= xin_imag2_FF <<< 23;
        xin_imag3_FF2 <= xin_imag3_FF <<< 23;
        xin_imag4_FF2 <= xin_imag4_FF <<< 23;
    end

    always @(posedge clk) begin
        Xout_imag0 <= Xout_imag0_next[0+:32];
        Xout_imag1 <= Xout_imag1_next[0+:32];
        Xout_imag2 <= Xout_imag2_next[0+:32];
        Xout_imag3 <= Xout_imag3_next[0+:32];
        Xout_imag4 <= Xout_imag4_next[0+:32];
        Xout_imag5 <= Xout_imag5_next[0+:32];
        Xout_imag6 <= Xout_imag6_next[0+:32];
        Xout_imag7 <= Xout_imag7_next[0+:32];
    end

    always @(*) begin
        Xout_imag0_next = xin_imag0_FF2 + xin_imag4_FF2;
        Xout_imag1_next = xin_imag1_FF2 + xin_imag5_FF2;
        Xout_imag2_next = xin_imag2_FF2 + xin_imag6_FF2;
        Xout_imag3_next = xin_imag3_FF2 + xin_imag7_FF2;

        Xout_imag4_next = xin_imag0_FF2 - xin_imag4_FF2;
        Xout_imag5_next = xin_imag1_FF2 - xin_imag5_FF2;
        Xout_imag6_next = xin_imag2_FF2 - xin_imag6_FF2;
        Xout_imag7_next = xin_imag3_FF2 - xin_imag7_FF2;

        Xout_imag0_next = Xout_imag0_next >>> 23;
        Xout_imag1_next = Xout_imag1_next >>> 23;
        Xout_imag2_next = Xout_imag2_next >>> 23;
        Xout_imag3_next = Xout_imag3_next >>> 23;

        Xout_imag4_next = Xout_imag4_next >>> 23;
        Xout_imag5_next = Xout_imag5_next >>> 23;
        Xout_imag6_next = Xout_imag6_next >>> 23;
        Xout_imag7_next = Xout_imag7_next >>> 23;

        if (Xout_imag0_next > 2**31-1) begin
            Xout_imag0_next = 2**31-1;
        end
        else if (Xout_imag0_next < -2**31) begin
            Xout_imag0_next = -2**31;
        end

        if (Xout_imag1_next > 2**31-1) begin
            Xout_imag1_next = 2**31-1;
        end
        else if (Xout_imag1_next < -2**31) begin
            Xout_imag1_next = -2**31;
        end

        if (Xout_imag2_next > 2**31-1) begin
            Xout_imag2_next = 2**31-1;
        end
        else if (Xout_imag2_next < -2**31) begin
            Xout_imag2_next = -2**31;
        end

        if (Xout_imag3_next > 2**31-1) begin
            Xout_imag3_next = 2**31-1;
        end
        else if (Xout_imag3_next < -2**31) begin
            Xout_imag3_next = -2**31;
        end

        if (Xout_imag4_next > 2**31-1) begin
            Xout_imag4_next = 2**31-1;
        end
        else if (Xout_imag4_next < -2**31) begin
            Xout_imag4_next = -2**31;
        end

        if (Xout_imag5_next > 2**31-1) begin
            Xout_imag5_next = 2**31-1;
        end
        else if (Xout_imag5_next < -2**31) begin
            Xout_imag5_next = -2**31;
        end

        if (Xout_imag6_next > 2**31-1) begin
            Xout_imag6_next = 2**31-1;
        end
        else if (Xout_imag6_next < -2**31) begin
            Xout_imag6_next = -2**31;
        end

        if (Xout_imag7_next > 2**31-1) begin
            Xout_imag7_next = 2**31-1;
        end
        else if (Xout_imag7_next < -2**31) begin
            Xout_imag7_next = -2**31;
        end
    end
endmodule