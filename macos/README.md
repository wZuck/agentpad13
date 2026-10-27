# AgentPad Studio

原生 SwiftUI macOS 应用，为 AgentPad13 `codex_oai` 固件配置 4–16 层，每层 13 个按键、
TP5 指示灯颜色，以及全局 LED 开关和亮度。默认四层为 CODEX、FN、NAV、MEDIA。
支持 macOS 13+，无第三方运行时依赖。Swift Package 包含独立的协议核心、IOKit HID 传输及界面。

## 选择哪个 App

| 软件 | 适合的用途 | 使用边界 |
|---|---|---|
| **AgentPad Studio 1.3.2+** | 按真实 AgentPad13 位置改键、设置每层指示色和全局灯光、显示 Input 自定义层名、导入导出配置 | 推荐作为日常配置工具；读取后会显示设备实际的 4–16 层 |
| **Input 1.0.2** | 使用 Input 的键盘编辑界面改键、添加第五层及更多层 | 需 `codex_oai` v001C；最多 16 层，单一配置；宏、智能动作与固定控制改写尚不支持 |
| **Codex Desktop** | 使用 Codex 动作及任务状态灯 | 负责运行时控制；配置键位仍使用 Studio 或 Input |
| **Vial** | 配置普通 Vial 固件 | 仅用于普通 `agentpad13.uf2`，不适用于此处的 `codex_oai` 固件 |

Studio 与 Input 读写同一份设备映射，无需转换或分别刷两份固件。先用 Input 添加层，
再到 Studio 点击“读取设备”，即可继续编辑新增层。切换配置工具时先读取最新配置，
避免用旧草稿覆盖另一工具的改动；暂不保证多个 App 同时发送 HID 请求时没有冲突。

**Studio 1.3.1 修复了读取 Input 扩展动作时的 3D 键帽标题越界闪退。**
若使用 1.3.0 读取后闪退，请退出旧进程并改用下方重新构建的应用；此修复不需要清空设备配置。

## 编译与运行

在仓库根目录执行（需要 Xcode 或支持 Swift 5.9+ 的命令行工具）：

```sh
macos/scripts/build-app.sh
open 'macos/dist/AgentPad Studio.app'
```

产物位于 `macos/dist/AgentPad Studio.app`。默认按当前 Mac 架构构建，使用本地 ad-hoc 签名；
对外分发需要自己的 Developer ID 签名与公证。无需安装 Xcode 项目生成器或包管理器依赖。

离线演示（不扫描或打开 USB）：

```sh
open 'macos/dist/AgentPad Studio.app' --args --demo
```

## 使用

1. 插入运行 `codex_oai` 的设备，点击“扫描”，选择 USB 设备，再点击“连接并读取”。连接会用设备配置替换草稿。
2. 在“编辑层”选择设备已有的层，点击板上 K00–K12，再选择此层的功能。
   v001C 可读取 Input 新增的第五层至第十六层；CODEX 也能分配普通键或 Codex 动作。
   编辑层不会切换设备的实际层；实际层通过 TP5、摇杆或已分配的切层键切换。
   在颜色选择器设置当前层的 TP5 指示灯，黑色表示关闭此层指示；颜色与键位一起保存。
3. 点击“保存到设备”。应用等待固件确认，并再次读取完整映射进行比较；只有匹配时才显示保存成功。
4. 配置保存在固件的 wear-leveling 存储中。断线保留当前草稿，但再次连接需要重新读取。
5. 在“LED 灯光”区域切换开关、调整 1–100% 亮度，再点击“应用灯光”；应用会回读确认。
6. “导出”保存全部已配置层的键位、颜色及全局灯光草稿的 format 2 JSON；也可导入旧版 CODEX format 1 文件。
   “导入”和“载入出厂键位”只更改草稿，保存按钮才会写入设备；全局灯光通过“应用灯光”独立写入。

如需新增层，请使用下节的 Input 流程；Studio 读取后提供对应层的编辑入口。
导入多层配置或载入四层出厂草稿后，保存会同步调整设备层数。若其他工具已改变设备层数，
Studio 会要求先重新读取。

若保存超时，其结果可能未知；先重新读取设备以确认实际状态，再继续编辑。写入失败后禁用继续保存，
直到读取成功。读取设备会替换草稿，重要配置可先导出。没有连接设备时也可编辑、导入和导出。

应用仅匹配 `303A:8360`、usage `FF00:61` 的 OAI Raw HID 接口，以非独占方式打开，
不需要 Vial、Python helper、辅助功能权限或常驻服务。若系统拒绝 HID 访问，
按 macOS 提示允许 USB 配件或输入监控权限后重新打开应用。
产品 VID/PID 是实验身份，不用于普通 Vial 固件，也无法仅凭此身份区分其他仿真设备，连接前应核对设备。

## 使用 Input 改键和新增层

1. 确认设备运行 `release/firmware/prebuilt/agentpad13_codex_oai.uf2` 的 **v001C**，
   再打开 Input。设备按兼容身份显示为 **Codex Micro**；不要通过 Input 安装原厂 ESP 固件。
2. 连接设备并读取键盘配置。在现有层改键，或添加第五层及更多层，最多 16 层。
   支持字母、数字、F1–F24、修饰键、导航/媒体键、Codex 动作，以及 `KI_LS` / `KI_LM` 切层键。
   现有四个基础层保留，可删除新增的扩展层。
3. 保存并等待 Input 完成校验。固件先验证整份配置，再保存；不支持的宏、组合动作、
   多配置、编码器或摇杆改写会报错，不能将报错当作保存成功。
4. 用 TP5 或摇杆切到新增层，测试对应按键。默认摇杆左/右按当前层数环绕切换，回中后再次触发。
   新增层的默认空编码器和摇杆占位配置会继承设备固定的控制行为。
5. 打开 Studio 1.3.2+，连接并读取，确认层数、层名、键位和颜色；后续可继续使用 Studio 编辑。
   从 Studio 改完后，也要在 Input 中重新连接/读取最新配置。

在 Input 中重命名后先保存，再到 Studio 点“读取设备”（或重新连接）。层选择器、当前层标题、
指示灯设置及帮助文字会显示设备保存的自定义名称，支持中文和其他 Unicode 字符。
层名从现有固件的 `keymap.json` 分块读取，**无需为此重刷固件**；Studio 当前只显示层名，重命名仍在 Input 中进行。

Input 的图示是 Codex Micro 的 2/4/4/3 排列，按显示顺序展开对应 AgentPad13 的 K00–K12，
最后一键对应独立 2U 键；实际位置以 Studio 的 3D 视图为准。
Input 的宏、多动作和智能动作尚未实现，多个修饰键组合通常也属于宏。
编码器、TP5 和摇杆控制保持设备原有行为；全局灯光和任务灯请分别由 Studio、Codex 控制。

层数、按键、层名称和指示色在重启后保留。重启会重新生成 Input 文件，校验值可能变化，
Input 会根据新的文件列表重新读取。完整上传文件上限 16 KiB；名称最多 127 字节的 JSON 字符串，
包括引号及 Unicode 转义。协议范围和验证证据见 [Input 兼容报告](../docs/input-compatibility.zh-CN.md)。

## 3D 实物视图与系统外观

主界面使用 SceneKit 的 Metal 渲染器直接绘制仓库 CAD 网格：外壳、金属侧带、面板、碟形键帽、
带纹理旋钮和摇杆顶帽。加入物理材质、棚拍环境光和接触阴影；不使用 PCB 轮廓图或 AI 推测键位。
点击 3D 键帽即可编辑，选中键帽以绿色高亮；无障碍接口同样提供 SW1–SW13 按钮。
整个界面与模型材质自动跟随 macOS 的浅色／深色外观，不改变系统设置。

开关中心使用 `release/hardware/pcb/v5_8.kicad_pcb` 的毫米坐标，3D 视图保留实物的相对布局。
编码器在左上，摇杆在右上；SW1–SW12 是 3×4 矩阵，底部 SW13 2U 键居中，TP5 在其左侧。
RE1 使用机械轴心，而非封装 pin A 原点。坐标生成脚本仍会检查当前 PCB 与界面坐标是否一致。

```sh
python3 macos/scripts/generate-layout.py --check
'macos/dist/AgentPad Studio.app/Contents/MacOS/AgentPadStudio' --render-previews /tmp/agentpad-previews
```

第二条命令只离屏渲染浅色／深色预览，用于材质与资源验证，不打开窗口或访问 USB。
运行正常应用无需 Python 或浏览器。模型来源与许可见 `Sources/AgentPadStudio/Resources/Models/README.md`。

## 固件能力边界

- 通过 `v.oai.keymap.get/set` 操作 `l:0`，通过 `v.agentpad.led.get/set` 持久化 LED
  开关与亮度。不发送 rgbcfg/thstatus 握手，不覆盖 Codex 的任务颜色状态。
- 64 字节 report 含 ID `6`、channel `2`、有效载荷长度及最多 61 字节 JSON 片段，其余补零。
- 固件请求 ID 限于 `0...998`，应用在 `700...998` 区间滚动并验证响应 ID。共享接口不是协议级多客户端总线；
  若 Codex 同时发送分片请求造成超时，可暂时退出后重试。应用不会将通知视为配置成功。
- 地图为 15 个十六进制字符，出厂值 `123456789abecd1`。实体可编辑键只有前 13 个。
  编码器槽位 13 和 legacy 槽位 14 在读取、导入和普通键编辑时保留；载入出厂键位时恢复其出厂值。
- 当前固件始终将编码器按压路由到 ENC；TP5 始终切层，legacy 槽位不连接实体输入，因此不提供虚假的编辑项。
- v0014 通过 `v.agentpad.cfg.get/set` 编辑 FN/NAV/MEDIA 的 13 个按键和四层指示灯颜色。
  可选普通键、F 键、导航、媒体、摇杆模式和常用 ⌘ 快捷键。“沿用 CODEX 此键”执行对应物理键的 CODEX 动作。
  编码器旋转、按压和 TP5 切层仍固定；暂不支持任意组合键录制、宏和任务状态颜色编辑。
  原有 RGB 效果／色相键调整 QMK 配置；OAI 渲染器仍负责实际任务灯颜色，不保证呈现这些背景效果。
- 麦克风有两种兼容动作：`e`“合并模式”发 ACT10，`f`“分离模式”发 ACT11。当前 Codex 客户端在
  `separateMicrophoneKeys=false` 时直接忽略 ACT11；固件因此默认使用合并模式。若要把麦克风键改为分离模式，
  需在 Codex 中启用分离按键并分配语音动作。
  `e` 是固件保留的 MICROPHONE 兼容值，会绕过 ACCEPT 保护；`b` 才是受保护的 ACCEPT 动作。
  两种麦克风动作都没有未握手时的原生语音快捷键回退。语音功能还取决于 Codex 的配置与权限。
  应用只读写映射，显示“HID 已连接”不代表语音已就绪。
- 当前工作区固件版本 `0x001C` 支持 4–16 层及 Input 文件读写，`0x0018` 支持原生 CODEX 覆盖和扩展键目录。
  `0x0014` 支持四层配置和层指示灯颜色；`0x0013` 支持 CODEX 与全局灯光，
  更早固件仅支持 CODEX。应用根据 USB 固件版本禁用不支持的功能并提示升级。

默认摇杆模式下，左拨切到上一层、右拨切到下一层，按当前已配置层数首尾循环；每次拨动只切一层，回中后可再次触发。
TP5 继续向下一层切换，层指示灯同步更新。FN 的 `JS_MODE` 可切换为方向键、滚动或手柄模式。

### 多层配置协议

`v.agentpad.cfg.info` 返回 `{ "n":当前层数, "max":16 }`，传 `{ "n":4到16 }` 可调整层数。
`v.agentpad.cfg.get` 参数为 `{"l":0}`，返回 `{"l":0,"m":"..."}`；set 另需 `m`，成功返回 `true`。
`l` 从 0 到当前层数减 1；`m` 是 32 个十六进制字符：13 个动作 ID 字节及 TP5 的 R/G/B 三字节。
CODEX 的原生覆盖为 0 时使用原有 OAI 映射；该映射仍通过 `v.oai.keymap.get/set` 配置。
动作目录及出厂值见 `Sources/AgentPadCore/LayerConfiguration.swift` 与固件 `native_actions.def`。
读取响应可跨多个 HID 帧，以 CRLF 结束。

v001C 使用现有逻辑 EEPROM `192..` 的紧凑记录，保留 CODEX、全局 LED 和摇杆校准区域，
并兼容旧的 112–178 四层记录及早期 Input 记录。设置立即生效且重启后恢复。
全局灯光开关和亮度同样影响层指示灯。按下时缓存动作，切层或修改映射后仍释放原动作。
Studio 按层依次写入，并非整份配置事务：中途失败可能保存了部分层，需重新读取后才能继续保存。

协议依据：[`codex_oai.h`](../firmware/loudest_micro/keymaps/codex_oai/codex_oai.h)、
[`codex_oai.c`](../firmware/loudest_micro/keymaps/codex_oai/codex_oai.c)、
[`keymap.c`](../firmware/loudest_micro/keymaps/codex_oai/keymap.c)。本实现无需提取第三方 DMG 的代码或资源。

## 验证

```sh
swift test --package-path macos
python3 -m unittest discover -s firmware/tests/codex_oai -p 'test_*.py'
```

Swift 测试覆盖映射合法性、保留槽位、JSON 配置兼容性、灯光参数、HID 分片及响应重组，
并编译仓库真实的 C 协议引擎，将 Swift 生成的键位与灯光帧送入引擎，验证读取、写入及回读。
层名测试覆盖 16 层、中英文/emoji、分块读取、重命名刷新及异常响应。
扩展动作标题测试覆盖整个动作目录；离屏渲染额外覆盖 Input 的 Codex、直接切层和按住切层键，
防止把扩展动作编号误用为旧版标题表索引。
这验证了字节协议，不等同于实机 IOKit/USB、断线重连或断电持久化验证。

实机验收：读取 → 修改一个键 → 保存回读一致 → 按键验证 → 拔插后重读 → 验证 Codex Desktop 同时运行。
本次开发不自动写入或刷写任何连接设备。固件实机操作另参见仓库 physical runbook。

License: GPL-2.0-or-later.
