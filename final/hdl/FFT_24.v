module FFT_24 (
    input wire clk,
    input wire rst_n,

    input wire compute_start_FF,
    output reg [1:0] state,

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
    parameter IDLE = 2'd0;
    parameter LOAD_DATA = 2'd1;
    parameter COMPUTE_DATA = 2'd2;
    parameter DONE = 2'd3;
    parameter NUM_INPUT = 4'd10;

    // ===== operation flow ===== //
    // LOAD DATA -> COMPUTE DATA -> WRITE BACK -> LOAD DATA -> ...

    // ===== FSM ===== //
    reg [1:0] next_state;
    reg load_done;
    reg compute_done;
    reg fft_done;

    always @(posedge clk) begin
        if (~rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (compute_start_FF)
                    next_state = LOAD_DATA;
                else
                    next_state = IDLE;
            end 
            LOAD_DATA : begin
                if (load_done)
                    next_state = COMPUTE_DATA;
                else
                    next_state = LOAD_DATA;
            end
            COMPUTE_DATA : begin
                if (fft_done)
                    next_state = DONE;
                else if (compute_done)
                    next_state = LOAD_DATA;
                else
                    next_state = COMPUTE_DATA;
            end
            DONE: begin
                next_state = DONE;
            end
        endcase
    end

    // ===== count read addr ====== //
    reg [3:0] cnt_input_num,cnt_input_num_next;
    reg [4:0] cnt_read_addr,cnt_read_addr_next;
    reg [31:0] input_real_map [0:23];
    reg [31:0] input_imag_map [0:23];
    reg [4:0] k,k_next;

    always @(posedge clk) begin
        if (~rst_n) begin
            cnt_input_num <= 4'd0;
            cnt_read_addr <= 8'd0;
        end
        else begin
            cnt_input_num <= cnt_input_num_next;
            cnt_read_addr <= cnt_read_addr_next;
        end
    end

    always @(*) begin
        cnt_input_num_next = cnt_input_num;
        cnt_read_addr_next = cnt_read_addr;
        if (state == LOAD_DATA) begin
            // 因為要搭配後面運算所以需要算到12
            if (cnt_read_addr == 4'd14) begin
                cnt_input_num_next = cnt_input_num + 1;
                cnt_read_addr_next = 8'd0;
            end
            else begin
                cnt_input_num_next = cnt_input_num;
                cnt_read_addr_next = cnt_read_addr + 1;
            end
        end
    end

    always @(*) begin
        sram_real_addr0 = 0;
        sram_real_addr1 = 0;
        sram_imag_addr0 = 0;
        sram_imag_addr1 = 0;
        if (state == LOAD_DATA) begin
            sram_real_addr0 = 24*cnt_input_num + 2*cnt_read_addr;
            sram_real_addr1 = 24*cnt_input_num + 2*cnt_read_addr + 1;
            sram_imag_addr0 = 24*cnt_input_num + 2*cnt_read_addr;
            sram_imag_addr1 = 24*cnt_input_num + 2*cnt_read_addr + 1;
        end
        else if (state == COMPUTE_DATA) begin
            if (k >= 3) begin
                sram_real_addr0 = 24*(cnt_input_num-1) + 2*(k-4) + 240;
                sram_real_addr1 = 24*(cnt_input_num-1) + 2*(k-4) + 241;
                sram_imag_addr0 = 24*(cnt_input_num-1) + 2*(k-4) + 240;
                sram_imag_addr1 = 24*(cnt_input_num-1) + 2*(k-4) + 241;
            end
        end
    end

    always @(posedge clk ) begin
        if (state == LOAD_DATA) begin
            if (cnt_read_addr >= 3) begin
                // 2*(cnt_read_addr-3)
                // 2*(cnt_read_addr-3) + 1
                input_real_map[2*cnt_read_addr-6] <= sram_real_rdata0;
                input_real_map[2*cnt_read_addr-5] <= sram_real_rdata1;
                input_imag_map[2*cnt_read_addr-6] <= sram_imag_rdata0;
                input_imag_map[2*cnt_read_addr-5] <= sram_imag_rdata1;
            end
        end
    end

    // ===== LOAD DONE ===== //
    reg load_done_next;

    always @(posedge clk ) begin
        if (~rst_n)
            load_done <= 1'b0;
        else
            load_done <= load_done_next;
    end

    always @(*) begin
        load_done_next = 1'b0;
        if (cnt_read_addr == 4'd13)
            load_done_next = 1'b1;
    end

    // ===== compute_data_period ===== //
    reg [4:0] data_period,data_period_next;

    always @(posedge clk) begin
        if (~rst_n)
            data_period <= 5'd0;
        else
            data_period <= data_period_next;
    end

    always @(*) begin
        data_period_next = 5'd0;
        if (state == COMPUTE_DATA) begin
            if (data_period == 5'd23)
                data_period_next = 5'd0;
            else
                data_period_next = data_period + 1;
        end
    end

    // ===== COMPUTE 3 8-pt DFT ===== //
    wire [31:0] Xout_real_3m_0 [0:7];
    wire [31:0] Xout_real_3m_1 [0:7];
    wire [31:0] Xout_real_3m_2 [0:7];
    wire [31:0] Xout_imag_3m_0 [0:7];
    wire [31:0] Xout_imag_3m_1 [0:7];
    wire [31:0] Xout_imag_3m_2 [0:7];
    reg [31:0] output_real_map [0:23];
    reg [31:0] output_imag_map [0:23];
    wire [31:0] twiddle1_8_real;
    wire [31:0] twiddle1_8_imag;
    wire [31:0] twiddle2_8_real;
    wire [31:0] twiddle2_8_imag;
    wire [31:0] twiddle3_8_real;
    wire [31:0] twiddle3_8_imag;
    
    assign twiddle1_8_real = 32'h005A827A;
    assign twiddle1_8_imag = 32'hFFA57D86;
    assign twiddle2_8_real = 32'h00000000;
    assign twiddle2_8_imag = 32'hFF800000;
    assign twiddle3_8_real = 32'hFFA57D86;
    assign twiddle3_8_imag = 32'hFFA57D86;

    FFT_8 m3_0(
        .clk(clk),
        
        .twiddle1_8_real(twiddle1_8_real),
        .twiddle1_8_imag(twiddle1_8_imag),
        .twiddle2_8_real(twiddle2_8_real),
        .twiddle2_8_imag(twiddle2_8_imag),
        .twiddle3_8_real(twiddle3_8_real),
        .twiddle3_8_imag(twiddle3_8_imag),

        .xin_real0(input_real_map[0]),
        .xin_real1(input_real_map[12]),
        .xin_real2(input_real_map[6]),
        .xin_real3(input_real_map[18]),
        .xin_real4(input_real_map[3]),
        .xin_real5(input_real_map[15]),
        .xin_real6(input_real_map[9]),
        .xin_real7(input_real_map[21]),
        .xin_imag0(input_imag_map[0]),
        .xin_imag1(input_imag_map[12]),
        .xin_imag2(input_imag_map[6]),
        .xin_imag3(input_imag_map[18]),
        .xin_imag4(input_imag_map[3]),
        .xin_imag5(input_imag_map[15]),
        .xin_imag6(input_imag_map[9]),
        .xin_imag7(input_imag_map[21]),

        .Xout_real0(Xout_real_3m_0[0]),
        .Xout_real1(Xout_real_3m_0[1]),
        .Xout_real2(Xout_real_3m_0[2]),
        .Xout_real3(Xout_real_3m_0[3]),
        .Xout_real4(Xout_real_3m_0[4]),
        .Xout_real5(Xout_real_3m_0[5]),
        .Xout_real6(Xout_real_3m_0[6]),
        .Xout_real7(Xout_real_3m_0[7]),
        .Xout_imag0(Xout_imag_3m_0[0]),
        .Xout_imag1(Xout_imag_3m_0[1]),
        .Xout_imag2(Xout_imag_3m_0[2]),
        .Xout_imag3(Xout_imag_3m_0[3]),
        .Xout_imag4(Xout_imag_3m_0[4]),
        .Xout_imag5(Xout_imag_3m_0[5]),
        .Xout_imag6(Xout_imag_3m_0[6]),
        .Xout_imag7(Xout_imag_3m_0[7])
    );

    FFT_8 m3_1(
        .clk(clk),
        
        .twiddle1_8_real(twiddle1_8_real),
        .twiddle1_8_imag(twiddle1_8_imag),
        .twiddle2_8_real(twiddle2_8_real),
        .twiddle2_8_imag(twiddle2_8_imag),
        .twiddle3_8_real(twiddle3_8_real),
        .twiddle3_8_imag(twiddle3_8_imag),

        .xin_real0(input_real_map[1]),
        .xin_real1(input_real_map[13]),
        .xin_real2(input_real_map[7]),
        .xin_real3(input_real_map[19]),
        .xin_real4(input_real_map[4]),
        .xin_real5(input_real_map[16]),
        .xin_real6(input_real_map[10]),
        .xin_real7(input_real_map[22]),
        .xin_imag0(input_imag_map[1]),
        .xin_imag1(input_imag_map[13]),
        .xin_imag2(input_imag_map[7]),
        .xin_imag3(input_imag_map[19]),
        .xin_imag4(input_imag_map[4]),
        .xin_imag5(input_imag_map[16]),
        .xin_imag6(input_imag_map[10]),
        .xin_imag7(input_imag_map[22]),

        .Xout_real0(Xout_real_3m_1[0]),
        .Xout_real1(Xout_real_3m_1[1]),
        .Xout_real2(Xout_real_3m_1[2]),
        .Xout_real3(Xout_real_3m_1[3]),
        .Xout_real4(Xout_real_3m_1[4]),
        .Xout_real5(Xout_real_3m_1[5]),
        .Xout_real6(Xout_real_3m_1[6]),
        .Xout_real7(Xout_real_3m_1[7]),
        .Xout_imag0(Xout_imag_3m_1[0]),
        .Xout_imag1(Xout_imag_3m_1[1]),
        .Xout_imag2(Xout_imag_3m_1[2]),
        .Xout_imag3(Xout_imag_3m_1[3]),
        .Xout_imag4(Xout_imag_3m_1[4]),
        .Xout_imag5(Xout_imag_3m_1[5]),
        .Xout_imag6(Xout_imag_3m_1[6]),
        .Xout_imag7(Xout_imag_3m_1[7])
    );

    FFT_8 m3_2(
        .clk(clk),
        
        .twiddle1_8_real(twiddle1_8_real),
        .twiddle1_8_imag(twiddle1_8_imag),
        .twiddle2_8_real(twiddle2_8_real),
        .twiddle2_8_imag(twiddle2_8_imag),
        .twiddle3_8_real(twiddle3_8_real),
        .twiddle3_8_imag(twiddle3_8_imag),

        .xin_real0(input_real_map[2]),
        .xin_real1(input_real_map[14]),
        .xin_real2(input_real_map[8]),
        .xin_real3(input_real_map[20]),
        .xin_real4(input_real_map[5]),
        .xin_real5(input_real_map[17]),
        .xin_real6(input_real_map[11]),
        .xin_real7(input_real_map[23]),
        .xin_imag0(input_imag_map[2]),
        .xin_imag1(input_imag_map[14]),
        .xin_imag2(input_imag_map[8]),
        .xin_imag3(input_imag_map[20]),
        .xin_imag4(input_imag_map[5]),
        .xin_imag5(input_imag_map[17]),
        .xin_imag6(input_imag_map[11]),
        .xin_imag7(input_imag_map[23]),

        .Xout_real0(Xout_real_3m_2[0]),
        .Xout_real1(Xout_real_3m_2[1]),
        .Xout_real2(Xout_real_3m_2[2]),
        .Xout_real3(Xout_real_3m_2[3]),
        .Xout_real4(Xout_real_3m_2[4]),
        .Xout_real5(Xout_real_3m_2[5]),
        .Xout_real6(Xout_real_3m_2[6]),
        .Xout_real7(Xout_real_3m_2[7]),
        .Xout_imag0(Xout_imag_3m_2[0]),
        .Xout_imag1(Xout_imag_3m_2[1]),
        .Xout_imag2(Xout_imag_3m_2[2]),
        .Xout_imag3(Xout_imag_3m_2[3]),
        .Xout_imag4(Xout_imag_3m_2[4]),
        .Xout_imag5(Xout_imag_3m_2[5]),
        .Xout_imag6(Xout_imag_3m_2[6]),
        .Xout_imag7(Xout_imag_3m_2[7])
    );


    // ===== write to output map ===== //
    integer i;
    always @(posedge clk) begin
        if (state == COMPUTE_DATA) begin
            if (data_period == 6'd7) begin
                for (i = 0; i<8; i=i+1) begin
                    output_real_map[i] <= Xout_real_3m_0[i];
                    output_real_map[i+8] <= Xout_real_3m_1[i];
                    output_real_map[i+16] <= Xout_real_3m_2[i];
                    output_imag_map[i] <= Xout_imag_3m_0[i];
                    output_imag_map[i+8] <= Xout_imag_3m_1[i];
                    output_imag_map[i+16] <= Xout_imag_3m_2[i];
                end
            end
        end
    end

    // ===== complex_mul 0 ===== //
    wire [31:0] real_part1_l0,imag_part1_l0,real_part1_l1,imag_part1_l1,real_part1_l2,imag_part1_l2;
    wire [31:0] real_part2_l0,imag_part2_l0,real_part2_l1,imag_part2_l1,real_part2_l2,imag_part2_l2;
    wire [64:0] Xout_real_ans0_l0,Xout_real_ans0_l1,Xout_real_ans0_l2;
    wire [64:0] Xout_real_ans1_l0,Xout_real_ans1_l1,Xout_real_ans1_l2;
    wire [64:0] Xout_imag_ans0_l0,Xout_imag_ans0_l1,Xout_imag_ans0_l2;
    wire [64:0] Xout_imag_ans1_l0,Xout_imag_ans1_l1,Xout_imag_ans1_l2;
    reg [4:0] idx_even,idx_odd;

    always @(posedge clk ) begin
        if (~rst_n)
            k <= 5'd0;
        else
            k <= k_next;
    end

    always @(*) begin
        k_next = 5'd0;
        if (data_period >= 5'd8 && data_period <= 22) begin
            k_next = k + 1;
        end
    end

    always @(*) begin
        idx_even = 2*k;
        idx_odd = 2*k+1;
    end
    
    twiddle_factor tf(
    .clk(clk),
    .k(k),
    .real_part1_l0(real_part1_l0),
    .imag_part1_l0(imag_part1_l0),
    .real_part1_l1(real_part1_l1),
    .imag_part1_l1(imag_part1_l1),
    .real_part1_l2(real_part1_l2),
    .imag_part1_l2(imag_part1_l2),
    .real_part2_l0(real_part2_l0),
    .imag_part2_l0(imag_part2_l0),
    .real_part2_l1(real_part2_l1),
    .imag_part2_l1(imag_part2_l1),
    .real_part2_l2(real_part2_l2),
    .imag_part2_l2(imag_part2_l2)
    );

    complex_mul L0_0(
    .clk(clk),
    .xin_real0(output_real_map[idx_even[2:0]]),
    .xin_real1(real_part1_l0),
    .xin_imag0(output_imag_map[idx_even[2:0]]),
    .xin_imag1(imag_part1_l0),

    .Xout_real(Xout_real_ans0_l0),
    .Xout_imag(Xout_imag_ans0_l0)
    );

    complex_mul L0_1(
    .clk(clk),
    .xin_real0(output_real_map[idx_even[2:0] + 8]),
    .xin_real1(real_part1_l1),
    .xin_imag0(output_imag_map[idx_even[2:0] + 8]),
    .xin_imag1(imag_part1_l1),

    .Xout_real(Xout_real_ans0_l1),
    .Xout_imag(Xout_imag_ans0_l1)
    );

    complex_mul L0_2(
    .clk(clk),
    .xin_real0(output_real_map[idx_even[2:0] + 16]),
    .xin_real1(real_part1_l2),
    .xin_imag0(output_imag_map[idx_even[2:0] + 16]),
    .xin_imag1(imag_part1_l2),

    .Xout_real(Xout_real_ans0_l2),
    .Xout_imag(Xout_imag_ans0_l2)
    );

    complex_mul L1_0(
    .clk(clk),
    .xin_real0(output_real_map[idx_odd[2:0]]),
    .xin_real1(real_part2_l0),
    .xin_imag0(output_imag_map[idx_odd[2:0]]),
    .xin_imag1(imag_part2_l0),

    .Xout_real(Xout_real_ans1_l0),
    .Xout_imag(Xout_imag_ans1_l0)
    );

    complex_mul L1_1(
    .clk(clk),
    .xin_real0(output_real_map[idx_odd[2:0] + 8]),
    .xin_real1(real_part2_l1),
    .xin_imag0(output_imag_map[idx_odd[2:0] + 8]),
    .xin_imag1(imag_part2_l1),

    .Xout_real(Xout_real_ans1_l1),
    .Xout_imag(Xout_imag_ans1_l1)
    );

    complex_mul L1_2(
    .clk(clk),
    .xin_real0(output_real_map[idx_odd[2:0] + 16]),
    .xin_real1(real_part2_l2),
    .xin_imag0(output_imag_map[idx_odd[2:0] + 16]),
    .xin_imag1(imag_part2_l2),

    .Xout_real(Xout_real_ans1_l2),
    .Xout_imag(Xout_imag_ans1_l2)
    );

    // ===== 3 sum ===== //
    reg signed [65:0] sum2_real_ans0,sum2_imag_ans0,Xout_real_ans0_l2_n,Xout_imag_ans0_l2_n;
    reg signed [66:0] sum3_real_ans0_next,sum3_imag_ans0_next;
    reg signed [66:0] sum3_real_ans0,sum3_imag_ans0;

    always @(posedge clk ) begin
        Xout_real_ans0_l2_n <= {Xout_real_ans0_l2[64],Xout_real_ans0_l2};
        Xout_imag_ans0_l2_n <= {Xout_imag_ans0_l2[64],Xout_imag_ans0_l2};
    end

    always @(posedge clk ) begin
        sum2_real_ans0 <= Xout_real_ans0_l0 + Xout_real_ans0_l1;
        sum2_imag_ans0 <= Xout_imag_ans0_l0 + Xout_imag_ans0_l1;
        sum3_real_ans0 <= sum3_real_ans0_next;
        sum3_imag_ans0 <= sum3_imag_ans0_next;
    end

    always @(*) begin
        sum3_real_ans0_next = sum2_real_ans0 + Xout_real_ans0_l2_n;
        sum3_imag_ans0_next = sum2_imag_ans0 + Xout_imag_ans0_l2_n;

        sum3_real_ans0_next = sum3_real_ans0_next >>> 23;
        sum3_imag_ans0_next = sum3_imag_ans0_next >>> 23;

        if (sum3_real_ans0_next > 2**31-1) begin
            sum3_real_ans0_next = 2**31-1;
        end
        else if (sum3_real_ans0_next < -2**31) begin
            sum3_real_ans0_next = -2**31;
        end

        if (sum3_imag_ans0_next > 2**31-1) begin
            sum3_imag_ans0_next = 2**31-1;
        end
        else if (sum3_imag_ans0_next < -2**31) begin
            sum3_imag_ans0_next = -2**31;
        end
    end

    reg signed [65:0] sum2_real_ans1,sum2_imag_ans1,Xout_real_ans1_l2_n,Xout_imag_ans1_l2_n;
    reg signed [66:0] sum3_real_ans1_next,sum3_imag_ans1_next;
    reg signed [66:0] sum3_real_ans1,sum3_imag_ans1;

    always @(posedge clk ) begin
        Xout_real_ans1_l2_n <= {Xout_real_ans1_l2[64],Xout_real_ans1_l2};
        Xout_imag_ans1_l2_n <= {Xout_imag_ans1_l2[64],Xout_imag_ans1_l2};
    end

    always @(posedge clk ) begin
        sum2_real_ans1 <= Xout_real_ans1_l0 + Xout_real_ans1_l1;
        sum2_imag_ans1 <= Xout_imag_ans1_l0 + Xout_imag_ans1_l1;
        sum3_real_ans1 <= sum3_real_ans1_next;
        sum3_imag_ans1 <= sum3_imag_ans1_next;
    end

    always @(*) begin
        sum3_real_ans1_next = sum2_real_ans1 + Xout_real_ans1_l2_n;
        sum3_imag_ans1_next = sum2_imag_ans1 + Xout_imag_ans1_l2_n;

        sum3_real_ans1_next = sum3_real_ans1_next >>> 23;
        sum3_imag_ans1_next = sum3_imag_ans1_next >>> 23;

        if (sum3_real_ans1_next > 2**31-1) begin
            sum3_real_ans1_next = 2**31-1;
        end
        else if (sum3_real_ans1_next < -2**31) begin
            sum3_real_ans1_next = -2**31;
        end

        if (sum3_imag_ans1_next > 2**31-1) begin
            sum3_imag_ans1_next = 2**31-1;
        end
        else if (sum3_imag_ans1_next < -2**31) begin
            sum3_imag_ans1_next = -2**31;
        end
    end

    // ===== write back to sram ===== //
    always @(*) begin
        sram_real_wea0 = 4'd0;
        sram_real_wea1 = 4'd0;
        sram_imag_wea0 = 4'd0;
        sram_imag_wea1 = 4'd0;
        if (data_period >= 5'd12) begin
            sram_real_wea0 = 4'b1111;
            sram_real_wea1 = 4'b1111;
            sram_imag_wea0 = 4'b1111;
            sram_imag_wea1 = 4'b1111;
        end
    end

    always @(*) begin
        sram_real_wdata0 = {sum3_real_ans0[66],sum3_real_ans0[0+:31]};
        sram_real_wdata1 = {sum3_real_ans1[66],sum3_real_ans1[0+:31]};
        sram_imag_wdata0 = {sum3_imag_ans0[66],sum3_imag_ans0[0+:31]};
        sram_imag_wdata1 = {sum3_imag_ans1[66],sum3_imag_ans1[0+:31]};
    end

    always @(*) begin
        compute_done = 1'b0;
        if (state == COMPUTE_DATA) begin
            if (cnt_input_num < NUM_INPUT && data_period == 5'd23) begin
                compute_done = 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (~rst_n) begin
            fft_done <= 1'b0;
        end
        if (state == COMPUTE_DATA) begin
            if (cnt_input_num == NUM_INPUT && data_period == 5'd23)
                fft_done <= 1'b1;
        end
    end

endmodule