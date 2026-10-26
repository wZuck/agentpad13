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
        let requests = try OAIWire.request(method: "v.oai.keymap.get", id: 701)
            + OAIWire.request(method: "v.oai.keymap.set", id: 702, map: candidate)
            + OAIWire.request(method: "v.oai.keymap.get", id: 703)
            + OAIWire.request(method: "v.agentpad.led.set", id: 704, led: LEDSettings(isOn: false, brightness: 37))
            + OAIWire.request(method: "v.agentpad.led.get", id: 705)
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
        XCTAssertEqual(responses.count, 5)
        guard responses.count == 5 else { return }
        XCTAssertEqual((responses.first?["result"] as? [String: Any])?["m"] as? String, Keymap.factoryHex)
        XCTAssertEqual(responses[1]["result"] as? Bool, true)
        XCTAssertEqual((responses[2]["result"] as? [String: Any])?["m"] as? String, candidate.hex)
        XCTAssertEqual(responses[2]["id"] as? Int, 703)
        XCTAssertEqual(responses[3]["result"] as? Bool, true)
        let ledResult = try XCTUnwrap(responses[4]["result"] as? [String: Any])
        XCTAssertEqual(ledResult["on"] as? Bool, false)
        XCTAssertEqual((ledResult["brightness"] as? NSNumber)?.intValue, 37)
        XCTAssertEqual(responses[4]["id"] as? Int, 705)
    }
}
