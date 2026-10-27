# Input 1.0.2 改键兼容实验

`codex_oai` v001C 增加 Input 的 `keymap.json` 读写适配，与 AgentPad Studio
共用同一组层映射和指示色。普通 Vial/default 固件不变。当前实验 UF2 的摘要与大小
以 `firmware/evidence/codex-oai-current-manifest.json` 为准。

## 支持的改键范围

- 单一 AgentPad13 配置，默认 CODEX、FN、NAV、MEDIA 四层，可通过 Input 添加到最多 16 层，各 13 个按键。
- 字母、数字、F1–F24、方向/导航、标点、左右修饰键、媒体键，以及原有 Studio 动作。
- Codex 控制可重新分配，CODEX 层也能改成普通键；明确的禁用键不会退回默认动作。
- SAFE、受保护的 ACCEPT、麦克风兼容路由继续使用原有动作处理，确认保护不因适配绕过。
- Input 保存后可由 Studio 读取并编辑；Studio 保存后，重新读取 Input 配置可看到新映射。
- 层配置和层名称和元数据随重启恢复。灯光开关/亮度、OAI 按键表、摇杆校准和任务 LED 状态
  保留原有存储与接口。Input 读取配置不触发 OAI handshake。

Input 的键盘外观是 Codex Micro 的固定布局：按显示顺序展开 2/4/4/3 个键，对应
AgentPad13 的 K00–K12；物理布局与它的图示不同，独立 2U 键对应最后一键。

支持在四个基础层之外新增、编辑和删除扩展层，支持 KI_LS / KI_LM 切层键。
目前不支持多配置、宏/多动作/智能动作、按应用切层、改变编码器、
改变摇杆手势或原厂升级。这些映射请求明确失败，旧配置保持不变。
Input 的多修饰键组合通常属于宏，也不在本次支持范围内。
编码器保持原有 OAI/回退行为，TP5 和摇杆保持原有换层/模式功能。
Input 的灯光效果设置不取代 Codex 的任务灯光；请继续用 Studio 控制灯光。

## 使用

1. 按设备既有刷写流程安装 `release/firmware/prebuilt/agentpad13_codex_oai.uf2`。
2. Input 会按 `303A:8360` 识别为 Codex Micro，加载 `keymap.json`。
3. 选择现有层，或添加第五层及更多层，分配普通键或 Codex 动作后保存。Input 会用文件列表中的 SHA‑1 校验保存内容。
4. 在新版 Studio 点“读取设备”，会显示实际的 4–16 层，核对映射；反向修改后，在 Input 中重新连接/读取。
5. 需使用更新后的 Studio（本仓库构建），才能显示 CODEX 原生键及扩展按键目录；
   旧 Studio v0014 的功能仍适用于旧固件，不能完整显示新固件新增的动作编号。

不要通过 Input 向 RP2040 安装原厂 ESP 固件。此次工作没有刷写任何实机。

## 协议和存储

- USB VID/PID、manufacturer、product、usage、Report ID 保留，`bcdDevice` 升为 `0x001C`；
  低两位仍为零，符合 Input 的 USB 连接判断。`device.status` / `sys.version` 返回
  `0.0.28-agentpad13`。Studio 保持原有版本门槛并对新增动作作版本判断。
- `fs.list` 提供 `keymap.json` 的字节数和 SHA‑1；`fs.readbin` 返回 base64、`total_size`。
  为限制单次响应，固件每次最多返回 192 个原始字节，Input 按实际读取长度继续。
- `fs.writebin` 接受 Input 的最多 3072 字节原始块，检查 base64、append、offset、completed；
  接收缓冲上限 4608 字节。也支持 `fs.read` / `fs.write` 的 JSON 对象形式。
- 完整上传文件上限 16384 字节。提交前验证全部层和映射；失败或中断不替换当前配置。
  Studio 在上传分块之间修改配置时，拒绝提交陈旧的上传。
- 通过 `v.agentpad.cfg.info` 查询 `{n,max}`（默认 4，最多 16），也可传 `{n:数量}` 调整层数。
  Studio 按设备实际层数读取、编辑、导入导出。TP5/摇杆按当前层数环绕切换；删除当前层
  后回到 CODEX。原生按键跨层释放仍跟随按下时的绑定。
- 新共享记录使用现有 4 KiB logical EEPROM 的 `192..` 空闲区域，保存紧凑的 16 层映射、
  层数、名称、ID、OS 与指示色；没有改变 flash 布局。旧 `112..178` 层记录以及旧版
  Input 四层记录可迁移。名称为最多 127 字节的 JSON 字符串（包括引号和转义）。
- 上传后保留原始 JSON 在 RAM 中，Input 的立即回读和 SHA‑1 校验使用完全相同的字节。
  重启后从持久化配置重新生成文件：键位、层数、层名/ID/OS 与颜色保留，序列化格式
  和校验值可能变化；Input 会依据新的 `fs.list` 校验值重新读取。Studio 改键也会刷新文件。
- 不支持的写入返回结构化错误，不虚假报告成功。`host.focused_app` 接受通知但不切换配置。

## 本机应用证据与验证边界

检查 `/Applications/input.app` 1.0.2，bundle ID `it.focusense.input-app`。
`app.asar` SHA‑256：
`eda035d04893827d86506058b9655bfb8b797973bb0a1fda4a6819d4cb38fd9c`。
REA 静态分析及应用附带的 source map 确认发现、文件传输和模型格式；
未修改应用，也未复制其专有实现进固件。REA 记录了 28 个 unpacked 原生文件摘要不一致，
分析依据为可读 JS/source map；测试只在隔离 VM 中加载选定的模型/序列化类，
不运行应用启动、原生模块、网络或 HID。

发现逻辑先匹配 Work Louder manufacturer，完全没有匹配时才回退到 VID。
当前 `ZiyiWang` manufacturer 保留，同时连接真正的 Work Louder 设备时，回退可能不执行。

主机测试覆盖原始字节校验、跨 3072 字节边界上传、第五/六/十二/十六层、未完成/非法/超长/失败写入、
重启、旧记录迁移、Studio 双向读回、CODEX 原生覆盖及 OAI 状态保留。
Input 新层默认的空编码器和 RADIAL 占位配置可保存；它们继承设备固定的编码器/摇杆行为。
本机安装应用的模型能读取固件文件、改为 A 键并重新序列化，真实 C 引擎接受其输出。
Studio Swift 测试覆盖扩展目录、混合 CODEX 显示、配置导入导出及实际固件读写与 16 层配置文件。
模拟器运行完整 UF2 验证文件保存、SHA‑1、Studio 读回与键盘输出，以及原有换层、
按键释放、OAI handshake 和灯光；证据字段为 `input_keymap_read_write_verified` 和 `input_extra_layers_verified`。

构建沿用本机 GCC 15.2.0 与固定 Vial-QMK `00fc4627` 及既有补丁，未放宽
要求 GCC 15.2.1 的发布构建器。以上是离线验证，实机 UI、按键与掉电检查仍待完成。
多个应用共享 HID 时没有事务仲裁；未保证同时发送分片请求或复用同一 ID 的并发行为。
顺序配置、切换应用后重新读取已验证，不能将此描述为实机或任意并发完全兼容。
