import SwiftUI

struct SoffitCommands: Commands {
    @ObservedObject var services: AppServices

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Workspace…") { pickWorkspace() }
                .keyboardShortcut("o", modifiers: [.command])
            Button("New Terminal") { services.openTerminal() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
        }

        CommandGroup(after: .appSettings) {
            Button("Set Anthropic API Key…") { services.promptForAPIKey() }
        }

        CommandMenu("Panes") {
            Button("Close Tab") {
                services.layout.closeFocusedTab()
            }
            .keyboardShortcut("w", modifiers: [.command])

            Divider()

            Button("Split Right") { splitFocused(.horizontal) }
                .keyboardShortcut("\\", modifiers: [.command])

            Button("Split Down") { splitFocused(.vertical) }
                .keyboardShortcut("\\", modifiers: [.command, .shift])

            Divider()

            Button("Focus Next Pane") {
                services.layout.focusNextPane()
            }
            .keyboardShortcut("]", modifiers: [.command])

            Button("Focus Previous Pane") {
                services.layout.focusPreviousPane()
            }
            .keyboardShortcut("[", modifiers: [.command])

            Divider()

            Button("Open Brief") {
                NSWorkspace.shared.open(URL(string: "https://github.com/lukataylo/soffit#readme")!)
            }
        }
    }

    private func splitFocused(_ direction: Orientation) {
        guard let paneID = services.layout.focusedPane else { return }
        let panel: Panel
        if let active = services.layout.tree.pane(paneID)?.activeTab {
            panel = Panel(source: active.source, title: active.title)
        } else if let root = services.workspace?.root {
            panel = Panel(source: FolderURL.makeSource(for: root), title: root.lastPathComponent)
        } else {
            return
        }
        services.layout.splitPane(paneID, direction: direction, newPanel: panel, side: .second)
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
