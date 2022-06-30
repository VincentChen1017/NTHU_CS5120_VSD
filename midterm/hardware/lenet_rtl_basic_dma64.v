module lenet_rtl_basic_dma64( clk, rst, dma_read_chnl_valid, dma_read_chnl_data, dma_read_chnl_ready,
/* <<--params-list-->> */
conf_info_scale_CONV2,
conf_info_scale_CONV3,
conf_info_scale_CONV1,
conf_info_scale_FC2,
conf_info_scale_FC1,
conf_done, acc_done, debug, dma_read_ctrl_valid, dma_read_ctrl_data_index, dma_read_ctrl_data_length, dma_read_ctrl_data_size, dma_read_ctrl_ready, dma_write_ctrl_valid, dma_write_ctrl_data_index, dma_write_ctrl_data_length, dma_write_ctrl_data_size, dma_write_ctrl_ready, dma_write_chnl_valid, dma_write_chnl_data, dma_write_chnl_ready);

input clk;
input rst;

/* <<--params-def-->> */
input wire [31:0]  conf_info_scale_CONV2;
input wire [31:0]  conf_info_scale_CONV3;
input wire [31:0]  conf_info_scale_CONV1;
input wire [31:0]  conf_info_scale_FC2;
input wire [31:0]  conf_info_scale_FC1;
input wire 	       conf_done;  // inform FSM to start to receive the signal and do the computation

input wire 	       dma_read_ctrl_ready;
output reg	       dma_read_ctrl_valid;
output reg [31:0]  dma_read_ctrl_data_index;
output reg [31:0]  dma_read_ctrl_data_length;
output reg [ 2:0]  dma_read_ctrl_data_size;

output reg	       dma_read_chnl_ready;
input wire 	       dma_read_chnl_valid;
input wire [63:0]  dma_read_chnl_data;

input wire         dma_write_ctrl_ready;
output reg	       dma_write_ctrl_valid;
output reg [31:0]  dma_write_ctrl_data_index;
output reg [31:0]  dma_write_ctrl_data_length;
output reg [ 2:0]  dma_write_ctrl_data_size;

input wire 	       dma_write_chnl_ready;
output reg	       dma_write_chnl_valid;
output reg [63:0]  dma_write_chnl_data;

output reg     	 acc_done;
output reg [31:0]  debug;

///////////////////////////////////
// Add your design here
always@* begin
   debug = 32'b0;
end
/********** parameter & variable declare **********/
// FSM
localparam IDLE = 4'd0;
localparam LOAD_WEIGHT_CTRL = 4'd1;
localparam LOAD_WEIGHT = 4'd2;
localparam LOAD_IFM_CTRL = 4'd3;
localparam LOAD_IFM = 4'd4;
localparam COMPUTATION = 4'd5;
localparam STORE_ACT_CTRL = 4'd6;
localparam STORE_ACT = 4'd7;
localparam DONE = 4'd8;
reg [4-1:0] state, next_state;
// For DMA
reg dma_write_chnl_valid_next;
// For Weight BRAM
reg [15:0] sram_weight_addr0_dma;
reg [15:0] sram_weight_addr1_dma;
reg [3:0] weight_wea0_dma;
reg [3:0] weight_wea1_dma;
wire [15:0] sram_weight_addr0_lenet;
wire [15:0] sram_weight_addr1_lenet;
wire [3:0] weight_wea0_lenet;
wire [3:0] weight_wea1_lenet;
reg [15:0] sram_weight_addr0;
reg [15:0] sram_weight_addr1;
reg [3:0] weight_wea0;
reg [3:0] weight_wea1;
reg [31:0] weight_wdata0;
reg [31:0] weight_wdata1;
wire [31:0] weight_rdata0;
wire [31:0] weight_rdata1;
// For Activation BRAM
wire [15:0] sram_act_addr0_lenet;
wire [15:0] sram_act_addr1_lenet;
wire [3:0] act_wea0_lenet;
wire [3:0] act_wea1_lenet;
reg [15:0] sram_act_addr0_dma;
reg [15:0] sram_act_addr1_dma;
reg [3:0] act_wea0_dma;
reg [3:0] act_wea1_dma;
reg [15:0] sram_act_addr0;
reg [15:0] sram_act_addr1;
reg [3:0] act_wea0;
reg [3:0] act_wea1;
reg [31:0] act_wdata0;
reg [31:0] act_wdata1;
wire [31:0] act_rdata0; 
wire [31:0] act_rdata1;
// lenet_engine in/out
wire compute_finish;
reg compute_start;
wire [31:0] lenet_act_wdata0; 
wire [31:0] lenet_act_wdata1;
wire [31:0] lenet_weight_wdata0; 
wire [31:0] lenet_weight_wdata1;


/***************************************************/
/****************** other module *******************/
SRAM_weight_16384x32b sram_weight( 
   .clk(clk),
   .wea0(weight_wea0), // wea control from outside.
   .addr0(sram_weight_addr0),
   .wdata0(weight_wdata0), // write into sram
   .rdata0(weight_rdata0), // read from sram
   .wea1(weight_wea1),
   .addr1(sram_weight_addr1),
   .wdata1(weight_wdata1),
   .rdata1(weight_rdata1)
);
SRAM_activation_1024x32b sram_act( 
   .clk(clk),  
   .wea0(act_wea0),
   .addr0(sram_act_addr0),
   .wdata0(act_wdata0),
   .rdata0(act_rdata0),
   .wea1(act_wea1),
   .addr1(sram_act_addr1),
   .wdata1(act_wdata1),
   .rdata1(act_rdata1)
);
lenet lenet_engine 
(
   .clk(clk),
   .rst_n(rst),

   .compute_start(compute_start),
   .compute_finish(compute_finish),

   // Quantization scale
   .scale_CONV1(conf_info_scale_CONV1),
   .scale_CONV2(conf_info_scale_CONV2),
   .scale_CONV3(conf_info_scale_CONV3),
   .scale_FC1(conf_info_scale_FC1),
   .scale_FC2(conf_info_scale_FC2),

   // Weight sram, dual port
   .sram_weight_wea0(weight_wea0_lenet),
   .sram_weight_addr0(sram_weight_addr0_lenet),
   .sram_weight_wdata0(lenet_weight_wdata0),
   .sram_weight_rdata0(weight_rdata0),
   .sram_weight_wea1(weight_wea1_lenet),
   .sram_weight_addr1(sram_weight_addr1_lenet),
   .sram_weight_wdata1(lenet_weight_wdata1),
   .sram_weight_rdata1(weight_rdata1),

    // Activation sram, dual port
   .sram_act_wea0(act_wea0_lenet),
   .sram_act_addr0(sram_act_addr0_lenet),
   .sram_act_wdata0(lenet_act_wdata0),
   .sram_act_rdata0(act_rdata0),
   .sram_act_wea1(act_wea1_lenet),
   .sram_act_addr1(sram_act_addr1_lenet),
   .sram_act_wdata1(lenet_act_wdata1),
   .sram_act_rdata1(act_rdata1)
);
/**************************************************/
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
   // for weight sram
   weight_wea0_dma = 4'b0000;
   weight_wea1_dma = 4'b0000;
   // for act sram
   act_wea0_dma = 4'b0000;
   act_wea1_dma = 4'b0000;
   // for lenet engine
   compute_start = 0;
   next_state = state;
   case(state)
      IDLE: begin
         if(conf_done) begin
            next_state = LOAD_WEIGHT_CTRL;
         end
         else begin
            next_state = state;
         end
      end

      LOAD_WEIGHT_CTRL: begin
         dma_read_ctrl_data_index= 0;
         dma_read_ctrl_data_length = 7880;
         dma_read_ctrl_data_size= 3'b010;
         dma_read_ctrl_valid = 1;
         if(dma_read_ctrl_ready) begin
            next_state = LOAD_WEIGHT;
         end
         else begin
            next_state = state;
         end
      end

      LOAD_WEIGHT: begin
         dma_read_chnl_ready = 1;  // for read, the signal can always to be high 
         weight_wea0_dma = 4'b1111;
         weight_wea1_dma = 4'b1111;
         if(sram_weight_addr0_dma == 15760) begin  // change from 15758 to 15760 means weight sram is loading ready.
            next_state = LOAD_IFM_CTRL;
         end
         else begin
            next_state = state;
         end
      end

      LOAD_IFM_CTRL: begin
         dma_read_ctrl_data_index= 10000;
         dma_read_ctrl_data_length = 128;
         dma_read_ctrl_data_size= 3'b010;
         dma_read_ctrl_valid = 1;
         if(dma_read_ctrl_ready) begin
            next_state = LOAD_IFM;
         end
         else begin
            next_state = state;
         end
      end

      LOAD_IFM: begin
         act_wea0_dma = 4'b1111;
         act_wea1_dma = 4'b1111;
         dma_read_chnl_ready = 1;  // for read, the signal can always to be high 
         if(sram_act_addr0_dma == 256) begin  // change from 255 to 256 means act sram is loading ready.
            next_state = COMPUTATION;
         end
         else begin
            next_state = state;
         end
      end
      
      COMPUTATION: begin
         compute_start = 1;
         if(compute_finish) begin
            next_state = STORE_ACT_CTRL;
         end
         else begin
            next_state = state;
         end
      end

      STORE_ACT_CTRL: begin
         dma_write_ctrl_data_index= 10128;
         dma_write_ctrl_data_length = 249;
         dma_write_ctrl_data_size= 3'b010;
         dma_write_ctrl_valid = 1;
         if(dma_write_ctrl_ready) begin
            next_state =  STORE_ACT;
         end
         else begin
            next_state = state;
         end
      end

      STORE_ACT: begin
         // hand shaking
         if(dma_write_chnl_valid==1 && dma_write_chnl_ready==1) begin
            dma_write_chnl_valid_next = 0;
         end
         else begin
            dma_write_chnl_valid_next = 1;
         end

         if(sram_act_addr0_dma == 754) begin
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
/********** weight address process **********/
// for DMA load weight
always@(posedge clk) begin
   if(~rst) begin
      sram_weight_addr0_dma <= 0;
      sram_weight_addr1_dma <= 1;
   end
   else if(state == LOAD_WEIGHT) begin
      if(dma_read_chnl_valid==1 && dma_read_chnl_ready==1) begin
         sram_weight_addr0_dma <= sram_weight_addr0_dma + 2;
         sram_weight_addr1_dma <= sram_weight_addr1_dma + 2;
      end
   end
end

always@* begin
   if(state == COMPUTATION) begin
      weight_wea0 = weight_wea0_lenet;
      weight_wea1 = weight_wea1_lenet;
      sram_weight_addr0 = sram_weight_addr0_lenet;
      sram_weight_addr1 = sram_weight_addr1_lenet;
   end      
   else begin
      weight_wea0 = weight_wea0_dma;
      weight_wea1 = weight_wea1_dma;
      sram_weight_addr0 = sram_weight_addr0_dma;
      sram_weight_addr1 = sram_weight_addr1_dma;
   end
end
/********************************************/
/********** input feature map address process **********/
// for DMA load/store input feature map
always@(posedge clk) begin
   if(~rst) begin
      sram_act_addr0_dma <= 0;
      sram_act_addr1_dma <= 1;
   end
   else if(state == LOAD_IFM) begin
      if(dma_read_chnl_valid==1 && dma_read_chnl_ready==1) begin
         sram_act_addr0_dma <= sram_act_addr0_dma + 2;
         sram_act_addr1_dma <= sram_act_addr1_dma + 2;
      end
   end
   else if(state == STORE_ACT) begin
      if(dma_write_chnl_valid==1 && dma_write_chnl_ready==1) begin
         sram_act_addr0_dma <= sram_act_addr0_dma + 2;
         sram_act_addr1_dma <= sram_act_addr1_dma + 2;
      end
   end
end

always@* begin
   if(state == COMPUTATION) begin
      act_wea0 = act_wea0_lenet;
      act_wea1 = act_wea1_lenet;
      sram_act_addr0 = sram_act_addr0_lenet;
      sram_act_addr1 = sram_act_addr1_lenet;
   end      
   else begin
      act_wea0 = act_wea0_dma;
      act_wea1 = act_wea1_dma;
      sram_act_addr0 = sram_act_addr0_dma;
      sram_act_addr1 = sram_act_addr1_dma;
   end
end
/********************************************/
/********** data process **********/
always@* begin
   dma_write_chnl_data = {act_rdata1, act_rdata0};
   if(state == COMPUTATION) begin
      weight_wdata0 = lenet_weight_wdata0;
      weight_wdata1 = lenet_weight_wdata1;
      act_wdata0 = lenet_act_wdata0;
      act_wdata1 = lenet_act_wdata1;
   end
   else begin
      weight_wdata0 = dma_read_chnl_data[31:0];
      weight_wdata1 = dma_read_chnl_data[63:32];
      act_wdata0 = dma_read_chnl_data[31:0];
      act_wdata1 = dma_read_chnl_data[63:32];
   end
end
/********************************************/
   
endmodule
