`timescale 1ns/1ps
`define CYCLE 10
`define END_CYCLES 50000
module tb_fft();

    

    // ===== System Signals =====
    reg clk;
    integer i, cycle_count;
    reg start_count;


    // ===== SRAM Signals =====
    wire [ 3:0] sram_real_wea0;
    wire [15:0] sram_real_addr0;
    wire [31:0] sram_real_wdata0;
    wire [31:0] sram_real_rdata0;
    wire [ 3:0] sram_real_wea1;
    wire [15:0] sram_real_addr1;
    wire [31:0] sram_real_wdata1;
    wire [31:0] sram_real_rdata1;
    
    wire [ 3:0] sram_imag_wea0;
    wire [15:0] sram_imag_addr0;
    wire [31:0] sram_imag_wdata0;
    wire [31:0] sram_imag_rdata0;
    wire [ 3:0] sram_imag_wea1;
    wire [15:0] sram_imag_addr1;
    wire [31:0] sram_imag_wdata1;
    wire [31:0] sram_imag_rdata1;

    // ===== Golden =====
    reg [31:0] real_golden [0:479];
    reg [31:0] imag_golden [0:479];

    // ===== Lenet Signals =====
    reg rst_n;
    reg compute_start;
    wire compute_finish;

    // ===== Module instantiation =====
    fft fft_inst(
        .clk(clk),
        .rst_n(rst_n),
        
        .compute_start(compute_start),
        .compute_finish(compute_finish),

        // Real part sram(), dual port
        .sram_real_wea0(sram_real_wea0),
        .sram_real_addr0(sram_real_addr0),
        .sram_real_wdata0(sram_real_wdata0),
        .sram_real_rdata0(sram_real_rdata0),
        .sram_real_wea1(sram_real_wea1),
        .sram_real_addr1(sram_real_addr1),
        .sram_real_wdata1(sram_real_wdata1),
        .sram_real_rdata1(sram_real_rdata1),

        // imag part sram(), dual port
        .sram_imag_wea0(sram_imag_wea0),
        .sram_imag_addr0(sram_imag_addr0),
        .sram_imag_wdata0(sram_imag_wdata0),
        .sram_imag_rdata0(sram_imag_rdata0),
        .sram_imag_wea1(sram_imag_wea1),
        .sram_imag_addr1(sram_imag_addr1),
        .sram_imag_wdata1(sram_imag_wdata1),
        .sram_imag_rdata1(sram_imag_rdata1)
    );

    SRAM_real_480x32b real_sram( 
        .clk(clk),
        .wea0(sram_real_wea0),
        .addr0(sram_real_addr0),
        .wdata0(sram_real_wdata0),
        .rdata0(sram_real_rdata0),
        .wea1(sram_real_wea1),
        .addr1(sram_real_addr1),
        .wdata1(sram_real_wdata1),
        .rdata1(sram_real_rdata1)
    );
    
    SRAM_imag_480x32b imag_sram( 
        .clk(clk),
        .wea0(sram_imag_wea0),
        .addr0(sram_imag_addr0),
        .wdata0(sram_imag_wdata0),
        .rdata0(sram_imag_rdata0),
        .wea1(sram_imag_wea1),
        .addr1(sram_imag_addr1),
        .wdata1(sram_imag_wdata1),
        .rdata1(sram_imag_rdata1)
    );



    // ===== Load data ===== //
    initial begin
        real_sram.load_data("../pattern/input/real.txt");
        imag_sram.load_data("../pattern//input/imag.txt");
        $readmemh("../pattern/golden/real_golden.txt", real_golden);
        $readmemh("../pattern/golden/imag_golden.txt", imag_golden);
    end


    // ===== System reset ===== //
    initial begin
        clk = 0;
        rst_n = 1;
        compute_start = 0;
        cycle_count = 0;
    end
    
    // ===== Cycle count ===== //
    initial begin
        wait(compute_start == 1);
        start_count = 1;
        wait(compute_finish == 1);
        start_count = 0;
    end

    always @(posedge clk) begin
        if(start_count)
            cycle_count <= cycle_count + 1;
    end 
   
    // ===== Time Exceed Abortion ===== //
    initial begin
        #(`CYCLE*`END_CYCLES);
        $display("\n========================================================");
        $display("You have exceeded the cycle count limit.");
        $display("Simulation abort");
        $display("========================================================");
        $finish;    
    end

    // ===== Clk fliping ===== //
    always #(`CYCLE/2) begin
        clk = ~clk;
    end 

    // ===== Set simulation info ===== //
    initial begin
    `ifdef GATESIM
        $dumpfile("fft_syn.vcd");
        $dumpvars("+all");
        $sdf_annotate("../syn/netlist/fft_syn.sdf", fft_inst);
	`else
        `ifdef POSTSIM
            $dumpfile("fft_post.vcd");
            $dumpvars("+all");
            $sdf_annotate("../apr/netlist/CHIP.sdf", fft_inst);
        `else
            $fsdbDumpfile("fft.fsdb");
            $fsdbDumpvars("+all");
        `endif
    `endif
    end
        

    // ===== Simulating  ===== //
    initial begin
        #(`CYCLE*100);
        $display("Reset System");
        @(negedge clk);
        rst_n = 1'b0;
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        $display("Compute start");
        @(negedge clk);
        compute_start = 1'b1;
        @(negedge clk);
        compute_start = 1'b0;

        wait(compute_finish == 1);
        $display("Compute finished, start validating result...");

        validate();

        $display("Simulation finish");
        $finish;
    end

    integer errors, total_errors;
    task validate; begin
        // Input Image
        
        total_errors = 0;
        $display("=====================");

        errors = 0;
        for(i=0 ; i<240 ; i=i+1)
            if(real_golden[i] !== real_sram.RAM[i] || imag_golden[i] !== imag_sram.RAM[i]) begin
                $display("[ERROR] FFT Result[%d]:%8h + j%8h Golden:%8h + j%8h", i, real_sram.RAM[i], imag_sram.RAM[i], real_golden[i], imag_golden[i]);
                errors = errors + 1;
            end
            else begin
                //$display("[CORRECT]   [%d] Image Result:%8h Golden:%8h", i, act_sram.RAM[i], golden[i]);
            end
        if(errors == 0)
            $display("input             [PASS]");
        else
            $display("input             [FAIL]");
        total_errors = total_errors + errors;
            
        errors = 0;
        for(i=240 ; i<480 ; i=i+1)
            if(real_golden[i] !== real_sram.RAM[i] || imag_golden[i] !== imag_sram.RAM[i]) begin
                $display("[ERROR] FFT Result[%d]:%8h + j%8h Golden:%8h + j%8h", i, real_sram.RAM[i], imag_sram.RAM[i], real_golden[i], imag_golden[i]);
                errors = errors + 1;
            end
            else begin
                //$display("[CORRECT]   [%d] Conv1 Result:%8h Golden:%8h", i-256, act_sram.RAM[i], golden[i]);
            end
        if(errors == 0)
            $display("Xout [PASS]");
        else
            $display("Xout [FAIL]");
        total_errors = total_errors + errors;
        
        if(total_errors == 0)
            $display(">>> Congratulation! All result are correct");
        else
            $display(">>> There are %d errors QQ", total_errors);
            
    `ifdef GATESIM
        $display("  [Pre-layout gate-level simulation]");
	`else
        `ifdef POSTSIM
            $display("  [Post-layout gate-level simulation]");
        `else
            $display("  [RTL simulation]");
        `endif
    `endif
        $display("Clock Period: %.2f ns,Total cycle count: %d cycles", `CYCLE, cycle_count);
        $display("=====================");
    end
    endtask



endmodule
