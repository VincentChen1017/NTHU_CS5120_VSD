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

module fsm(
    input wire clk,
    input wire rst_n,
    input wire change_state,  // come from addr_ctl
    input wire compute_start,
    output reg compute_finish,
    output reg [3-1:0] state,
    output reg is_ReLU,
    output reg is_Pooling
);

localparam IDLE = 3'd0;
localparam CONV1 = 3'd1;
localparam CONV2 = 3'd2;
localparam CONV3 = 3'd3;
localparam FC1 = 3'd4;
localparam FC2 = 3'd5;
localparam DONE = 3'd6;

reg [3-1:0] next_state;
//================================= FSM state =================================//
always@* begin
    // case default declare
    next_state = IDLE;
    is_ReLU = 0;
    is_Pooling = 0;
    compute_finish = 0;
    case(state)
        IDLE: begin
            if(compute_start) 
                next_state = CONV1;
            else 
                next_state = IDLE;
        end

        CONV1: begin
            is_ReLU = 1;
            is_Pooling = 1;
            if(change_state) 
                next_state = CONV2;
            else 
                next_state = CONV1;
        end

        CONV2: begin
            compute_finish = 0;
            is_ReLU = 1;
            is_Pooling = 1;
            if(change_state) 
                next_state = CONV3;
            else 
                next_state = CONV2;
        end

        CONV3: begin
            compute_finish = 0;
            is_ReLU = 1;
            is_Pooling = 0;
            if(change_state) 
                next_state = FC1;
            else 
                next_state = CONV3;
        end

       FC1: begin
            compute_finish = 0;
            is_ReLU = 1;
            is_Pooling = 0;
            if(change_state) 
                next_state = FC2;
            else 
                next_state = FC1;
        end

        FC2: begin
            compute_finish = 0;
            is_ReLU = 0;
            is_Pooling = 0;
            if(change_state) 
                next_state = DONE;
            else 
                next_state = FC2;
        end

        DONE: begin
            compute_finish = 1;
            is_ReLU = 0;
            is_Pooling = 0;
            next_state = DONE;
        end

    endcase
end


always@(posedge clk) begin
    if(~rst_n)
        state <= IDLE;
    else
        state <= next_state;
end



endmodule

module addr_ctl #(
    parameter LAST_CYCLE = 5'd10
)
(
    input wire clk,
    input wire rst_n,
    input wire [3-1:0] state,

    // Weight sram, dual port
    output reg [ 3:0] sram_weight_wea0,
    output reg [15:0] sram_weight_addr0,
    output reg [ 3:0] sram_weight_wea1,
    output reg [15:0] sram_weight_addr1,

    // Activation sram, dual port
    output reg [ 3:0] sram_act_wea0,
    output reg [15:0] sram_act_addr0,

    output reg [ 3:0] sram_act_wea1,
    output reg [15:0] sram_act_addr1,

    output reg change_state,
    output reg [5-1:0] count_last_cycle_to_write, // 0~8
    output reg [3-1:0] down,
    output reg [3-1:0] store_case
);

localparam IDLE = 3'd0;
localparam CONV1 = 3'd1;
localparam CONV2 = 3'd2;
localparam CONV3 = 3'd3;
localparam FC1 = 3'd4;
localparam FC2 = 3'd5;
localparam DONE = 3'd6;

// act SRAM offset
localparam act_offset_c1 = 0;     // for conv1
localparam act_offset_c2 = 256;   // for conv2: conv1 output start from address:256
localparam act_offset_c3 = 592;   // for conv3
localparam act_offset_fc1 = 692;   // for fc1
localparam act_offset_fc2 = 722;  // for fc2
localparam act_offset_bias = 743;  // for bias

// weight SRAM offset
localparam weight_offset_c1 = 0;     // for conv1
localparam weight_offset_c2 = 60;   // for conv2
localparam weight_offset_c3 = 1020;   // for conv3
localparam weight_offset_fc1 = 13020;   // for fc1
localparam weight_offset_fc2 = 15540;  // for fc2
localparam weight_offset_bias = 15750;  // for bias

// act input channel
localparam act_ch_in = 1 - 1; // image channel
localparam act_ch_c1 = 6 - 1 ; // conv1 output channel
localparam act_ch_c2 = 16 - 1; // conv2 output channel
localparam act_ch_c3 = 120 - 1; // conv3 output channel
localparam act_ch_fc1 = 84 - 1; // fc1 output channel
localparam act_ch_fc2 = 10 - 1; // fc2 output channel

// col address_num
localparam row_address_num_c1 = 8;  // 0~7
localparam row_address_num_c2 = 4;  // 0~3

// row pixel_num
localparam col_pixel_num_c1 = 32;  
localparam col_pixel_num_c2 = 14; 




//=============================== act & weight movement =================================//
// for the act 
// for conv1: row will shift down 14 times index 0~13; conv2: row will shift down 5 times index 0~4
reg [4-1:0] row, next_row;  
// for conv1: 0~6 ; for conv2: 0~2    unit is 1 address,
reg [3-1:0] col, next_col;  
// it will repeat count 0~5
reg [3-1:0] next_down;
// deal with different act stage
reg [15:0] act_w_offset;
reg [15:0] act_r_offset;
// act and weight deal with the same channel at the same time
reg [7-1:0] act_ch, next_act_ch;
// input/output channel
reg [7-1:0] input_channel, output_channel;
// for CONV3, FC1, FC2
reg [7-1:0] fc_raddr, next_fc_raddr;
reg [7-1:0] fc_in_addr_done;
reg [4-1:0] bias_offset, next_bias_offset;
// for the weight
// for the weight kernel, it will repeat count from 0~4
reg [3-1:0] weight_row, next_weight_row;
reg [7-1:0] weight_batch_offset, next_weight_batch_offset;
reg [15:0] weight_offset;

always@(posedge clk) begin
    if(~rst_n) begin
        down <= 0 ;
        act_ch <= 0;
        row <= 0;
        col <= 0;
        weight_row <= 0;
        weight_batch_offset <= 0;
        fc_raddr <= 0;
        bias_offset <= 0;
    end
    else begin
        down <= next_down ;
        act_ch <= next_act_ch;
        row <= next_row;
        col <= next_col;
        weight_row <= next_weight_row;
        weight_batch_offset <= next_weight_batch_offset;
        fc_raddr <= next_fc_raddr;
        bias_offset <= next_bias_offset;
    end
end

// count_flag make counter to count the "8" cycle, after 8 cycle the data need to write out, before this the act position can't change
reg count_flag;
always@* begin
    if(((down == 3'd5 && act_ch == input_channel) || fc_raddr == fc_in_addr_done) && count_last_cycle_to_write != LAST_CYCLE )
        count_flag = 1;
    else
        count_flag = 0;
end

always@(posedge clk) begin
    if(~rst_n)
        count_last_cycle_to_write <= 0;
    else if(count_last_cycle_to_write == LAST_CYCLE)
        count_last_cycle_to_write <= 0;
    else if(count_flag)
        count_last_cycle_to_write <= count_last_cycle_to_write + 1;
end

always@* begin
    input_channel = 0;
    output_channel = 0;
    fc_in_addr_done = 7'd127;
    case(state)
        CONV1: begin
            input_channel = act_ch_in;
            output_channel = act_ch_c1;            
        end
        CONV2: begin
            input_channel = act_ch_c1;
            output_channel = act_ch_c2;
        end
        CONV3: begin
            fc_in_addr_done = 98;
            output_channel = act_ch_c3;
        end
        FC1: begin
            fc_in_addr_done = 28;
            output_channel = act_ch_fc1;
        end
        FC2: begin
            fc_in_addr_done = 20;
            output_channel = act_ch_fc2;
        end
    endcase
end

reg change_state_flag;
always@* begin
    // case default declare
    next_row = row;
    next_col = col;
    next_down = down;
    next_act_ch = act_ch;
    next_weight_row = weight_row;
    next_weight_batch_offset = weight_batch_offset;
    act_w_offset = 0;
    act_r_offset = 0;
    weight_offset = 0;
    change_state_flag = 0;
    next_fc_raddr = fc_raddr;
    next_bias_offset = bias_offset;
    case(state)
        CONV1: begin
            act_r_offset = act_offset_c1;
            act_w_offset = act_offset_c2;
            weight_offset = weight_offset_c1;

            // process order : 1.down  2. channel  3. col 4. row
            if(down == 3'd5 && act_ch == input_channel && col == 3'd6 && row == 4'd13 && ~count_flag ) begin // determine when the 1xCxHxW act done with 1xCxHxW weigth and change the weight to next batch
                if(weight_batch_offset == output_channel) begin // this layer 's conv is done
                    next_weight_batch_offset = 0;
                    change_state_flag = 1;
                end
                else
                    next_weight_batch_offset = weight_batch_offset + 1; 
                next_row = 0;
                next_col = 0;
                next_act_ch = 0;
                next_down = 0;
                next_weight_row = 0;
            end
            else if(down == 3'd5 && act_ch == input_channel && col == 3'd6 && ~count_flag) begin
                next_row = row + 1;
                next_col = 0;
                next_act_ch = 0;
                next_down = 0;
                next_weight_row = 0;
                next_weight_batch_offset = weight_batch_offset;
            end
            else if(down == 3'd5 && act_ch == input_channel && ~count_flag) begin
                next_row = row;
                next_col = col + 1;
                next_act_ch = 0;
                next_down = 0;
                next_weight_row = 0;
                next_weight_batch_offset = weight_batch_offset;
            end
            else if(down == 3'd5 && ~count_flag ) begin
                next_row = row;
                next_col = col;
                next_act_ch = act_ch + 1;
                next_down = 0;
                next_weight_row = 0;
                next_weight_batch_offset = weight_batch_offset;
            end
            else if(~count_flag)begin
                next_row = row;
                next_col = col;
                next_act_ch = act_ch;
                next_down = down + 1;
                next_weight_row = weight_row + 1;
                next_weight_batch_offset = weight_batch_offset;
            end
        end

        CONV2: begin
            act_r_offset = act_offset_c2;
            act_w_offset = act_offset_c3;
            weight_offset = weight_offset_c2;

            // process order : 1.down  2. channel  3. col 4. row
            if(down == 3'd5 && act_ch == input_channel && col == 3'd2 && row == 4'd4 && ~count_flag) begin // determine when the 1xCxHxW act done with 1xCxHxW weigth and change the weight to next batch
                if(weight_batch_offset == output_channel) begin// this layer 's conv is done
                    next_weight_batch_offset = 0;
                    change_state_flag = 1;
                end
                else
                    next_weight_batch_offset = weight_batch_offset + 1; 
                next_row = 0;
                next_col = 0;
                next_act_ch = 0;
                next_down = 0;
                next_weight_row = 0;
            end
            else if(down == 3'd5 && act_ch == input_channel && col == 3'd2 && ~count_flag) begin
                next_row = row + 1;
                next_col = 0;
                next_act_ch = 0;
                next_down = 0;
                next_weight_row = 0;
                next_weight_batch_offset = weight_batch_offset;
            end
            else if(down == 3'd5 && act_ch == input_channel && ~count_flag) begin
                next_row = row;
                next_col = col + 1;
                next_act_ch = 0;
                next_down = 0;
                next_weight_row = 0;
                next_weight_batch_offset = weight_batch_offset;
            end
            else if(down == 3'd5 && ~count_flag) begin
                next_row = row;
                next_col = col;
                next_act_ch = act_ch + 1;
                next_down = 0;
                next_weight_row = 0;
                next_weight_batch_offset = weight_batch_offset;
            end
            else if(~count_flag)begin
                next_row = row;
                next_col = col;
                next_act_ch = act_ch;
                next_down = down + 1;
                next_weight_row = weight_row + 1;
                next_weight_batch_offset = weight_batch_offset;
            end
        end

    CONV3: begin
            act_r_offset = act_offset_c3;
            act_w_offset = act_offset_fc1;
            weight_offset = weight_offset_c3;

            if(fc_raddr == fc_in_addr_done && ~count_flag) begin // determine when the 1xCxHxW act done with 1xCxHxW weigth and change the weight to next batch
                if(weight_batch_offset == output_channel) begin
                    next_weight_batch_offset = 0;
                    change_state_flag = 1;
                end
                else 
                    next_weight_batch_offset = weight_batch_offset + 1; 
                next_fc_raddr  = 0;
            end
            else if(~count_flag)begin
                next_fc_raddr = fc_raddr + 2;
                next_weight_batch_offset = weight_batch_offset;
            end
        end

    FC1: begin
            act_r_offset = act_offset_fc1;
            act_w_offset = act_offset_fc2;
            weight_offset = weight_offset_fc1;

            if(fc_raddr == fc_in_addr_done && ~count_flag) begin // determine when the 1xCxHxW act done with 1xCxHxW weigth and change the weight to next batch
                if(weight_batch_offset == output_channel) begin
                    next_weight_batch_offset = 0;
                    change_state_flag = 1;
                end
                else 
                    next_weight_batch_offset = weight_batch_offset + 1; 
                next_fc_raddr  = 0;
            end
            else if(~count_flag)begin
                next_fc_raddr = fc_raddr + 2;
                next_weight_batch_offset = weight_batch_offset;
            end
        end

    FC2: begin
            act_r_offset = act_offset_fc2;
            act_w_offset = act_offset_bias;
            weight_offset = weight_offset_fc2;

            if(fc_raddr == fc_in_addr_done && ~count_flag) begin // determine when the 1xCxHxW act done with 1xCxHxW weigth and change the weight to next batch
                if(weight_batch_offset == output_channel) begin
                    next_weight_batch_offset = 0;
                    next_bias_offset = 0;
                    change_state_flag = 1;
                end
                else begin
                    next_weight_batch_offset = weight_batch_offset + 1; 
                    next_bias_offset = bias_offset + 1;
                end
                next_fc_raddr  = 0;
            end
            else if(~count_flag)begin
                next_fc_raddr = fc_raddr + 2;
                next_weight_batch_offset = weight_batch_offset;
            end
        end
    endcase
end


// for conv1: count 0~1 to signify the write address position in one address, count_w_position=0 means sram_act_wea0= 0011 , count_w_position=0 means sram_act_wea0= 1100
/*always@(posedge clk) begin
    if(~rst_n)
        count_w_position <= 0;
    else if(count_last_cycle_to_write == LAST_CYCLE)
        if (col == 3'd6) // for conv1: col6 is position0 and is end. next col is 0 and it is position 0
            count_w_position <= 0;
        else
            count_w_position <= count_w_position + 1;
end*/

reg [2-1:0] stored_data; // for conv1: store 2 number at once, for conv2 it may store 2number or 1number at once. stored_data remind how many number store in this write mem
reg [7-1:0] conv2_waddr; // count from 0 to 100
reg [5-1:0] fc_waddr; 
always@(posedge clk) begin
    if(~rst_n) begin
        stored_data <= 0;
        conv2_waddr <= 0;
        fc_waddr <= 0;
    end
    else if(count_last_cycle_to_write == LAST_CYCLE) begin
        case(state)
            CONV1: begin
                if(stored_data == 3'd2 || col == 3'd6) // for conv1: col6 is position0 and is end. next col is 0 and it is position 0
                    stored_data <= 0;
                else
                    stored_data <= 3'd2;
            end
           CONV2: begin
                if(stored_data == 3'd3)
                    if(col == 2)  begin// in the boundary only store 1 max pooling result
                        stored_data <= 0;
                        conv2_waddr <= conv2_waddr + 1;
                    end
                    else begin
                        stored_data <= 1;
                        conv2_waddr <= conv2_waddr + 1;
                    end
                else if(stored_data == 3'd2)
                    if(col == 2) begin
                        stored_data <= 3;
                        conv2_waddr <= conv2_waddr;
                    end   
                    else begin
                        stored_data <= 0;
                        conv2_waddr <= conv2_waddr + 1;
                    end
                else if (stored_data == 3'd1)
                    if(col == 2) begin
                        stored_data <= 2;
                        conv2_waddr <= conv2_waddr;
                    end
                    else begin
                        stored_data <= 3;
                        conv2_waddr <= conv2_waddr;
                    end
                else
                    if(col == 2) begin
                        stored_data <= 1;
                        conv2_waddr <= conv2_waddr; 
                    end
                    else begin
                        stored_data <= 2;
                        conv2_waddr <= conv2_waddr;
                    end
            end
            CONV3, FC1: begin
                if(change_state) begin
                    stored_data <= 3'd0;
                    fc_waddr <= 0;
                end
                else if(stored_data == 3'd3) begin  // add up from 0
                    stored_data <= 3'd0;
                    fc_waddr <= fc_waddr + 1;
                end
                else begin
                    stored_data <= stored_data + 1;
                    fc_waddr <= fc_waddr;
                end
            end
            FC2: begin
                if(change_state) begin
                    stored_data <= 3'd0;
                    fc_waddr <= 0;
                end
                else begin
                    fc_waddr <= fc_waddr + 1;
                end
            end
        endcase
    end
end

always@* begin
    if(change_state_flag)
        change_state = 1;
    else
        change_state = 0;
end

//================================ act SRAM read & write ==================================//
always@* begin
    sram_act_addr0 = 16'd0;
    sram_act_addr1 = 16'd0;
    sram_act_wea0 = 4'b0000;
    sram_act_wea1 = 4'b0000;
    store_case = 0;
    case(state)
        CONV1: begin
            // count_last_cycle_to_write == LAST_CYCLE means need to write data
            if(count_last_cycle_to_write == LAST_CYCLE ) begin
                if (stored_data==0) begin
                    sram_act_wea0 = 4'b1111; // when position==0 whire xy00 
                    store_case = 0;
                end
                else begin 
                    sram_act_wea0 = 4'b1100;
                    store_case = 1;
                end
                case(col) 
                    0, 1: sram_act_addr0 = 0 + row*4 + weight_batch_offset*56 + act_w_offset; 
                    2, 3: sram_act_addr0 = 1 + row*4 + weight_batch_offset*56 + act_w_offset;
                    4, 5: sram_act_addr0 = 2 + row*4 + weight_batch_offset*56 + act_w_offset;
                    6: sram_act_addr0 = 3 + row*4 + weight_batch_offset*56 + act_w_offset;
                endcase
            end
            else begin
                // SRAM read data
                sram_act_addr0 = down*8 + act_ch*256 + col + row*16 + act_r_offset;
                sram_act_addr1 = sram_act_addr0 + 1;
            end
        end

        CONV2: begin
            // count_last_cycle_to_write == LAST_CYCLE means need to write data
            if(count_last_cycle_to_write == LAST_CYCLE ) begin
                case(stored_data)
                    2'd3: begin
                        if(col == 2) begin
                            store_case = 7;
                            sram_act_wea0 = 4'b1000;
                            sram_act_addr0 = conv2_waddr + act_w_offset;
                        end
                        else begin
                            store_case = 6;
                            sram_act_wea0 = 4'b1000;
                            sram_act_addr0 = conv2_waddr + act_w_offset;
                            sram_act_wea1 = 4'b0001;
                            sram_act_addr1 = conv2_waddr + act_w_offset + 1;
                        end
                    end
                    2'd2: begin
                        if(col == 2) begin
                            store_case = 5;
                            sram_act_wea0 = 4'b0100;
                            sram_act_addr0 = conv2_waddr + act_w_offset;
                        end
                        else begin
                            store_case = 1;
                            sram_act_wea0 = 4'b1100;
                            sram_act_addr0 = conv2_waddr + act_w_offset;
                        end
                    end
                    2'd1: begin
                        if(col == 2) begin
                            store_case = 3;
                            sram_act_wea0 = 4'b0010;
                            sram_act_addr0 = conv2_waddr + act_w_offset;
                        end
                        else begin
                            store_case = 2;
                            sram_act_wea0 = 4'b0110;
                            sram_act_addr0 = conv2_waddr + act_w_offset;
                        end
                    end
                    2'd0: begin
                        if(col == 2) begin
                            store_case = 4;
                            sram_act_wea0 = 4'b0001;
                            sram_act_addr0 = conv2_waddr + act_w_offset;
                        end
                        else begin
                            store_case = 0;
                            sram_act_wea0 = 4'b0011;
                            sram_act_addr0 = conv2_waddr + act_w_offset;
                        end
                    end
                endcase
            end
            else begin
                // SRAM read data
                sram_act_addr0 = down*4 + act_ch*56 + col + row*8 + act_r_offset;
                sram_act_addr1 = sram_act_addr0 + 1;
            end
        end

        CONV3, FC1, FC2: begin
            // count_last_cycle_to_write == LAST_CYCLE means need to write data
            if(count_last_cycle_to_write == LAST_CYCLE ) begin
                sram_act_addr0 = fc_waddr + act_w_offset;
                case(stored_data)
                    2'd0: begin
                        if(state == FC2) begin
                            store_case = 4; 
                            sram_act_wea0 = 4'b1111;                       
                        end
                        else begin
                            store_case = 4; 
                            sram_act_wea0 = 4'b0001;
                        end
                    end
                    2'd1: begin
                        store_case = 3; 
                        sram_act_wea0 = 4'b0010;
                    end
                    2'd2: begin
                        store_case = 5; 
                        sram_act_wea0 = 4'b0100;
                    end
                    2'd3: begin
                        store_case = 6; 
                        sram_act_wea0 = 4'b1000;
                    end
                endcase
            end
            else begin
                // SRAM read data
                sram_act_addr0 = fc_raddr + act_r_offset;
                sram_act_addr1 = sram_act_addr0 + 1;                    
            end
        end
    endcase
end


//================================ weight SRAM read ===============================//
always@* begin
    sram_weight_wea0 = 4'b0000;
    sram_weight_wea1 = 4'b0000;
    if(state < CONV3)
        sram_weight_addr0 = weight_row*2 + act_ch*10 + weight_batch_offset*10*(input_channel+1) + weight_offset;
    else
        if(state == FC2)
            sram_weight_addr0 = fc_raddr + weight_batch_offset*(fc_in_addr_done + 1) + weight_offset;
        else
            sram_weight_addr0 = fc_raddr + weight_batch_offset*(fc_in_addr_done + 2) + weight_offset;

    if(state==FC2 && count_flag)
        sram_weight_addr1 = weight_offset_bias + bias_offset;
    else
        sram_weight_addr1 = sram_weight_addr0 + 1; 
end


endmodule

module pe#(
    parameter PARAM_BIT = 8,
    parameter KERNEL_SIZE = 5,  // one row of kernel weight
    parameter PARTIAL_BIT = 25,   // 25~26
    parameter LAST_CYCLE = 5'd10
)
(
input wire clk,
input wire rst_n,

// input ifmap, load 5x5 ifmap to do conv
input [PARAM_BIT*KERNEL_SIZE-1:0] ifmap_in,
input [PARAM_BIT*KERNEL_SIZE-1:0] weight_in,
// count_last_cycle_to_write
input [5-1:0] count_last_cycle_to_write, // 0~8
output reg signed [PARTIAL_BIT-1:0] sum

);
integer i,j,k;

//================================= load the ifmap and weight =================================//
wire signed [PARAM_BIT-1:0] ifmap [0:KERNEL_SIZE-1];
wire signed  [PARAM_BIT-1:0] weight [0:KERNEL_SIZE-1];

assign {ifmap[0], ifmap[1], ifmap[2], ifmap[3], ifmap[4]} = ifmap_in;

assign {weight[0], weight[1], weight[2], weight[3], weight[4]} = weight_in;

//=================================the conv process: 25's ifmap bitwise operation =================================//
reg signed [2*PARAM_BIT-1:0] dot_product [0:KERNEL_SIZE-1];  // Max(#bit) of 8bit * 8bit = 16bits
always@* begin
    for(i=0; i<5; i=i+1) begin
        dot_product[i] = ifmap[i] * weight[i];
    end   
end

//******************************** DFF 1 *********************************************//
reg signed [2*PARAM_BIT-1:0] dot_product_n [0:KERNEL_SIZE-1];
always@(posedge clk) begin
    if(~rst_n) begin
        dot_product_n[0] <= 0;
        dot_product_n[1] <= 0;
        dot_product_n[2] <= 0;
        dot_product_n[3] <= 0;
        dot_product_n[4] <= 0;
    end
    else begin
        dot_product_n[0] <= dot_product[0];
        dot_product_n[1] <= dot_product[1];
        dot_product_n[2] <= dot_product[2];
        dot_product_n[3] <= dot_product[3];
        dot_product_n[4] <= dot_product[4];
    end
end

//================================= output =================================//
reg signed [PARTIAL_BIT-1:0] sum_tmp;
always@* begin
    sum_tmp = sum + dot_product_n[0]+ dot_product_n[1] + dot_product_n[2] + dot_product_n[3] + dot_product_n[4];
end

//******************************** DFF 2 *********************************************//
always@(posedge clk)
    if(~rst_n)
        sum <= 0;
    else if(count_last_cycle_to_write == LAST_CYCLE) // write data finish. next data need to start sum up from 0
        sum <= 0;
    else
        sum <= sum_tmp;    

endmodule 

module actquant #(
    parameter PARAM_BIT = 8,
    parameter PARTIAL_BIT = 25 
)
(
    input signed [16-1:0] scale,
    input signed [PARTIAL_BIT-1:0] act_in,
    input clk,
    input rst_n,
    output reg signed [PARAM_BIT-1:0] act_out
);



//================================== quantize =================================//
//================ shift 16 bits and clip the act return to 8bit =================//
//reg signed_bit;
reg signed [PARAM_BIT-1:0] act_scaled_n;
reg signed[40-1:0] tmp;
always@* begin
    //signed_bit = act_scaled_n[31];  // {signed_bit, act_scaled_n[31:16]} or   >>> 16 (>>> means signed shift)   
    tmp = ((act_in*scale) >>> 16);
end

/************************************* DFF1 **************************************/
reg signed[47-1:0] tmp_n;
always@(posedge clk) begin
    if(~rst_n)
        tmp_n <= 0;
    else
        tmp_n <= tmp;
end

always@* begin
    if( tmp_n  < -128)
        act_scaled_n = -128;
    else if(tmp_n > 127)
        act_scaled_n = 127;
    else
        act_scaled_n = tmp_n;
end

/************************************* DFF2 **************************************/
always@(posedge clk) begin
    if(~rst_n)
        act_out <= 0;
    else
        act_out <= act_scaled_n;
end


/////////////////////// WRONG WAY !!!!!!!!!!!!!!!!!!! /////////////////////////////////
/*
wire signed [31:0] act_scaled;
assign act_scaled = act_in * scale;


reg signed [31:0] act_scaled_n;
always@(posedge clk) begin
    if(~rst_n)
        act_scaled_n <= 0;
    else
        act_scaled_n <= act_scaled;
end


reg signed_bit;
always@* begin
    //signed_bit = act_scaled_n[31];
    act_out = act_scaled_n >>> 16;    // {signed_bit, act_scaled_n[31:16]} or   >>> 16 (>>> means signed shift) ? 
    if(act_out < -128)
        act_out = -128;
    else if(act_out > 127)
        act_out = 127;
end*/

endmodule