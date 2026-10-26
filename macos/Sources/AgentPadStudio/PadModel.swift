import SwiftUI
import AppKit
import AgentPadCore

@MainActor
final class PadModel: ObservableObject {
    @Published var map = try! Keymap()
    @Published var selected = 0
    @Published var devices: [HIDTransport.Device] = []
    @Published var deviceID: Int?
    @Published var connected = false
    @Published var busy = false
    @Published var demo = ProcessInfo.processInfo.arguments.contains("--demo")
    @Published var status = "连接设备以读取当前键位，或先离线编辑。"
    @Published var error: String?
    @Published var baseline: Keymap?
    @Published var led = LEDSettings.factory
    @Published var ledBaseline: LEDSettings?
    @Published var ledSupported = true
    @Published var deviceVersion: Int?
    private let transport = HIDTransport()
    var dirty: Bool { map != baseline }
    var ledDirty: Bool { led != ledBaseline }
    var canSave: Bool { connected && !demo && !busy && baseline != nil && dirty }
    var canSaveLED: Bool { connected && !demo && !busy && ledSupported && ledBaseline != nil && ledDirty }

    init() {
        transport.onDisconnect = { [weak self] in
            self?.connected = false
            self?.baseline = nil
            self?.ledBaseline = nil
            self?.deviceVersion = nil
            self?.status = "USB 连接已断开；草稿已保留。"
        }
        if demo { status = "演示模式 · 所有修改仅在本地，不访问 USB。" }
    }
    func scan() {
        guard !demo else { return }
        do {
            devices = try transport.discover()
            if !devices.contains(where: { $0.id == deviceID }) { deviceID = devices.first?.id }
            status = devices.isEmpty ? "未找到 Codex OAI 设备（303A:8360 / FF00:61）。" : "找到 \(devices.count) 个设备，请连接并读取。"
        } catch { self.error = error.localizedDescription }
    }
    func connect() {
        guard let target = devices.first(where: { $0.id == deviceID }), !busy else { return }
        run {
            try self.transport.connect(target)
            self.connected = true
            self.baseline = nil
            self.ledBaseline = nil
            self.deviceVersion = target.version
            self.ledSupported = target.version >= 0x0013
            do {
                try await self.readMap()
                if await self.readLEDIfSupported() {
                    self.status = "已读取键位与灯光配置。"
                } else {
                    self.status = "已读取键位；固件 \(Self.versionLabel(target.version)) 不支持灯光配置。"
                }
            } catch {
                self.transport.disconnect()
                self.connected = false
                self.baseline = nil
                self.ledBaseline = nil
                self.deviceVersion = nil
                throw error
            }
        }
    }
    func disconnect() {
        transport.disconnect()
        connected = false
        baseline = nil
        ledBaseline = nil
        deviceVersion = nil
        status = "已断开；草稿已保留。"
    }
    func read() {
        run {
            try await self.readMap()
            if await self.readLEDIfSupported() {
                self.status = "已重新读取键位与灯光配置。"
            } else {
                self.status = "已重新读取键位；此设备固件不支持灯光配置。"
            }
        }
    }
    private func readMap() async throws {
        let response = try await transport.request("v.oai.keymap.get")
        guard let result = response["result"] as? [String: Any],
              let layer = result["l"] as? Int, layer == 0,
              let hex = result["m"] as? String else { throw PadError.invalidReport }
        let received = try Keymap(hex: hex)
        map = received
        baseline = received
    }
    private func readLED() async throws {
        let response = try await transport.request("v.agentpad.led.get")
        guard let result = response["result"] as? [String: Any] else { throw PadError.invalidReport }
        let received = try LEDSettings(result: result)
        led = received
        ledBaseline = received
        ledSupported = true
    }
    @discardableResult
    private func readLEDIfSupported() async -> Bool {
        if let deviceVersion, deviceVersion < 0x0013 {
            ledSupported = false
            ledBaseline = nil
            return false
        }
        do {
            try await readLED()
            return true
        } catch {
            ledSupported = false
            ledBaseline = nil
            return false
        }
    }
    private static func versionLabel(_ version: Int) -> String {
        String(format: "v%04X", version)
    }
    func save() {
        guard canSave else { return }
        let candidate = map
        run {
            self.baseline = nil
            let response = try await self.transport.request("v.oai.keymap.set", map: candidate)
            guard let result = response["result"] as? Bool, result else { throw PadError.invalidReport }
            // Do not report success on ACK alone: verify persisted-map readback.
            try await self.readMap()
            guard self.map == candidate else { throw PadError.device("回读键位与写入值不一致，请重新读取后检查。") }
            self.status = "已保存到设备并回读验证；固件将在重启后恢复此配置。"
        }
    }
    func restore() { map = try! Keymap(); status = "已载入出厂键位草稿；点击保存后才会写入设备。" }
    func saveLED() {
        guard canSaveLED else { return }
        let candidate = led
        run {
            let response = try await self.transport.request("v.agentpad.led.set", led: candidate)
            guard let result = response["result"] as? Bool, result else { throw PadError.invalidReport }
            try await self.readLED()
            guard self.led == candidate else { throw PadError.device("回读灯光设置与写入值不一致，请重新读取后检查。") }
            self.status = "灯光设置已保存到设备并回读验证。"
        }
    }
    func assign(_ value: Int) { map.assign(value, to: selected) }
    func importProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            map = try Keymap(profileData: Data(contentsOf: url))
            status = "已导入 \(url.lastPathComponent)；尚未写入设备。"
        } catch { self.error = error.localizedDescription }
    }
    func exportProfile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "AgentPad13-Codex.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try map.profileData().write(to: url, options: .atomic)
            status = "已导出 \(url.lastPathComponent)。"
        } catch { self.error = error.localizedDescription }
    }
    private func run(_ operation: @escaping () async throws -> Void) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do { try await operation() }
            catch { self.error = error.localizedDescription }
        }
    }
}
