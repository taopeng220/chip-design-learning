/* 方式1：使用 MUX 原语的综合结果 */

module mux_2to1(a, b, sel, y);
  input a;
  input b;
  input sel;
  output y;

  // Yosys 保留了 MUX 结构！
  $_MUX_ _0_ (
    .A(a),      // sel=0 时选择 a
    .B(b),      // sel=1 时选择 b
    .S(sel),    // 选择信号
    .Y(y)       // 输出
  );

endmodule

/*
统计：
  Number of cells:    1
    $_MUX_            1

只用了 1 个 MUX 门！
*/
