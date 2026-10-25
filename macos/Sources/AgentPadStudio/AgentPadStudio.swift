import SwiftUI
import AgentPadCore

@main
struct AgentPadStudio: App {
    @StateObject private var model = PadModel()
    var body: some Scene {
        WindowGroup("AgentPad Studio") {
            StudioView(model: model)
                .frame(minWidth: 1010, minHeight: 730)
                .preferredColorScheme(.dark)
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
    private let accent = Color(red: 0.72, green: 0.94, blue: 0.40)
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
                        Text(model.dirty ? "草稿" : "已同步").font(.caption).foregroundStyle(.secondary)
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
        .background(Color(red: 0.075, green: 0.085, blue: 0.09))
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
                    Text("OAI 已连接").font(.callout)
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
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AGENTPAD / 13").font(.system(size: 12, weight: .bold, design: .monospaced))
                    Text("CODEX OAI EDITION").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "circle.circle").font(.system(size: 36)).foregroundStyle(.secondary)
                VStack(alignment: .leading) {
                    Text("ENC").font(.caption.bold())
                    Text("按压 · 固定动作").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }.padding(.bottom, 8)
            ForEach(0..<3) { row in
                HStack(spacing: 12) {
                    ForEach(0..<4) { column in key(row * 4 + column) }
                }
            }
            HStack(spacing: 12) {
                key(12).frame(maxWidth: .infinity)
                VStack(spacing: 5) {
                    Image(systemName: "hand.tap").font(.title3)
                    Text("TP5 · 切换层").font(.caption)
                }.foregroundStyle(.secondary).frame(maxWidth: .infinity).frame(height: 72)
                VStack(spacing: 5) {
                    Image(systemName: "plus.circle").font(.title3)
                    Text("摇杆 · 会话切换¹").font(.caption)
                }.foregroundStyle(.secondary).frame(maxWidth: .infinity).frame(height: 72)
            }
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(white: 0.12)))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.10)))
    }
    private func key(_ index: Int) -> some View {
        let action = PadAction.all[model.map.values[index]]
        let active = model.selected == index
        return Button { model.selected = index } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(String(format: "K%02d", index)).font(.system(size: 10, design: .monospaced)).foregroundStyle(active ? accent : .gray)
                    Spacer(minLength: 0)
                    Circle().fill(index < 6 ? accent.opacity(0.65) : .white.opacity(0.45)).frame(width: 4, height: 4)
                }
                Text(action.title).font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
                Text(action.wire.components(separatedBy: " · ").first ?? "").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
            }.padding(11).frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(active ? accent.opacity(0.10) : .white.opacity(0.045)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(active ? accent : .white.opacity(0.09), lineWidth: active ? 1.5 : 1))
        }.buttonStyle(.plain).disabled(model.busy)
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
            Label("固定硬件行为", systemImage: "lock").font(.caption.bold())
            Text("编码器按压：ENC\nCODEX 旋转：推理强度\nTP5：CODEX → FN → NAV → MEDIA\n¹ 摇杆默认左右切换会话；FN 的 JS_MODE 可切换模式。")
                .font(.caption).foregroundStyle(.secondary).lineSpacing(5)
            Text("保护规则、原生快捷键回退和 LED 均由固件执行。旧版麦克风别名实际走 ACT10，请优先选择“麦克风”（ACT11）。")
                .font(.caption).foregroundStyle(.secondary).lineSpacing(4)
        }.disabled(model.busy)
    }
    private var actionHelp: String {
        switch model.map.values[model.selected] {
        case 10: return "SAFE 的解锁状态由固件计时，松开后清除。"
        case 11, 14: return "ACT10 具有确认保护：短按不触发；保持 600 ms 后松开，或先由 SAFE 解锁。"
        case 3: return "新建任务；原生快捷键回退模式下，长按可切换会话。"
        case 15: return "发送官方第二麦克风触点 ACT11 的按下与松开事件。"
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
                    .buttonStyle(.borderedProminent).foregroundStyle(.black).disabled(!model.canSave)
            }.disabled(model.busy)
        }.padding(22)
    }
}
