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