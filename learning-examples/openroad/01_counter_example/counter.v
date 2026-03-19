// 4-bit 计数器设计
// 用于演示完整的 OpenROAD 流程

module counter (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    output reg  [3:0] count,
    output wire       overflow
);

    // 计数逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 4'b0000;
        end else if (enable) begin
            count <= count + 1'b1;
        end
    end

    // 溢出检测（当计数到最大值时）
    assign overflow = (count == 4'b1111) && enable;

endmodule
