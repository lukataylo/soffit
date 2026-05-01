import SwiftUI

struct FileTreeView: View {
    @ObservedObject var workspace: WorkspaceStore
    @EnvironmentObject var services: AppServices
    @State private var expanded: Set<URL> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            workspaceHeader
                .padding(.top, 10)
            quickSections
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    Text("FOLDERS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                    ForEach(workspace.entries) { entry in
                        entryRow(entry, depth: 0)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var workspaceHeader: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.95, green: 0.55, blue: 0.35).opacity(0.22))
                    .frame(width: 26, height: 26)
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.35))
                    .font(.system(size: 11, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Soffit")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text(workspace.root.lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            Spacer()
            Button {
                pickWorkspace()
            } label: {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Change workspace")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var quickSections: some View {
        VStack(alignment: .leading, spacing: 1) {
            sectionRow(icon: "square.stack.3d.up.fill", label: "All Documents", tint: Color(red: 0.95, green: 0.55, blue: 0.35)) {
                openFolder(workspace.root)
            }
            sectionRow(icon: "clock.fill", label: "Recent", tint: Color(red: 0.38, green: 0.56, blue: 0.92)) {
                openFolder(workspace.root)
            }
            sectionRow(icon: "terminal.fill", label: "New Terminal", tint: Color(red: 0.35, green: 0.65, blue: 0.55)) {
                services.openTerminal()
            }
            sectionRow(icon: "bubble.left.and.bubble.right.fill", label: "New Chat", tint: Color(red: 0.85, green: 0.42, blue: 0.55)) {
                let panel = Panel(source: "chat://claude", title: "Claude")
                services.layout.addTab(panel)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func sectionRow(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
        )
        .onTapGesture { action() }
    }

    private func entryRow(_ entry: FSEntry, depth: Int) -> AnyView {
        if entry.isDirectory {
            return AnyView(
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(expanded.contains(entry.url) ? 90 : 0))
                            .frame(width: 12)
                            .contentShape(Rectangle())
                            .onTapGesture { toggle(entry.url) }

                        HStack(spacing: 7) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.35))
                            Text(entry.name)
                                .font(.system(size: 12.5, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { openFolder(entry.url) }
                    }
                    .padding(.leading, CGFloat(depth) * 12 + 8)
                    .padding(.trailing, 8)
                    .padding(.vertical, 4)

                    if expanded.contains(entry.url) {
                        ForEach(WorkspaceStore.readDirectory(entry.url)) { child in
                            entryRow(child, depth: depth + 1)
                        }
                    }
                }
            )
        } else {
            return AnyView(
                HStack(spacing: 7) {
                    Image(systemName: iconName(for: entry.url))
                        .font(.system(size: 10.5))
                        .foregroundStyle(tintColor(for: entry.url))
                        .frame(width: 14)
                    Text(entry.name)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.leading, CGFloat(depth) * 12 + 20)
                .padding(.trailing, 8)
                .padding(.vertical, 3.5)
                .contentShape(Rectangle())
                .gesture(
                    TapGesture(count: 2)
                        .onEnded { openFile(entry.url, mode: .split) }
                        .exclusively(before:
                            TapGesture(count: 1).onEnded { openFile(entry.url, mode: .preview) }
                        )
                )
                .contextMenu {
                    Button("Open as Tab") { openFile(entry.url, mode: .preview) }
                    Button("Open in Editor Mode") { openFile(entry.url, mode: .split) }
                    Divider()
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([entry.url])
                    }
                }
            )
        }
    }

    private func iconName(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "md", "markdown", "mdx": return "doc.richtext.fill"
        case "mmd": return "point.3.filled.connected.trianglepath.dotted"
        case "png", "jpg", "jpeg", "gif", "heic": return "photo.fill"
        case "json", "yaml", "yml", "toml": return "curlybraces"
        default: return "doc.fill"
        }
    }

    private func tintColor(for url: URL) -> Color {
        switch url.pathExtension.lowercased() {
        case "md", "markdown", "mdx": return Color(red: 0.38, green: 0.56, blue: 0.92)
        case "mmd": return Color(red: 0.60, green: 0.40, blue: 0.85)
        default: return .secondary
        }
    }

    private func toggle(_ url: URL) {
        if expanded.contains(url) { expanded.remove(url) } else { expanded.insert(url) }
    }

    private func openFile(_ url: URL, mode: MarkdownPanelMode = .preview) {
        services.openFile(url, mode: mode)
    }

    private func openFolder(_ url: URL) {
        services.openFolderPanel(url)
    }

    private func pickWorkspace() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            services.openWorkspace(at: url)
        }
    }
}

