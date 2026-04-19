import SwiftUI

struct WorkbenchCommands: Commands {
    @ObservedObject var services: AppServices

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Workspace…") { pickWorkspace() }
                .keyboardShortcut("o", modifiers: [.command])
        }

        CommandMenu("Panels") {
            Button("Split Right") {
                services.layout.splitFocused(.horizontal, insertOn: .second)
            }
            .keyboardShortcut("d", modifiers: [.command])

            Button("Split Down") {
                services.layout.splitFocused(.vertical, insertOn: .second)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Button("Close Panel") {
                services.layout.closeFocused()
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])

            Button("Focus Next Panel") {
                services.layout.focusNext()
            }
            .keyboardShortcut("]", modifiers: [.command])

            Divider()

            Button("Open Brief") {
                NSWorkspace.shared.open(URL(string: "https://github.com/anthropics/workbench#readme")!)
            }
        }
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
