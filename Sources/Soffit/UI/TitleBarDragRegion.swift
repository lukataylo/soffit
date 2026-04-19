import AppKit
import SwiftUI

/// A thin strip at the top of the window that acts as the macOS title bar region —
/// drag to move the window, double-click to zoom (honouring the user's system
/// preference for "double-click a window's title bar to"). Traffic lights sit on
/// top of this view (rendered by the window). Content sits below it.
struct TitleBarDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { TitleBarDragNSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class TitleBarDragNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}
