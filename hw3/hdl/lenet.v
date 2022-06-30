module lenet #(
    parameter PARTIAL_BIT = 25
)
(
    input wire clk,
    input wire rst_n,

    input wire compute_start,
    output reg compute_finish,

    // Quantization scale
    input wire [31:0] scale_CONV1,
    input wire [31:0] scale_CONV2,
    input wire [31:0] scale_CONV3,
    input wire [31:0] scale_FC1,
    input wire [31:0] scale_FC2,

    // Weight sram, dual port
    output reg [ 3:0] sram_weight_wea0,
    output reg [15:0] sram_weight_addr0,
    output reg [31:0] sram_weight_wdata0,
    input wire [31:0] sram_weight_rdata0,
    output reg [ 3:0] sram_weight_wea1,
    output reg [15:0] sram_weight_addr1,
    output reg [31:0] sram_weight_wdata1,
    input wire [31:0] sram_weight_rdata1,

    // Activation sram, dual port
    output reg [ 3:0] sram_act_wea0,
    output reg [15:0] sram_act_addr0,
    output reg [31:0] sram_act_wdata0,
    input wire [31:0] sram_act_rdata0,
    output reg [ 3:0] sram_act_wea1,
    output reg [15:0] sram_act_addr1,
    output reg [31:0] sram_act_wdata1,
    input wire [31:0] sram_act_rdata1
);

localparam IDLE = 3'd0;
localparam CONV1 = 3'd1;
localparam CONV2 = 3'd2;
localparam CONV3 = 3'd3;
localparam FC1 = 3'd4;
localparam FC2 = 3'd5;
localparam BIAS = 3'd6;
localparam LAST_CYCLE = 5'd10;

// Add your design here
reg rst_n_n;
reg compute_start_n;
reg n_compute_finish;
// Quantization scale
reg [31:0] scale_CONV1_n;
reg [31:0] scale_CONV2_n;
reg [31:0] scale_CONV3_n;
reg [31:0] scale_FC1_n;
reg [31:0] scale_FC2_n;
// Weight sram_n; dual port
wire [ 3:0] n_sram_weight_wea0;
wire [15:0] n_sram_weight_addr0;
reg [31:0] n_sram_weight_wdata0;
reg [31:0] sram_weight_rdata0_n;
wire [ 3:0] n_sram_weight_wea1;
wire [15:0] n_sram_weight_addr1;
reg [31:0] n_sram_weight_wdata1;
reg [31:0] sram_weight_rdata1_n;
// Activation sram_n; dual port
wire [ 3:0] n_sram_act_wea0;
wire [15:0] n_sram_act_addr0;
reg [31:0] n_sram_act_wdata0;
reg [31:0] sram_act_rdata0_n;
wire [ 3:0] n_sram_act_wea1;
wire [15:0] n_sram_act_addr1;
reg [31:0] n_sram_act_wdata1;
reg [31:0] sram_act_rdata1_n;

// module connect wire
wire change_state;
wire [3-1:0] state;
wire [5-1:0] count_last_cycle_to_write;
wire [3-1:0] down;
wire is_ReLU;
wire is_Pooling;
wire signed [PARTIAL_BIT-1:0] pe_sum00;
wire signed [PARTIAL_BIT-1:0] pe_sum01;
wire signed [PARTIAL_BIT-1:0] pe_sum02;
wire signed [PARTIAL_BIT-1:0] pe_sum03;
wire signed [PARTIAL_BIT-1:0] pe_sum10;
wire signed [PARTIAL_BIT-1:0] pe_sum11;
wire signed [PARTIAL_BIT-1:0] pe_sum12;
wire signed [PARTIAL_BIT-1:0] pe_sum13;
wire [3-1:0] store_case;
wire nn_compute_finish;


//===================================== DFF BLOCK THE INPUT SIGNAL =====================================//
always@(posedge clk)begin
    rst_n_n <= rst_n;
end

always@(posedge clk) begin
    compute_start_n <= compute_start;
    scale_CONV1_n <= scale_CONV1;
    scale_CONV2_n <= scale_CONV2;
    scale_CONV3_n <= scale_CONV3;
    scale_FC1_n <= scale_FC1;
    //scale_FC2_n <= scale_FC2;
    sram_weight_rdata0_n <= sram_weight_rdata0;
    sram_weight_rdata1_n <= sram_weight_rdata1;
    sram_act_rdata0_n <= sram_act_rdata0;
    sram_act_rdata1_n <= sram_act_rdata1;
end
//********************************************************************************************************//
//===================================== data Pre-process =====================================//
reg [31:0] sram_weight_rdata0_n2;
reg [31:0] sram_weight_rdata1_n2;
always@(posedge clk) begin
    sram_weight_rdata0_n2 <= sram_weight_rdata0_n;
    sram_weight_rdata1_n2 <= sram_weight_rdata1_n;      
end

// for conv1, conv2
// down=0 data don't need to pass to pe10,11,12,13 and down=5 don't need to pass to pe00,01,02,03, and data will delay 3 cycle
/*reg [2-1:0] first_pe_stop_count, second_pe_stop_count; 
always@(posedge clk) begin
    if(~rst_n_n) 
        first_pe_stop_count <= 0;
    else if(down==3'd5 || first_pe_stop_count > 0)
        first_pe_stop_count <= first_pe_stop_count + 1;
end
always@(posedge clk) begin
    if(~rst_n_n) 
        second_pe_stop_count <= 0;
    else if( state!= IDLE && (down==3'd0 || second_pe_stop_count > 0))
        second_pe_stop_count <= second_pe_stop_count + 1;
end*/

// for change state, we need to wait 3 cycle, so can get needed data
reg [2-1:0] load_count;
always@(posedge clk) begin
    if(~rst_n_n)
        load_count <= 0;
    else if(state!=IDLE)
        if(load_count < 3)
            load_count <= load_count + 1;
        else if(count_last_cycle_to_write == LAST_CYCLE)
            load_count <= 0;
end

reg [8*5-1:0] pe00_w, pe00_act;
reg [8*5-1:0] pe01_w, pe01_act;
reg [8*5-1:0] pe02_w, pe02_act;
reg [8*5-1:0] pe03_w, pe03_act;
reg [8*5-1:0] pe10_w, pe10_act;
reg [8*5-1:0] pe11_w, pe11_act;
reg [8*5-1:0] pe12_w, pe12_act;
reg [8*5-1:0] pe13_w, pe13_act;
always@* begin
    // for pe00, pe01, pe02, pe03
    if(count_last_cycle_to_write > 2 || down==2 || load_count!=3) begin   // first_pe_stop_count == 2'd3 -> down==2
        pe00_w = 40'd0;
        pe01_w = 40'd0;
        pe02_w = 40'd0;
        pe03_w = 40'd0;
        pe00_act = 40'd0;
        pe01_act = 40'd0;
        pe02_act = 40'd0;
        pe03_act = 40'd0;
    end
    else begin
        pe00_w = {sram_weight_rdata1_n[7:0], sram_weight_rdata0_n};
        pe01_w = {sram_weight_rdata1_n[7:0], sram_weight_rdata0_n};
        pe02_w = {sram_weight_rdata1_n[7:0], sram_weight_rdata0_n};
        pe03_w = {sram_weight_rdata1_n[7:0], sram_weight_rdata0_n};
        pe00_act = {sram_act_rdata1_n[7:0], sram_act_rdata0_n[31:0]};
        pe01_act = {sram_act_rdata1_n[15:0], sram_act_rdata0_n[31:8]};
        pe02_act = {sram_act_rdata1_n[23:0], sram_act_rdata0_n[31:16]};
        pe03_act = {sram_act_rdata1_n[31:0], sram_act_rdata0_n[31:24]};
    end

    // for pe10, pe11, pe12, pe13
    if(count_last_cycle_to_write > 3 || down==3 || load_count!=3) begin // second_pe_stop_count == 2'd3 -> down==3
        pe10_w = 40'd0;
        pe11_w = 40'd0;
        pe12_w = 40'd0;
        pe13_w = 40'd0;
        pe10_act = 40'd0;
        pe11_act = 40'd0;
        pe12_act = 40'd0;
        pe13_act = 40'd0;
    end
    else begin
        if(state < CONV3) begin
            pe10_w = {sram_weight_rdata1_n2[7:0], sram_weight_rdata0_n2};
            pe11_w = {sram_weight_rdata1_n2[7:0], sram_weight_rdata0_n2};
            pe10_act = {sram_act_rdata1_n[7:0], sram_act_rdata0_n[31:0]};
            pe11_act = {sram_act_rdata1_n[15:0], sram_act_rdata0_n[31:8]};
        end
        else if(state==FC2 && count_last_cycle_to_write == 3) begin  // FC2 addr only 0~20,  (20 21) only use 20
            pe10_w = {8'd0, sram_weight_rdata0_n};
            pe11_w = 40'd0; 
            pe10_act = {8'd0, sram_act_rdata0_n};
            pe11_act = 40'd0;
        end
        else begin
            pe10_w = {8'd0, sram_weight_rdata0_n};
            pe11_w = {8'd0, sram_weight_rdata1_n};
            pe10_act = {8'd0, sram_act_rdata0_n};
            pe11_act = {8'd0, sram_act_rdata1_n};
        end

        pe12_w = {sram_weight_rdata1_n2[7:0], sram_weight_rdata0_n2};
        pe13_w = {sram_weight_rdata1_n2[7:0], sram_weight_rdata0_n2};
        pe12_act = {sram_act_rdata1_n[23:0], sram_act_rdata0_n[31:16]};
        pe13_act = {sram_act_rdata1_n[31:0], sram_act_rdata0_n[31:24]};
    end
end

reg [16-1:0] scale;
always@* begin
    scale = 16'd0;
    case(state)
        CONV1:
            scale = scale_CONV1_n[15:0];
        CONV2:
            scale = scale_CONV2_n[15:0];
        CONV3:
            scale = scale_CONV3_n[15:0];
        FC1:
            scale = scale_FC1_n[15:0];
    endcase
end

reg [16-1:0] scale_n;
always@(posedge clk) begin
    scale_n <= scale;
end

//********************************************************************************************************//
//===================================== module initiation =====================================//
fsm fsm
(
    .clk(clk),
    .rst_n(rst_n_n),
    .change_state(change_state),  // come from addr_ctl
    .compute_start(compute_start_n),
    .compute_finish(nn_compute_finish),
    .state(state),
    .is_ReLU(is_ReLU),
    .is_Pooling(is_Pooling)
);


addr_ctl addr_ctl
(
    .clk(clk),
    .rst_n(rst_n_n),
    .state(state),
    // Weight sram, dual port
    .sram_weight_wea0(n_sram_weight_wea0),
    .sram_weight_addr0(n_sram_weight_addr0),
    .sram_weight_wea1(n_sram_weight_wea1),
    .sram_weight_addr1(n_sram_weight_addr1),
    // Activation sram, dual port
    .sram_act_wea0(n_sram_act_wea0),
    .sram_act_addr0(n_sram_act_addr0),
    .sram_act_wea1(n_sram_act_wea1),
    .sram_act_addr1(n_sram_act_addr1),
    .change_state(change_state),
    .count_last_cycle_to_write(count_last_cycle_to_write),
    .down(down),
    .store_case(store_case)
);


pe pe00
(
.clk(clk),
.rst_n(rst_n_n),
// input ifmap, load 5x5 ifmap to do conv
.ifmap_in(pe00_act),
.weight_in(pe00_w),
// count_last_cycle_to_write
.count_last_cycle_to_write(count_last_cycle_to_write), // 0~8
.sum(pe_sum00)
);

pe pe01
(
.clk(clk),
.rst_n(rst_n_n),
// input ifmap, load 5x5 ifmap to do conv
.ifmap_in(pe01_act),
.weight_in(pe01_w),
// count_last_cycle_to_write
.count_last_cycle_to_write(count_last_cycle_to_write), // 0~8
.sum(pe_sum01)
);

pe pe02
(
.clk(clk),
.rst_n(rst_n_n),
// input ifmap, load 5x5 ifmap to do conv
.ifmap_in(pe02_act),
.weight_in(pe02_w),
// count_last_cycle_to_write
.count_last_cycle_to_write(count_last_cycle_to_write), // 0~8
.sum(pe_sum02)
);

pe pe03
(
.clk(clk),
.rst_n(rst_n_n),
// input ifmap, load 5x5 ifmap to do conv
.ifmap_in(pe03_act),
.weight_in(pe03_w),
// count_last_cycle_to_write
.count_last_cycle_to_write(count_last_cycle_to_write), // 0~8
.sum(pe_sum03)
);

pe pe10
(
.clk(clk),
.rst_n(rst_n_n),
// input ifmap, load 5x5 ifmap to do conv
.ifmap_in(pe10_act),
.weight_in(pe10_w),
// count_last_cycle_to_write
.count_last_cycle_to_write(count_last_cycle_to_write), // 0~8
.sum(pe_sum10)
);

pe pe11
(
.clk(clk),
.rst_n(rst_n_n),
// input ifmap, load 5x5 ifmap to do conv
.ifmap_in(pe11_act),
.weight_in(pe11_w),
// count_last_cycle_to_write
.count_last_cycle_to_write(count_last_cycle_to_write), // 0~8
.sum(pe_sum11)
);

pe pe12
(
.clk(clk),
.rst_n(rst_n_n),
// input ifmap, load 5x5 ifmap to do conv
.ifmap_in(pe12_act),
.weight_in(pe12_w),
// count_last_cycle_to_write
.count_last_cycle_to_write(count_last_cycle_to_write), // 0~8
.sum(pe_sum12)
);

pe pe13
(
.clk(clk),
.rst_n(rst_n_n),
// input ifmap, load 5x5 ifmap to do conv
.ifmap_in(pe13_act),
.weight_in(pe13_w),
// count_last_cycle_to_write
.count_last_cycle_to_write(count_last_cycle_to_write), // 0~8
.sum(pe_sum13)
);

// Relu
reg signed [PARTIAL_BIT-1:0] act_in00;
reg signed [PARTIAL_BIT-1:0] act_in01;
reg signed [PARTIAL_BIT-1:0] act_in02;
reg signed [PARTIAL_BIT-1:0] act_in03;
reg signed [PARTIAL_BIT-1:0] act_in10;
reg signed [PARTIAL_BIT-1:0] act_in11;
reg signed [PARTIAL_BIT-1:0] act_in12;
reg signed [PARTIAL_BIT-1:0] act_in13;
reg signed [PARTIAL_BIT-1:0] act_in_fu;
always@* begin
    if(is_ReLU) begin
        act_in00 = (pe_sum00 > 0) ? pe_sum00 : 0;
        act_in01 = (pe_sum01 > 0) ? pe_sum01 : 0;
        act_in02 = (pe_sum02 > 0) ? pe_sum02 : 0;
        act_in03 = (pe_sum03 > 0) ? pe_sum03 : 0;
        act_in10 = (pe_sum10 > 0) ? pe_sum10 : 0;
        act_in11 = (pe_sum11 > 0) ? pe_sum11 : 0;
        act_in12 = (pe_sum12 > 0) ? pe_sum12 : 0;
        act_in13 = (pe_sum13 > 0) ? pe_sum13 : 0;
        act_in_fu = ((pe_sum10 + pe_sum11)  > 0) ? (pe_sum10 + pe_sum11) : 0;
    end
    else begin
        act_in00 =  pe_sum00;
        act_in01 =  pe_sum01;
        act_in02 =  pe_sum02; 
        act_in03 =  pe_sum03;
        act_in10 =  pe_sum10;
        act_in11 =  pe_sum11;
        act_in12 =  pe_sum12;
        act_in13 =  pe_sum13;
        act_in_fu = (pe_sum10 + pe_sum11);
    end
end

// Max Pooling
reg signed [PARTIAL_BIT-1:0] max_data0_tmp0, max_data0_tmp1, max_data1_tmp0, max_data1_tmp1;
reg signed [PARTIAL_BIT-1:0] max_data0, max_data1;

always@ * begin
// pe00 pe01 pe10 pe11  
    if(act_in00 > act_in01)
        max_data0_tmp0 = act_in00;
    else
        max_data0_tmp0 = act_in01;
    if(act_in10 > act_in11)
       max_data0_tmp1 = act_in10;
    else
        max_data0_tmp1 = act_in11;
    if(max_data0_tmp0 > max_data0_tmp1)
        max_data0 = max_data0_tmp0;
    else
        max_data0 =max_data0_tmp1;
// pe02 pe03 pe12 pe13  
    if(act_in02 > act_in03)
        max_data1_tmp0 = act_in02;
    else
        max_data1_tmp0 = act_in03;
    if(act_in12 > act_in13)
        max_data1_tmp1 = act_in12;
    else
        max_data1_tmp1 = act_in13;
    if(max_data1_tmp0 > max_data1_tmp1)
        max_data1 = max_data1_tmp0;
    else
        max_data1 = max_data1_tmp1;
end

reg signed [PARTIAL_BIT-1:0] max_data0_n, max_data1_n;
reg signed [PARTIAL_BIT-1:0] act_in_fu_n;
always@(posedge clk) begin
    max_data0_n <= max_data0;
    max_data1_n <= max_data1;
    act_in_fu_n <= act_in_fu;     
end


// quantization
reg signed [PARTIAL_BIT-1:0] act_in;
always@* begin
    act_in = 0;
    case(count_last_cycle_to_write)
        6: begin
            if(is_Pooling)
                act_in = max_data0_n;  
            else
                act_in = act_in_fu_n;   // act_in_fu need delay ? critical path ?
        end
        7: act_in = max_data1_n;

    endcase 
end

wire signed [8-1:0] act_out;
actquant actqunat00
(
    .scale(scale_n),
    .act_in(act_in),
    .clk(clk),
    .rst_n(rst_n_n),
    .act_out(act_out)
);

reg signed  [8-1:0] wdata0;
reg signed  [8-1:0] wdata1;
always@(posedge clk) begin
    case(count_last_cycle_to_write) // case need to depend on last_cycle_count & actquant need to compute
        8: wdata0 <= act_out;
        9: wdata1 <= act_out;
    endcase
end

// FC2 bias:
reg signed[32-1:0] fc2_out_tmp;
reg signed[32-1:0] fc2_out;
always@* begin
    fc2_out_tmp = act_in_fu_n + $signed(sram_weight_rdata1_n);
end

always@(posedge clk) begin
    fc2_out <= fc2_out_tmp;
end

// output value
always@* begin
    n_sram_weight_wdata0 = 32'd0;
    n_sram_weight_wdata1 = 32'd0;
    n_sram_act_wdata1 = 32'd0;
    if(store_case == 0)
        n_sram_act_wdata0 = {8'd0, 8'd0, wdata1, wdata0};
    else if(store_case == 1)
        n_sram_act_wdata0 = {wdata1, wdata0 , 8'd0, 8'd0};   
    else if(store_case == 2)
        n_sram_act_wdata0 = {8'd0, wdata1, wdata0 ,8'd0}; 
    else if(store_case == 3)
        n_sram_act_wdata0 = {8'd0, 8'd0, wdata0 , 8'd0}; 
    else if(store_case == 4)
        if(state == FC2)
            n_sram_act_wdata0 = fc2_out;
        else 
            n_sram_act_wdata0 = {8'd0, 8'd0, 8'd0, wdata0}; 
    else if(store_case == 5)
        n_sram_act_wdata0 = {8'd0, wdata0 , 8'd0, 8'd0}; 
    else if(store_case == 6) begin
        n_sram_act_wdata0 = {wdata0, 8'd0 , 8'd0, 8'd0}; 
        n_sram_act_wdata1 = {8'd0 , 8'd0, 8'd0, wdata1}; 
    end
    else // store_case == 7
        n_sram_act_wdata0 = {wdata0 , 8'd0, 8'd0, 8'd0}; 

end

//===================================== DFF BLOCK THE OUTPUT SIGNAL =====================================//
always@(posedge clk) begin
    n_compute_finish <= nn_compute_finish;
    compute_finish <= n_compute_finish;
    sram_weight_wea0 <= n_sram_weight_wea0;
    sram_weight_addr0 <= n_sram_weight_addr0;
    sram_weight_wdata0 <= n_sram_weight_wdata0;
    sram_weight_wea1 <= n_sram_weight_wea1;
    sram_weight_addr1 <= n_sram_weight_addr1;
    sram_weight_wdata1 <= n_sram_weight_wdata1;
    sram_act_wea0 <= n_sram_act_wea0;
    sram_act_addr0 <= n_sram_act_addr0;
    sram_act_wdata0 <= n_sram_act_wdata0;
    sram_act_wea1 <= n_sram_act_wea1;
    sram_act_addr1 <= n_sram_act_addr1;
    sram_act_wdata1 <= n_sram_act_wdata1;
end
//********************************************************************************************************//

endmodule