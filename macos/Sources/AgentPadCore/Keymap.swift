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
    public static let editable = all.filter { $0.id != 13 }
}

public struct Keymap: Equatable, Sendable {
    public static let factoryHex = "123456789abfcd1"
    public private(set) var values: [Int]
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

public enum OAIWire {
    public static func request(method: String, id: UInt16, map: Keymap? = nil) throws -> [[UInt8]] {
        guard id <= 998 else { throw PadError.invalidReport }
        var params: [String: Any] = ["l": 0]
        if let map { params["m"] = map.hex }
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
