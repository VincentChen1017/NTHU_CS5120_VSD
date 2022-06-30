module twiddle_factor(
    input wire clk,
    input wire [4:0] k,
    output reg [31:0] real_part1_l0,
    output reg [31:0] imag_part1_l0,
    output reg [31:0] real_part1_l1,
    output reg [31:0] imag_part1_l1,
    output reg [31:0] real_part1_l2,
    output reg [31:0] imag_part1_l2,
    output reg [31:0] real_part2_l0,
    output reg [31:0] imag_part2_l0,
    output reg [31:0] real_part2_l1,
    output reg [31:0] imag_part2_l1,
    output reg [31:0] real_part2_l2,
    output reg [31:0] imag_part2_l2
);

    always @(*) begin
        real_part1_l0 = 32'd0;
        imag_part1_l0 = 32'd0;
        real_part1_l1 = 32'd0;
        imag_part1_l1 = 32'd0;
        real_part1_l2 = 32'd0;
        imag_part1_l2 = 32'd0;

        real_part2_l0 = 32'd0;
        imag_part2_l0 = 32'd0;
        real_part2_l1 = 32'd0;
        imag_part2_l1 = 32'd0;
        real_part2_l2 = 32'd0;
        imag_part2_l2 = 32'd0;


        // k = 0 => 算 X[0] X[1]
        // k = 1 => 算 X[2] X[3]...
        case (k)
            0 : begin 
                // 0 0 0
                real_part1_l0 = 32'h00800000;
                imag_part1_l0 = 32'h00000000;
                real_part1_l1 = 32'h00800000;
                imag_part1_l1 = 32'h00000000;
                real_part1_l2 = 32'h00800000;
                // 0 0 0
                real_part2_l0 = 32'h00800000;
                imag_part2_l0 = 32'h00000000;
                real_part2_l1 = 32'h00800000;
                imag_part2_l1 = 32'h00000000;
                real_part2_l2 = 32'h00800000;
                imag_part2_l2 = 32'h00000000;

            end 
            1 : begin 
                // 0 2 4
                real_part1_l0 = 32'h00800000;
                imag_part1_l0 = 32'h00000000;
                real_part1_l1 = 32'h006ED9EC;
                imag_part1_l1 = 32'hFFC00000;
                real_part1_l2 = 32'h00400000;
                imag_part1_l2 = 32'hFF912614;
                // 0 3 6
                real_part2_l0 = 32'h00800000;
                imag_part2_l0 = 32'h00000000;
                real_part2_l1 = 32'h005A827A;
                imag_part2_l1 = 32'hFFA57D86;
                real_part2_l2 = 32'h00000000;
                imag_part2_l2 = 32'hFF800000;
            end 
            2 : begin 
                // 0 4 8
                real_part1_l0 = 32'h00800000;
                imag_part1_l0 = 32'h00000000;
                real_part1_l1 = 32'h00400000;
                imag_part1_l1 = 32'hFF912614;
                real_part1_l2 = 32'hFFC00000;
                imag_part1_l2 = 32'hFF912614;
                // 0 5 10
                real_part2_l0 = 32'h00800000;
                imag_part2_l0 = 32'h00000000;
                real_part2_l1 = 32'h002120FC;
                imag_part2_l1 = 32'hFF845C8B;
                real_part2_l2 = 32'hFF912614;
                imag_part2_l2 = 32'hFFC00000;
            end 
            3 : begin 
                // 0 6 12
                real_part1_l0 = 32'h00800000;
                imag_part1_l0 = 32'h00000000;
                real_part1_l1 = 32'h00000000;
                imag_part1_l1 = 32'hFF800000;
                real_part1_l2 = 32'hFF800000;
                imag_part1_l2 = 32'h00000000;
                // 0 7 14
                real_part2_l0 = 32'h00800000;
                imag_part2_l0 = 32'h00000000;
                real_part2_l1 = 32'hFFDEDF04;
                imag_part2_l1 = 32'hFF845C8B;
                real_part2_l2 = 32'hFF912614;
                imag_part2_l2 = 32'h00400000;
            end 
            4 : begin 
                // 0 8 16
                real_part1_l0 = 32'h00800000;
                imag_part1_l0 = 32'h00000000;
                real_part1_l1 = 32'hFFC00000;
                imag_part1_l1 = 32'hFF912614;
                real_part1_l2 = 32'hFFC00000;
                imag_part1_l2 = 32'h006ED9EC;
                // 0 9 18
                real_part2_l0 = 32'h00800000;
                imag_part2_l0 = 32'h00000000;
                real_part2_l1 = 32'hFFA57D86;
                imag_part2_l1 = 32'hFFA57D86;
                real_part2_l2 = 32'h00000000;
                imag_part2_l2 = 32'h00800000;
            end 
            5 : begin 
                // 0 10 20
                real_part1_l0 = 32'h00800000;
                imag_part1_l0 = 32'h00000000;
                real_part1_l1 = 32'hFF912614;
                imag_part1_l1 = 32'hFFC00000;
                real_part1_l2 = 32'h00400000;
                imag_part1_l2 = 32'h006ED9EC;
                // 0 11 22
                real_part2_l0 = 32'h00800000;
                imag_part2_l0 = 32'h00000000;
                real_part2_l1 = 32'hFF845C8B;
                imag_part2_l1 = 32'hFFDEDF04;
                real_part2_l2 = 32'h006ED9EC;
                imag_part2_l2 = 32'h00400000;
            end 
            6 : begin 
                // 0 12 24(0)
                real_part1_l0 = 32'h00800000;
                imag_part1_l0 = 32'h00000000;
                real_part1_l1 = 32'hFF800000;
                imag_part1_l1 = 32'h00000000;
                real_part1_l2 = 32'h00800000;
                imag_part1_l2 = 32'h00000000;
                // 0 13 26(2)
                real_part2_l0 = 32'h00800000;
                imag_part2_l0 = 32'h00000000;
                real_part2_l1 = 32'hFF845C8B;
                imag_part2_l1 = 32'h002120FC;
                real_part2_l2 = 32'h006ED9EC;
                imag_part2_l2 = 32'hFFC00000;
            end 
            7 : begin 
                // 0 14 28(4)
                real_part1_l0 = 32'h00800000;
                imag_part1_l0 = 32'h00000000;
                real_part1_l1 = 32'hFF912614;
                imag_part1_l1 = 32'h00400000;
                real_part1_l2 = 32'h00400000;
                imag_part1_l2 = 32'hFF912614;
                // 0 15 30(6)
                real_part2_l0 = 32'h00800000;
                imag_part2_l0 = 32'h00000000;
                real_part2_l1 = 32'hFFA57D86;
                imag_part2_l1 = 32'h005A827A;
                real_part2_l2 = 32'h00000000;
                imag_part2_l2 = 32'hFF800000;
            end 
            8 : begin 
                // 0 16 32(8)
                real_part1_l0 = 32'h00800000;
                imag_part1_l0 = 32'h00000000;
                real_part1_l1 = 32'hFFC00000;
                imag_part1_l1 = 32'h006ED9EC;
                real_part1_l2 = 32'hFFC00000;
                imag_part1_l2 = 32'hFF912614;
                // 0 17 34(10)
                real_part2_l0 = 32'h00800000;
                imag_part2_l0 = 32'h00000000;
                real_part2_l1 = 32'hFFDEDF04;
                imag_part2_l1 = 32'h007BA375;
                real_part2_l2 = 32'hFF912614;
                imag_part2_l2 = 32'hFFC00000;
            end 
            9 : begin 
                // 0 18 36(12)
                real_part1_l0 = 32'h00800000;
                imag_part1_l0 = 32'h00000000;
                real_part1_l1 = 32'h00000000;
                imag_part1_l1 = 32'h00800000;
                real_part1_l2 = 32'hFF800000;
                imag_part1_l2 = 32'h00000000;
                // 0 19 38(14)
                real_part2_l0 = 32'h00800000;
                imag_part2_l0 = 32'h00000000;
                real_part2_l1 = 32'h002120FC;
                imag_part2_l1 = 32'h007BA375;
                real_part2_l2 = 32'hFF912614;
                imag_part2_l2 = 32'h00400000;
            end 
            10 : begin 
                // 0 20 40(16)
                real_part1_l0 = 32'h00800000;
                imag_part1_l0 = 32'h00000000;
                real_part1_l1 = 32'h00400000;
                imag_part1_l1 = 32'h006ED9EC;
                real_part1_l2 = 32'hFFC00000;
                imag_part1_l2 = 32'h006ED9EC;
                // 0 21 42(18)
                real_part2_l0 = 32'h00800000;
                imag_part2_l0 = 32'h00000000;
                real_part2_l1 = 32'h005A827A;
                imag_part2_l1 = 32'h005A827A;
                real_part2_l2 = 32'h00000000;
                imag_part2_l2 = 32'h00800000;
            end 
            11 : begin 
                // 0 22 44(20)
                real_part1_l0 = 32'h00800000;
                imag_part1_l0 = 32'h00000000;
                real_part1_l1 = 32'h006ED9EC;
                imag_part1_l1 = 32'h00400000;
                real_part1_l2 = 32'h00400000;
                imag_part1_l2 = 32'h006ED9EC;
                // 0 23 46(22)
                real_part2_l0 = 32'h00800000;
                imag_part2_l0 = 32'h00000000;
                real_part2_l1 = 32'h007BA375;
                imag_part2_l1 = 32'h002120FC;
                real_part2_l2 = 32'h006ED9EC;
                imag_part2_l2 = 32'h00400000;
            end  
        endcase
    end
    
endmodule