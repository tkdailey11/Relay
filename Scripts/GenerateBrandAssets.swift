// Run from the repository root: swift Scripts/GenerateBrandAssets.swift
// Original vector reconstruction of Relay's approved branding reference.
import AppKit

func color(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func render(size: Int, dark: Bool, to url: URL) throws {
    let space = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: size * 4, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(size) / 1024
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: 0, y: 1024)
    context.scaleBy(x: 1, y: -1)

    func gradient(_ path: CGPath, colors: [UInt32], start: CGPoint, end: CGPoint) {
        context.saveGState()
        context.addPath(path)
        context.clip()
        let gradient = CGGradient(colorsSpace: space, colors: colors.map(color) as CFArray,
                                  locations: nil)!
        context.drawLinearGradient(gradient, start: start, end: end,
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
    }

    let tile = CGPath(roundedRect: CGRect(x: 64, y: 64, width: 896, height: 896),
                      cornerWidth: 212, cornerHeight: 212, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 20,
                      color: CGColor(gray: 0, alpha: dark ? 0.22 : 0.12))
    context.setFillColor(color(dark ? 0x18212D : 0xF8FAFC))
    context.addPath(tile)
    context.fillPath()
    context.restoreGState()
    gradient(tile, colors: dark ? [0x2B3746, 0x111827] : [0xFFFFFF, 0xF2F5FA],
             start: CGPoint(x: 150, y: 64), end: CGPoint(x: 850, y: 960))
    context.addPath(tile)
    context.setStrokeColor(color(dark ? 0x354252 : 0xE5E7EB))
    context.setLineWidth(2)
    context.strokePath()

    let top = CGMutablePath()
    top.move(to: CGPoint(x: 232, y: 552))
    top.addLine(to: CGPoint(x: 232, y: 431))
    top.addCurve(to: CGPoint(x: 361, y: 310), control1: CGPoint(x: 232, y: 359),
                 control2: CGPoint(x: 287, y: 310))
    top.addLine(to: CGPoint(x: 742, y: 310))
    let upper = top.copy(strokingWithWidth: 60, lineCap: .round, lineJoin: .round, miterLimit: 10)
    let arrow = CGMutablePath()
    arrow.move(to: CGPoint(x: 715, y: 222))
    arrow.addLine(to: CGPoint(x: 804, y: 310))
    arrow.addLine(to: CGPoint(x: 715, y: 398))
    arrow.closeSubpath()
    for path in [upper, arrow, arrow.copy(strokingWithWidth: 28, lineCap: .round, lineJoin: .round, miterLimit: 10)] {
        gradient(path, colors: [0x19C5ED, 0x009AFF],
                 start: CGPoint(x: 232, y: 280), end: CGPoint(x: 780, y: 520))
    }

    let bottom = CGMutablePath()
    bottom.move(to: CGPoint(x: 792, y: 500))
    bottom.addLine(to: CGPoint(x: 792, y: 593))
    bottom.addCurve(to: CGPoint(x: 667, y: 722), control1: CGPoint(x: 792, y: 668),
                    control2: CGPoint(x: 742, y: 722))
    bottom.addLine(to: CGPoint(x: 282, y: 722))
    let lowerArrow = CGMutablePath()
    lowerArrow.move(to: CGPoint(x: 309, y: 634))
    lowerArrow.addLine(to: CGPoint(x: 220, y: 722))
    lowerArrow.addLine(to: CGPoint(x: 309, y: 810))
    lowerArrow.closeSubpath()
    let lowerStroke = bottom.copy(strokingWithWidth: 60, lineCap: .round, lineJoin: .round, miterLimit: 10)
    for path in [lowerStroke, lowerArrow, lowerArrow.copy(strokingWithWidth: 28, lineCap: .round, lineJoin: .round, miterLimit: 10)] {
        gradient(path, colors: [0xA078FF, 0x8144FF],
                 start: CGPoint(x: 230, y: 470), end: CGPoint(x: 770, y: 780))
    }

    context.setLineWidth(42)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setStrokeColor(color(dark ? 0xF8FAFC : 0x111827))
    context.move(to: CGPoint(x: 397, y: 438))
    context.addLine(to: CGPoint(x: 473, y: 512))
    context.addLine(to: CGPoint(x: 397, y: 587))
    context.move(to: CGPoint(x: 533, y: 597))
    context.addLine(to: CGPoint(x: 627, y: 597))
    context.strokePath()

    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

let root = URL(filePath: FileManager.default.currentDirectoryPath)
let assets = root.appending(path: "Relay/Assets.xcassets")
for size in [16, 32, 64, 128, 256, 512, 1024] {
    try render(size: size, dark: true,
               to: assets.appending(path: "AppIcon.appiconset/icon-\(size).png"))
}
for dark in [false, true] {
    try render(size: 256, dark: dark,
               to: assets.appending(path: "RelayMark.imageset/relay-\(dark ? "dark" : "light").png"))
}
