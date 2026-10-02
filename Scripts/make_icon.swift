// 生成 App 图标：swift Scripts/make_icon.swift <输出的 .iconset 目录>
import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let rect = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let bg = NSBezierPath(roundedRect: rect, xRadius: s * 0.18, yRadius: s * 0.18)
    NSGradient(starting: NSColor(red: 0.45, green: 0.6, blue: 1, alpha: 1),
               ending: NSColor(red: 0.75, green: 0.45, blue: 0.95, alpha: 1))!.draw(in: bg, angle: -90)

    // 四个彩色键帽：A S J K
    let colors: [NSColor] = [
        NSColor(red: 1, green: 0.45, blue: 0.6, alpha: 1), NSColor(red: 1, green: 0.6, blue: 0.2, alpha: 1),
        NSColor(red: 0.15, green: 0.7, blue: 0.75, alpha: 1), NSColor(red: 0.3, green: 0.75, blue: 0.35, alpha: 1),
    ]
    let letters = ["A", "B", "C", "D"]
    let key = s * 0.27, gap = s * 0.05
    let originX = s * 0.5 - key - gap / 2, originY = s * 0.5 - key - gap / 2
    for i in 0..<4 {
        let col = CGFloat(i % 2), row = CGFloat(1 - i / 2)
        let r = NSRect(x: originX + col * (key + gap), y: originY + row * (key + gap), width: key, height: key)
        NSColor.black.withAlphaComponent(0.18).setFill()
        NSBezierPath(roundedRect: r.offsetBy(dx: 0, dy: -s * 0.012), xRadius: key * 0.2, yRadius: key * 0.2).fill()
        colors[i].setFill()
        NSBezierPath(roundedRect: r, xRadius: key * 0.2, yRadius: key * 0.2).fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: key * 0.6, weight: .heavy),
            .foregroundColor: NSColor.white,
        ]
        let str = NSAttributedString(string: letters[i], attributes: attrs)
        let size = str.size()
        str.draw(at: NSPoint(x: r.midX - size.width / 2, y: r.midY - size.height / 2))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: outDir.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: outDir.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
