/* Generated from the transparent-build single-type soldering steps. */
window.AGENTPAD_STEPS = [
  {
    "id": "step-01",
    "code": "01",
    "count": "30 件",
    "color": "#2563EB",
    "phase": "P1",
    "phaseTitle": "被动件",
    "title": "30 × 100 nF 固定去耦",
    "subtitle": "0402 X7R",
    "image": "step-01.zh-CN.png",
    "summary": "先在底面完成 30 颗固定 100 nF 去耦电容。",
    "parts": [
      "型号 · 100 nF 0402 X7R",
      "封装 · 0402 / C_0402_1005Metric",
      "位号 · C1-C10, C13, C20-C24, C26-C39"
    ],
    "steps": [
      "按 C1-C10、C13、C20-C24、C26-C39 逐一核对位号。",
      "每颗先固定一端，确认无立碑和偏移后再焊另一端。",
      "本步不要混入 C40-C49；它们属于透明版侧灯步骤。"
    ],
    "checkpoint": "30 颗全部安装，C25 不在此步。",
    "method": "烙铁逐件焊 / 低风速热风",
    "side": "bottom",
    "optional": false,
    "index": 1
  },
  {
    "id": "step-02",
    "code": "02",
    "count": "4 件",
    "color": "#2563EB",
    "phase": "P1",
    "phaseTitle": "被动件",
    "title": "4 × 1 uF",
    "subtitle": "0402 X5R",
    "image": "step-02.zh-CN.png",
    "summary": "焊接稳压器与 LDO 输入输出的 4 颗 1 uF 电容。",
    "parts": [
      "型号 · 1 uF 0402 X5R",
      "封装 · 0402 / C_0402_1005Metric",
      "位号 · C11, C12, C14, C15"
    ],
    "steps": [
      "先焊 C14、C15，再焊 C11、C12。",
      "逐颗确认焊盘没有桥连。",
      "不要与 100 nF 或 10 uF 电容混袋。"
    ],
    "checkpoint": "4 颗均为 1 uF，不得用 100 nF 替代。",
    "method": "烙铁逐件焊 / 低风速热风",
    "side": "bottom",
    "optional": false,
    "index": 2
  },
  {
    "id": "step-03",
    "code": "03",
    "count": "2 件",
    "color": "#2563EB",
    "phase": "P1",
    "phaseTitle": "被动件",
    "title": "2 × 10 uF 大容量",
    "subtitle": "0805 X5R",
    "image": "step-03.zh-CN.png",
    "summary": "安装 +5 V 与 +3V3 的 2 颗大容量储能电容。",
    "parts": [
      "型号 · 10 uF 0805 X5R",
      "封装 · 0805 / C_0805_2012Metric",
      "位号 · C16, C17"
    ],
    "steps": [
      "先给一个焊盘上锡，放平元件后焊另一端。",
      "确认底部没有立碑或翘起。",
      "这两颗比 0402 高，后面避免再被热风反复吹。"
    ],
    "checkpoint": "C16、C17 均为 10 uF 0805。",
    "method": "烙铁逐件焊 / 热风",
    "side": "bottom",
    "optional": false,
    "index": 3
  },
  {
    "id": "step-04",
    "code": "04",
    "count": "2 件",
    "color": "#2563EB",
    "phase": "P1",
    "phaseTitle": "被动件",
    "title": "2 × 15 pF 晶振负载",
    "subtitle": "0402 C0G",
    "image": "step-04.zh-CN.png",
    "summary": "安装 12 MHz 晶振的两颗负载电容。",
    "parts": [
      "型号 · 15 pF 0402 C0G",
      "封装 · 0402 / C_0402_1005Metric",
      "位号 · C18, C19"
    ],
    "steps": [
      "只使用 15 pF C0G，不要用 100 nF 替代。",
      "分别安装 C18、C19。",
      "焊完确认没有与晶振焊盘短路。"
    ],
    "checkpoint": "容值和温度特性必须正确。",
    "method": "烙铁逐件焊 / 热风",
    "side": "bottom",
    "optional": false,
    "index": 4
  },
  {
    "id": "step-05",
    "code": "05",
    "count": "2 件",
    "color": "#2563EB",
    "phase": "P1",
    "phaseTitle": "被动件",
    "title": "2 × 5.1 kΩ",
    "subtitle": "USB-C CC",
    "image": "step-05.zh-CN.png",
    "summary": "焊接 USB-C 两颗 CC 下拉电阻。",
    "parts": [
      "型号 · 5.1 kΩ 1% 0402",
      "封装 · 0402 / R_0402_1005Metric",
      "位号 · R1, R2"
    ],
    "steps": [
      "R1、R2 都是 5.1 kΩ。",
      "确认没有与 4.7 kΩ 电阻混袋。",
      "逐颗固定两端，避免立碑。"
    ],
    "checkpoint": "R1、R2 均为 5.1 kΩ。",
    "method": "烙铁逐件焊",
    "side": "bottom",
    "optional": false,
    "index": 5
  },
  {
    "id": "step-06",
    "code": "06",
    "count": "2 件",
    "color": "#2563EB",
    "phase": "P1",
    "phaseTitle": "被动件",
    "title": "2 × 27 Ω",
    "subtitle": "USB D+/D-",
    "image": "step-06.zh-CN.png",
    "summary": "焊接 USB D+/D- 两颗串联电阻。",
    "parts": [
      "型号 · 27 Ω 0402",
      "封装 · 0402 / R_0402_1005Metric",
      "位号 · R3, R4"
    ],
    "steps": [
      "R3、R4 都是 27 Ω。",
      "焊完用放大镜检查 USB 数据线焊盘。",
      "不要用 0 Ω 或 1 kΩ 替代。"
    ],
    "checkpoint": "R3、R4 均为 27 Ω。",
    "method": "烙铁逐件焊",
    "side": "bottom",
    "optional": false,
    "index": 6
  },
  {
    "id": "step-07",
    "code": "07",
    "count": "4 件",
    "color": "#2563EB",
    "phase": "P1",
    "phaseTitle": "被动件",
    "title": "4 × 1 kΩ",
    "subtitle": "RC / BOOT",
    "image": "step-07.zh-CN.png",
    "summary": "焊接晶振、BOOTSEL 和摇杆 RC 的 4 颗 1 kΩ。",
    "parts": [
      "型号 · 1 kΩ 0402",
      "封装 · 0402 / R_0402_1005Metric",
      "位号 · R5, R6, R11, R12"
    ],
    "steps": [
      "按 R5、R6、R11、R12 逐颗核对。",
      "不要与 10 kΩ、4.7 kΩ 混装。",
      "每颗确认电阻体完全贴平。"
    ],
    "checkpoint": "4 颗全部为 1 kΩ。",
    "method": "烙铁逐件焊",
    "side": "bottom",
    "optional": false,
    "index": 7
  },
  {
    "id": "step-08",
    "code": "08",
    "count": "1 件",
    "color": "#2563EB",
    "phase": "P1",
    "phaseTitle": "被动件",
    "title": "1 × 10 kΩ",
    "subtitle": "RUN PULL-UP",
    "image": "step-08.zh-CN.png",
    "summary": "安装 RP2040 RUN 引脚的 10 kΩ 上拉电阻。",
    "parts": [
      "型号 · 10 kΩ 0402",
      "封装 · 0402 / R_0402_1005Metric",
      "位号 · R7"
    ],
    "steps": [
      "只安装 R7。",
      "确认阻值为 10 kΩ。",
      "焊完检查两端焊盘无桥连。"
    ],
    "checkpoint": "R7 = 10 kΩ。",
    "method": "烙铁",
    "side": "bottom",
    "optional": false,
    "index": 8
  },
  {
    "id": "step-09",
    "code": "09",
    "count": "2 件",
    "color": "#2563EB",
    "phase": "P1",
    "phaseTitle": "被动件",
    "title": "2 × 4.7 kΩ",
    "subtitle": "I2C PULL-UP",
    "image": "step-09.zh-CN.png",
    "summary": "安装 I2C SDA/SCL 的两颗 4.7 kΩ 上拉。",
    "parts": [
      "型号 · 4.7 kΩ 0402",
      "封装 · 0402 / R_0402_1005Metric",
      "位号 · R8, R9"
    ],
    "steps": [
      "R8、R9 都是 4.7 kΩ。",
      "不要与 5.1 kΩ 混袋。",
      "逐颗确认焊端完整。"
    ],
    "checkpoint": "R8、R9 均为 4.7 kΩ。",
    "method": "烙铁逐件焊",
    "side": "bottom",
    "optional": false,
    "index": 9
  },
  {
    "id": "step-10",
    "code": "10",
    "count": "1 件",
    "color": "#2563EB",
    "phase": "P1",
    "phaseTitle": "被动件",
    "title": "1 × 0 Ω",
    "subtitle": "TOUCH AHLB STRAP",
    "image": "step-10.zh-CN.png",
    "summary": "安装触摸 AHLB 配置的 0 Ω 跳线。",
    "parts": [
      "型号 · 0 Ω 0402",
      "封装 · 0402 / R_0402_1005Metric",
      "位号 · R10"
    ],
    "steps": [
      "只安装 R10。",
      "确认没有装成普通电阻。",
      "R10 决定触摸高有效配置，不能漏装。"
    ],
    "checkpoint": "R10 = 0 Ω。",
    "method": "烙铁",
    "side": "bottom",
    "optional": false,
    "index": 10
  },
  {
    "id": "step-11",
    "code": "11",
    "count": "1 件",
    "color": "#2563EB",
    "phase": "P1",
    "phaseTitle": "被动件",
    "title": "1 × 600 Ω 磁珠",
    "subtitle": "ADC_AVDD FILTER",
    "image": "step-11.zh-CN.png",
    "summary": "安装 ADC_AVDD 电源滤波磁珠。",
    "parts": [
      "型号 · 600 Ω @ 100 MHz",
      "封装 · 0402 / L_0402_1005Metric",
      "位号 · FB1"
    ],
    "steps": [
      "只安装 FB1。",
      "磁珠外形像电阻，不能混入 R 袋。",
      "确认焊盘两端无桥连。"
    ],
    "checkpoint": "FB1 = 600 Ω @ 100 MHz。",
    "method": "烙铁 / 热风",
    "side": "bottom",
    "optional": false,
    "index": 11
  },
  {
    "id": "step-12",
    "code": "12",
    "count": "1 件",
    "color": "#0F766E",
    "phase": "P2",
    "phaseTitle": "电源",
    "title": "1 × AP2112K-3.3",
    "subtitle": "3.3 V LDO",
    "image": "step-12.zh-CN.png",
    "summary": "先安装 3.3 V LDO，为后续电源测试做准备。",
    "parts": [
      "型号 · AP2112K-3.3",
      "封装 · SOT-23-5",
      "位号 · U3"
    ],
    "steps": [
      "对齐 U3 pin 1。",
      "先固定一只脚，确认芯片平贴后焊完。",
      "检查 5 只脚之间没有锡桥。"
    ],
    "checkpoint": "方向、pin 1 和脚间连锡。",
    "method": "锡膏 / 助焊剂 + 热风",
    "side": "bottom",
    "optional": false,
    "index": 12
  },
  {
    "id": "step-13",
    "code": "13",
    "count": "1 件",
    "color": "#0F766E",
    "phase": "P2",
    "phaseTitle": "电源",
    "title": "1 × USBLC6-2SC6",
    "subtitle": "USB ESD ARRAY",
    "image": "step-13.zh-CN.png",
    "summary": "安装 USB D+/D- ESD 保护阵列。",
    "parts": [
      "型号 · USBLC6-2SC6",
      "封装 · SOT-23-6",
      "位号 · U4"
    ],
    "steps": [
      "对齐 U4 pin 1。",
      "先固定对角脚，再焊余下四脚。",
      "重点检查 D+、D-、VBUS 相邻脚无桥连。"
    ],
    "checkpoint": "pin 1 方向和 USB 数据脚连锡。",
    "method": "锡膏 / 助焊剂 + 热风",
    "side": "bottom",
    "optional": false,
    "index": 13
  },
  {
    "id": "step-14",
    "code": "14",
    "count": "1 件",
    "color": "#0F766E",
    "phase": "P2",
    "phaseTitle": "电源",
    "title": "1 × 750 mA 保险丝",
    "subtitle": "USB INPUT PROTECTION",
    "image": "step-14.zh-CN.png",
    "summary": "安装 USB 输入自恢复保险丝。",
    "parts": [
      "型号 · MF-MSMF075/24-2",
      "封装 · 1812 / Fuse_1812_4532Metric",
      "位号 · F1"
    ],
    "steps": [
      "只安装 F1。",
      "1812 封装必须完全平贴。",
      "确认两端焊盘均有焊锡，不使用过多锡。"
    ],
    "checkpoint": "F1 无裂纹、无偏斜、两端可靠连接。",
    "method": "烙铁 / 热风",
    "side": "bottom",
    "optional": false,
    "index": 14
  },
  {
    "id": "step-15",
    "code": "15",
    "count": "1 件",
    "color": "#0F766E",
    "phase": "P2",
    "phaseTitle": "电源",
    "title": "1 × USB-C 16P",
    "subtitle": "POWER CHECKPOINT",
    "image": "step-15.zh-CN.png",
    "summary": "安装 USB-C 座；完成后先验证 3.3 V，再继续主控。",
    "parts": [
      "型号 · TYPE-C-31-M-12",
      "封装 · USB_C_Receptacle_HRO",
      "位号 · J1"
    ],
    "steps": [
      "先固定两端壳脚，确认开口朝板外。",
      "逐脚焊 VBUS、CC、D+、D- 与 GND。",
      "限流 100 mA 上电，测量 U3 输出约 3.3 V。",
      "3.3 V 异常时停止，不要安装 U1。"
    ],
    "checkpoint": "USB 无短路、3.3 V 正常后才能进入下一步。",
    "method": "锡膏 + 热风，壳脚可补烙铁",
    "side": "bottom",
    "optional": false,
    "index": 15
  },
  {
    "id": "step-16",
    "code": "16",
    "count": "1 件",
    "color": "#EA580C",
    "phase": "P3",
    "phaseTitle": "主控",
    "title": "1 × RP2040",
    "subtitle": "QFN-56 · 0.4 mm",
    "image": "step-16.zh-CN.png",
    "summary": "安装本板最难的高密度主控芯片。",
    "parts": [
      "型号 · RP2040",
      "封装 · QFN-56 + EP 3.2 × 3.2",
      "位号 · U1"
    ],
    "steps": [
      "焊盘薄涂锡膏，中心散热焊盘只放少量。",
      "严格对齐 U1 pin 1。",
      "低风速热风回流，让芯片自行回位。",
      "冷却后用助焊剂和吸锡带清理脚间连锡。"
    ],
    "checkpoint": "四边无连锡、中心焊盘已回流、3.3 V 无短路。",
    "method": "锡膏 + 热风（不能只靠烙铁）",
    "side": "bottom",
    "optional": false,
    "index": 16
  },
  {
    "id": "step-17",
    "code": "17",
    "count": "1 件",
    "color": "#EA580C",
    "phase": "P3",
    "phaseTitle": "主控",
    "title": "1 × 16 MB Flash",
    "subtitle": "QSPI SOIC-8",
    "image": "step-17.zh-CN.png",
    "summary": "安装 RP2040 的 QSPI Flash。",
    "parts": [
      "型号 · W25Q128JVSIQ",
      "封装 · SOIC-8 / 1.27 mm",
      "位号 · U2"
    ],
    "steps": [
      "U2 对齐 pin 1。",
      "使用热风或逐脚拖焊。",
      "检查 8 只脚均连接且相邻脚无桥连。"
    ],
    "checkpoint": "pin 1 方向、8 脚焊接完整。",
    "method": "热风 / 拖焊",
    "side": "bottom",
    "optional": false,
    "index": 17
  },
  {
    "id": "step-18",
    "code": "18",
    "count": "1 件",
    "color": "#EA580C",
    "phase": "P3",
    "phaseTitle": "主控",
    "title": "1 × 12 MHz 晶振",
    "subtitle": "4-PAD CRYSTAL",
    "image": "step-18.zh-CN.png",
    "summary": "安装 RP2040 的 12 MHz 晶振。",
    "parts": [
      "型号 · ABM8-272-T3",
      "封装 · 3225 / 4-pad",
      "位号 · Y1"
    ],
    "steps": [
      "按丝印方向放正 Y1。",
      "先固定一个角，再焊其余三脚。",
      "不要歪斜或悬空。"
    ],
    "checkpoint": "Y1 方向正确，四脚可靠连接。",
    "method": "烙铁点焊四角 / 热风",
    "side": "bottom",
    "optional": false,
    "index": 18
  },
  {
    "id": "step-19",
    "code": "19",
    "count": "1 件",
    "color": "#7C3AED",
    "phase": "P4",
    "phaseTitle": "辅助 IC",
    "title": "1 × SN74LVC1T45",
    "subtitle": "LED LEVEL SHIFTER",
    "image": "step-19.zh-CN.png",
    "summary": "安装 LED 数据电平转换器。",
    "parts": [
      "型号 · SN74LVC1T45DBVR",
      "封装 · SOT-23-6",
      "位号 · U5"
    ],
    "steps": [
      "U5 对齐 pin 1。",
      "先固定对角脚，再焊余下四脚。",
      "检查六脚之间没有锡桥。"
    ],
    "checkpoint": "pin 1 正确，六脚无桥连。",
    "method": "烙铁 / 热风",
    "side": "bottom",
    "optional": false,
    "index": 19
  },
  {
    "id": "step-20",
    "code": "20",
    "count": "1 件",
    "color": "#7C3AED",
    "phase": "P4",
    "phaseTitle": "辅助 IC",
    "title": "1 × TTP223-BA6",
    "subtitle": "TOUCH CONTROLLER",
    "image": "step-20.zh-CN.png",
    "summary": "安装触摸输入控制器。",
    "parts": [
      "型号 · TTP223-BA6",
      "封装 · SOT-23-6",
      "位号 · U6"
    ],
    "steps": [
      "U6 对齐 pin 1。",
      "先固定对角脚，再焊余下四脚。",
      "复核 R10 已在第一步组中安装。"
    ],
    "checkpoint": "pin 1 正确，六脚无桥连，R10 = 0 Ω。",
    "method": "烙铁 / 热风",
    "side": "bottom",
    "optional": false,
    "index": 20
  },
  {
    "id": "step-21",
    "code": "21",
    "count": "10 件",
    "color": "#0891B2",
    "phase": "P5",
    "phaseTitle": "灯光",
    "title": "10 × 100 nF 侧灯去耦",
    "subtitle": "TRANSLUCENT ONLY",
    "image": "step-21.zh-CN.png",
    "summary": "透明版固定安装的 10 颗侧灯去耦电容。",
    "parts": [
      "型号 · 100 nF 0402 X7R",
      "封装 · 0402 / C_0402_1005Metric",
      "位号 · C40-C49"
    ],
    "steps": [
      "按 C40-C49 逐一安装。",
      "每颗先固定一端，再焊另一端。",
      "检查电容与侧面 LED 焊盘不短路。"
    ],
    "checkpoint": "10 颗全部安装，不得留空。",
    "method": "烙铁逐件焊 / 热风",
    "side": "bottom",
    "optional": false,
    "index": 21
  },
  {
    "id": "step-22",
    "code": "22",
    "count": "14 件",
    "color": "#0891B2",
    "phase": "P5",
    "phaseTitle": "灯光",
    "title": "14 × 反装 RGB LED",
    "subtitle": "PER-KEY LED",
    "image": "step-22.zh-CN.png",
    "summary": "安装 14 颗主灯链 LED1-LED14。",
    "parts": [
      "型号 · SK6812MINI-E",
      "封装 · LED_6028R 反装",
      "位号 · LED1-LED14"
    ],
    "steps": [
      "每颗按板上 pin 1 / DIN 标记对齐。",
      "先固定对角两点，再焊另外两点。",
      "LED13 在 2U 轴位，LED14 是独立指示位。"
    ],
    "checkpoint": "14 颗方向全部正确，一颗反装会导致后续整串异常。",
    "method": "烙铁逐脚焊 / 低风速热风",
    "side": "bottom",
    "optional": false,
    "index": 22
  },
  {
    "id": "step-23",
    "code": "23",
    "count": "10 件",
    "color": "#0891B2",
    "phase": "P5",
    "phaseTitle": "灯光",
    "title": "10 × 侧发光 RGB LED",
    "subtitle": "EDGE-FIRING LED",
    "image": "step-23.zh-CN.png",
    "summary": "安装透明版四周的 10 颗侧发光 LED。",
    "parts": [
      "型号 · SK6812SIDE-A",
      "封装 · LED_WS2812_4020",
      "位号 · LED15-LED24"
    ],
    "steps": [
      "上边 LED15-LED16，右边 LED17-LED19。",
      "下边 LED20-LED21，左边 LED22-LED24。",
      "LED15、LED16 按设计朝外，不要旋转。"
    ],
    "checkpoint": "10 颗均对齐 pin 1，LED15/LED16 保持向外。",
    "method": "烙铁逐脚焊 / 低风速热风",
    "side": "bottom",
    "optional": false,
    "index": 23
  },
  {
    "id": "step-24",
    "code": "24",
    "count": "2 件",
    "color": "#B91C1C",
    "phase": "P6",
    "phaseTitle": "按键与座",
    "title": "2 × 6 mm 轻触按键",
    "subtitle": "BOOT / RESET",
    "image": "step-24.zh-CN.png",
    "summary": "安装 BOOT 和 RESET 两颗同型号轻触按键。",
    "parts": [
      "型号 · PTS645SM43SMTR92 LFS",
      "封装 · 6.0 × 6.0 mm H4.3 鸥翼脚",
      "位号 · SW14, SW15"
    ],
    "steps": [
      "SW14 = BOOT，SW15 = RESET。",
      "先对角固定，确认按键平贴后再焊余下两脚。",
      "禁止使用 J 引脚型号。"
    ],
    "checkpoint": "型号、方向和平贴度。",
    "method": "烙铁，四脚对角固定",
    "side": "bottom",
    "optional": false,
    "index": 24
  },
  {
    "id": "step-25",
    "code": "25",
    "count": "13 件",
    "color": "#B91C1C",
    "phase": "P6",
    "phaseTitle": "按键与座",
    "title": "13 × MX 热插拔座",
    "subtitle": "LAST BOTTOM SMD",
    "image": "step-25.zh-CN.png",
    "summary": "安装 13 个 MX 热插拔座；实际轴体不焊。",
    "parts": [
      "型号 · Kailh CPG151101S11",
      "封装 · SW_MX_HS_CPG151101S11_1u",
      "位号 · SW1-SW13"
    ],
    "steps": [
      "从 SW4→SW3→SW2→SW1 开始，按排推进。",
      "每个座子先焊一端，确认平贴后再焊另一端。",
      "座内不能进锡，不要用轴体做高温夹具。"
    ],
    "checkpoint": "13 个方向一致、平贴、座内无异物。",
    "method": "烙铁，先固定一端",
    "side": "bottom",
    "optional": false,
    "index": 25
  },
  {
    "id": "step-26",
    "code": "26",
    "count": "1 件",
    "color": "#BE185D",
    "phase": "P7",
    "phaseTitle": "顶面直插",
    "title": "1 × EC11 编码器",
    "subtitle": "TOP SIDE · THT",
    "image": "step-26.zh-CN.png",
    "summary": "翻面后安装旋转编码器。",
    "parts": [
      "型号 · PEC11R-4215F-S0024",
      "封装 · EC11 vertical H20",
      "位号 · RE1"
    ],
    "steps": [
      "先干插 RE1，确认 7 个焊点都能进入。",
      "只焊两个对角脚，检查垂直和贴平。",
      "确认后再焊全部信号脚与机械脚。"
    ],
    "checkpoint": "轴垂直、器件贴平、A/B/C 与机械脚全部可靠。",
    "method": "烙铁（THT）",
    "side": "top",
    "optional": false,
    "index": 26
  },
  {
    "id": "step-27",
    "code": "27",
    "count": "1 件",
    "color": "#BE185D",
    "phase": "P7",
    "phaseTitle": "顶面直插",
    "title": "1 × YA13 摇杆",
    "subtitle": "TOP SIDE · THT",
    "image": "step-27.zh-CN.png",
    "summary": "翻面后安装两轴模拟摇杆。",
    "parts": [
      "型号 · YA13-FL7.4-B5Ka",
      "封装 · 10-pad tilt joystick",
      "位号 · JS1"
    ],
    "steps": [
      "干插 JS1，确认 10 个焊点无应力进入。",
      "先焊两个对角脚，检查垂直和行程。",
      "确认摇杆能完整活动后焊完剩余焊点。"
    ],
    "checkpoint": "10 个焊点可靠，摇杆不被结构干涉。",
    "method": "烙铁（THT）",
    "side": "top",
    "optional": false,
    "index": 27
  },
  {
    "id": "step-28",
    "code": "28",
    "count": "选装 0–1 件",
    "color": "#BE185D",
    "phase": "P7",
    "phaseTitle": "顶面直插",
    "title": "TP5 触摸触点",
    "subtitle": "OPTIONAL CONTACT",
    "image": "step-28.zh-CN.png",
    "summary": "只有使用电极式触摸定位板时才安装。",
    "parts": [
      "型号 · 用户选弹簧 / 导线",
      "封装 · TP5 Ø4.0 mm 焊盘",
      "位号 · TP5"
    ],
    "steps": [
      "普通打印板或空白 FR4 板不需要焊接。",
      "选择能稳定压住定位板电极的弹簧或导线。",
      "焊后确认触点不会短路到其他焊盘。"
    ],
    "checkpoint": "仅电极式面板需要；其他情况留空。",
    "method": "烙铁（选装）",
    "side": "top",
    "optional": true,
    "index": 28
  }
];
