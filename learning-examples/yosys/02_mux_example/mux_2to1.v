// 2选1 多路选择器
module mux_2to1 (
    input  a,
    input  b,
    input  sel,
    output y
);

    assign y = sel ? b : a;

endmodule
