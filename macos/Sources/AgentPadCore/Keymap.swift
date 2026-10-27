import Foundation

public enum PadError: LocalizedError {
    case invalidMap, invalidProfile, invalidReport, disconnected, busy, timeout, device(String)
    public var errorDescription: String? {
        switch self {
        case .invalidMap: return "键位必须是 15 位十六进制；ENC 只能放在编码器槽位。"
        case .invalidProfile: return "配置文件格式或设备类型不匹配。"
        case .invalidReport: return "设备返回了无效的 HID 数据。"
        case .disconnected: return "设备未连接。请连接 Codex OAI 固件设备。"
        case .busy: return "正在处理上一条设备请求。"
        case .timeout: return "设备响应超时。请确认固件支持 keymap RPC，或暂时退出其他配置工具后重试。"
        case .device(let message): return message
        }
    }
}

public struct PadAction: Identifiable {
    public let id: Int
    public let title: String
    public let wire: String
    public static let all: [PadAction] = [
        .init(id: 0, title: "无操作", wire: "NOOP"),
        .init(id: 1, title: "上一个会话", wire: "AG00 · PREVIOUS"),
        .init(id: 2, title: "下一个会话", wire: "AG01 · NEXT"),
        .init(id: 3, title: "新建任务", wire: "AG02 · NEW"),
        .init(id: 4, title: "审查", wire: "AG03 · REVIEW"),
        .init(id: 5, title: "计划", wire: "AG04 · PLAN"),
        .init(id: 6, title: "实现", wire: "AG05 · IMPLEMENT"),
        .init(id: 7, title: "重构", wire: "ACT06 · REFACTOR"),
        .init(id: 8, title: "测试", wire: "ACT07 · TEST"),
        .init(id: 9, title: "中止", wire: "ACT08 · ABORT"),
        .init(id: 10, title: "安全解锁", wire: "ACT09 · SAFE"),
        .init(id: 11, title: "确认（保护）", wire: "ACT10 · ACCEPT"),
        .init(id: 12, title: "发送", wire: "ACT12 · SEND"),
        .init(id: 13, title: "编码器", wire: "ENC"),
        .init(id: 14, title: "麦克风（合并模式）", wire: "ACT10 · MICROPHONE"),
        .init(id: 15, title: "麦克风（分离模式）", wire: "ACT11")
    ]
    /// Compact legends apply only to the legacy OAI catalog. Native actions
    /// have their own IDs, including Input's KV_* and KI_* bindings.
    public var keycapTitle: String {
        let titles = ["无操作", "上个会话", "下个会话", "新建任务", "审查", "计划", "实现", "重构", "测试", "中止", "解锁", "确认", "发送", "编码器", "麦克风", "麦克风"]
        guard Self.all.indices.contains(id), Self.all[id].wire == wire else { return title }
        return titles[id]
    }
    public static let editable = all.filter { $0.id != 13 }
}

public struct Keymap: Equatable, Sendable {
    public static let factoryHex = "123456789abecd1"
    public private(set) var values: [Int]
    private var native = false
    public init(nativeActions: [Int]) { values = nativeActions; native = true }
    public func nativeDisplay(overrides: [Int]) -> Keymap {
        Keymap(nativeActions: overrides.enumerated().map { position, action in
            action == 0 || action == 1 ? 82 + values[position] : action
        })
    }
    public func action(at index: Int) -> PadAction { (native ? PadAction.native : PadAction.all)[values[index]] }
    public init(hex: String = Keymap.factoryHex) throws {
        let parsed = hex.compactMap { Int(String($0), radix: 16) }
        guard hex.utf8.count == 15, parsed.count == 15,
              parsed.enumerated().allSatisfy({ $0.element != 13 || $0.offset == 13 }) else {
            throw PadError.invalidMap
        }
        values = parsed
    }
    public var hex: String { values.map { String($0, radix: 16) }.joined() }
    public mutating func assign(_ action: Int, to position: Int) {
        guard (0..<13).contains(position), (0..<16).contains(action), action != 13 else { return }
        values[position] = action
    }
    // These slots are retained byte-for-byte on device reads/imports. Current
    // firmware bypasses them: encoder is fixed ENC and TP5 cycles layers.
    public func profileData() throws -> Data {
        try JSONEncoder().encode(Profile(format: 1, device: "agentpad13-codex-oai", layer: 0, map: hex))
    }
    public init(profileData: Data) throws {
        let profile = try JSONDecoder().decode(Profile.self, from: profileData)
        guard profile.format == 1, profile.device == "agentpad13-codex-oai", profile.layer == 0 else {
            throw PadError.invalidProfile
        }
        try self.init(hex: profile.map)
    }
    private struct Profile: Codable {
        let format: Int
        let device: String
        let layer: Int
        let map: String
    }
}

public struct LEDSettings: Equatable, Sendable {
    public static let factory = LEDSettings(isOn: true, brightness: 100)

    public var isOn: Bool
    private var level: Int
    public var brightness: Int {
        get { level }
        set { level = min(max(newValue, 0), 100) }
    }

    public init(isOn: Bool, brightness: Int) {
        self.isOn = isOn
        level = min(max(brightness, 0), 100)
    }

    public init(result: [String: Any]) throws {
        guard let isOn = result["on"] as? Bool,
              let brightness = (result["brightness"] as? NSNumber)?.intValue,
              (0...100).contains(brightness) else {
            throw PadError.invalidReport
        }
        self.init(isOn: isOn, brightness: brightness)
    }
}

public enum OAIWire {
    public static func request(
        method: String,
        id: UInt16,
        map: Keymap? = nil,
        led: LEDSettings? = nil,
        layer: Int = 0, configuration: LayerConfiguration? = nil, layerCount: Int? = nil, fileOffset: Int? = nil
    ) throws -> [[UInt8]] {
        guard id <= 998 else { throw PadError.invalidReport }
        var params: [String: Any] = [:]
        if map != nil || method.hasPrefix("v.oai.keymap.") {
            params["l"] = 0
        }
        if let map { params["m"] = map.hex }
        if method.hasPrefix("v.agentpad.cfg.") && method != "v.agentpad.cfg.info" { params["l"] = layer }
        if let layerCount {
            guard (4...16).contains(layerCount) else { throw PadError.invalidProfile }
            params["n"] = layerCount
        }
        if method == "fs.readbin" {
            guard let offset = fileOffset, (0...16384).contains(offset) else { throw PadError.invalidReport }
            params["file"] = "keymap.json"
            params["offset"] = offset
            params["len"] = 192
        }
        if let configuration { params["m"] = configuration.hex }
        if let led {
            params["on"] = led.isOn
            params["brightness"] = led.brightness
        }
        let data = try JSONSerialization.data(withJSONObject: ["method": method, "id": Int(id), "params": params], options: [.sortedKeys])
        return frames(Array(data) + [13, 10])
    }
    public static func frames(_ payload: [UInt8]) -> [[UInt8]] {
        stride(from: 0, to: payload.count, by: 61).map { offset in
            let chunk = Array(payload[offset..<min(offset + 61, payload.count)])
            return [6, 2, UInt8(chunk.count)] + chunk + Array(repeating: 0, count: 61 - chunk.count)
        }
    }
    public static func payload(_ report: [UInt8]) throws -> [UInt8] {
        guard report.count == 64, report[0] == 6, report[1] == 2,
              report[2] <= 61 else { throw PadError.invalidReport }
        let end = 3 + Int(report[2])
        guard report[end...].allSatisfy({ $0 == 0 }) else { throw PadError.invalidReport }
        return Array(report[3..<end])
    }
}

// Firmware RPC responses end in CRLF. Notifications on the same endpoint are
// ignored by the caller unless their numeric id matches the in-flight request.
public struct RPCDecoder {
    private var buffer = [UInt8]()
    public init() {}
    public mutating func reset() { buffer.removeAll() }
    public mutating func receive(_ report: [UInt8]) throws -> [[String: Any]] {
        buffer += try OAIWire.payload(report)
        guard buffer.count <= 4096 else { reset(); throw PadError.invalidReport }
        var messages = [[String: Any]]()
        while let end = buffer.firstIndex(of: 10) {
            let line = Array(buffer[..<end])
            buffer.removeFirst(end + 1)
            if let json = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] {
                messages.append(json)
            }
        }
        return messages
    }
}
