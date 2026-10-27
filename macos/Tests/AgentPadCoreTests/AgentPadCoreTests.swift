import XCTest
@testable import AgentPadCore

final class AgentPadCoreTests: XCTestCase {
    func testMapValidationAndProfiles() throws {
        let factory = try Keymap()
        XCTAssertEqual(factory.hex, "123456789abecd1")
        XCTAssertEqual(try Keymap(profileData: factory.profileData()), factory)
        for invalid in ["", "123", "123456789abfcdz", "d23456789abfcd1", "123456789abfcdd"] {
            XCTAssertThrowsError(try Keymap(hex: invalid))
        }
        XCTAssertThrowsError(try Keymap(profileData: Data("{\"format\":1,\"device\":\"other\",\"layer\":0,\"map\":\"123456789abfcd1\"}".utf8)))
        var custom = try Keymap(hex: "123456789abfc01")
        custom.assign(15, to: 0)
        custom.assign(13, to: 1)
        custom.assign(0, to: 14)
        XCTAssertEqual(custom.hex, "f23456789abfc01", "Fixed/legacy slots must survive editing unchanged")
    }

    func testFourLayerProfilesAndValidation() throws {
        let layers = PadLayer.allCases.map { LayerConfiguration.factory($0) }
        let profile = PadProfile(map: try Keymap(), layers: layers, led: .factory)
        let data = try JSONEncoder().encode(profile)
        let (_, decoded, led) = try JSONDecoder().decode(PadProfile.self, from: data).validated()
        XCTAssertEqual(layers, decoded)
        XCTAssertEqual(led, .factory)
        for layer in PadLayer.allCases {
            XCTAssertEqual(try LayerConfiguration(hex: layers[layer.rawValue].hex), layers[layer.rawValue])
        }
        XCTAssertThrowsError(try LayerConfiguration(hex: String(repeating: "ff", count: 16)))
        XCTAssertThrowsError(try LayerConfiguration(hex: "abcd"))
        XCTAssertEqual(Keymap(nativeActions: layers[1].actions).action(at: 0).wire, "JS_MODE")
    }

    func testInputNativeCatalogAndCodexOverrides() throws {
        let map = try Keymap()
        var layer = LayerConfiguration.factory(.codex)
        layer.actions[0] = 42
        layer.actions[1] = 98
        layer.actions[2] = 82
        let display = map.nativeDisplay(overrides: layer.actions)
        XCTAssertEqual(display.action(at: 0).wire, "KC_A")
        XCTAssertEqual(display.action(at: 1).wire, "KC_LCTL")
        XCTAssertEqual(display.action(at: 2).wire, "KC_NONE")
        XCTAssertEqual(display.action(at: 3).wire, "KV_OAI_AG03")
        XCTAssertEqual(try LayerConfiguration(hex: layer.hex), layer)
        XCTAssertEqual(PadAction.native.count, 168)
        let profile = PadProfile(map: map, layers: [layer] + PadLayer.allCases.dropFirst().map { LayerConfiguration.factory($0) }, led: .factory)
        let decoded = try JSONDecoder().decode(PadProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(try decoded.validated().1[0], layer)
    }

    func testDynamicLayerProfilesAndCountRequests() throws {
        let layers = PadLayer.configured(16).map { LayerConfiguration.factory($0) }
        XCTAssertEqual(layers.count, 16)
        XCTAssertEqual(PadLayer(rawValue: 15)?.title, "LAYER 16")
        XCTAssertNil(PadLayer(rawValue: 16))
        let profile = PadProfile(map: try Keymap(), layers: layers, led: .factory)
        XCTAssertEqual(try JSONDecoder().decode(PadProfile.self, from: JSONEncoder().encode(profile)).validated().1, layers)
        let frames = try OAIWire.request(method: "v.agentpad.cfg.info", id: 701, layerCount: 16)
        let payload = try frames.flatMap { try OAIWire.payload($0) }
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(payload)) as? [String: Any])
        XCTAssertEqual((json["params"] as? [String: Any])?["n"] as? Int, 16)
        XCTAssertThrowsError(try OAIWire.request(method: "v.agentpad.cfg.info", id: 701, layerCount: 17))
    }

    func testKeycapLegendsCoverInputAndLayerActionsWithoutLegacyIndexing() throws {
        XCTAssertEqual(PadAction.all[1].keycapTitle, "上个会话")
        for action in PadAction.native {
            XCTAssertEqual(action.keycapTitle, action.title)
        }
        XCTAssertEqual(PadAction.native[83].keycapTitle, "Codex 上一个")
        XCTAssertEqual(PadAction.native[151].keycapTitle, "切到层 16")
        XCTAssertEqual(PadAction(id: 999, title: "扩展动作", wire: "FUTURE").keycapTitle, "扩展动作")
        let display = try Keymap().nativeDisplay(overrides: LayerConfiguration.factory(.codex).actions)
        for index in 0..<13 { XCTAssertFalse(display.action(at: index).keycapTitle.isEmpty) }
    }

    func testFramingAndDecoder() throws {
        let frames = try OAIWire.request(method: "v.oai.keymap.set", id: 701, map: Keymap())
        XCTAssertThrowsError(try OAIWire.request(method: "v.oai.keymap.get", id: 999))
        XCTAssertGreaterThan(frames.count, 1)
        for frame in frames { XCTAssertEqual(frame.count, 64) }
        let payload = try frames.flatMap { try OAIWire.payload($0) }
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(payload)) as? [String: Any])
        XCTAssertEqual(json["id"] as? Int, 701)
        XCTAssertEqual((json["params"] as? [String: Any])?["m"] as? String, Keymap.factoryHex)
        var decoder = RPCDecoder()
        let message = "{\"result\":{\"l\":0,\"m\":\"123456789abfcd1\"},\"id\":701}\r\n"
        let bytes = Array(message.utf8)
        XCTAssertTrue(try decoder.receive(OAIWire.frames(Array(bytes.prefix(20)))[0]).isEmpty)
        let decoded = try decoder.receive(OAIWire.frames(Array(bytes.dropFirst(20)))[0])
        XCTAssertEqual(decoded.first?["id"] as? Int, 701)
        var malformed = Array(repeating: UInt8(0), count: 64)
        malformed[0] = 6; malformed[1] = 2; malformed[2] = 62
        XCTAssertThrowsError(try decoder.receive(malformed))
    }

    func testLEDSettingsAndRequestParameters() throws {
        let settings = try LEDSettings(result: ["on": false, "brightness": 37])
        XCTAssertFalse(settings.isOn)
        XCTAssertEqual(settings.brightness, 37)
        XCTAssertEqual(LEDSettings(isOn: true, brightness: -10).brightness, 0)
        XCTAssertEqual(LEDSettings(isOn: true, brightness: 140).brightness, 100)
        XCTAssertThrowsError(try LEDSettings(result: ["on": true, "brightness": 101]))

        let frames = try OAIWire.request(method: "v.agentpad.led.set", id: 704, led: settings)
        let payload = try frames.flatMap { try OAIWire.payload($0) }
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(payload)) as? [String: Any])
        let params = try XCTUnwrap(json["params"] as? [String: Any])
        XCTAssertEqual(params["on"] as? Bool, false)
        XCTAssertEqual(params["brightness"] as? Int, 37)
        XCTAssertNil(params["l"])
    }

    func testSwiftRequestsAgainstActualFirmwareEngine() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let binary = temporary.appendingPathComponent("firmware-harness")
        let firmware = root.appendingPathComponent("firmware")
        let harness = firmware.appendingPathComponent("tests/codex_oai")
        let keymap = firmware.appendingPathComponent("loudest_micro/keymaps/codex_oai")
        let compile = Process()
        compile.executableURL = URL(fileURLWithPath: "/usr/bin/cc")
        compile.arguments = ["-std=c11", "-Wall", "-Wextra", "-Werror", "-DRAW_EPSIZE=64", "-DRAW_REPORT_ID=6", "-DWEAR_LEVELING_ENABLE", "-I", harness.appendingPathComponent("stubs").path, "-I", keymap.path, harness.appendingPathComponent("protocol_harness.c").path, keymap.appendingPathComponent("codex_oai.c").path, "-o", binary.path]
        try compile.run(); compile.waitUntilExit()
        XCTAssertEqual(compile.terminationStatus, 0)
        guard compile.terminationStatus == 0 else { return }
        let candidate = try Keymap(hex: "f23456789abfcd1")
        var native = LayerConfiguration.factory(.nav)
        native.actions[0] = 40
        native.color = [12, 34, 56]
        let requests = try OAIWire.request(method: "v.oai.keymap.get", id: 701)
            + OAIWire.request(method: "v.oai.keymap.set", id: 702, map: candidate)
            + OAIWire.request(method: "v.oai.keymap.get", id: 703)
            + OAIWire.request(method: "v.agentpad.led.set", id: 704, led: LEDSettings(isOn: false, brightness: 37))
            + OAIWire.request(method: "v.agentpad.led.get", id: 705)
            + OAIWire.request(method: "v.agentpad.cfg.set", id: 706, layer: 2, configuration: native)
            + OAIWire.request(method: "v.agentpad.cfg.get", id: 707, layer: 2)
            + OAIWire.request(method: "v.agentpad.cfg.info", id: 708, layerCount: 8)
            + OAIWire.request(method: "v.agentpad.cfg.set", id: 709, layer: 7, configuration: native)
            + OAIWire.request(method: "v.agentpad.cfg.get", id: 710, layer: 7)
            + OAIWire.request(method: "v.agentpad.cfg.info", id: 711)
        var commands = ""
        for (index, frame) in requests.enumerated() {
            if index == requests.count - 1 { commands += "RESET\n" }
            commands += "FRAME " + frame.map { String(format: "%02x", $0) }.joined() + "\n"
        }
        let process = Process()
        process.executableURL = binary
        let input = Pipe(), output = Pipe()
        process.standardInput = input; process.standardOutput = output
        try process.run()
        input.fileHandleForWriting.write(Data(commands.utf8))
        try input.fileHandleForWriting.close()
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        var decoder = RPCDecoder()
        var responses = [[String: Any]]()
        for line in text.split(separator: "\n") where line.hasPrefix("SENT ") {
            let hex = Array(line.dropFirst(5))
            let bytes = stride(from: 0, to: hex.count, by: 2).compactMap { UInt8(String(hex[$0..<$0+2]), radix: 16) }
            responses += try decoder.receive(bytes)
        }
        XCTAssertEqual(responses.count, 11)
        guard responses.count == 11 else { return }
        XCTAssertEqual((responses.first?["result"] as? [String: Any])?["m"] as? String, Keymap.factoryHex)
        XCTAssertEqual(responses[1]["result"] as? Bool, true)
        XCTAssertEqual((responses[2]["result"] as? [String: Any])?["m"] as? String, candidate.hex)
        XCTAssertEqual(responses[2]["id"] as? Int, 703)
        XCTAssertEqual(responses[3]["result"] as? Bool, true)
        let ledResult = try XCTUnwrap(responses[4]["result"] as? [String: Any])
        XCTAssertEqual(ledResult["on"] as? Bool, false)
        XCTAssertEqual((ledResult["brightness"] as? NSNumber)?.intValue, 37)
        XCTAssertEqual(responses[4]["id"] as? Int, 705)
        XCTAssertEqual(responses[5]["result"] as? Bool, true)
        let nativeResult = try XCTUnwrap(responses[6]["result"] as? [String: Any])
        XCTAssertEqual(nativeResult["l"] as? Int, 2)
        XCTAssertEqual(nativeResult["m"] as? String, native.hex)
        XCTAssertEqual((responses[7]["result"] as? [String: Any])?["n"] as? Int, 8)
        XCTAssertEqual(responses[8]["result"] as? Bool, true)
        XCTAssertEqual((responses[9]["result"] as? [String: Any])?["l"] as? Int, 7)
        XCTAssertEqual((responses[9]["result"] as? [String: Any])?["m"] as? String, native.hex)
        XCTAssertEqual((responses[10]["result"] as? [String: Any])?["n"] as? Int, 8)
    }
}
