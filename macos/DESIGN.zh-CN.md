# AgentPad Studio：设计与开发

[English](DESIGN.md) | 简体中文

本文介绍原生 macOS 应用及其与 AgentPad13 `codex_oai` 固件的接口。应用选择和配置
步骤请参见 [README](README.zh-CN.md)。

## 架构

Studio 是一个面向 macOS 13+ 的 SwiftUI 应用，使用 Swift 5.9 或更高版本构建。
它没有第三方运行时依赖、辅助进程或配置守护进程。

| 组件 | 职责 |
|---|---|
| `Sources/AgentPadCore/` | 动作目录、层配置、配置校验、HID 分帧、响应解码和 Input 层名称解析 |
| `Sources/AgentPadStudio/PadModel.swift` | 设备状态、草稿、能力门槛、保存/回读流程和层标签 |
| `Sources/AgentPadStudio/HIDTransport.swift` | IOKit 发现、非独占连接、请求 ID 和超时 |
| `Sources/AgentPadStudio/HardwareRenderView.swift` | 基于 CAD 的 SceneKit 视图、按键选择、辅助功能和图例 |
| `Sources/AgentPadStudio/RenderValidation.swift` | 无需 USB 访问的离屏渲染和拾取检查 |
| `Tests/AgentPadCoreTests/` | 核心约定，以及针对实际 C 固件引擎的 Swift 请求 |

仓库中采用 GPL-2.0-or-later 的源码即为应用实现。硬件网格使用单独的
CERN-OHL-W-2.0 来源许可，详见下文。

## 状态和保存行为

模型会保留一份本地草稿和一个设备基准。连接或读取设备会替换草稿。断开连接会保留
草稿，但会清除基准；再次保存前必须重新读取。应用支持离线编辑、导入和导出。

保存键位绑定时，应用会写入 OAI 映射和已配置的层记录，然后回读并与目标值比较。
仅收到确认并不代表保存成功。LED 电源/亮度使用单独的保存和回读流程。写入失败或
结果不明确时，必须重新读取设备，才能继续保存。

层记录按顺序逐个写入，并非一个 Studio 事务。写入中途失败可能留下部分已保存的层。
保存前，Studio 会检查设备端层数，以免覆盖其他工具对层数所做的更改。

默认的四个层为 CODEX、FN、NAV 和 MEDIA。固件 v001C 最多支持十六层。Studio 会
读取已配置的层数并创建对应的编辑项；导入的配置或出厂草稿可在保存时改变层数。
编辑某个层不会在设备上激活该层。

### 配置格式

- 格式 1 保存旧版 CODEX 映射。
- 格式 2 保存 CODEX 映射、4–16 层记录和全局 LED 设置。
- 导入和出厂重置会影响草稿。键位绑定和 LED 设置需分别通过对应的保存控件应用。
- 层名称从设备的 Input 文件读取。重命名在 Input 中完成；Studio 的配置格式不包含
  层名称。

## USB 传输

Studio 匹配 VID/PID `303A:8360`、usage page/usage `FF00:61`，并以非独占方式打开
Raw HID 接口。这是一个实验性兼容标识；连接多个匹配设备时，请确认所选设备。
该接口与普通 Vial 固件配置相互独立。

每个报告为 64 字节：报告 ID `6`、通道 `2`、载荷长度、最多 61 个 JSON 字节，之后
补零。回复可以跨多个报告，并以 CRLF 结尾。固件接受请求 ID `0...998`；Studio 在
`700...998` 之间轮换，并将回复与待处理 ID 匹配。通知不会满足配置请求。请求超时
会清除待处理状态和响应解码状态。

非独占访问并非协议层面的客户端隔离。来自其他应用的交错分片或相同 ID 可能干扰
请求。请按顺序配置，并在切换工具后重新读取。Studio 不发送 `v.oai.rgbcfg` /
`v.oai.thstatus` 就绪握手，也不替换任务颜色。

如果 macOS 拒绝 HID 访问，请按系统的 USB 配件或“输入监控”提示操作，然后重新打开
应用。Studio 不需要辅助功能访问权限。

### 固件能力门槛

| USB 设备版本 | Studio 能力 |
|---|---|
| 早于 `0x0013` | CODEX 配置 |
| `0x0013` | CODEX 以及全局 LED 电源/亮度 |
| `0x0014` | 四层配置和指示色 |
| `0x0018` | 原生 CODEX 覆盖和扩展动作目录 |
| `0x001C` | 动态 4–16 层配置和 Input 文件适配器 |

## 配置 API 和持久化

| API | 用途 |
|---|---|
| `v.oai.keymap.get/set` | `l:0` 上的旧版 OAI 映射 |
| `v.agentpad.cfg.info` | 读取 `{n,max}`，或通过 `{n:4...16}` 设置已配置的层数 |
| `v.agentpad.cfg.get/set` | 使用 `{l,m}` 读取/写入一个层 |
| `v.agentpad.led.get/set` | 持久化全局 LED 电源和百分比亮度 |
| `fs.readbin` | 读取现有 Input 元数据，以获取自定义层名称 |

OAI 映射包含 15 个十六进制数字；出厂值为 `123456789abecd1`。只有前 13 个位置是
可编辑的物理按键。位置 13 是固定编码器槽位；位置 14 是没有物理输入的旧版槽位。
普通编辑和导入会保留这些槽位；出厂草稿会恢复其默认值。

层的 `m` 为 32 个十六进制字符：十三个动作 ID 字节，后接三个指示 RGB 字节。`l` 是
从零到已配置层数减一的索引。CODEX 覆盖值为零时使用 OAI 映射。原生动作和 Codex
动作共用 `native_actions.def` 与 `LayerConfiguration.swift` 中的目录。

v001C 紧凑记录从逻辑 EEPROM 地址 192 开始，并位于现有的 4 KiB 逻辑区域内。它保存
映射、层数、名称、ID、OS 元数据和颜色，并带有完整性校验和。现有 CODEX、全局 LED
和摇杆校准记录保留各自区域。旧的 112–178 四层记录和更早的 Input 记录可以迁移。
设置会立即生效，并在重启后恢复。按下时的绑定会被缓存，因此层或配置改变后，松开
按键时仍会匹配原始动作。

TP5 会在已配置的层之间依次切换。默认摇杆模式会左右循环并首尾回绕，每一步之间
需要让摇杆回中。FN 层的 `JS_MODE` 可选择方向键、滚动或游戏手柄操作。编码器行为
保持固定。全局 LED 电源和亮度也会缩放层指示色；任务颜色仍由 OAI 渲染器控制。
当该渲染器控制 LED 时，QMK RGB 效果键不一定表现为背景效果。

### Input 文件桥接和层名称

适配器通过 `fs.list`、`fs.readbin` 和 `fs.writebin` 提供一个共享的 `keymap.json`，
并带有 SHA-1 值，供 Input 在保存后验证。上传内容会先暂存并校验，再发布。完整文件
上限为 16 KiB；每次上传的数据块最多包含 3072 个原始字节。层/配置名称字面量最多
为 127 个 JSON 字节，包含引号和 Unicode 转义。

上传的原始字节会保留在 RAM 中，以便立即进行校验和回读一致性检查。重启后，文件会
根据紧凑的持久化状态重新生成。键位绑定、层数、名称、ID、OS 元数据和颜色会保留；
序列化结果和由此生成的校验和可能改变。Studio 的更改也会使缓存文件失效。不支持
的宏、智能动作、多配置和控制重映射会被拒绝。`host.focused_app` 可接受上下文，
但不会切换配置。

Studio 1.3.2 使用现有固件 API，以 192 字节为单位分块读取文件。
`InputLayerNameReader` 会限制文件大小，检查读取进度和报告大小是否一致，然后校验
层数。层数组顺序决定物理层索引；Input ID 可以不连续。Unicode 名称会在所有字节
组装完成后解码，因此一个数据块可能从中间截断 UTF-8 序列。空名称会回退为
CODEX/FN/NAV/MEDIA 或 `LAYER N`。名称会显示在选择器、当前层标题、指示控件和
帮助文本中。

适配器的应用证据和详细范围记录在 [Input 兼容性报告](../docs/input-compatibility.zh-CN.md)中。

### 麦克风兼容性

旧版映射数字 `e` 选择组合麦克风模式并发出 ACT10。数字 `f` 选择独立麦克风模式并
发出 ACT11。数字 `b` 是受保护的 ACCEPT；MICROPHONE 兼容动作会绕过该确认分支。
在 OAI 握手之前，两种麦克风动作都不提供原生语音快捷键回退。仅建立 HID 连接并不
代表语音功能已就绪。

2026-10-26 的一次历史调查观察到 USB 固件 `0x0012`、SW12/K11 上的 ACT11 绑定，
以及 `v.oai.rgbcfg` / `v.oai.thstatus` 的成功响应。对该客户端的静态检查发现，
当 `separateMicrophoneKeys=false` 时 ACT11 被忽略，而 ACT10 处理组合麦克风输入。
这标识了一种兼容条件，并非每个语音问题唯一已证实的原因；该调查没有验证用户当前
设置和实际录音/权限行为。

固件 `0x0013` 及更高版本在出厂映射中使用组合模式。完全匹配旧出厂映射
`123456789abfcd1` 的值会迁移为 `123456789abecd1`；包含 `f` 的任意自定义映射会
保留。Studio 会分别标记两种麦克风模式。独立模式需要相应的客户端设置和语音动作
绑定。

历史证据（保留自此前的麦克风报告）：

- 检查的构件：`/Applications/ChatGPT.app/Contents/Resources/app.asar`。
- SHA-256：`130145706a912db74e4d260ad7538f10f1e05e88af955f9afba42cdf01e64606`。
- 选定的 JavaScript：`webview/assets/codex-micro-bridge-a2956a34f88d.js`、
  `codex-micro-layout-46c1317ad24a.js` 和 SDK 通知键。
- REA 证据：`ev_dcdd28acfe0485a2106e03c290fe2eae94d352fdf7bc7d509db16563da78a87a`。
- 选定的 JavaScript 已作静态检查。存在 ASAR 元数据差异的未选定原生依赖没有被用来
  确定事件路由。

## CAD 视图、资源和图例

SceneKit 使用 Metal 渲染仓库中实际的壳体、环形边、定位板、键帽、编码器旋钮和摇杆
网格。展示层会添加材质、环境光和接触阴影。视图会跟随系统的浅色/深色外观，但不
更改系统设置。选中的键帽会高亮；辅助功能会提供 SW1–SW13 控件。

轴体中心来自 `release/hardware/pcb/v5_8.kicad_pcb`，单位为毫米。编码器位于左上，
摇杆位于右上，SW1–SW12 构成 3×4 矩阵，SW13 是下方 2U 键，其左侧为 TP5。编码器
位置使用机械轴心，而不是封装引脚 A。`generate-layout.py --check` 会将生成的 UI
坐标与 PCB 比较。

网格从 `configurator/build/out/meshes/` 原样复制。源设计位于
`release/hardware/case/v2/`，键帽设计由 `configurator/build/out/positions.json`
描述。

| 资源 | 放置位置 |
|---|---|
| `tray.glb` | v2 托盘，已烘焙到板框坐标系中 |
| `band_w5.4.glb` | v2 5.4 mm 环形边，已烘焙到板框坐标系中 |
| `plate.glb` | v2 定位板，已烘焙到板框坐标系中 |
| `cap_dish_1u_17p5.glb` | 17.5 mm 1U 键帽，局部原点位于 PCB 轴体中心，Y = 11.6 mm |
| `cap_dish_2u_stab_17p5.glb` | 同一坐标系中带稳定杆的 2U 键帽 |
| `knob_A.glb` | RE1 轴轴线处的旋钮 A |
| `stick_cap_topper_12_restricted.glb` | JS1 处受限的 12 mm 摇杆帽 |

单位为毫米；Y 轴向上，Z 轴沿用 PCB 的向下 Y 坐标。只有展示材质会改变；源顶点保持
不变。图例、紧固件近似模型和 TP5 的视觉圆盘属于展示几何。这些资源是采用
CERN-OHL-W-2.0 的硬件设计数据，与采用 GPL-2.0-or-later 的应用代码相互独立。复制
后的资源文件夹保留了分发用的 [NOTICE](Sources/AgentPadStudio/Resources/Models/NOTICE.txt)。

Studio 1.3.1 修复了 Input 渲染崩溃：原生 `KV_*` / `KI_*` 动作 ID 曾被错误地用作
一个包含 16 项的旧版标题表索引。现在，`PadAction.keycapTitle` 仅对匹配的旧版项
使用紧凑标签，其他情况使用各原生动作自己的标题。测试覆盖整个原生目录和未知的
未来 ID；离屏渲染包含 Codex 覆盖、直接层选择和瞬时层绑定。

## 构建和验证

请在仓库根目录运行命令。构建需要 Swift 5.9+ 的 Xcode 或命令行工具链：

```sh
macos/scripts/build-app.sh
open 'macos/dist/AgentPad Studio.app'
```

脚本会检查 PCB 布局数据，为当前 Mac 架构构建 Release 版本，复制应用资源并应用
ad-hoc 签名。输出为 `macos/dist/AgentPad Studio.app`。Developer ID 签名和公证是
独立的分发步骤；现有发布 ZIP 是 Apple Silicon 构建。

离线演示（不发现也不连接 USB）：

```sh
open 'macos/dist/AgentPad Studio.app' --args --demo
```

测试和离屏验证：

```sh
swift test --package-path macos
python3 -m unittest discover -s firmware/tests/codex_oai -p 'test_*.py'
python3 macos/scripts/generate-layout.py --check
'macos/dist/AgentPad Studio.app/Contents/MacOS/AgentPadStudio' --render-previews /tmp/agentpad-previews
```

Swift 测试覆盖映射、保留槽位、配置、灯光、HID 分片和响应组装。测试会编译实际的
C 协议引擎，并通过它发送 Swift 生成的请求，包括动态层持久化。名称测试覆盖十六层、
Unicode/表情符号、分块边界、刷新和无效响应。

渲染器会检查 CAD 资源、两种系统外观、扩展动作图例和全部十三个拾取目标，无需打开
窗口或访问 USB。离屏渲染使用 AppKit/SceneKit，需要适当的 macOS 图形环境。应用的
正常运行既不需要 Python，也不需要浏览器。

这些检查不能证明真实设备上的 IOKit/USB 行为、重连处理、物理断电后的持久性、语音
就绪状态或任意并发客户端的安全性。人工验收包括读取 → 编辑 → 验证保存 → 物理按键
测试 → 重新连接/回读 → 在 Codex 运行时观察。上述构建或测试命令都不会刷写设备。
物理固件操作记录在[操作手册](../docs/codex-oai-physical-runbook.md)中。

## 源码参考

- [核心模型和线上格式](Sources/AgentPadCore/Keymap.swift)
- [层记录和动作目录](Sources/AgentPadCore/LayerConfiguration.swift)
- [层名称读取器](Sources/AgentPadCore/InputLayerNames.swift)
- [固件接口](../firmware/loudest_micro/keymaps/codex_oai/codex_oai.h)
- [固件实现](../firmware/loudest_micro/keymaps/codex_oai/codex_oai.c)
- [QMK 按键行为](../firmware/loudest_micro/keymaps/codex_oai/keymap.c)

应用许可证：GPL-2.0-or-later。网格许可证：CERN-OHL-W-2.0。
