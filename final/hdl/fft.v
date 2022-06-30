module fft (
    input wire clk,
    input wire rst_n,
    
    input wire compute_start,
    output reg compute_finish,

    // Real part sram, dual port
    output reg [ 3:0] sram_real_wea0,
    output reg [15:0] sram_real_addr0,
    output reg [31:0] sram_real_wdata0,
    input wire [31:0] sram_real_rdata0,
    output reg [ 3:0] sram_real_wea1,
    output reg [15:0] sram_real_addr1,
    output reg [31:0] sram_real_wdata1,
    input wire [31:0] sram_real_rdata1,

    // imag part sram, dual port
    output reg [ 3:0] sram_imag_wea0,
    output reg [15:0] sram_imag_addr0,
    output reg [31:0] sram_imag_wdata0,
    input wire [31:0] sram_imag_rdata0,
    output reg [ 3:0] sram_imag_wea1,
    output reg [15:0] sram_imag_addr1,
    output reg [31:0] sram_imag_wdata1,
    input wire [31:0] sram_imag_rdata1
);
    // ===== input FF ===== //
    reg compute_start_FF;
    reg rst_n_FF;
    reg [31:0] sram_real_rdata0_FF,sram_real_rdata1_FF;
    reg [31:0] sram_imag_rdata0_FF,sram_imag_rdata1_FF;

    always @(posedge clk) begin
        compute_start_FF <= compute_start;
        rst_n_FF <= rst_n;
    end 

    always @(posedge clk ) begin
        sram_real_rdata0_FF <= sram_real_rdata0;
        sram_real_rdata1_FF <= sram_real_rdata1;
        sram_imag_rdata0_FF <= sram_imag_rdata0;
        sram_imag_rdata1_FF <= sram_imag_rdata1;
    end

    // ===== output FF ===== //
    /*reg compute_finish_FF;

    always @(posedge clk ) begin
        compute_finish <= compute_finish_FF;
    end*/

    wire [ 3:0] sram_real_wea0_FF,sram_real_wea1_FF;
    wire [15:0] sram_real_addr0_FF,sram_real_addr1_FF;
    wire [31:0] sram_real_wdata0_FF,sram_real_wdata1_FF;

    always @(posedge clk) begin
        sram_real_wea0 <= sram_real_wea0_FF;
        sram_real_wea1 <= sram_real_wea1_FF;
        sram_real_addr0 <= sram_real_addr0_FF;
        sram_real_addr1 <= sram_real_addr1_FF;
        sram_real_wdata0 <= sram_real_wdata0_FF;
        sram_real_wdata1 <= sram_real_wdata1_FF;
    end

    wire [ 3:0] sram_imag_wea0_FF,sram_imag_wea1_FF;
    wire [15:0] sram_imag_addr0_FF,sram_imag_addr1_FF;
    wire [31:0] sram_imag_wdata0_FF,sram_imag_wdata1_FF;

    always @(posedge clk) begin
        sram_imag_wea0 <= sram_imag_wea0_FF;
        sram_imag_wea1 <= sram_imag_wea1_FF;
        sram_imag_addr0 <= sram_imag_addr0_FF;
        sram_imag_addr1 <= sram_imag_addr1_FF;
        sram_imag_wdata0 <= sram_imag_wdata0_FF;
        sram_imag_wdata1 <= sram_imag_wdata1_FF;
    end

    wire [1:0] state;
    parameter DONE = 2'd3;

    FFT_24 fft_24(
    .clk(clk),
    .rst_n(rst_n_FF),

    .compute_start_FF(compute_start_FF),
    .state(state),

    // Real part sram(), dual port
    .sram_real_wea0(sram_real_wea0_FF),
    .sram_real_addr0(sram_real_addr0_FF),
    .sram_real_wdata0(sram_real_wdata0_FF),
    .sram_real_rdata0(sram_real_rdata0_FF),
    .sram_real_wea1(sram_real_wea1_FF),
    .sram_real_addr1(sram_real_addr1_FF),
    .sram_real_wdata1(sram_real_wdata1_FF),
    .sram_real_rdata1(sram_real_rdata1_FF),

    // imag part sram(), dual port
    .sram_imag_wea0(sram_imag_wea0_FF),
    .sram_imag_addr0(sram_imag_addr0_FF),
    .sram_imag_wdata0(sram_imag_wdata0_FF),
    .sram_imag_rdata0(sram_imag_rdata0_FF),
    .sram_imag_wea1(sram_imag_wea1_FF),
    .sram_imag_addr1(sram_imag_addr1_FF),
    .sram_imag_wdata1(sram_imag_wdata1_FF),
    .sram_imag_rdata1(sram_imag_rdata1_FF) 
    );

    always @(posedge clk) begin
        if (~rst_n_FF) begin
            compute_finish <= 1'b0;
        end
        else if (state == DONE) begin
            compute_finish <= 1'b1;
        end
    end

endmodule