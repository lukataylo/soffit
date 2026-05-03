#!/usr/bin/env swift
// Generates the Soffit app icon at all required sizes and compiles to .icns.
// Usage: ./scripts/generate-icon.swift   (writes Resources/AppIcon.icns)

import AppKit
import Foundation

// Required AppIcon sizes for macOS (point sizes; @2x doubles).
// iconutil expects: icon_16x16, icon_16x16@2x, icon_32x32, ..., icon_512x512@2x
let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16",      16),
    ("icon_16x16@2x",   32),
    ("icon_32x32",      32),
    ("icon_32x32@2x",   64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x", 1024)
]

func renderIcon(pixels: Int) -> NSImage {
    let size = NSSize(width: pixels, height: pixels)
    let img = NSImage(size: size)
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus(); return img
    }

    let bounds = CGRect(origin: .zero, size: size)

    // Squircle (macOS Big Sur+ icon shape) — ~22.5% corner radius is the
    // standard Apple icon curve for full-bleed bitmaps. iconutil/dock will
    // mask further, but we keep it consistent so previews look right.
    let radius = CGFloat(pixels) * 0.2237
    let path = CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Warm coral → magenta gradient diagonal.
    let colorspace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(srgbRed: 0.96, green: 0.62, blue: 0.42, alpha: 1.0),
        CGColor(srgbRed: 0.92, green: 0.36, blue: 0.48, alpha: 1.0)
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorspace, colors: colors, locations: [0.0, 1.0])!

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: bounds.height),
                           end: CGPoint(x: bounds.width, y: 0),
                           options: [])
    ctx.restoreGState()

    // 2x2 pane grid mark — represents the tiled-canvas product.
    let inset = CGFloat(pixels) * 0.22
    let gap = CGFloat(pixels) * 0.045
    let cell = (CGFloat(pixels) - inset * 2 - gap) / 2
    let cornerR = cell * 0.16
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.94)
    for (cx, cy) in [(0, 0), (1, 0), (0, 1), (1, 1)] {
        let x = inset + CGFloat(cx) * (cell + gap)
        let y = inset + CGFloat(cy) * (cell + gap)
        let rect = CGRect(x: x, y: y, width: cell, height: cell)
        let p = CGPath(roundedRect: rect, cornerWidth: cornerR, cornerHeight: cornerR, transform: nil)
        ctx.addPath(p)
        ctx.fillPath()
    }

    // Subtle inner highlight for depth at large sizes.
    if pixels >= 128 {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let highlight = [
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.18),
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.0)
        ] as CFArray
        let g2 = CGGradient(colorsSpace: colorspace, colors: highlight, locations: [0.0, 0.6])!
        ctx.drawLinearGradient(g2,
                               start: CGPoint(x: 0, y: bounds.height),
                               end: CGPoint(x: 0, y: bounds.height * 0.4),
                               options: [])
        ctx.restoreGState()
    }

    img.unlockFocus()
    return img
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "iconGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG encode failed"])
    }
    try png.write(to: url)
}

let fm = FileManager.default
let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
let iconset = cwd.appendingPathComponent("Sources/Soffit/Resources/AppIcon.iconset", isDirectory: true)
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for entry in sizes {
    let img = renderIcon(pixels: entry.pixels)
    let url = iconset.appendingPathComponent("\(entry.name).png")
    try writePNG(img, to: url)
    FileHandle.standardOutput.write(Data("wrote \(url.lastPathComponent) (\(entry.pixels)px)\n".utf8))
}

// Compile .iconset → .icns via iconutil.
let icns = cwd.appendingPathComponent("Sources/Soffit/Resources/AppIcon.icns")
try? fm.removeItem(at: icns)
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil failed (exit \(task.terminationStatus))\n".utf8))
    exit(1)
}
FileHandle.standardOutput.write(Data("\nbuilt \(icns.path)\n".utf8))
