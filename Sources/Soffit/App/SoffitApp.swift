import AppKit
import SwiftUI

@main
struct SoffitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var services = AppServices()

    var body: some Scene {
        WindowGroup("Soffit") {
            RootView()
                .environmentObject(services)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear { services.start() }
                .background(WindowChromeConfigurator())
        }
        .windowStyle(.hiddenTitleBar)
        .commands { SoffitCommands(services: services) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        AppIcon.install()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// Configures the hosting NSWindow to use a transparent, full-size-content titlebar
/// and a translucent look that lets the SwiftUI gradient show through.
struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { configure(v) }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView) }
    }

    private func configure(_ view: NSView) {
        guard let window = view.window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        // Do NOT enable isMovableByWindowBackground — it intercepts drags on
        // translucent areas (tabs, sidebar) and moves the window instead of
        // letting SwiftUI .onDrag initiate a real drag session. Users can still
        // drag the window by the traffic-light strip at the top-left.
        window.isMovableByWindowBackground = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.invalidateShadow()
    }
}
