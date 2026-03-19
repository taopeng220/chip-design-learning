// 简单的 4-bit 加法器
// 这是我们的第一个用开源工具综合的设计！

module adder_4bit (
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    assign {cout, sum} = a + b + cin;

endmodule
