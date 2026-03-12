// 交通灯控制器 - 有限状态机 (FSM)
// 3个状态：GREEN → YELLOW → RED → GREEN (循环)

module traffic_light (
    input  wire       clk,
    input  wire       rst_n,      // 异步复位（低有效）
    output reg        red,
    output reg        yellow,
    output reg        green
);

    // 状态定义（使用 parameter）
    parameter [1:0] S_GREEN  = 2'b00;
    parameter [1:0] S_YELLOW = 2'b01;
    parameter [1:0] S_RED    = 2'b10;

    // 状态寄存器
    reg [1:0] current_state;
    reg [1:0] next_state;

    // 计数器（控制每个状态的持续时间）
    reg [3:0] counter;
    parameter [3:0] GREEN_TIME  = 4'd10;  // 绿灯持续 10 个周期
    parameter [3:0] YELLOW_TIME = 4'd3;   // 黄灯持续 3 个周期
    parameter [3:0] RED_TIME    = 4'd10;  // 红灯持续 10 个周期

    //===================================================
    // 1. 状态寄存器更新（时序逻辑）
    //===================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_GREEN;  // 复位后从绿灯开始
            counter <= 4'd0;
        end else begin
            current_state <= next_state;

            // 计数器逻辑
            if (current_state != next_state)
                counter <= 4'd0;  // 状态改变时重置计数器
            else
                counter <= counter + 1'b1;
        end
    end

    //===================================================
    // 2. 次态逻辑（组合逻辑）
    //===================================================
    always @(*) begin
        // 默认保持当前状态
        next_state = current_state;

        case (current_state)
            S_GREEN: begin
                if (counter >= GREEN_TIME - 1)
                    next_state = S_YELLOW;
            end

            S_YELLOW: begin
                if (counter >= YELLOW_TIME - 1)
                    next_state = S_RED;
            end

            S_RED: begin
                if (counter >= RED_TIME - 1)
                    next_state = S_GREEN;
            end

            default: begin
                next_state = S_GREEN;
            end
        endcase
    end

    //===================================================
    // 3. 输出逻辑（组合逻辑）
    //===================================================
    always @(*) begin
        // 默认全部灯灭
        red    = 1'b0;
        yellow = 1'b0;
        green  = 1'b0;

        case (current_state)
            S_GREEN:  green  = 1'b1;
            S_YELLOW: yellow = 1'b1;
            S_RED:    red    = 1'b1;
            default:  green  = 1'b1;  // 默认绿灯
        endcase
    end

endmodule
