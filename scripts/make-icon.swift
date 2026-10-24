import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("Stillday-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }
for (points, scale) in [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)] {
    let size = points * scale
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    NSColor(calibratedRed: 0.90, green: 0.93, blue: 0.85, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 54,y: 54,width: 916,height: 916),xRadius: 210,yRadius: 210).fill()
    NSColor(calibratedRed: 0.32, green: 0.43, blue: 0.29, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 327, y: 391, width: 370, height: 370)).fill()
    NSColor(calibratedRed: 0.90, green: 0.93, blue: 0.85, alpha: 1).setFill()
    NSRect(x: 210, y: 210, width: 610, height: 303).fill()
    let horizon = NSBezierPath(); horizon.move(to: NSPoint(x: 237,y: 492)); horizon.line(to: NSPoint(x: 787,y: 492)); horizon.lineWidth = 32; horizon.lineCapStyle = .round
    NSColor(calibratedRed: 0.32, green: 0.43, blue: 0.29, alpha: 1).setStroke(); horizon.stroke()
    let water = NSBezierPath(); water.move(to: NSPoint(x: 306,y: 389)); water.line(to: NSPoint(x: 718,y: 389)); water.lineWidth = 24; water.lineCapStyle = .round; water.stroke()
    let lower = NSBezierPath(); lower.move(to: NSPoint(x: 382,y: 291)); lower.line(to: NSPoint(x: 642,y: 291)); lower.lineWidth = 24; lower.lineCapStyle = .round; lower.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
    try rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(filename))
}
let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil"); task.arguments = ["-c", "icns", iconset.path, "-o", destination.path]
try task.run(); task.waitUntilExit()
if task.terminationStatus != 0 { exit(task.terminationStatus) }
