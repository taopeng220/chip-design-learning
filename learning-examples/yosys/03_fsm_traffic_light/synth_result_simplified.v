/*
 * 交通灯 FSM 综合结果（简化版）
 * 展示 Yosys 如何把 RTL 状态机转换成门级网表
 */

module traffic_light(clk, rst_n, red, yellow, green);
  input clk;
  input rst_n;
  output red;
  output yellow;
  output green;

  //==============================================
  // 内部信号
  //==============================================
  wire [1:0] current_state;     // 当前状态
  wire [1:0] next_state;        // 次态
  wire [3:0] counter;           // 计数器
  wire [3:0] counter_next;      // 计数器次值

  // 大量中间信号（省略详细列举）
  wire n1, n2, n3, n4, n5, ...;

  //==============================================
  // Part 1: 状态寄存器（2 个 DFF）
  //==============================================

  // current_state[0]
  $_DFF_N_ state_reg_bit0 (
    .C(clk),
    .D(next_state[0]),
    .Q(current_state[0]),
    .R(!rst_n)
  );

  // current_state[1]
  $_DFF_N_ state_reg_bit1 (
    .C(clk),
    .D(next_state[1]),
    .Q(current_state[1]),
    .R(!rst_n)
  );

  //==============================================
  // Part 2: 计数器寄存器（4 个 DFF）
  //==============================================

  $_DFF_N_ counter_reg_0 (.C(clk), .D(counter_next[0]), .Q(counter[0]), .R(!rst_n));
  $_DFF_N_ counter_reg_1 (.C(clk), .D(counter_next[1]), .Q(counter[1]), .R(!rst_n));
  $_DFF_N_ counter_reg_2 (.C(clk), .D(counter_next[2]), .Q(counter[2]), .R(!rst_n));
  $_DFF_N_ counter_reg_3 (.C(clk), .D(counter_next[3]), .Q(counter[3]), .R(!rst_n));

  //==============================================
  // Part 3: 次态逻辑（组合逻辑）
  //==============================================

  // 状态判断
  // is_green = (current_state == 2'b00)
  $_NOR_ is_green_gate1 (.A(current_state[0]), .B(current_state[1]), .Y(is_green));

  // is_yellow = (current_state == 2'b01)
  $_AND_ is_yellow_gate1 (.A(current_state[0]), .B(!current_state[1]), .Y(is_yellow));

  // is_red = (current_state == 2'b10)
  $_AND_ is_red_gate1 (.A(!current_state[0]), .B(current_state[1]), .Y(is_red));

  // 计数器比较
  // counter_ge_9 = (counter >= 4'd9)
  // 实现为比较器逻辑
  $_AND_ cmp1 (.A(counter[3]), .B(counter[0]), .Y(n1));
  $_OR_  cmp2 (.A(n1), .B(...), .Y(counter_ge_9));

  // counter_ge_2 = (counter >= 4'd2)
  $_OR_ cmp3 (.A(counter[1]), .B(counter[2]), .Y(counter_ge_2));

  // 次态逻辑
  // next_state[0] = (is_green & counter_ge_9) | (is_red & counter_ge_9) | ...
  $_AND_ ns0_and1 (.A(is_green), .B(counter_ge_9), .Y(n10));
  $_AND_ ns0_and2 (.A(is_red), .B(counter_ge_9), .Y(n11));
  $_OR_  ns0_or1  (.A(n10), .B(n11), .Y(next_state[0]));

  // next_state[1] = ...
  $_MUX_ ns1_mux (.A(...), .B(...), .S(...), .Y(next_state[1]));

  //==============================================
  // Part 4: 计数器逻辑（组合逻辑）
  //==============================================

  // state_changed = (current_state != next_state)
  $_XOR_ change1 (.A(current_state[0]), .B(next_state[0]), .Y(c1));
  $_XOR_ change2 (.A(current_state[1]), .B(next_state[1]), .Y(c2));
  $_OR_  change3 (.A(c1), .B(c2), .Y(state_changed));

  // counter_next = state_changed ? 0 : counter + 1
  // 加法器实现
  $_XOR_ add0 (.A(counter[0]), .B(1'b1), .Y(sum0));
  // ... 更多加法器逻辑

  // MUX 选择
  $_MUX_ cnt_mux0 (.A(sum0), .B(1'b0), .S(state_changed), .Y(counter_next[0]));
  $_MUX_ cnt_mux1 (.A(sum1), .B(1'b0), .S(state_changed), .Y(counter_next[1]));
  $_MUX_ cnt_mux2 (.A(sum2), .B(1'b0), .S(state_changed), .Y(counter_next[2]));
  $_MUX_ cnt_mux3 (.A(sum3), .B(1'b0), .S(state_changed), .Y(counter_next[3]));

  //==============================================
  // Part 5: 输出逻辑（组合逻辑 - 2-to-3 译码）
  //==============================================

  // green = (current_state == 2'b00)
  assign green = is_green;

  // yellow = (current_state == 2'b01)
  assign yellow = is_yellow;

  // red = (current_state == 2'b10)
  assign red = is_red;

endmodule

/*
===============================================
综合统计（预期）
===============================================

总单元数: ~35-40 个

寄存器:
  - 2 个 DFF (状态)
  - 4 个 DFF (计数器)

组合逻辑:
  - 比较器 (判断 counter 阈值)
  - 加法器 (counter + 1)
  - MUX (选择次态和计数器值)
  - AND/OR/NOT (状态译码和控制逻辑)

面积估算:
  - 如果用 180nm 工艺
  - 约 200-300 个门当量 (gate equivalent)

===============================================
与 FusionCompiler 输出的对比
===============================================

相同点:
✓ 都会生成 DFF 存储状态和计数器
✓ 都会用组合逻辑实现次态转换
✓ 都会优化不必要的逻辑

不同点:
✗ FC 会有物理属性（坐标、orientation）
✗ FC 会映射到工艺库标准单元（如 DFF_X1, AND2_X2）
✗ FC 会有时序标注（setup/hold time）
✗ Yosys 只是通用门，还需要 technology mapping

===============================================
*/
