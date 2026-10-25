# 麦克风兼容性检查 · 2026-10-26

## 已确认

- 系统枚举到实验键盘 `303A:8360`、固件 USB 版本 `0x0012`、Raw HID `FF00:61`。
- 配置应用显示设备映射已同步：SW12 / K11 为 `f`，即 ACT11。
- 当前 Codex Micro 日志中，`v.oai.rgbcfg` 和 `v.oai.thstatus` 均收到成功响应；因此“从未握手”不足以解释此次问题。
- 本机客户端的静态事件处理明确在 `separateMicrophoneKeys=false` 时忽略 ACT11，而用 ACT10 处理合并麦克风槽。
- 固件 `e` / MICROPHONE 兼容动作直接发 ACT10，并不经过 `b` / ACCEPT 的保护分支。
- 未完成握手时，固件的 ACT11 原生回退没有操作；ACT10 的 MICROPHONE 兼容值也不提供语音快捷键回退。

## 应用中的处理

原“旧版麦克风别名”改名为“麦克风（合并模式）”；原“麦克风”改名为“麦克风（分离模式）”。
用户可选择与 Codex 设置一致的动作并保存到设备；不需刷固件。此检查没有自动改写任何键位。

## 证据和限制

只读检查目标：`/Applications/ChatGPT.app/Contents/Resources/app.asar`，
SHA-256 `130145706a912db74e4d260ad7538f10f1e05e88af955f9afba42cdf01e64606`。
所选源码：`webview/assets/codex-micro-bridge-a2956a34f88d.js`、`codex-micro-layout-46c1317ad24a.js` 及 SDK notify keys。
REA 分析 Evidence：`ev_dcdd28acfe0485a2106e03c290fe2eae94d352fdf7bc7d509db16563da78a87a`。
所选 JavaScript 为静态检查，未执行第三方代码；部分未选择的原生依赖有 ASAR 完整性元数据差异，
它们不作为本次事件映射结论的依据。

尚未直接读取用户当前的 `separateMicrophoneKeys` 设置，也未完成实际录音或语音权限验收。
因此确认的是一个会让 ACT11 被忽略的兼容条件，不将它表述为已实测排除其他因素后的唯一原因。
