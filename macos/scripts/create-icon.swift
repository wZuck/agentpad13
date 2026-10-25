import AppKit
import Foundation

let destination = CommandLine.arguments[1]
let manager = FileManager.default
try manager.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let factor = CGFloat(pixels) / 1024
        let transform = NSAffineTransform()
        transform.scale(by: factor)
        transform.concat()
        NSColor(calibratedRed: 0.09, green: 0.11, blue: 0.12, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 195, yRadius: 195).fill()
        let lime = NSColor(calibratedRed: 0.72, green: 0.94, blue: 0.40, alpha: 1)
        for row in 0..<3 {
            for col in 0..<4 {
                (row == 0 ? lime : lime.withAlphaComponent(0.30 + CGFloat(col) * 0.1)).setFill()
                NSBezierPath(roundedRect: NSRect(x: 190 + col * 165, y: 360 + row * 150, width: 120, height: 110), xRadius: 22, yRadius: 22).fill()
            }
        }
        lime.setFill()
        NSBezierPath(roundedRect: NSRect(x: 190, y: 210, width: 285, height: 110), xRadius: 22, yRadius: 22).fill()
        lime.withAlphaComponent(0.5).setStroke()
        let knob = NSBezierPath(ovalIn: NSRect(x: 540, y: 210, width: 110, height: 110))
        knob.lineWidth = 14
        knob.stroke()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        let output = URL(fileURLWithPath: destination).appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: output)
    }
}
