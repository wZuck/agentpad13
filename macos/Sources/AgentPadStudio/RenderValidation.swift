import AppKit
import SceneKit
import AgentPadCore

// Build/QA entry point: render both materials offscreen without changing the
// user's appearance, opening a window, or opening any HID device.
enum RenderValidation {
    static func runIfRequested() -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--render-previews"), arguments.indices.contains(index + 1) else { return false }
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: arguments[index + 1])
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let view = PadSceneView()
            view.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
            guard view.assetErrors.isEmpty else {
                throw NSError(domain: "AgentPadStudio.Render", code: 1, userInfo: [NSLocalizedDescriptionKey: view.assetErrors.joined(separator: "\n")])
            }
            let renderer = SCNRenderer(device: nil, options: nil)
            renderer.scene = view.scene
            renderer.pointOfView = view.pointOfView
            for dark in [false, true] {
                view.update(map: try Keymap(), selected: 11, dark: dark)
                let snapshot = renderer.snapshot(atTime: 0, with: CGSize(width: 1440, height: 1120), antialiasingMode: .multisampling4X)
                guard let data = snapshot.tiffRepresentation,
                      let png = NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:]) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                let url = directory.appendingPathComponent(dark ? "agentpad-dark.png" : "agentpad-light.png")
                try png.write(to: url)
                print(url.path)
            }
            for layer in PadLayer.allCases where layer != .codex {
                view.update(map: Keymap(nativeActions: LayerConfiguration.factory(layer).actions), selected: 0, dark: false)
                let snapshot = renderer.snapshot(atTime: 0, with: CGSize(width: 1440, height: 1120), antialiasingMode: .multisampling4X)
                guard let data = snapshot.tiffRepresentation,
                      let png = NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
                try png.write(to: directory.appendingPathComponent("agentpad-\(layer.title.lowercased()).png"))
            }
            // Input/CODEX native overlays and direct/momentary layer bindings
            // use IDs outside the legacy 0...15 OAI legend table.
            view.update(map: Keymap(nativeActions: [83,86,92,96,97,136,151,152,167,42,98,82,81]), selected: 0, dark: false)
            let inputSnapshot = renderer.snapshot(atTime: 0, with: CGSize(width: 1440, height: 1120), antialiasingMode: .multisampling4X)
            guard let inputTIFF = inputSnapshot.tiffRepresentation,
                  let inputPNG = NSBitmapImageRep(data: inputTIFF)?.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
            try inputPNG.write(to: directory.appendingPathComponent("agentpad-input-actions.png"))
            let missed = view.validatePicking()
            guard missed.isEmpty else {
                throw NSError(domain: "AgentPadStudio.Render", code: 2, userInfo: [NSLocalizedDescriptionKey: "3D key picking mismatch: \(missed)"])
            }
            print("CAD assets loaded, both appearance renders completed, and all 13 key pick targets verified; no USB access.")
        } catch {
            fputs("Render verification failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
        return true
    }
}
