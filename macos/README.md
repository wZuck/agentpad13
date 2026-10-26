# AgentPad Studio

原生 SwiftUI macOS 应用，为当前 AgentPad13 `codex_oai` 固件配置 CODEX 层的 13 个实体按键。
支持 macOS 13+，无第三方运行时依赖。Swift Package 包含独立的协议核心、IOKit HID 传输及界面。

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
2. 点击板上 K00–K12，对应 3×4 矩阵及独立 2U 键，再选择 Codex 动作。
3. 点击“保存到设备”。应用等待固件确认，并再次读取完整映射进行比较；只有匹配时才显示保存成功。
4. 配置保存在固件的 wear-leveling 存储中。断线保留当前草稿，但再次连接需要重新读取。
5. “导出”保存 JSON 文件；“导入”和“载入出厂键位”只更改草稿，保存按钮才会写入设备。

若保存超时，其结果可能未知；先重新读取设备以确认实际状态，再继续编辑。写入失败后禁用继续保存，
直到读取成功。读取设备会替换草稿，重要配置可先导出。没有连接设备时也可编辑、导入和导出。

应用仅匹配 `303A:8360`、usage `FF00:61` 的 OAI Raw HID 接口，以非独占方式打开，
不需要 Vial、Python helper、辅助功能权限或常驻服务。若系统拒绝 HID 访问，
按 macOS 提示允许 USB 配件或输入监控权限后重新打开应用。
产品 VID/PID 是实验身份，不用于普通 Vial 固件，也无法仅凭此身份区分其他仿真设备，连接前应核对设备。

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

- 通过 `v.oai.keymap.get/set`，只操作 `l:0`。不发送 rgbcfg/thstatus 握手，不覆盖 Codex 的 LED/任务状态。
- 64 字节 report 含 ID `6`、channel `2`、有效载荷长度及最多 61 字节 JSON 片段，其余补零。
- 固件请求 ID 限于 `0...998`，应用在 `700...998` 区间滚动并验证响应 ID。共享接口不是协议级多客户端总线；
  若 Codex 同时发送分片请求造成超时，可暂时退出后重试。应用不会将通知视为配置成功。
- 地图为 15 个十六进制字符，出厂值 `123456789abecd1`。实体可编辑键只有前 13 个。
  编码器槽位 13 和 legacy 槽位 14 在读取、导入和普通键编辑时保留；载入出厂键位时恢复其出厂值。
- 当前固件始终将编码器按压路由到 ENC；TP5 始终切层，legacy 槽位不连接实体输入，因此不提供虚假的编辑项。
- FN/NAV/MEDIA、摇杆模式、旋转、RGB、任意键盘快捷键和宏不在当前 keymap RPC 能力范围内。
  若需要动态配置这些行为，必须扩展固件协议和持久化结构。
- 麦克风有两种兼容动作：`e`“合并模式”发 ACT10，`f`“分离模式”发 ACT11。当前 Codex 客户端在
  `separateMicrophoneKeys=false` 时直接忽略 ACT11；固件因此默认使用合并模式。若要把麦克风键改为分离模式，
  需在 Codex 中启用分离按键并分配语音动作。
  `e` 是固件保留的 MICROPHONE 兼容值，会绕过 ACCEPT 保护；`b` 才是受保护的 ACCEPT 动作。
  两种麦克风动作都没有未握手时的原生语音快捷键回退。语音功能还取决于 Codex 的配置与权限。
  应用只读写映射，显示“HID 已连接”不代表语音已就绪。
- 当前工作区固件版本 `0x0013` 默认麦克风使用合并模式；更早固件仍可配置键位。

协议依据：[`codex_oai.h`](../firmware/loudest_micro/keymaps/codex_oai/codex_oai.h)、
[`codex_oai.c`](../firmware/loudest_micro/keymaps/codex_oai/codex_oai.c)、
[`keymap.c`](../firmware/loudest_micro/keymaps/codex_oai/keymap.c)。本实现无需提取第三方 DMG 的代码或资源。

## 验证

```sh
swift test --package-path macos
python3 -m unittest discover -s firmware/tests/codex_oai -p 'test_*.py'
```

Swift 测试覆盖映射合法性、保留槽位、JSON 配置兼容性、HID 分片及响应重组，
并编译仓库真实的 C 协议引擎，将 Swift 生成的 GET/SET/GET 帧送入引擎，验证出厂读取、写入及回读。
这验证了字节协议，不等同于实机 IOKit/USB、断线重连或断电持久化验证。

实机验收：读取 → 修改一个键 → 保存回读一致 → 按键验证 → 拔插后重读 → 验证 Codex Desktop 同时运行。
本次开发不自动写入或刷写任何连接设备。固件实机操作另参见仓库 physical runbook。

License: GPL-2.0-or-later.
