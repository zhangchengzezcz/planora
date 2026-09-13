import AppKit

let size = NSSize(width: 720, height: 460)
let image = NSImage(size: size)
image.lockFocus()
NSColor(calibratedRed: 0.95, green: 0.97, blue: 0.98, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
func text(_ text: String, y: CGFloat, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    (text as NSString).draw(in: NSRect(x: 40, y: y, width: 640, height: 46), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: paragraph
    ])
}
let ink = NSColor(calibratedWhite: 0.12, alpha: 1)
let accent = NSColor(calibratedRed: 0.03, green: 0.48, blue: 0.43, alpha: 1)
text("Planora", y: 359, size: 38, color: ink, weight: .bold)
text("拖入应用程序，开始规划", y: 316, size: 19, color: ink, weight: .medium)
let arrow = NSImage(systemSymbolName: "arrow.right", accessibilityDescription: nil)!
    .withSymbolConfiguration(.init(pointSize: 36, weight: .medium))!
arrow.draw(in: NSRect(x: 337, y: 227, width: 46, height: 34))
text("Drag Planora into Applications", y: 100, size: 16, color: accent, weight: .medium)
text("安装后请从「应用程序」打开 / Open from Applications", y: 62, size: 13, color: .darkGray)
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
