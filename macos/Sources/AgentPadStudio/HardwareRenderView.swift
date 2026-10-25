import SwiftUI
import SceneKit
import AgentPadCore

struct HardwareRenderView: NSViewRepresentable {
    let map: Keymap
    let selected: Int
    let dark: Bool
    let enabled: Bool
    let onSelect: (Int) -> Void

    func makeNSView(context: Context) -> PadSceneView { PadSceneView() }
    func updateNSView(_ view: PadSceneView, context: Context) {
        view.onSelect = onSelect
        view.editingEnabled = enabled
        view.update(map: map, selected: selected, dark: dark)
    }
}

private final class KeyAccessibilityElement: NSAccessibilityElement {
    var press: (() -> Void)?
    override func accessibilityPerformPress() -> Bool { press?(); return press != nil }
}

final class PadSceneView: SCNView {
    var onSelect: ((Int) -> Void)?
    var editingEnabled = true
    private(set) var assetErrors = [String]()
    private var renderedMap: Keymap?
    private var renderedSelection = -1
    private var renderedDark: Bool?
    private var caps = [SCNNode]()
    private var legends = [SCNNode]()
    private var rings = [SCNNode]()
    private var accessibleKeys = [KeyAccessibilityElement]()
    private var housing = [SCNNode]()
    private var plate: SCNNode!
    private var knob: SCNNode!
    private var stick: SCNNode!
    private var floorNode: SCNNode!

    init() {
        super.init(frame: .zero, options: [SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue])
        antialiasingMode = .multisampling4X
        autoenablesDefaultLighting = false
        allowsCameraControl = false
        backgroundColor = .clear
        rendersContinuously = false
        preferredFramesPerSecond = 30
        setAccessibilityElement(false)
        buildScene()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func gray(_ value: CGFloat) -> NSColor {
        NSColor(srgbRed: value, green: value, blue: value, alpha: 1)
    }

    private func material(_ color: NSColor, metallic: CGFloat = 0, roughness: CGFloat = 0.5) -> SCNMaterial {
        let value = SCNMaterial()
        value.lightingModel = .physicallyBased
        value.diffuse.contents = color
        value.metalness.contents = metallic
        value.roughness.contents = roughness
        return value
    }

    private func mesh(_ name: String, color: NSColor, metallic: CGFloat = 0) -> SCNNode {
        do {
            let geometry = try GLBGeometry.load(name)
            geometry.firstMaterial = material(color, metallic: metallic)
            return SCNNode(geometry: geometry)
        } catch {
            assetErrors.append("\(name): \(error.localizedDescription)")
            // Bundled assets are required; keep a visible diagnostic rather
            // than silently substituting a shape with different key positions.
            let text = SCNText(string: "模型加载失败：\(name)", extrusionDepth: 0)
            text.font = .systemFont(ofSize: 3)
            text.firstMaterial = material(.systemRed)
            return SCNNode(geometry: text)
        }
    }

    private func buildScene() {
        let scene = SCNScene()
        self.scene = scene
        let product = SCNNode()
        product.position = SCNVector3(-42.1, 0, -50)
        scene.rootNode.addChildNode(product)
        for name in ["tray", "band_w5.4"] {
            let node = mesh(name, color: .darkGray, metallic: name == "tray" ? 0 : 0.65)
            product.addChildNode(node)
            housing.append(node)
        }
        plate = mesh("plate", color: .gray, metallic: 0.4)
        product.addChildNode(plate)
        for index in 0..<13 {
            let point = PhysicalLayout.switches[index]
            let key = SCNNode()
            key.name = "key-\(index)"
            key.position = SCNVector3(point.x, 11.6, point.y)
            let cap = mesh(index == 12 ? "cap_dish_2u_stab_17p5" : "cap_dish_1u_17p5", color: .white)
            key.addChildNode(cap)
            caps.append(cap)
            let ringGeometry = SCNBox(width: index == 12 ? 36.85 : 17.8, height: 0.65, length: 17.8, chamferRadius: 0.28)
            let ring = SCNNode(geometry: ringGeometry)
            ring.position.y = 0.15
            key.addChildNode(ring)
            rings.append(ring)
            let legend = SCNNode(geometry: SCNPlane(width: index == 12 ? 31 : 14.4, height: 12.6))
            legend.eulerAngles.x = -.pi / 2
            legend.position.y = 6.15
            key.addChildNode(legend)
            legends.append(legend)
            product.addChildNode(key)
            let accessible = KeyAccessibilityElement()
            accessible.setAccessibilityRole(.button)
            accessible.setAccessibilityParent(self)
            accessible.press = { [weak self] in
                guard let self, self.editingEnabled else { return }
                self.onSelect?(index)
            }
            accessibleKeys.append(accessible)
        }
        setAccessibilityChildren(accessibleKeys)
        knob = mesh("knob_A", color: .gray, metallic: 0.85)
        knob.position = SCNVector3(PhysicalLayout.encoder.x, 0, PhysicalLayout.encoder.y)
        product.addChildNode(knob)
        stick = mesh("stick_cap_topper_12_restricted", color: .darkGray)
        stick.position = SCNVector3(PhysicalLayout.joystick.x, 0, PhysicalLayout.joystick.y)
        product.addChildNode(stick)
        let touchGeometry = SCNCylinder(radius: 6.7, height: 0.3)
        touchGeometry.radialSegmentCount = 64
        touchGeometry.firstMaterial = material(NSColor(calibratedRed: 0.67, green: 0.57, blue: 0.34, alpha: 1), metallic: 0.75)
        let touch = SCNNode(geometry: touchGeometry)
        touch.position = SCNVector3(PhysicalLayout.touch.x, 5.1, PhysicalLayout.touch.y)
        product.addChildNode(touch)
        // Fasteners belong to the shipped plate, outside the control surfaces.
        for (x, z) in [(3.7, 3.7), (80.5, 3.7), (3.7, 96.3), (80.5, 96.3)] {
            let screw = SCNNode(geometry: SCNCylinder(radius: 2.4, height: 1.8))
            screw.geometry?.firstMaterial = material(.gray, metallic: 0.95, roughness: 0.27)
            screw.position = SCNVector3(x, 5.2, z)
            product.addChildNode(screw)
        }
        let floor = SCNFloor()
        floor.reflectivity = 0
        floorNode = SCNNode(geometry: floor)
        floorNode.position.y = -10
        scene.rootNode.addChildNode(floorNode)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 70
        camera.camera?.zNear = 1
        camera.camera?.zFar = 1000
        camera.camera?.wantsHDR = true
        camera.camera?.exposureOffset = -0.4
        camera.camera?.wantsExposureAdaptation = false
        camera.camera?.screenSpaceAmbientOcclusionIntensity = 0.35
        camera.camera?.screenSpaceAmbientOcclusionRadius = 2
        camera.camera?.screenSpaceAmbientOcclusionBias = 0.05
        camera.position = SCNVector3(55, 230, 145)
        camera.look(at: SCNVector3(0, 3, 0))
        scene.rootNode.addChildNode(camera)
        pointOfView = camera
        light(scene, position: SCNVector3(-85, 180, 45), intensity: 1000, shadow: true)
        light(scene, position: SCNVector3(100, 100, -60), intensity: 600, shadow: false)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 100
        scene.rootNode.addChildNode(ambient)
        scene.lightingEnvironment.contents = studioEnvironment()
        scene.lightingEnvironment.intensity = 0.5
    }

    private func light(_ scene: SCNScene, position: SCNVector3, intensity: CGFloat, shadow: Bool) {
        let node = SCNNode()
        node.light = SCNLight()
        node.light?.type = .directional
        node.light?.intensity = intensity
        node.light?.color = NSColor(calibratedWhite: 1, alpha: 1)
        node.light?.castsShadow = shadow
        node.light?.shadowMode = .forward
        node.light?.shadowRadius = 5
        node.light?.shadowSampleCount = 32
        node.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
        node.light?.shadowColor = NSColor.black.withAlphaComponent(0.28)
        node.light?.orthographicScale = 160
        node.light?.zNear = 1
        node.light?.zFar = 500
        node.position = position
        node.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(node)
    }

    private func studioEnvironment() -> NSImage {
        let image = NSImage(size: NSSize(width: 1024, height: 512))
        image.lockFocus()
        NSColor(white: 0.35, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 1024, height: 512).fill()
        NSGradient(starting: NSColor(white: 0.9, alpha: 1), ending: NSColor(white: 0.2, alpha: 1))?
            .draw(in: NSRect(x: 0, y: 0, width: 1024, height: 512), angle: 90)
        NSColor(white: 1, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 100, y: 230, width: 270, height: 180), xRadius: 24, yRadius: 24).fill()
        NSBezierPath(roundedRect: NSRect(x: 700, y: 200, width: 100, height: 220), xRadius: 20, yRadius: 20).fill()
        image.unlockFocus()
        return image
    }

    func update(map: Keymap, selected: Int, dark: Bool) {
        guard map != renderedMap || selected != renderedSelection || dark != renderedDark else { return }
        let themeChanged = dark != renderedDark
        renderedMap = map
        renderedSelection = selected
        renderedDark = dark
        if themeChanged {
            let background = gray(dark ? 0.075 : 0.93)
            scene?.background.contents = background
            floorNode.geometry?.firstMaterial = material(background, roughness: 0.9)
            housing[0].geometry?.firstMaterial = material(gray(dark ? 0.10 : 0.76), roughness: 0.55)
            housing[1].geometry?.firstMaterial = material(gray(dark ? 0.19 : 0.65), metallic: 0.72, roughness: 0.32)
            plate.geometry?.firstMaterial = material(gray(dark ? 0.12 : 0.72), metallic: 0.35, roughness: 0.5)
            knob.geometry?.firstMaterial = material(gray(dark ? 0.35 : 0.70), metallic: 0.9, roughness: 0.27)
            stick.geometry?.firstMaterial = material(gray(dark ? 0.12 : 0.25), roughness: 0.85)
        }
        for index in 0..<13 {
            let active = index == selected
            let keyColor = active
                ? NSColor(srgbRed: 0.67, green: 0.86, blue: 0.42, alpha: 1)
                : gray(dark ? 0.18 : 0.80)
            caps[index].geometry?.firstMaterial = material(keyColor, roughness: 0.6)
            let glow = material(active ? .systemGreen : gray(dark ? 0.10 : 0.48))
            if active { glow.emission.contents = NSColor(calibratedRed: 0.25, green: 0.45, blue: 0.08, alpha: 1) }
            rings[index].geometry?.firstMaterial = glow
            let legend = SCNMaterial()
            legend.lightingModel = .constant
            legend.diffuse.contents = legendTexture(index: index, action: PadAction.all[map.values[index]], lightInk: dark && !active)
            legend.transparencyMode = .aOne
            legend.writesToDepthBuffer = false
            legends[index].geometry?.firstMaterial = legend
            accessibleKeys[index].setAccessibilityLabel("SW\(index + 1)，\(PadAction.all[map.values[index]].title)")
            accessibleKeys[index].setAccessibilityValue(active ? "已选中" : "")
            accessibleKeys[index].setAccessibilityEnabled(editingEnabled)
        }
        needsDisplay = true
        updateAccessibilityFrames()
    }

    private func legendTexture(index: Int, action: PadAction, lightInk: Bool) -> NSImage {
        let width: CGFloat = index == 12 ? 1024 : 512
        let image = NSImage(size: NSSize(width: width, height: 512))
        image.lockFocus()
        let color = gray(lightInk ? 0.93 : 0.12)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        func text(_ string: String, size: CGFloat, y: CGFloat, weight: NSFont.Weight) {
            (string as NSString).draw(in: NSRect(x: 8, y: y, width: width - 16, height: size * 1.7), withAttributes: [
                .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color,
                .paragraphStyle: paragraph
            ])
        }
        text("SW\(index + 1)", size: 58, y: 355, weight: .regular)
        let titles = ["无操作", "上个会话", "下个会话", "新建任务", "审查", "计划", "实现", "重构", "测试", "中止", "解锁", "确认", "发送", "编码器", "麦克风", "麦克风"]
        text(titles[action.id], size: 91, y: 175, weight: .semibold)
        text(action.wire.components(separatedBy: " · ").first ?? "", size: 54, y: 55, weight: .medium)
        image.unlockFocus()
        return image
    }

    private func keyIndex(at point: NSPoint) -> Int? {
        guard let hit = hitTest(point, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue]).first else { return nil }
        var node: SCNNode? = hit.node
        while let current = node {
            if let name = current.name, name.hasPrefix("key-"), let index = Int(name.dropFirst(4)) { return index }
            node = current.parent
        }
        return nil
    }
    override func mouseDown(with event: NSEvent) {
        guard editingEnabled, let index = keyIndex(at: convert(event.locationInWindow, from: nil)) else { return }
        onSelect?(index)
    }
    func validatePicking() -> [Int] {
        layoutSubtreeIfNeeded()
        return (0..<13).filter { index in
            let world = caps[index].parent!.convertPosition(SCNVector3(0, 6.2, 0), to: nil)
            let point = projectPoint(world)
            return keyIndex(at: NSPoint(x: CGFloat(point.x), y: CGFloat(point.y))) != index
        }
    }
    override func layout() { super.layout(); updateAccessibilityFrames() }
    private func updateAccessibilityFrames() {
        guard let window, caps.count == 13 else { return }
        for index in 0..<13 {
            let center = caps[index].parent!.convertPosition(SCNVector3(0, 6, 0), to: nil)
            let projected = projectPoint(center)
            let side: CGFloat = index == 12 ? 70 : 45
            let rect = convert(NSRect(x: CGFloat(projected.x) - side / 2, y: CGFloat(projected.y) - 22, width: side, height: 44), to: nil)
            accessibleKeys[index].setAccessibilityFrame(window.convertToScreen(rect))
        }
    }
}
