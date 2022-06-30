module complex_mul (
    input wire clk,
    input wire [31:0] xin_real0,
    input wire [31:0] xin_real1,
    input wire [31:0] xin_imag0,
    input wire [31:0] xin_imag1,

    output reg [64:0] Xout_real,
    output reg [64:0] Xout_imag
);

    // ===== real part ==== //
    reg [64:0] real_mul0,real_mul1;
    reg [64:0] real_mul0_next,real_mul1_next;

    always @(posedge clk) begin
        real_mul0 <= real_mul0_next;
        real_mul1 <= real_mul1_next;
    end

    always @(*) begin
        real_mul0_next = xin_real0 * xin_real1;
        real_mul1_next = xin_imag0 * xin_imag1;
    end

    reg [64:0] Xout_real_next;
    always @(posedge clk) begin
        Xout_real <= Xout_real_next;
    end

    always @(*) begin
        Xout_real_next = real_mul0 - real_mul1;
    end

    // ===== imag part ===== //
    reg [64:0] imag_mul0,imag_mul1;
    reg [64:0] imag_mul0_next,imag_mul1_next;

    always @(posedge clk) begin
        imag_mul0 <= imag_mul0_next;
        imag_mul1 <= imag_mul1_next;
    end

    always @(*) begin
        imag_mul0_next = xin_real0 * xin_imag1;
        imag_mul1_next = xin_real1 * xin_imag0;
    end

    reg [64:0] Xout_imag_next;
    always @(posedge clk) begin
        Xout_imag <= Xout_imag_next;
    end

    always @(*) begin
        Xout_imag_next = imag_mul0 + imag_mul1;
    end
    
endmodule