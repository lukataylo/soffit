import AppKit
import SwiftUI

@main
struct WorkbenchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var services = AppServices()

    var body: some Scene {
        WindowGroup("Workbench") {
            RootView()
                .environmentObject(services)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear { services.start() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands { WorkbenchCommands(services: services) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
