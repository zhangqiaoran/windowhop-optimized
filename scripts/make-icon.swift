// Builds AppIcon.iconset from the committed my-alt-tab brand source image.
// Usage:
//   swift scripts/make-icon.swift <output-dir> [source-png]
//   iconutil -c icns <output-dir>/AppIcon.iconset -o Support/AppIcon.icns
import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/icon"
let sourcePath = CommandLine.arguments.count > 2
    ? CommandLine.arguments[2]
    : "Support/AppIconSource.png"

guard let master = NSImage(contentsOfFile: sourcePath) else {
    fputs("unable to load app icon source: \(sourcePath)\n", stderr)
    exit(1)
}

func writePNG(_ image: NSImage, to url: URL, pixels: Int) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: NSRect(origin: .zero, size: image.size),
        operation: .copy,
        fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let iconsetURL = URL(fileURLWithPath: outputDir).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconsetURL)
try! FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for size in [16, 32, 128, 256, 512] {
    writePNG(master,
             to: iconsetURL.appendingPathComponent("icon_\(size)x\(size).png"),
             pixels: size)
    writePNG(master,
             to: iconsetURL.appendingPathComponent("icon_\(size)x\(size)@2x.png"),
             pixels: size * 2)
}
print("wrote \(iconsetURL.path) from \(sourcePath)")
