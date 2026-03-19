/* 方式2：分解成基本门的综合结果 */

module mux_2to1(a, b, sel, y);
  input a;
  input b;
  input sel;
  output y;

  wire _0_;  // 中间信号
  wire _1_;  // 中间信号

  // 实现：y = (sel & b) | (!sel & a)

  // !sel
  $_NOT_ _2_ (
    .A(sel),
    .Y(_0_)
  );

  // !sel & a
  $_AND_ _3_ (
    .A(_0_),
    .B(a),
    .Y(_1_)
  );

  // sel & b
  $_AND_ _4_ (
    .A(sel),
    .B(b),
    .Y(_2_)
  );

  // (!sel & a) | (sel & b)
  $_OR_ _5_ (
    .A(_1_),
    .B(_2_),
    .Y(y)
  );

endmodule

/*
统计：
  Number of cells:    4
    $_AND_            2
    $_NOT_            1
    $_OR_             1

用了 4 个基本门！
*/
