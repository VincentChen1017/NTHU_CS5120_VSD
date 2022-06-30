module fft_rtl_basic_dma64( clk, rst, dma_read_chnl_valid, dma_read_chnl_data, dma_read_chnl_ready,
/* <<--params-list-->> */
conf_info_size,
conf_done, acc_done, debug, dma_read_ctrl_valid, dma_read_ctrl_data_index, dma_read_ctrl_data_length, dma_read_ctrl_data_size, dma_read_ctrl_ready, dma_write_ctrl_valid, dma_write_ctrl_data_index, dma_write_ctrl_data_length, dma_write_ctrl_data_size, dma_write_ctrl_ready, dma_write_chnl_valid, dma_write_chnl_data, dma_write_chnl_ready);

   input clk;
   input rst;

   /* <<--params-def-->> */
   input [31:0]  conf_info_size;
   input 	 conf_done; // inform FSM to start to receive the signal and do the computation

   input 	 dma_read_ctrl_ready;
   output reg 	 dma_read_ctrl_valid;
   output reg [31:0] dma_read_ctrl_data_index;
   output reg [31:0] dma_read_ctrl_data_length;
   output reg [2:0]  dma_read_ctrl_data_size;

   output reg 	 dma_read_chnl_ready;
   input 	 dma_read_chnl_valid;
   input [63:0]  dma_read_chnl_data;

   input 	 dma_write_ctrl_ready;
   output reg 	 dma_write_ctrl_valid;
   output reg [31:0] dma_write_ctrl_data_index;
   output reg [31:0] dma_write_ctrl_data_length;
   output reg [2:0]  dma_write_ctrl_data_size;

   input 	 dma_write_chnl_ready;
   output reg 	 dma_write_chnl_valid;
   output reg [63:0] dma_write_chnl_data;

   output reg 	 acc_done;
   output reg [31:0] debug;

///////////////////////////////////
// Add your design here
always@* begin
   debug = 32'b0;
end
/********** parameter & variable declare **********/
// FSM
localparam IDLE = 4'd0;
localparam LOAD_REAL_CTRL = 4'd1;
localparam LOAD_REAL = 4'd2;
localparam LOAD_IMAG_CTRL = 4'd3;
localparam LOAD_IMAG = 4'd4;
localparam COMPUTATION = 4'd5;
localparam STORE_CTRL = 4'd6;
localparam STORE = 4'd7;
localparam DONE = 4'd8;
reg [4-1:0] state, next_state;
reg real_store_done;
// For DMA
reg dma_write_chnl_valid_next;
// For real BRAM
reg [15:0] sram_real_addr0_dma;
reg [15:0] sram_real_addr1_dma;
reg [3:0] real_wea0_dma;
reg [3:0] real_wea1_dma;
wire [15:0] sram_real_addr0_fft;
wire [15:0] sram_real_addr1_fft;
wire [3:0] real_wea0_fft;
wire [3:0] real_wea1_fft;
reg [15:0] sram_real_addr0;
reg [15:0] sram_real_addr1;
reg [3:0] real_wea0;
reg [3:0] real_wea1;
reg [31:0] real_wdata0;
reg [31:0] real_wdata1;
wire [31:0] real_rdata0;
wire [31:0] real_rdata1;
// For imag BRAM
wire [15:0] sram_imag_addr0_fft;
wire [15:0] sram_imag_addr1_fft;
wire [3:0] imag_wea0_fft;
wire [3:0] imag_wea1_fft;
reg [15:0] sram_imag_addr0_dma;
reg [15:0] sram_imag_addr1_dma;
reg [3:0] imag_wea0_dma;
reg [3:0] imag_wea1_dma;
reg [15:0] sram_imag_addr0;
reg [15:0] sram_imag_addr1;
reg [3:0] imag_wea0;
reg [3:0] imag_wea1;
reg [31:0] imag_wdata0;
reg [31:0] imag_wdata1;
wire [31:0] imag_rdata0; 
wire [31:0] imag_rdata1;
// fft_engine in/out
wire compute_finish;
reg compute_start;
wire [31:0] fft_imag_wdata0; 
wire [31:0] fft_imag_wdata1;
wire [31:0] fft_real_wdata0; 
wire [31:0] fft_real_wdata1;

/***************************************************/
/****************** other module *******************/
fft fft_engine(
   .clk(clk),
   .rst_n(rst),
    
  .compute_start(compute_start),
   .compute_finish(compute_finish),

   // Real part sram, dual port
   .sram_real_wea0(real_wea0_fft),
   .sram_real_addr0(sram_real_addr0_fft),
   .sram_real_wdata0(fft_real_wdata0),
   .sram_real_rdata0(real_rdata0),
   .sram_real_wea1(real_wea1_fft),
   .sram_real_addr1(sram_real_addr1_fft),
   .sram_real_wdata1(fft_real_wdata1),
   .sram_real_rdata1(real_rdata1),

   // imag part sram, dual port
   .sram_imag_wea0(imag_wea0_fft),
   .sram_imag_addr0(sram_imag_addr0_fft),
   .sram_imag_wdata0(fft_imag_wdata0),
   .sram_imag_rdata0(imag_rdata0),
   .sram_imag_wea1(imag_wea1_fft),
   .sram_imag_addr1(sram_imag_addr1_fft),
   .sram_imag_wdata1(fft_imag_wdata1),
   .sram_imag_rdata1(imag_rdata1)
);

SRAM_real_480x32b sram_real( 
   .clk(clk),  
   .wea0(real_wea0),
   .addr0(sram_real_addr0),
   .wdata0(real_wdata0),
   .rdata0(real_rdata0),
   .wea1(real_wea1),
   .addr1(sram_real_addr1),
   .wdata1(real_wdata1),
   .rdata1(real_rdata1)
);

SRAM_imag_480x32b sram_imag( 
   .clk(clk),  
   .wea0(imag_wea0),
   .addr0(sram_imag_addr0),
   .wdata0(imag_wdata0),
   .rdata0(imag_rdata0),
   .wea1(imag_wea1),
   .addr1(sram_imag_addr1),
   .wdata1(imag_wdata1),
   .rdata1(imag_rdata1)
);

/***************************************************/
/***** FSM *****/ 
/***** FSM *****/ 
always@* begin
   acc_done = 0;
   // for dma read control
   dma_read_ctrl_data_index = 0;
   dma_read_ctrl_data_length= 0;
   dma_read_ctrl_data_size = 0;
   dma_read_ctrl_valid = 0;
   // for dma write control
   dma_write_ctrl_data_index = 0;
   dma_write_ctrl_data_length = 0;
   dma_write_ctrl_data_size = 0;
   dma_write_ctrl_valid = 0;
   // for dma read channel
   dma_read_chnl_ready = 0;
   // for dma write channel
   dma_write_chnl_valid_next = 0;     
   // for real sram
   real_wea0_dma = 4'b0000;
   real_wea1_dma = 4'b0000;
   // for imag sram
   imag_wea0_dma = 4'b0000;
   imag_wea1_dma = 4'b0000;
   // for fft engine
   compute_start = 0;
   // for store address
   real_store_done = 0;

   next_state = state;
   case(state)
      IDLE: begin
         if(conf_done) begin
            next_state = LOAD_REAL_CTRL;
         end
         else begin
            next_state = state;
         end
      end

      LOAD_REAL_CTRL: begin
         dma_read_ctrl_data_index= 0;
         dma_read_ctrl_data_length = 120;
         dma_read_ctrl_data_size= 3'b010;
         dma_read_ctrl_valid = 1;
         if(dma_read_ctrl_ready) begin
            next_state = LOAD_REAL;
         end
         else begin
            next_state = state;
         end
      end

      LOAD_REAL: begin
         dma_read_chnl_ready = 1;  // for read, the signal can always to be high 
         real_wea0_dma = 4'b1111;
         real_wea1_dma = 4'b1111;
         if(sram_real_addr0_dma == 240) begin  // change from 238 to 240 means real sram is loading ready.
            next_state = LOAD_IMAG_CTRL;
         end
         else begin
            next_state = state;
         end
      end

      LOAD_IMAG_CTRL: begin
         dma_read_ctrl_data_index= 120;
         dma_read_ctrl_data_length = 120;
         dma_read_ctrl_data_size= 3'b010;
         dma_read_ctrl_valid = 1;
         if(dma_read_ctrl_ready) begin
            next_state = LOAD_IMAG;
         end
         else begin
            next_state = state;
         end
      end

      LOAD_IMAG: begin
         imag_wea0_dma = 4'b1111;
         imag_wea1_dma = 4'b1111;
         dma_read_chnl_ready = 1;  // for read, the signal can always to be high 
         if(sram_imag_addr0_dma == 240) begin  // change from 238 to 240 means imag sram is loading ready.
            next_state = COMPUTATION;
         end
         else begin
            next_state = state;
         end
      end
      
      COMPUTATION: begin
         compute_start = 1;
         if(compute_finish) begin
            next_state = STORE_CTRL;
         end
         else begin
            next_state = state;
         end
      end

      STORE_CTRL: begin
         dma_write_ctrl_data_index= 240;
         dma_write_ctrl_data_length = 240;
         dma_write_ctrl_data_size= 3'b010;
         dma_write_ctrl_valid = 1;
         if(dma_write_ctrl_ready) begin
            next_state =  STORE;
         end
         else begin
            next_state = state;
         end
      end

      STORE: begin
         // hand shaking
         if(dma_write_chnl_valid==1 && dma_write_chnl_ready==1) begin
            dma_write_chnl_valid_next = 0;
         end
         else begin
            dma_write_chnl_valid_next = 1;
         end

         if(sram_real_addr0_dma == 480) begin
            real_store_done = 1;
         end
         else begin
            real_store_done = 0;   
         end

         if(sram_imag_addr0_dma == 480) begin
            next_state = DONE;
         end
         else begin
            next_state = state;
         end
      end

      DONE: begin
         acc_done = 1;
         next_state = IDLE;
      end
   endcase
end

always@(posedge clk) begin
   if(~rst) begin
      state <= IDLE;
      dma_write_chnl_valid <= 0;
   end
   else begin
      state <= next_state;
      dma_write_chnl_valid <= dma_write_chnl_valid_next;
   end
end   
/********************************************/
/********** address process **********/
// for DMA load/store real/imag
always@(posedge clk) begin
   if(~rst) begin
      sram_real_addr0_dma <= 0;
      sram_real_addr1_dma <= 1;
      sram_imag_addr0_dma <= 0;
      sram_imag_addr1_dma <= 1;
   end
   else if(state == LOAD_REAL) begin
      if(dma_read_chnl_valid==1 && dma_read_chnl_ready==1) begin
         sram_real_addr0_dma <= sram_real_addr0_dma + 2;
         sram_real_addr1_dma <= sram_real_addr1_dma + 2;
      end
   end
   else if(state == LOAD_IMAG) begin
      if(dma_read_chnl_valid==1 && dma_read_chnl_ready==1) begin
         sram_imag_addr0_dma <= sram_imag_addr0_dma + 2;
         sram_imag_addr1_dma <= sram_imag_addr1_dma + 2;
      end
   end
   else if(state == STORE) begin
      if(dma_write_chnl_valid==1 && dma_write_chnl_ready==1) begin
         if(~real_store_done) begin
            sram_real_addr0_dma <= sram_real_addr0_dma + 2;
            sram_real_addr1_dma <= sram_real_addr1_dma + 2;
         end
         else begin
            sram_imag_addr0_dma <= sram_imag_addr0_dma + 2;
            sram_imag_addr1_dma <= sram_imag_addr1_dma + 2;
         end
      end
   end
end

always@* begin
   if(state == COMPUTATION) begin
      real_wea0 = real_wea0_fft;
      real_wea1 = real_wea1_fft;
      sram_real_addr0 = sram_real_addr0_fft;
      sram_real_addr1 = sram_real_addr1_fft;

      imag_wea0 = imag_wea0_fft;
      imag_wea1 = imag_wea1_fft;
      sram_imag_addr0 = sram_imag_addr0_fft;
      sram_imag_addr1 = sram_imag_addr1_fft;
   end      
   else begin
      real_wea0 = real_wea0_dma;
      real_wea1 = real_wea1_dma;
      sram_real_addr0 = sram_real_addr0_dma;
      sram_real_addr1 = sram_real_addr1_dma;

      imag_wea0 = imag_wea0_dma;
      imag_wea1 = imag_wea1_dma;
      sram_imag_addr0 = sram_imag_addr0_dma;
      sram_imag_addr1 = sram_imag_addr1_dma;     
   end
end
/********************************************/
/********** data process **********/
always@* begin
   if(~real_store_done)
      dma_write_chnl_data = {real_rdata1, real_rdata0};
   else
      dma_write_chnl_data = {imag_rdata1, imag_rdata0};
   if(state == COMPUTATION) begin
      real_wdata0 = fft_real_wdata0;
      real_wdata1 = fft_real_wdata1;
      imag_wdata0 = fft_imag_wdata0;
      imag_wdata1 = fft_imag_wdata1;
   end
   else begin
      real_wdata0 = dma_read_chnl_data[31:0];
      real_wdata1 = dma_read_chnl_data[63:32];
      imag_wdata0 = dma_read_chnl_data[31:0];
      imag_wdata1 = dma_read_chnl_data[63:32];
   end
end
/********************************************/

endmodule

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
    wire signed [31:0] real_part1_l0,imag_part1_l0,real_part1_l1,imag_part1_l1,real_part1_l2,imag_part1_l2;
    wire signed [31:0] real_part2_l0,imag_part2_l0,real_part2_l1,imag_part2_l1,real_part2_l2,imag_part2_l2;
    wire signed [64:0] Xout_real_ans0_l0,Xout_real_ans0_l1,Xout_real_ans0_l2;
    wire signed [64:0] Xout_real_ans1_l0,Xout_real_ans1_l1,Xout_real_ans1_l2;
    wire signed [64:0] Xout_imag_ans0_l0,Xout_imag_ans0_l1,Xout_imag_ans0_l2;
    wire signed [64:0] Xout_imag_ans1_l0,Xout_imag_ans1_l1,Xout_imag_ans1_l2;
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
    
    twiddle_fimagor tf(
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
        sum3_real_ans0_next = (sum3_real_ans0_next + 2**22) >>> 23;
        sum3_imag_ans0_next = (sum3_imag_ans0_next + 2**22) >>> 23;

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

        sum3_real_ans1_next = (sum3_real_ans1_next + 2**22) >>> 23;
        sum3_imag_ans1_next = (sum3_imag_ans1_next + 2**22) >>> 23;
        
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
        sram_real_wdata0 = sum3_real_ans0[0+:32];
        sram_real_wdata1 = sum3_real_ans1[0+:32];
        sram_imag_wdata0 = sum3_imag_ans0[0+:32];
        sram_imag_wdata1 = sum3_imag_ans1[0+:32];
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
    wire signed [64:0] xin_real5_FF2,xin_real6_FF2,xin_real7_FF2;
    reg signed [64:0] Xout_real0_next,Xout_real1_next,Xout_real2_next,Xout_real3_next,Xout_real4_next,Xout_real5_next,Xout_real6_next,Xout_real7_next;
    wire signed [64:0] xin_imag5_FF2,xin_imag6_FF2,xin_imag7_FF2;

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

        Xout_real0_next = (Xout_real0_next + 2**22)  >>> 23;
        Xout_real1_next = (Xout_real1_next + 2**22) >>> 23;
        Xout_real2_next = (Xout_real2_next + 2**22) >>> 23;
        Xout_real3_next = (Xout_real3_next + 2**22) >>> 23;

        Xout_real4_next = (Xout_real4_next + 2**22) >>> 23;
        Xout_real5_next = (Xout_real5_next + 2**22) >>> 23;
        Xout_real6_next = (Xout_real6_next + 2**22) >>> 23;
        Xout_real7_next = (Xout_real7_next + 2**22) >>> 23;

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

        Xout_imag0_next = (Xout_imag0_next + 2**22) >>> 23;
        Xout_imag1_next = (Xout_imag1_next + 2**22) >>> 23;
        Xout_imag2_next = (Xout_imag2_next + 2**22) >>> 23;
        Xout_imag3_next = (Xout_imag3_next + 2**22) >>> 23;

        Xout_imag4_next = (Xout_imag4_next + 2**22) >>> 23;
        Xout_imag5_next = (Xout_imag5_next + 2**22) >>> 23;
        Xout_imag6_next = (Xout_imag6_next + 2**22) >>> 23;
        Xout_imag7_next = (Xout_imag7_next + 2**22) >>> 23;

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

module com_4pt (
    input wire clk,
    
    input wire signed [31:0] twiddle2_8_real,
    input wire signed [31:0] twiddle2_8_imag,

    input wire signed [31:0] xin_real0,
    input wire signed [31:0] xin_real1,
    input wire signed [31:0] xin_real2,
    input wire signed [31:0] xin_real3,
    input wire signed [31:0] xin_imag0,
    input wire signed [31:0] xin_imag1,
    input wire signed [31:0] xin_imag2,
    input wire signed [31:0] xin_imag3,

    output reg [31:0] Xout_real0,
    output reg [31:0] Xout_real1,
    output reg [31:0] Xout_real2,
    output reg [31:0] Xout_real3,
    output reg [31:0] Xout_imag0,
    output reg [31:0] Xout_imag1,
    output reg [31:0] Xout_imag2,
    output reg [31:0] Xout_imag3
);
    // ===== real part ===== //
    reg signed [31:0] xin_real0_FF,xin_real1_FF,xin_real2_FF;
    reg signed [64:0] xin_real0_FF2,xin_real1_FF2,xin_real2_FF2;
    reg signed [64:0] Xout_real0_next,Xout_real1_next,Xout_real2_next,Xout_real3_next;
    wire signed [64:0] xin_real3_FF2;
    wire signed [64:0] xin_imag3_FF2;

    always @(posedge clk) begin
        xin_real0_FF <= xin_real0;
        xin_real1_FF <= xin_real1;
        xin_real2_FF <= xin_real2;
    end

    always @(posedge clk) begin
        xin_real0_FF2 <= xin_real0_FF <<< 23;
        xin_real1_FF2 <= xin_real1_FF <<< 23;
        xin_real2_FF2 <= xin_real2_FF <<< 23;
    end

    complex_mul m0(
    .clk(clk),
    .xin_real0(xin_real3),
    .xin_real1(twiddle2_8_real),
    .xin_imag0(xin_imag3),
    .xin_imag1(twiddle2_8_imag),
    .Xout_real(xin_real3_FF2),
    .Xout_imag(xin_imag3_FF2)
    );

    always @(posedge clk) begin
        Xout_real0 <= Xout_real0_next[0+:32];
        Xout_real1 <= Xout_real1_next[0+:32];
        Xout_real2 <= Xout_real2_next[0+:32];
        Xout_real3 <= Xout_real3_next[0+:32];
    end

    always @(*) begin
        Xout_real0_next = xin_real0_FF2 + xin_real2_FF2;
        Xout_real1_next = xin_real1_FF2 + xin_real3_FF2;
        Xout_real2_next = xin_real0_FF2 - xin_real2_FF2;
        Xout_real3_next = xin_real1_FF2 - xin_real3_FF2;

        Xout_real0_next = Xout_real0_next >>> 23;
        Xout_real1_next = Xout_real1_next >>> 23;
        Xout_real2_next = Xout_real2_next >>> 23;
        Xout_real3_next = Xout_real3_next >>> 23;

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
        
    end

    // ===== imag part ===== //
    reg signed [31:0] xin_imag0_FF,xin_imag1_FF,xin_imag2_FF;
    reg signed [64:0] xin_imag0_FF2,xin_imag1_FF2,xin_imag2_FF2;
    reg signed [64:0] Xout_imag0_next,Xout_imag1_next,Xout_imag2_next,Xout_imag3_next;

    always @(posedge clk) begin
        xin_imag0_FF <= xin_imag0;
        xin_imag1_FF <= xin_imag1;
        xin_imag2_FF <= xin_imag2;
    end

    always @(posedge clk) begin
        xin_imag0_FF2 <= xin_imag0_FF <<< 23;
        xin_imag1_FF2 <= xin_imag1_FF <<< 23;
        xin_imag2_FF2 <= xin_imag2_FF <<< 23;
    end

    always @(posedge clk) begin
        Xout_imag0 <= Xout_imag0_next[0+:32];
        Xout_imag1 <= Xout_imag1_next[0+:32];
        Xout_imag2 <= Xout_imag2_next[0+:32];
        Xout_imag3 <= Xout_imag3_next[0+:32];
    end

    always @(*) begin
        Xout_imag0_next = xin_imag0_FF2 + xin_imag2_FF2;
        Xout_imag1_next = xin_imag1_FF2 + xin_imag3_FF2;
        Xout_imag2_next = xin_imag0_FF2 - xin_imag2_FF2;
        Xout_imag3_next = xin_imag1_FF2 - xin_imag3_FF2;

        Xout_imag0_next = Xout_imag0_next >>> 23;
        Xout_imag1_next = Xout_imag1_next >>> 23;
        Xout_imag2_next = Xout_imag2_next >>> 23;
        Xout_imag3_next = Xout_imag3_next >>> 23;

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
    end

    
endmodule

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

module complex_mul (
    input wire clk,
    input wire signed [31:0] xin_real0,
    input wire signed [31:0] xin_real1,
    input wire signed [31:0] xin_imag0,
    input wire signed [31:0] xin_imag1,

    output reg [64:0] Xout_real,
    output reg [64:0] Xout_imag
);

    // ===== real part ==== //
    reg signed [64:0] real_mul0,real_mul1;
    reg signed [64:0] real_mul0_next,real_mul1_next;

    always @(posedge clk) begin
        real_mul0 <= real_mul0_next;
        real_mul1 <= real_mul1_next;
    end

    always @(*) begin
        real_mul0_next = xin_real0 * xin_real1;
        real_mul1_next = xin_imag0 * xin_imag1;
    end

    reg signed [64:0] Xout_real_next;
    always @(posedge clk) begin
        Xout_real <= Xout_real_next;
    end

    always @(*) begin
        Xout_real_next = real_mul0 - real_mul1;
    end

    // ===== imag part ===== //
    reg signed [64:0] imag_mul0,imag_mul1;
    reg signed [64:0] imag_mul0_next,imag_mul1_next;

    always @(posedge clk) begin
        imag_mul0 <= imag_mul0_next;
        imag_mul1 <= imag_mul1_next;
    end

    always @(*) begin
        imag_mul0_next = xin_real0 * xin_imag1;
        imag_mul1_next = xin_real1 * xin_imag0;
    end

    reg signed [64:0] Xout_imag_next;
    always @(posedge clk) begin
        Xout_imag <= Xout_imag_next;
    end

    always @(*) begin
        Xout_imag_next = imag_mul0 + imag_mul1;
    end
    
endmodule

module twiddle_fimagor(
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
                // 0 1 2
                real_part2_l0 = 32'h00800000;
                imag_part2_l0 = 32'h00000000;
                real_part2_l1 = 32'h007BA375;
                imag_part2_l1 = 32'hFFDEDF04;
                real_part2_l2 = 32'h006ED9EC;
                imag_part2_l2 = 32'hFFC00000;

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
