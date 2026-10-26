import SwiftUI
import AgentPadCore

@main
struct AgentPadStudio: App {
    @StateObject private var model = PadModel()
    init() {
        if RenderValidation.runIfRequested() { exit(0) }
    }
    var body: some Scene {
        WindowGroup("AgentPad Studio") {
            StudioView(model: model)
                .frame(minWidth: 1010, minHeight: 730)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("导入配置…", action: model.importProfile).keyboardShortcut("o").disabled(model.busy)
                Button("导出配置…", action: model.exportProfile).keyboardShortcut("s", modifiers: [.command, .shift]).disabled(model.busy)
            }
        }
    }
}

struct StudioView: View {
    @ObservedObject var model: PadModel
    @Environment(\.colorScheme) private var colorScheme
    private var accent: Color {
        colorScheme == .dark ? Color(red: 0.72, green: 0.94, blue: 0.40) : Color(red: 0.22, green: 0.42, blue: 0.10)
    }
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("CODEX").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(accent)
                        Text("第 1 层 · 13 个可配置按键").foregroundStyle(.secondary).font(.caption)
                        Spacer()
                        Text(model.dirty || model.ledDirty ? "有未保存修改" : "已同步").font(.caption).foregroundStyle(.secondary)
                    }
                    board
                    HStack(spacing: 16) {
                        Label("点选按键以修改动作", systemImage: "cursorarrow.click")
                        Spacer()
                        Text("RP2040 / OAI").fontDesign(.monospaced)
                    }.font(.caption).foregroundStyle(.secondary)
                    Text("FN、NAV、MEDIA 的键位仍由固件定义。当前 RPC 仅支持 CODEX 层的 OAI 动作映射。").font(.caption).foregroundStyle(.secondary).lineSpacing(4)
                }.frame(maxWidth: .infinity)
                inspector.frame(width: 285)
            }.padding(28)
            }
            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(accent)
        .alert("操作未完成", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("好") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: "square.grid.3x3.square").font(.system(size: 29)).foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("AgentPad Studio").font(.title2.bold())
                Text("让每个键，按你的方式工作。").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if model.demo {
                Label("离线演示", systemImage: "play.circle").foregroundStyle(accent)
            } else {
                Circle().fill(model.connected ? accent : .gray).frame(width: 7, height: 7)
                if model.connected {
                    Text("HID 已连接").font(.callout)
                    Button("断开", action: model.disconnect).disabled(model.busy)
                } else {
                    Picker("设备", selection: $model.deviceID) {
                        Text("选择 USB 设备").tag(Int?.none)
                        ForEach(model.devices) { Text($0.label).tag(Optional($0.id)) }
                    }.labelsHidden().frame(width: 205)
                    Button("扫描", action: model.scan)
                    Button("连接并读取", action: model.connect).disabled(model.deviceID == nil)
                }
            }
        }.disabled(model.busy).padding(.horizontal, 28).padding(.top, 30).padding(.bottom, 22)
    }
    private var board: some View {
        VStack(spacing: 12) {
            HStack {
                Label("AgentPad13", systemImage: "cube.transparent")
                Spacer()
                Text("3D 实物视图").font(.caption).foregroundStyle(.secondary)
            }.font(.callout.weight(.medium))
            HardwareRenderView(map: model.map, selected: model.selected,
                               dark: colorScheme == .dark, enabled: !model.busy) { model.selected = $0 }
                .frame(height: 430)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.primary.opacity(0.06)))
            Text("点击键帽设置动作 · 基于实际外壳与键帽 CAD 模型")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private var inspector: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("按键设置").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: "K%02d", model.selected)).font(.system(size: 32, weight: .medium, design: .monospaced))
                Text(model.selected == 12 ? "独立 2U 键 · SW13" : "矩阵 [\(model.selected / 4), \(model.selected % 4)] · SW\(model.selected + 1)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Text("分配 Codex 动作").font(.caption).foregroundStyle(.secondary)
            Picker("动作", selection: Binding(get: { model.map.values[model.selected] }, set: { model.assign($0) })) {
                ForEach(PadAction.editable) { Text($0.title).tag($0.id) }
            }.labelsHidden()
            Text(PadAction.all[model.map.values[model.selected]].wire)
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(accent)
            Text(actionHelp).font(.caption).foregroundStyle(.secondary).lineSpacing(4).frame(minHeight: 72, alignment: .top)
            Divider()
            lighting
            Divider()
            Label("固定硬件行为", systemImage: "lock").font(.caption.bold())
            Text("编码器按压：ENC\nCODEX 旋转：推理强度\nTP5：CODEX → FN → NAV → MEDIA\n¹ 摇杆默认左右切换会话；FN 的 JS_MODE 可切换模式。")
                .font(.caption).foregroundStyle(.secondary).lineSpacing(5)
            Text("麦克风需与 Codex 的按键布局模式一致：合并模式使用 ACT10；分离模式使用 ACT11。未握手时两者均无语音快捷键回退。")
                .font(.caption).foregroundStyle(.secondary).lineSpacing(4)
        }.disabled(model.busy)
    }
    private var lighting: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("LED 灯光", systemImage: "lightbulb.fill")
                Spacer()
                Toggle("", isOn: Binding(get: { model.led.isOn }, set: { model.led.isOn = $0 }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityLabel("LED 灯光开关")
                    .disabled(!model.ledSupported)
            }.font(.caption.bold())
            HStack(spacing: 10) {
                Image(systemName: model.led.isOn ? "sun.max.fill" : "moon.fill")
                    .foregroundStyle(model.led.isOn ? accent : .secondary)
                    .frame(width: 18)
                Slider(
                    value: Binding(
                        get: { Double(model.led.brightness) },
                        set: { model.led.brightness = Int($0.rounded()) }
                    ),
                    in: 1...100,
                    step: 1
                )
                .disabled(!model.ledSupported || !model.led.isOn)
                Text("\(model.led.brightness)%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }
            HStack {
                Text(model.ledSupported ? "亮度 1–100%" : "当前固件不支持灯光配置")
                    .font(.caption2)
                    .foregroundStyle(model.ledSupported ? Color(nsColor: .secondaryLabelColor) : Color.orange)
                Spacer()
                Button("应用灯光", action: model.saveLED)
                    .controlSize(.small)
                    .disabled(!model.canSaveLED)
            }
        }
    }
    private var actionHelp: String {
        switch model.map.values[model.selected] {
        case 10: return "SAFE 的解锁状态由固件计时，松开后清除。"
        case 11: return "ACT10 具有确认保护：短按不触发；保持 600 ms 后松开，或先由 SAFE 解锁。"
        case 3: return "新建任务；原生快捷键回退模式下，长按可切换会话。"
        case 14: return "发送 ACT10 按下／松开。适用于 Codex 合并麦克风模式；此兼容动作绕过固件 ACCEPT 的确认保护。"
        case 15: return "发送 ACT11 按下／松开。Codex 合并麦克风模式会忽略此事件；需要启用分离按键并分配语音动作。"
        case 0: return "禁用该键在 CODEX 层的动作。"
        default: return "OAI 就绪时发送所选控制事件；未握手时使用固件内置的原生快捷键。"
        }
    }
    private var footer: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                if model.busy { ProgressView().controlSize(.small) }
                Text(model.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Spacer()
            }
            HStack {
                Button("导入…", action: model.importProfile)
                Button("导出…", action: model.exportProfile)
                Button("载入出厂键位", action: model.restore)
                Spacer()
                Button("读取设备（替换草稿）", action: model.read).disabled(!model.connected || model.demo)
                Button("保存到设备", action: model.save)
                    .buttonStyle(.borderedProminent).foregroundStyle(colorScheme == .dark ? .black : .white).disabled(!model.canSave)
            }.disabled(model.busy)
        }.padding(22)
    }
}
