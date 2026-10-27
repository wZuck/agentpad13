import XCTest
@testable import AgentPadCore

final class InputLayerNamesTests: XCTestCase {
    private func file(names: [String]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["version": 1, "profiles": [["id": 0, "layers": names.enumerated().map { ["id": $0.offset * 3, "name": $0.element] as [String: Any] }]]])
    }

    func testRenamedUnicodeLayersAcrossFileChunksUseArrayOrder() throws {
        let names = ["工作", "FN 自定义", "导航", "媒体", "第五层 🎿"] + (6...16).map { "设计层 \($0)" }
        let data = try file(names: names)
        var reader = InputLayerNameReader()
        while reader.offset < data.count {
            let offset = reader.offset
            let chunk = data.subdata(in: offset..<min(offset + 37, data.count))
            try reader.append(result: ["total_size": data.count, "data": chunk.base64EncodedString()])
        }
        XCTAssertTrue(reader.isComplete)
        XCTAssertEqual(try reader.names(expectedCount: 16), names)
        XCTAssertThrowsError(try reader.names(expectedCount: 5))
    }

    func testRefreshReadsNewNamesAndBlankNamesHaveDefaults() throws {
        var reader = InputLayerNameReader()
        let data = try file(names: ["", "快捷键", "NAV", "MEDIA", "自定义五"])
        for offset in stride(from: 0, to: data.count, by: 192) {
            try reader.append(result: ["total_size": data.count, "data": data.subdata(in: offset..<min(offset+192, data.count)).base64EncodedString()])
        }
        XCTAssertEqual(try reader.names(expectedCount: 5), ["CODEX", "快捷键", "NAV", "MEDIA", "自定义五"])
        var refreshed = InputLayerNameReader()
        let changed = try file(names: ["工作台", "快捷键", "NAV", "MEDIA", "摄影"])
        for offset in stride(from: 0, to: changed.count, by: 192) {
            try refreshed.append(result: ["total_size": changed.count, "data": changed.subdata(in: offset..<min(offset+192, changed.count)).base64EncodedString()])
        }
        XCTAssertEqual(try refreshed.names(expectedCount: 5).last, "摄影")
    }

    func testInvalidAndChangingFilesFailWithoutUnboundedReads() throws {
        for result: [String: Any] in [
            ["total_size": 0, "data": ""], ["total_size": 16385, "data": "YQ=="],
            ["total_size": 10, "data": ""], ["total_size": 10, "data": "!bad!"],
            ["total_size": 2, "data": Data(repeating: 65, count: 193).base64EncodedString()]
        ] {
            var reader = InputLayerNameReader()
            XCTAssertThrowsError(try reader.append(result: result))
        }
        var reader = InputLayerNameReader()
        try reader.append(result: ["total_size": 10, "data": "YQ=="])
        XCTAssertThrowsError(try reader.append(result: ["total_size": 11, "data": "Yg=="]))
        XCTAssertThrowsError(try reader.names(expectedCount: 4))
    }

    func testReadRequestUsesTheExistingFirmwareFileAPI() throws {
        let frames = try OAIWire.request(method: "fs.readbin", id: 702, fileOffset: 192)
        let bytes = try frames.flatMap { try OAIWire.payload($0) }
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(bytes)) as? [String: Any])
        let params = try XCTUnwrap(object["params"] as? [String: Any])
        XCTAssertEqual(params["file"] as? String, "keymap.json")
        XCTAssertEqual(params["offset"] as? Int, 192)
        XCTAssertEqual(params["len"] as? Int, 192)
        XCTAssertThrowsError(try OAIWire.request(method: "fs.readbin", id: 702, fileOffset: -1))
    }
}
