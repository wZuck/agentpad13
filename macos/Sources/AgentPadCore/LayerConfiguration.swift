import Foundation

public struct PadLayer: RawRepresentable, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    public let rawValue: Int
    public init?(rawValue: Int) { guard (0..<16).contains(rawValue) else { return nil }; self.rawValue = rawValue }
    public static let codex = Self(rawValue: 0)!, fn = Self(rawValue: 1)!, nav = Self(rawValue: 2)!, media = Self(rawValue: 3)!
    public static let allCases = [codex, fn, nav, media]
    public static func configured(_ count: Int) -> [Self] { (0..<min(max(count, 4), 16)).map { Self(rawValue: $0)! } }
    public var id: Int { rawValue }
    public var title: String { rawValue < 4 ? ["CODEX", "FN", "NAV", "MEDIA"][rawValue] : "LAYER \(rawValue + 1)" }
}

public extension PadAction {
    static let native: [PadAction] = [
        .init(id: 0, title: "无操作", wire: "KC_NO"),
        .init(id: 1, title: "沿用 CODEX 此键", wire: "KC_TRNS"),
        .init(id: 2, title: "切换摇杆模式", wire: "JS_MODE"),
        .init(id: 3, title: "触摸切层开关", wire: "TP_TOG"),
        .init(id: 4, title: "F1", wire: "KC_F1"),
        .init(id: 5, title: "F2", wire: "KC_F2"),
        .init(id: 6, title: "F3", wire: "KC_F3"),
        .init(id: 7, title: "F4", wire: "KC_F4"),
        .init(id: 8, title: "F5", wire: "KC_F5"),
        .init(id: 9, title: "F6", wire: "KC_F6"),
        .init(id: 10, title: "F7", wire: "KC_F7"),
        .init(id: 11, title: "F8", wire: "KC_F8"),
        .init(id: 12, title: "F9", wire: "KC_F9"),
        .init(id: 13, title: "F10", wire: "KC_F10"),
        .init(id: 14, title: "F11", wire: "KC_F11"),
        .init(id: 15, title: "F12", wire: "KC_F12"),
        .init(id: 16, title: "Escape", wire: "KC_ESC"),
        .init(id: 17, title: "Home", wire: "KC_HOME"),
        .init(id: 18, title: "↑", wire: "KC_UP"),
        .init(id: 19, title: "End", wire: "KC_END"),
        .init(id: 20, title: "←", wire: "KC_LEFT"),
        .init(id: 21, title: "↓", wire: "KC_DOWN"),
        .init(id: 22, title: "→", wire: "KC_RGHT"),
        .init(id: 23, title: "Page Up", wire: "KC_PGUP"),
        .init(id: 24, title: "Page Down", wire: "KC_PGDN"),
        .init(id: 25, title: "Delete", wire: "KC_DEL"),
        .init(id: 26, title: "Backspace", wire: "KC_BSPC"),
        .init(id: 27, title: "静音", wire: "KC_MUTE"),
        .init(id: 28, title: "音量 −", wire: "KC_VOLD"),
        .init(id: 29, title: "音量 +", wire: "KC_VOLU"),
        .init(id: 30, title: "播放 / 暂停", wire: "KC_MPLY"),
        .init(id: 31, title: "上一曲", wire: "KC_MPRV"),
        .init(id: 32, title: "下一曲", wire: "KC_MNXT"),
        .init(id: 33, title: "停止播放", wire: "KC_MSTP"),
        .init(id: 34, title: "计算器", wire: "KC_CALC"),
        .init(id: 35, title: "RGB 开关", wire: "RGB_TOG"),
        .init(id: 36, title: "RGB 效果", wire: "RGB_MOD"),
        .init(id: 37, title: "RGB 色相 +", wire: "RGB_HUI"),
        .init(id: 38, title: "RGB 色相 −", wire: "RGB_HUD"),
        .init(id: 39, title: "Enter", wire: "KC_ENT"),
        .init(id: 40, title: "Space", wire: "KC_SPC"),
        .init(id: 41, title: "Tab", wire: "KC_TAB"),
        .init(id: 42, title: "A", wire: "KC_A"),
        .init(id: 43, title: "B", wire: "KC_B"),
        .init(id: 44, title: "C", wire: "KC_C"),
        .init(id: 45, title: "D", wire: "KC_D"),
        .init(id: 46, title: "E", wire: "KC_E"),
        .init(id: 47, title: "F", wire: "KC_F"),
        .init(id: 48, title: "G", wire: "KC_G"),
        .init(id: 49, title: "H", wire: "KC_H"),
        .init(id: 50, title: "I", wire: "KC_I"),
        .init(id: 51, title: "J", wire: "KC_J"),
        .init(id: 52, title: "K", wire: "KC_K"),
        .init(id: 53, title: "L", wire: "KC_L"),
        .init(id: 54, title: "M", wire: "KC_M"),
        .init(id: 55, title: "N", wire: "KC_N"),
        .init(id: 56, title: "O", wire: "KC_O"),
        .init(id: 57, title: "P", wire: "KC_P"),
        .init(id: 58, title: "Q", wire: "KC_Q"),
        .init(id: 59, title: "R", wire: "KC_R"),
        .init(id: 60, title: "S", wire: "KC_S"),
        .init(id: 61, title: "T", wire: "KC_T"),
        .init(id: 62, title: "U", wire: "KC_U"),
        .init(id: 63, title: "V", wire: "KC_V"),
        .init(id: 64, title: "W", wire: "KC_W"),
        .init(id: 65, title: "X", wire: "KC_X"),
        .init(id: 66, title: "Y", wire: "KC_Y"),
        .init(id: 67, title: "Z", wire: "KC_Z"),
        .init(id: 68, title: "0", wire: "KC_0"),
        .init(id: 69, title: "1", wire: "KC_1"),
        .init(id: 70, title: "2", wire: "KC_2"),
        .init(id: 71, title: "3", wire: "KC_3"),
        .init(id: 72, title: "4", wire: "KC_4"),
        .init(id: 73, title: "5", wire: "KC_5"),
        .init(id: 74, title: "6", wire: "KC_6"),
        .init(id: 75, title: "7", wire: "KC_7"),
        .init(id: 76, title: "8", wire: "KC_8"),
        .init(id: 77, title: "9", wire: "KC_9"),
        .init(id: 78, title: "复制 ⌘C", wire: "LGUI(KC_C)"),
        .init(id: 79, title: "粘贴 ⌘V", wire: "LGUI(KC_V)"),
        .init(id: 80, title: "撤销 ⌘Z", wire: "LGUI(KC_Z)"),
        .init(id: 81, title: "全选 ⌘A", wire: "LGUI(KC_A)"),
        .init(id: 82, title: "禁用此键", wire: "KC_NONE"),
        .init(id: 83, title: "Codex 上一个", wire: "KV_OAI_AG00"),
        .init(id: 84, title: "Codex 下一个", wire: "KV_OAI_AG01"),
        .init(id: 85, title: "Codex 新建", wire: "KV_OAI_AG02"),
        .init(id: 86, title: "Codex 审查", wire: "KV_OAI_AG03"),
        .init(id: 87, title: "Codex 计划", wire: "KV_OAI_AG04"),
        .init(id: 88, title: "Codex 实现", wire: "KV_OAI_AG05"),
        .init(id: 89, title: "Codex 重构", wire: "KV_OAI_ACT06"),
        .init(id: 90, title: "Codex 测试", wire: "KV_OAI_ACT07"),
        .init(id: 91, title: "Codex 中止", wire: "KV_OAI_ACT08"),
        .init(id: 92, title: "Codex SAFE", wire: "KV_OAI_ACT09"),
        .init(id: 93, title: "Codex ACCEPT", wire: "KV_OAI_ACCEPT"),
        .init(id: 94, title: "Codex 发送", wire: "KV_OAI_ACT12"),
        .init(id: 95, title: "固定编码器", wire: "KV_OAI_ENC_CLK"),
        .init(id: 96, title: "Codex 麦克风", wire: "KV_OAI_ACT10"),
        .init(id: 97, title: "Codex 独立麦克风", wire: "KV_OAI_ACT11"),
        .init(id: 98, title: "LCTL", wire: "KC_LCTL"),
        .init(id: 99, title: "LSFT", wire: "KC_LSFT"),
        .init(id: 100, title: "LALT", wire: "KC_LALT"),
        .init(id: 101, title: "LGUI", wire: "KC_LGUI"),
        .init(id: 102, title: "RCTL", wire: "KC_RCTL"),
        .init(id: 103, title: "RSFT", wire: "KC_RSFT"),
        .init(id: 104, title: "RALT", wire: "KC_RALT"),
        .init(id: 105, title: "RGUI", wire: "KC_RGUI"),
        .init(id: 106, title: "CAPS", wire: "KC_CAPS"),
        .init(id: 107, title: "INS", wire: "KC_INS"),
        .init(id: 108, title: "PSCR", wire: "KC_PSCR"),
        .init(id: 109, title: "SCRL", wire: "KC_SCRL"),
        .init(id: 110, title: "PAUS", wire: "KC_PAUS"),
        .init(id: 111, title: "MINS", wire: "KC_MINS"),
        .init(id: 112, title: "EQL", wire: "KC_EQL"),
        .init(id: 113, title: "LBRC", wire: "KC_LBRC"),
        .init(id: 114, title: "RBRC", wire: "KC_RBRC"),
        .init(id: 115, title: "BSLS", wire: "KC_BSLS"),
        .init(id: 116, title: "SCLN", wire: "KC_SCLN"),
        .init(id: 117, title: "QUOT", wire: "KC_QUOT"),
        .init(id: 118, title: "GRV", wire: "KC_GRV"),
        .init(id: 119, title: "COMM", wire: "KC_COMM"),
        .init(id: 120, title: "DOT", wire: "KC_DOT"),
        .init(id: 121, title: "SLSH", wire: "KC_SLSH"),
        .init(id: 122, title: "NUHS", wire: "KC_NUHS"),
        .init(id: 123, title: "NUBS", wire: "KC_NUBS"),
        .init(id: 124, title: "F13", wire: "KC_F13"),
        .init(id: 125, title: "F14", wire: "KC_F14"),
        .init(id: 126, title: "F15", wire: "KC_F15"),
        .init(id: 127, title: "F16", wire: "KC_F16"),
        .init(id: 128, title: "F17", wire: "KC_F17"),
        .init(id: 129, title: "F18", wire: "KC_F18"),
        .init(id: 130, title: "F19", wire: "KC_F19"),
        .init(id: 131, title: "F20", wire: "KC_F20"),
        .init(id: 132, title: "F21", wire: "KC_F21"),
        .init(id: 133, title: "F22", wire: "KC_F22"),
        .init(id: 134, title: "F23", wire: "KC_F23"),
        .init(id: 135, title: "F24", wire: "KC_F24"),
        .init(id: 136, title: "切到层 1", wire: "KI_LS1"),
        .init(id: 137, title: "切到层 2", wire: "KI_LS2"),
        .init(id: 138, title: "切到层 3", wire: "KI_LS3"),
        .init(id: 139, title: "切到层 4", wire: "KI_LS4"),
        .init(id: 140, title: "切到层 5", wire: "KI_LS5"),
        .init(id: 141, title: "切到层 6", wire: "KI_LS6"),
        .init(id: 142, title: "切到层 7", wire: "KI_LS7"),
        .init(id: 143, title: "切到层 8", wire: "KI_LS8"),
        .init(id: 144, title: "切到层 9", wire: "KI_LS9"),
        .init(id: 145, title: "切到层 10", wire: "KI_LS10"),
        .init(id: 146, title: "切到层 11", wire: "KI_LS11"),
        .init(id: 147, title: "切到层 12", wire: "KI_LS12"),
        .init(id: 148, title: "切到层 13", wire: "KI_LS13"),
        .init(id: 149, title: "切到层 14", wire: "KI_LS14"),
        .init(id: 150, title: "切到层 15", wire: "KI_LS15"),
        .init(id: 151, title: "切到层 16", wire: "KI_LS16"),
        .init(id: 152, title: "按住层 1", wire: "KI_LM1"),
        .init(id: 153, title: "按住层 2", wire: "KI_LM2"),
        .init(id: 154, title: "按住层 3", wire: "KI_LM3"),
        .init(id: 155, title: "按住层 4", wire: "KI_LM4"),
        .init(id: 156, title: "按住层 5", wire: "KI_LM5"),
        .init(id: 157, title: "按住层 6", wire: "KI_LM6"),
        .init(id: 158, title: "按住层 7", wire: "KI_LM7"),
        .init(id: 159, title: "按住层 8", wire: "KI_LM8"),
        .init(id: 160, title: "按住层 9", wire: "KI_LM9"),
        .init(id: 161, title: "按住层 10", wire: "KI_LM10"),
        .init(id: 162, title: "按住层 11", wire: "KI_LM11"),
        .init(id: 163, title: "按住层 12", wire: "KI_LM12"),
        .init(id: 164, title: "按住层 13", wire: "KI_LM13"),
        .init(id: 165, title: "按住层 14", wire: "KI_LM14"),
        .init(id: 166, title: "按住层 15", wire: "KI_LM15"),
        .init(id: 167, title: "按住层 16", wire: "KI_LM16")
    ]
}

public struct LayerConfiguration: Equatable, Codable, Sendable {
    public var actions: [Int]
    public var color: [Int]
    public static func factory(_ layer: PadLayer) -> Self {
        let maps = [Array(repeating: 0, count: 13), [2,5,6,7,8,9,10,11,12,13,14,15,30],
                    [16,17,18,19,20,21,22,23,24,25,26,3,1],
                    [27,28,29,30,31,32,33,34,35,36,37,38,1]]
        return Self(actions: layer.rawValue < 4 ? maps[layer.rawValue] : Array(repeating: 0, count: 13), color: [[255,0,0],[255,192,0],[0,255,0],[0,255,192],[0,128,255],[192,0,255],[255,128,0],[255,255,255]][layer.rawValue % 8])
    }
    public var hex: String { (actions + color).map { String(format: "%02x", $0) }.joined() }
    public init(actions: [Int], color: [Int]) { self.actions = actions; self.color = color }
    public init(hex: String) throws {
        let chars = Array(hex)
        guard chars.count == 32 else { throw PadError.invalidProfile }
        var bytes = [Int]()
        for i in stride(from: 0, to: 32, by: 2) {
            guard let byte = Int(String(chars[i...i+1]), radix: 16) else { throw PadError.invalidProfile }
            bytes.append(byte)
        }
        guard bytes.prefix(13).allSatisfy({ PadAction.native.indices.contains($0) && $0 != 95 }) else { throw PadError.invalidProfile }
        actions = Array(bytes.prefix(13)); color = Array(bytes.suffix(3))
    }
}

public struct PadProfile: Codable {
    public let format: Int
    public let device: String
    public let map: String
    public let layers: [String]
    public let ledOn: Bool
    public let brightness: Int
    public init(map: Keymap, layers: [LayerConfiguration], led: LEDSettings) {
        format = 2; device = "agentpad13-codex-oai"; self.map = map.hex
        self.layers = layers.map(\.hex); ledOn = led.isOn; brightness = led.brightness
    }
    public func validated() throws -> (Keymap, [LayerConfiguration], LEDSettings) {
        guard format == 2, device == "agentpad13-codex-oai", (4...16).contains(layers.count),
              (0...100).contains(brightness) else { throw PadError.invalidProfile }
        return (try Keymap(hex: map), try layers.map { try LayerConfiguration(hex: $0) }, LEDSettings(isOn: ledOn, brightness: brightness))
    }
}
