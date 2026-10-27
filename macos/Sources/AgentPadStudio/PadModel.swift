import SwiftUI
import AppKit
import AgentPadCore

@MainActor
final class PadModel: ObservableObject {
    @Published var map = try! Keymap()
    @Published var selectedLayer = PadLayer.codex
    @Published var layers = PadLayer.allCases.map { LayerConfiguration.factory($0) }
    @Published var layerNames = PadLayer.allCases.map(\.title)
    @Published var layerBaseline: [LayerConfiguration]?
    @Published var extendedSupported = true
    @Published var selected = 0
    func layerTitle(_ layer: PadLayer) -> String {
        layerNames.indices.contains(layer.rawValue) ? layerNames[layer.rawValue] : layer.title
    }
    var availableLayers: [PadLayer] { PadLayer.configured(layers.count) }
    var dynamicLayersSupported: Bool { demo || (deviceVersion ?? 0) >= 0x001C }
    var inputKeymapSupported: Bool { demo || (deviceVersion ?? 0) >= 0x0018 }
    var displayMap: Keymap {
        guard selectedLayer == .codex else { return Keymap(nativeActions: layers[selectedLayer.rawValue].actions) }
        guard inputKeymapSupported else { return map }
        return map.nativeDisplay(overrides: layers[0].actions)
    }
    var actions: [PadAction] {
        if selectedLayer == .codex && !inputKeymapSupported { return PadAction.editable }
        return inputKeymapSupported ? PadAction.native.filter { $0.id != 95 && (dynamicLayersSupported || $0.id < 136) } : Array(PadAction.native.prefix(82))
    }
    var selectedAction: Int { displayMap.values[selected] }
    var layerDirty: Bool { layers != layerBaseline }
    var canEditLayer: Bool { selectedLayer == .codex || extendedSupported }
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
    var dirty: Bool { map != baseline || (extendedSupported && layerDirty) }
    var ledDirty: Bool { led != ledBaseline }
    var canSave: Bool { connected && !demo && !busy && baseline != nil && dirty }
    var canSaveLED: Bool { connected && !demo && !busy && ledSupported && ledBaseline != nil && ledDirty }

    init() {
        transport.onDisconnect = { [weak self] in
            self?.connected = false
            self?.baseline = nil
            self?.layerBaseline = nil
            self?.ledBaseline = nil
            self?.deviceVersion = nil
            self?.extendedSupported = true
            self?.ledSupported = true
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
            self.layerBaseline = nil
            self.ledBaseline = nil
            self.deviceVersion = target.version
            self.ledSupported = target.version >= 0x0013
            self.extendedSupported = target.version >= 0x0014
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
                self.layerBaseline = nil
                self.ledBaseline = nil
                self.deviceVersion = nil
                self.extendedSupported = true
                self.ledSupported = true
                throw error
            }
        }
    }
    func disconnect() {
        transport.disconnect()
        connected = false
        baseline = nil
        layerBaseline = nil
        ledBaseline = nil
        deviceVersion = nil
        extendedSupported = true
        ledSupported = true
        status = "已断开；草稿已保留。"
    }
    func read() {
        run {
            self.baseline = nil
            self.layerBaseline = nil
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
        if extendedSupported {
            var receivedLayers = [LayerConfiguration]()
            let count = dynamicLayersSupported ? try await readLayerCount() : 4
            for layer in PadLayer.configured(count) { receivedLayers.append(try await readLayer(layer)) }
            let receivedNames = inputKeymapSupported ? try await readLayerNames(count: count) : PadLayer.configured(count).map(\.title)
            layerNames = receivedNames
            layers = receivedLayers
            if selectedLayer.rawValue >= layers.count { selectedLayer = .codex }
            layerBaseline = receivedLayers
        }
        map = received
        baseline = received
    }
    private func readLayerNames(count: Int) async throws -> [String] {
        var reader = InputLayerNameReader()
        var requests = 0
        while !reader.isComplete {
            guard requests < 128 else { throw PadError.invalidReport }
            let response = try await transport.request("fs.readbin", fileOffset: reader.offset)
            guard let result = response["result"] as? [String: Any] else { throw PadError.invalidReport }
            try reader.append(result: result)
            requests += 1
        }
        return try reader.names(expectedCount: count)
    }
    private func readLayerCount() async throws -> Int {
        let response = try await transport.request("v.agentpad.cfg.info")
        guard let result = response["result"] as? [String: Any], let count = result["n"] as? Int,
              (4...16).contains(count) else { throw PadError.invalidReport }
        return count
    }
    private func readLayer(_ layer: PadLayer) async throws -> LayerConfiguration {
        let response = try await transport.request("v.agentpad.cfg.get", layer: layer.rawValue)
        guard let result = response["result"] as? [String: Any],
              result["l"] as? Int == layer.rawValue, let hex = result["m"] as? String else { throw PadError.invalidReport }
        return try LayerConfiguration(hex: hex)
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
        let candidateLayers = layers
        let expectedLayerCount = layerBaseline?.count
        run {
            self.baseline = nil
            self.layerBaseline = nil
            if self.dynamicLayersSupported {
                let count = try await self.readLayerCount()
                guard expectedLayerCount == count else { throw PadError.device("设备层数已由其他工具修改，请先重新读取。") }
                if candidateLayers.count != count {
                    _ = try await self.transport.request("v.agentpad.cfg.info", layerCount: candidateLayers.count)
                }
            } else if candidateLayers.count != 4 { throw PadError.device("当前固件仅支持四层，请更新固件。") }
            let response = try await self.transport.request("v.oai.keymap.set", map: candidate)
            guard let result = response["result"] as? Bool, result else { throw PadError.invalidReport }
            if self.extendedSupported {
                for layer in PadLayer.configured(candidateLayers.count) {
                    let response = try await self.transport.request("v.agentpad.cfg.set", layer: layer.rawValue, configuration: candidateLayers[layer.rawValue])
                    guard response["result"] as? Bool == true else { throw PadError.invalidReport }
                }
            }
            // Do not report success on ACK alone: verify persisted-map readback.
            try await self.readMap()
            guard self.map == candidate && (!self.extendedSupported || self.layers == candidateLayers) else {
                self.baseline = nil
                self.layerBaseline = nil
                throw PadError.device("回读键位与写入值不一致，请重新读取后检查。")
            }
            self.status = "已保存到设备并回读验证；固件将在重启后恢复此配置。"
        }
    }
    func restore() { selectedLayer = .codex; map = try! Keymap(); layers = PadLayer.allCases.map { .factory($0) }; status = "已载入出厂键位草稿；点击保存后才会写入设备。" }
    func saveLED() {
        guard canSaveLED else { return }
        let candidate = led
        run {
            self.ledBaseline = nil
            let response = try await self.transport.request("v.agentpad.led.set", led: candidate)
            guard let result = response["result"] as? Bool, result else { throw PadError.invalidReport }
            try await self.readLED()
            guard self.led == candidate else { throw PadError.device("回读灯光设置与写入值不一致，请重新读取后检查。") }
            self.status = "灯光设置已保存到设备并回读验证。"
        }
    }
    func assign(_ value: Int) {
        if selectedLayer == .codex {
            if inputKeymapSupported {
                if (82..<98).contains(value) {
                    map.assign(value - 82, to: selected)
                    layers[0].actions[selected] = 0
                } else if value == 0 {
                    map.assign(0, to: selected)
                    layers[0].actions[selected] = 0
                } else {
                    layers[0].actions[selected] = value
                }
            } else { map.assign(value, to: selected) }
        }
        else if extendedSupported { layers[selectedLayer.rawValue].actions[selected] = value }
    }
    var indicatorColor: Color {
        get {
            let rgb = layers[selectedLayer.rawValue].color
            return Color(.sRGB, red: Double(rgb[0])/255, green: Double(rgb[1])/255, blue: Double(rgb[2])/255)
        }
        set {
            guard let color = NSColor(newValue).usingColorSpace(.sRGB) else { return }
            layers[selectedLayer.rawValue].color = [color.redComponent, color.greenComponent, color.blueComponent].map { Int(($0 * 255).rounded()) }
        }
    }
    func importProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            if let profile = try? JSONDecoder().decode(PadProfile.self, from: data) {
                let (importedMap, importedLayers, importedLED) = try profile.validated()
                map = importedMap; layers = importedLayers; led = importedLED
                if selectedLayer.rawValue >= layers.count { selectedLayer = .codex }
            } else { map = try Keymap(profileData: data) }
            status = "已导入 \(url.lastPathComponent)；尚未写入设备。"
        } catch { self.error = error.localizedDescription }
    }
    func exportProfile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "AgentPad13-All-Layers.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try JSONEncoder().encode(PadProfile(map: map, layers: layers, led: led)).write(to: url, options: .atomic)
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
