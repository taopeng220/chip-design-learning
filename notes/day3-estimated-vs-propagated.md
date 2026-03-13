# Estimated vs Propagated - 深入理解

📅 日期：2026-03-13
🎯 澄清 STA 报告中的关键标记

---

## 🔍 两个关键术语

在 STA 报告中，您会看到两个标记：
- `(estimated)` 或 `(est)`
- `(propagated)` 或 `(prop)`

它们分别指什么？

---

## 📊 1. Wire Delay: Estimated

### 适用场景
**Placement 后，Routing 前**

### 含义
Wire Delay 是**基于距离估算**的，不是实际走线

### 示例

```
Timing Report (Post-Placement):
────────────────────────────────────────────
Point                          Incr    Path
────────────────────────────────────────────
U1/Y                           0.25    1.00
U2/A              (est)        0.05    1.05  ← 估算的 Wire Delay
U2/Y                           0.30    1.35
────────────────────────────────────────────
```

### 计算方法

```
估算公式：
  Wire Delay = k × distance

其中：
  distance = Manhattan距离（|x1-x2| + |y1-y2|）
  k = 估算系数（来自工艺参数）

例子：
  U1 在 (100, 50)
  U2 在 (150, 80)

  Distance = |150-100| + |80-50| = 50 + 30 = 80um

  Wire Delay ≈ 0.5ps/um × 80um = 40ps
```

### 误差范围
- ±10% ~ ±20%
- 因为实际走线可能绕路、换层

---

## ⏰ 2. Clock Delay: Propagated

### 适用场景
**CTS 后**

### 含义
Clock Delay 是**实际的时钟树延迟**，不再是 ideal（假设为 0）

### 示例

**CTS 前（ideal clock）:**
```
Timing Report (Pre-CTS):
────────────────────────────────────────────
Point                          Incr    Path
────────────────────────────────────────────
clock clk (rise edge)          0.00    0.00
clock network delay (ideal)    0.00    0.00  ← 假设为 0
DFF1/CK                        0.00    0.00
DFF1/Q                         0.45    0.45
...
data arrival time                      1.85

clock clk (rise edge)         10.00   10.00
clock network delay (ideal)    0.00   10.00  ← 假设为 0
DFF2/CK                              10.00
library setup time            -0.12    9.88
data required time                     9.88
────────────────────────────────────────────
slack (MET)                            8.03
```

**CTS 后（propagated clock）:**
```
Timing Report (Post-CTS):
────────────────────────────────────────────
Point                            Incr    Path
────────────────────────────────────────────
clock clk (rise edge)            0.00    0.00
clock network delay (propagated) 0.85    0.85  ← 实际延迟！
DFF1/CK                          0.00    0.85
DFF1/Q                           0.45    1.30
...
data arrival time                        2.70

clock clk (rise edge)           10.00   10.00
clock network delay (propagated) 0.87   10.87  ← 实际延迟！
DFF2/CK                                 10.87
library setup time              -0.12   10.75
data required time                      10.75
────────────────────────────────────────────
slack (MET)                              8.05
```

### 关键变化

```
Launch Path:
  Ideal:      0.00 + 1.85 = 1.85ns
  Propagated: 0.85 + 1.85 = 2.70ns  (+0.85ns)

Capture Path:
  Ideal:      10.00 - 0.12 = 9.88ns
  Propagated: 10.87 - 0.12 = 10.75ns  (+0.87ns)

Slack:
  Ideal:      9.88 - 1.85 = 8.03ns
  Propagated: 10.75 - 2.70 = 8.05ns  (几乎不变！)
```

**为什么 Slack 几乎不变？**
- Launch Clock 增加了 0.85ns
- Capture Clock 增加了 0.87ns
- 相互抵消！
- 只有 Skew（0.02ns）的影响

---

## 🎯 完整对比表

| 类型 | 标记 | 什么被估算/实际化 | 出现时机 | 精度 |
|------|------|------------------|---------|------|
| **Wire Delay (est)** | `(est)` | 连线延迟 | Placement 后<br>Routing 前 | ±10-20% |
| **Wire Delay (实际)** | 无标记 | 连线延迟 | Routing 后<br>SPEF 提取后 | ±2-5% |
| **Clock (ideal)** | `(ideal)` | 时钟延迟 | CTS 前 | 完全不准！ |
| **Clock (propagated)** | `(propagated)` | 时钟延迟 | CTS 后 | 准确 ✅ |

---

## 📝 实际 STA 报告解读

### 例子 1: Placement 后

```
────────────────────────────────────────────
Point                          Incr    Path
────────────────────────────────────────────
clock clk (rise edge)          0.00    0.00
clock network delay (ideal)    0.00    0.00   ← Clock: ideal（不准）
DFF1/CK                        0.00    0.00
DFF1/Q                         0.45    0.45
U1/A              (est)        0.05    0.50   ← Wire: estimated（估算）
U1/Y                           0.25    0.75
U2/A              (est)        0.03    0.78   ← Wire: estimated（估算）
U2/Y                           0.30    1.08
DFF2/D            (est)        0.02    1.10   ← Wire: estimated（估算）
data arrival time                      1.10

clock clk (rise edge)         10.00   10.00
clock network delay (ideal)    0.00   10.00   ← Clock: ideal（不准）
DFF2/CK                              10.00
library setup time            -0.12    9.88
data required time                     9.88
────────────────────────────────────────────
slack (MET)                            8.78

警告：
  - Clock 是 ideal → 不准确
  - Wire Delay 是 estimated → 有误差
  - Slack 可能偏乐观
```

---

### 例子 2: CTS + Routing 后（SPEF）

```
────────────────────────────────────────────
Point                            Incr    Path
────────────────────────────────────────────
clock clk (rise edge)            0.00    0.00
clock network delay (propagated) 0.85    0.85   ← Clock: propagated（准确！）
DFF1/CK                          0.00    0.85
DFF1/Q                           0.45    1.30
U1/A                             0.08    1.38   ← Wire: 无标记（实际值！）
U1/Y                             0.25    1.63
U2/A                             0.06    1.69   ← Wire: 无标记（实际值！）
U2/Y                             0.30    1.99
DFF2/D                           0.04    2.03   ← Wire: 无标记（实际值！）
data arrival time                        2.03

clock clk (rise edge)           10.00   10.00
clock network delay (propagated) 0.87   10.87   ← Clock: propagated（准确！）
DFF2/CK                                 10.87
library setup time              -0.12   10.75
data required time                      10.75
────────────────────────────────────────────
slack (MET)                              8.72

这个报告可信！✅
  - Clock 是 propagated → 准确
  - Wire Delay 无 (est) 标记 → 实际值
  - Slack 是最终值
```

---

## 💡 关键启示

### 1. 两种"不准确"

**Wire Delay 的不准确：**
- 原因：还没有实际走线
- 解决：等 Routing + SPEF

**Clock Delay 的不准确：**
- 原因：还没有构建时钟树
- 解决：运行 CTS

### 2. 在 FusionCompiler 中的应用

**综合后看到 `ideal clock`：**
```tcl
compile_ultra

report_timing
# 会看到 clock network delay (ideal)
# 不要相信这个 Slack！
```

**需要 propagate clock：**
```tcl
# 方法 1: 手动设置
set_propagated_clock [all_clocks]

# 方法 2: 运行 CTS
clock_opt

report_timing
# 现在会看到 clock network delay (propagated)
# 这个 Slack 才可信
```

### 3. 判断报告可信度

**Checklist:**
```
查看 STA 报告时：

□ Clock 是 propagated？
  - ✅ 是 → 可信
  - ❌ 否（ideal）→ 不可信

□ Wire Delay 有 (est) 标记？
  - ✅ 无标记 → 实际值（可信）
  - ⚠️ 有 (est) → 估算值（留 margin）

□ 是否有 SPEF？
  - ✅ 是 → 最可信
  - ⚠️ 否 → 仍有误差
```

---

## 🎯 总结

### 用户的回答补充

**原回答：**
> "区别在于 wire delay 的估算"

**完整答案应该是：**

1. **`(estimated)` - Wire Delay 估算**
   - 出现在：Placement 后，Routing 前
   - 含义：基于距离估算的 Wire Delay
   - 误差：±10-20%

2. **`(propagated)` - Clock Delay 实际化**
   - 出现在：CTS 后
   - 含义：实际时钟树的延迟，不再是 ideal（0）
   - 精度：准确 ✅

**两者的区别：**
- Estimated 是关于 **Wire**（数据路径）
- Propagated 是关于 **Clock**（时钟路径）
- 都是从"估算/假设"到"实际/精确"的演变

---

## 🤔 思考题

### Q1: 如果看到 `clock network delay (ideal)`，说明什么？

**答案：**
- 还没有运行 CTS
- Clock Delay 假设为 0
- Slack 不准确，可能偏乐观

---

### Q2: Wire Delay 没有 `(est)` 标记，就一定准确吗？

**答案：**
- 不一定！
- Routing 后没有 SPEF → 仍是估算（基于 Global Route）
- 只有读入 SPEF 后才是真正精确

---

### Q3: 为什么 CTS 后 Slack 几乎不变？

**答案：**
- Launch Clock 和 Capture Clock 都从 ideal (0) 变成 propagated (0.8x)
- 两者相互抵消
- 只有 Skew 影响 Slack
- Skew 小（20ps）→ Slack 变化小

---

**现在您完全理解了吗？** 😊
