import AppKit
import SwiftUI

struct WorkspacePickerView: View {
    @EnvironmentObject var services: AppServices

    var body: some View {
        ZStack {
            WorkbenchSurface()
            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 76, height: 76)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.35))
                }

                VStack(spacing: 6) {
                    Text("Pick a workspace")
                        .font(.system(size: 26, weight: .bold))
                    Text("Workbench tiles markdown, diagrams, web previews, and Claude chats against one folder on disk.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                }

                Button { pick() } label: {
                    Label("Choose Folder…", systemImage: "folder.fill.badge.plus")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .font(.system(size: 13, weight: .semibold))
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
            .padding(40)
        }
    }

    private func pick() {
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
