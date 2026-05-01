import AppKit
import CoreGraphics

/// Generates a simple programmatic dock icon for Soffit and applies it to NSApp.
/// SPM-built executables ship without an Info.plist / icon resource, so we render
/// the brand mark (rounded gradient with a 2x2 grid of "panes") into an NSImage
/// at launch and set `NSApp.applicationIconImage`.
enum AppIcon {
    static func install() {
        if let image = render(side: 512) {
            NSApp.applicationIconImage = image
        }
    }

    private static func render(side: CGFloat) -> NSImage? {
        let size = NSSize(width: side, height: side)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            draw(in: ctx, rect: rect)
            return true
        }
        return image
    }

    private static func draw(in ctx: CGContext, rect: NSRect) {
        let inset: CGFloat = rect.width * 0.05
        let outer = rect.insetBy(dx: inset, dy: inset)
        let radius = outer.width * 0.22

        // Background gradient — Soffit orange to deep amber.
        let path = CGPath(roundedRect: outer, cornerWidth: radius, cornerHeight: radius, transform: nil)
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            NSColor(srgbRed: 0.99, green: 0.66, blue: 0.42, alpha: 1.0).cgColor,
            NSColor(srgbRed: 0.92, green: 0.46, blue: 0.24, alpha: 1.0).cgColor
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: colorspace, colors: colors, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: outer.minX, y: outer.maxY),
                                   end: CGPoint(x: outer.maxX, y: outer.minY),
                                   options: [])
        }
        ctx.restoreGState()

        // Inner highlight (subtle top sheen).
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let sheen = [
            NSColor(white: 1.0, alpha: 0.22).cgColor,
            NSColor(white: 1.0, alpha: 0.0).cgColor
        ] as CFArray
        if let g = CGGradient(colorsSpace: colorspace, colors: sheen, locations: [0.0, 0.6]) {
            ctx.drawLinearGradient(g,
                                   start: CGPoint(x: outer.midX, y: outer.maxY),
                                   end: CGPoint(x: outer.midX, y: outer.midY),
                                   options: [])
        }
        ctx.restoreGState()

        // 2x2 pane grid.
        let panePadding: CGFloat = outer.width * 0.14
        let gap: CGFloat = outer.width * 0.05
        let inner = outer.insetBy(dx: panePadding, dy: panePadding)
        let cellWidth = (inner.width - gap) / 2.0
        let cellHeight = (inner.height - gap) / 2.0
        let cellRadius = cellWidth * 0.18

        let cells: [(CGFloat, CGFloat, CGFloat)] = [
            (inner.minX, inner.maxY - cellHeight, 0.95),                // top-left  (largest highlight)
            (inner.minX + cellWidth + gap, inner.maxY - cellHeight, 0.78),
            (inner.minX, inner.minY, 0.78),
            (inner.minX + cellWidth + gap, inner.minY, 0.95)            // bottom-right (highlight)
        ]

        for (x, y, alpha) in cells {
            let cell = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
            let cellPath = CGPath(roundedRect: cell, cornerWidth: cellRadius, cornerHeight: cellRadius, transform: nil)
            ctx.addPath(cellPath)
            ctx.setFillColor(NSColor(white: 1.0, alpha: alpha).cgColor)
            ctx.fillPath()
        }

        // Outer hairline for definition.
        ctx.addPath(path)
        ctx.setStrokeColor(NSColor(white: 0.0, alpha: 0.10).cgColor)
        ctx.setLineWidth(rect.width * 0.006)
        ctx.strokePath()
    }
}
