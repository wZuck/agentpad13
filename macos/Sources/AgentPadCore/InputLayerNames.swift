import Foundation

/// Read-only view of the names already stored in Input's keymap.json.
/// Array order is the physical layer index; Input's IDs may be noncontiguous.
public struct InputLayerNameReader {
    private var bytes = Data()
    private var totalSize: Int?
    public init() {}
    public var offset: Int { bytes.count }
    public var isComplete: Bool { totalSize == bytes.count }

    public mutating func append(result: [String: Any]) throws {
        guard !isComplete,
              let size = result["total_size"] as? Int, (2...16384).contains(size),
              totalSize == nil || totalSize == size,
              let encoded = result["data"] as? String,
              let chunk = Data(base64Encoded: encoded), !chunk.isEmpty, chunk.count <= 192,
              bytes.count + chunk.count <= size else { throw PadError.invalidReport }
        totalSize = size
        bytes.append(chunk)
    }

    public func names(expectedCount: Int) throws -> [String] {
        guard isComplete, (4...16).contains(expectedCount),
              let document = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              document["version"] as? Int == 1,
              let profiles = document["profiles"] as? [[String: Any]], profiles.count == 1,
              let layers = profiles[0]["layers"] as? [[String: Any]], layers.count == expectedCount else {
            throw PadError.invalidReport
        }
        return try layers.enumerated().map { index, layer in
            guard let name = layer["name"] as? String else { throw PadError.invalidReport }
            return name.isEmpty ? PadLayer(rawValue: index)!.title : name
        }
    }
}
