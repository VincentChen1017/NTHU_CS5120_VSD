module com_2pt (
    input wire clk,
    
    input wire signed [31:0] xin_real0,
    input wire signed [31:0] xin_real1,
    input wire signed [31:0] xin_imag0,
    input wire signed [31:0] xin_imag1,

    output reg [31:0] Xout_real0,
    output reg [31:0] Xout_real1,
    output reg [31:0] Xout_imag0,
    output reg [31:0] Xout_imag1
);
    // ===== real part ===== //
    reg signed [32:0] Xout_real0_next,Xout_real1_next;

    always @(posedge clk) begin
        Xout_real0 <= {Xout_real0_next[32],Xout_real0_next[0+:31]};
        Xout_real1 <= {Xout_real1_next[32],Xout_real1_next[0+:31]};
    end

    always @(*) begin
        Xout_real0_next = xin_real0 + xin_real1;
        Xout_real1_next = xin_real0 - xin_real1;
        
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
    end

    // ===== imag part ===== //
    reg signed [32:0] Xout_imag0_next,Xout_imag1_next;

    always @(posedge clk) begin
        Xout_imag0 <= {Xout_imag0_next[32],Xout_imag0_next[0+:31]};
        Xout_imag1 <= {Xout_imag1_next[32],Xout_imag1_next[0+:31]};
    end

    always @(*) begin
        Xout_imag0_next = xin_imag0 + xin_imag1;
        Xout_imag1_next = xin_imag0 - xin_imag1;

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
    end
    
endmodule