import AppKit
import SceneKit

// The repository's CAD exporter emits one untransformed mesh per GLB, in
// millimetres with Y up. Read that bounded format without a web renderer.
enum GLBGeometry {
    static func load(_ name: String) throws -> SCNGeometry {
        let packaged = Bundle.main.resourceURL?.appendingPathComponent("Models/\(name).glb")
        let url = packaged.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
            ?? Bundle.module.url(forResource: name, withExtension: "glb", subdirectory: "Models")
        guard let url else { throw CocoaError(.fileNoSuchFile) }
        let data = try Data(contentsOf: url)
        func uint(_ offset: Int) -> UInt32 {
            data.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self)) }
        }
        guard data.count >= 28, uint(0) == 0x46546C67, uint(4) == 2 else { throw CocoaError(.fileReadCorruptFile) }
        let jsonLength = Int(uint(12))
        guard 20 + jsonLength + 8 <= data.count else { throw CocoaError(.fileReadCorruptFile) }
        let json = try JSONSerialization.jsonObject(with: data.subdata(in: 20..<20 + jsonLength)) as! [String: Any]
        let binary = data.subdata(in: 28 + jsonLength..<data.count)
        let accessors = json["accessors"] as! [[String: Any]]
        let views = json["bufferViews"] as! [[String: Any]]
        let meshes = json["meshes"] as! [[String: Any]]
        let primitive = (meshes[0]["primitives"] as! [[String: Any]])[0]
        let attributes = primitive["attributes"] as! [String: Int]
        func source(_ index: Int, semantic: SCNGeometrySource.Semantic) -> SCNGeometrySource {
            let accessor = accessors[index], view = views[accessor["bufferView"] as! Int]
            return SCNGeometrySource(data: binary, semantic: semantic, vectorCount: accessor["count"] as! Int,
                usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4,
                dataOffset: (view["byteOffset"] as? Int ?? 0) + (accessor["byteOffset"] as? Int ?? 0),
                dataStride: view["byteStride"] as? Int ?? 12)
        }
        let index = accessors[primitive["indices"] as! Int]
        let view = views[index["bufferView"] as! Int]
        let width = (index["componentType"] as! Int) == 5125 ? 4 : 2
        let count = index["count"] as! Int
        let start = (view["byteOffset"] as? Int ?? 0) + (index["byteOffset"] as? Int ?? 0)
        let elements = SCNGeometryElement(data: binary.subdata(in: start..<start + count * width),
            primitiveType: .triangles, primitiveCount: count / 3, bytesPerIndex: width)
        return SCNGeometry(sources: [source(attributes["POSITION"]!, semantic: .vertex),
                                     source(attributes["NORMAL"]!, semantic: .normal)], elements: [elements])
    }
}
