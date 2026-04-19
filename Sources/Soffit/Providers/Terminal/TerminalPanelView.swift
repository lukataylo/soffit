import AppKit
import SwiftTerm
import SwiftUI

struct TerminalPanelView: View {
    let source: PanelSource
    let context: PanelContext

    private var startingDirectory: URL {
        TerminalSource.folder(from: source) ?? context.workspaceRoot ?? FileManager.default.homeDirectoryForCurrentUser
    }

    var body: some View {
        TerminalHostView(workingDirectory: startingDirectory)
            .background(Color.black)
    }
}

private struct TerminalHostView: NSViewRepresentable {
    let workingDirectory: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let term = LocalProcessTerminalView(frame: .zero)
        term.processDelegate = context.coordinator
        term.configureNativeColors()
        term.installColors([])

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let quotedPath = "'" + workingDirectory.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let script = "cd \(quotedPath); exec \(shell) -l"

        // Run through bash -c so we can cd first, then exec into the user's shell.
        term.startProcess(
            executable: "/bin/bash",
            args: ["-c", script],
            environment: nil,
            execName: "bash"
        )
        return term
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {}
    }
}
