import AppKit
import SwiftUI

/// Single-instance About window. macOS apps typically reuse one window for About;
/// re-clicking the menu item just brings it forward.
@MainActor
enum AboutWindowController {
    private static var window: NSWindow?

    static func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: AboutView())
        let win = NSWindow(contentViewController: hosting)
        win.title = "About Soffit"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.center()
        win.delegate = AboutWindowDelegate.shared
        window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func windowDidClose() {
        window = nil
    }
}

@MainActor
private final class AboutWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = AboutWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        AboutWindowController.windowDidClose()
    }
}
