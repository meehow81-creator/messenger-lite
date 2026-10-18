import AppKit

let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels,
                                      pixelsHigh: pixels, bitsPerSample: 8,
                                      samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

        let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896),
                                xRadius: 206, yRadius: 206)
        let gradient = NSGradient(starting: NSColor(srgbRed: 0.10, green: 0.30, blue: 0.88, alpha: 1),
                                  ending: NSColor(srgbRed: 0.25, green: 0.76, blue: 0.95, alpha: 1))!
        gradient.draw(in: tile, angle: 65)

        let bubble = NSBezierPath(roundedRect: NSRect(x: 222, y: 300, width: 580, height: 452),
                                  xRadius: 170, yRadius: 170)
        NSColor.white.setFill()
        bubble.fill()
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: 302, y: 366))
        tail.line(to: NSPoint(x: 284, y: 222))
        tail.line(to: NSPoint(x: 460, y: 328))
        tail.close()
        tail.fill()

        NSColor(srgbRed: 0.13, green: 0.47, blue: 0.90, alpha: 1).setFill()
        for x in [366, 512, 658] {
            NSBezierPath(ovalIn: NSRect(x: x - 35, y: 491, width: 70, height: 70)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let url = URL(fileURLWithPath: destination).appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
    }
}
