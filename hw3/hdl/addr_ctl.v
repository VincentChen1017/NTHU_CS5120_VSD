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
