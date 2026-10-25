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
        VStack(spacing: 10) {
            HStack {
                Text("PCB v5.8 · 正面俯视").font(.caption)
                Spacer()
                Text("USB ↑").font(.system(size: 11, design: .monospaced))
            }.foregroundStyle(.secondary)
            GeometryReader { geometry in
                let scale = geometry.size.width / PhysicalLayout.width
                ZStack(alignment: .topLeading) {
                    PCBOutline().fill(Color(white: 0.12))
                    PCBOutline().stroke(.white.opacity(0.15), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.25))
                        .frame(width: 9 * scale, height: 3 * scale)
                        .position(x: PhysicalLayout.usb.x * scale, y: PhysicalLayout.usb.y * scale)
                    Text("AGENTPAD / 13")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .position(x: 42.1 * scale, y: 13 * scale)
                    fixedControl("ENC", symbol: "circle.circle", diameter: 17.5 * scale)
                        .position(x: PhysicalLayout.encoder.x * scale, y: PhysicalLayout.encoder.y * scale)
                        .help("RE1 · 编码器按压固定为 ENC；旋转调整推理强度")
                    fixedControl("JS1", symbol: "plus", diameter: 14 * scale)
                        .position(x: PhysicalLayout.joystick.x * scale, y: PhysicalLayout.joystick.y * scale)
                        .help("JS1 · 摇杆；默认左右切换会话")
                    ForEach(0..<13) { index in
                        let center = PhysicalLayout.switches[index]
                        key(index, scale: scale)
                            .frame(width: (index == 12 ? 36.55 : 17.5) * scale, height: 17.5 * scale)
                            .position(x: center.x * scale, y: center.y * scale)
                    }
                    fixedControl("TP5", symbol: "hand.tap", diameter: 14 * scale)
                        .position(x: PhysicalLayout.touch.x * scale, y: PhysicalLayout.touch.y * scale)
                        .help("TP5 · 固定循环切换 CODEX / FN / NAV / MEDIA")
                    serviceMark("BOOT", diameter: 6 * scale)
                        .position(x: PhysicalLayout.boot.x * scale, y: PhysicalLayout.boot.y * scale)
                        .help("背面 SW14 · BOOT / 摇杆校准，不是可映射键")
                    serviceMark("RESET", diameter: 6 * scale)
                        .position(x: PhysicalLayout.reset.x * scale, y: PhysicalLayout.reset.y * scale)
                        .help("背面 SW15 · 硬件 RESET，不是可映射键")
                }
            }
            .aspectRatio(PhysicalLayout.width / PhysicalLayout.height, contentMode: .fit)
            Text("按 PCB 毫米坐标等比绘制 · 虚线标记为背面 BOOT / RESET")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }.frame(maxWidth: 370).frame(maxWidth: .infinity)
    }
    private func fixedControl(_ name: String, symbol: String, diameter: Double) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: diameter * 0.23))
            Text(name).font(.system(size: max(8, diameter * 0.13), weight: .medium, design: .monospaced))
        }
        .foregroundStyle(.secondary)
        .frame(width: diameter, height: diameter)
        .background(Circle().fill(.white.opacity(0.035)))
        .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1.5))
    }
    private func serviceMark(_ name: String, diameter: Double) -> some View {
        Text(name).font(.system(size: 6, design: .monospaced)).foregroundStyle(.secondary)
            .frame(width: diameter, height: diameter)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.2), style: StrokeStyle(dash: [3, 2])))
    }
    private func key(_ index: Int, scale: Double) -> some View {
        let action = PadAction.all[model.map.values[index]]
        let active = model.selected == index
        return Button { model.selected = index } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 0) {
                    Text("SW\(index + 1)").font(.system(size: max(8, 1.7 * scale), design: .monospaced)).foregroundStyle(active ? accent : .gray)
                    Spacer(minLength: 0)
                    Circle().fill(index < 6 ? accent.opacity(0.65) : .white.opacity(0.45)).frame(width: 4, height: 4)
                }
                Text(action.title).font(.system(size: max(10, 2.1 * scale), weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(String(format: "K%02d", index) + " · " + (action.wire.components(separatedBy: " · ").first ?? ""))
                    .font(.system(size: max(8, 1.5 * scale), design: .monospaced)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            }.padding(8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 9).fill(active ? accent.opacity(0.10) : .white.opacity(0.045)))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(active ? accent : .white.opacity(0.09), lineWidth: active ? 1.5 : 1))
                .contentShape(RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).disabled(model.busy)
        .help("SW\(index + 1) · K\(String(format: "%02d", index)) · \(action.title)")
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

// Use the PCB's actual asymmetric chamfers rather than a generic rounded case.
private struct PCBOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = PhysicalLayout.outline.map {
            CGPoint(x: $0.x / PhysicalLayout.width * rect.width,
                    y: $0.y / PhysicalLayout.height * rect.height)
        }
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}
