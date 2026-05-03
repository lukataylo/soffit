import AppKit
import SwiftUI

struct SoffitCommands: Commands {
    @ObservedObject var services: AppServices
    @FocusedObject var session: WindowSession?

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Soffit") { AboutWindowController.show() }
            Button("Check for Updates…") {
                UpdaterController.shared.checkForUpdates()
            }
            .disabled(!UpdaterController.shared.canCheckForUpdates)
        }

        CommandGroup(after: .newItem) {
            Button("Open Workspace…") { pickWorkspace() }
                .keyboardShortcut("o", modifiers: [.command])
            Divider()
            Button("Today's Daily Note") { session?.openDailyNote() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Button("New Sketch") { session?.openSketch() }
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Quick Open…") {
                session?.paletteMode = .fileName
            }
            .keyboardShortcut("p", modifiers: [.command])

            Button("Search in Workspace…") {
                session?.paletteMode = .content
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Button("Find / Replace in Workspace…") {
                session?.findReplaceVisible = true
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
        }

        CommandMenu("Panes") {
            Button("Close Tab") {
                session?.layout.closeFocusedTab()
            }
            .keyboardShortcut("w", modifiers: [.command])

            Divider()

            Button("Split Right") { splitFocused(.horizontal) }
                .keyboardShortcut("\\", modifiers: [.command])

            Button("Split Down") { splitFocused(.vertical) }
                .keyboardShortcut("\\", modifiers: [.command, .shift])

            Divider()

            Button("Focus Next Pane") {
                session?.layout.focusNextPane()
            }
            .keyboardShortcut("]", modifiers: [.command])

            Button("Focus Previous Pane") {
                session?.layout.focusPreviousPane()
            }
            .keyboardShortcut("[", modifiers: [.command])
        }
    }

    private func splitFocused(_ direction: Orientation) {
        guard let session, let paneID = session.layout.focusedPane else { return }
        let panel: Panel
        if let active = session.layout.tree.pane(paneID)?.activeTab {
            panel = Panel(source: active.source, title: active.title)
        } else if let root = services.workspace?.root {
            panel = Panel(source: FolderURL.makeSource(for: root), title: root.lastPathComponent)
        } else {
            return
        }
        session.layout.splitPane(paneID, direction: direction, newPanel: panel, side: .second)
    }

    private func pickWorkspace() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Workspace"
        if panel.runModal() == .OK, let url = panel.url {
            services.openWorkspace(at: url)
        }
    }
}
