/* 这是 Yosys 综合后的门级网表示例 */
/* 相当于 FusionCompiler 输出的 PrePlace 网表（但没有物理信息）*/

module adder_4bit(a, b, cin, sum, cout);
  input [3:0] a;
  input [3:0] b;
  input cin;
  output [3:0] sum;
  output cout;

  // 内部连线（类似 FC 生成的中间信号）
  wire _00_;
  wire _01_;
  wire _02_;
  wire _03_;
  wire _04_;
  wire _05_;
  wire _06_;
  wire _07_;
  wire _08_;
  wire _09_;
  wire _10_;
  wire _11_;
  wire _12_;

  // sum[0] = a[0] ^ b[0] ^ cin
  $_XOR_ _13_ (
    .A(a[0]),
    .B(b[0]),
    .Y(_00_)
  );
  $_XOR_ _14_ (
    .A(_00_),
    .B(cin),
    .Y(sum[0])
  );

  // carry[0] = (a[0] & b[0]) | (cin & (a[0] ^ b[0]))
  $_AND_ _15_ (
    .A(a[0]),
    .B(b[0]),
    .Y(_01_)
  );
  $_AND_ _16_ (
    .A(cin),
    .B(_00_),
    .Y(_02_)
  );
  $_OR_ _17_ (
    .A(_01_),
    .B(_02_),
    .Y(_03_)  // carry to bit 1
  );

  // sum[1] = a[1] ^ b[1] ^ carry[0]
  $_XOR_ _18_ (
    .A(a[1]),
    .B(b[1]),
    .Y(_04_)
  );
  $_XOR_ _19_ (
    .A(_04_),
    .B(_03_),
    .Y(sum[1])
  );

  // carry[1]
  $_AND_ _20_ (
    .A(a[1]),
    .B(b[1]),
    .Y(_05_)
  );
  $_AND_ _21_ (
    .A(_03_),
    .B(_04_),
    .Y(_06_)
  );
  $_OR_ _22_ (
    .A(_05_),
    .B(_06_),
    .Y(_07_)  // carry to bit 2
  );

  // sum[2] = a[2] ^ b[2] ^ carry[1]
  $_XOR_ _23_ (
    .A(a[2]),
    .B(b[2]),
    .Y(_08_)
  );
  $_XOR_ _24_ (
    .A(_08_),
    .B(_07_),
    .Y(sum[2])
  );

  // carry[2]
  $_AND_ _25_ (
    .A(a[2]),
    .B(b[2]),
    .Y(_09_)
  );
  $_AND_ _26_ (
    .A(_07_),
    .B(_08_),
    .Y(_10_)
  );
  $_OR_ _27_ (
    .A(_09_),
    .B(_10_),
    .Y(_11_)  // carry to bit 3
  );

  // sum[3] = a[3] ^ b[3] ^ carry[2]
  $_XOR_ _28_ (
    .A(a[3]),
    .B(b[3]),
    .Y(_12_)
  );
  $_XOR_ _29_ (
    .A(_12_),
    .B(_11_),
    .Y(sum[3])
  );

  // cout = (a[3] & b[3]) | (carry[2] & (a[3] ^ b[3]))
  $_AND_ _30_ (
    .A(a[3]),
    .B(b[3]),
    .Y(_13_)
  );
  $_AND_ _31_ (
    .A(_11_),
    .B(_12_),
    .Y(_14_)
  );
  $_OR_ _32_ (
    .A(_13_),
    .B(_14_),
    .Y(cout)
  );

endmodule
