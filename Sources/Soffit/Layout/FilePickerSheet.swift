import SwiftUI

struct FilePickerSheet: View {
    let title: String
    let folderURL: URL?
    let workspaceRoot: URL?
    let onResolve: (URL?) -> Void

    @State private var entries: [FSEntry] = []
    @State private var filter: String = ""
    @State private var currentFolder: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button("Cancel") { onResolve(nil) }
                    .keyboardShortcut(.cancelAction)
            }

            if let url = currentFolder {
                BreadcrumbView(url: url, workspaceRoot: workspaceRoot) { target in
                    currentFolder = target
                    refresh()
                }
            }

            TextField("Filter…", text: $filter)
                .textFieldStyle(.roundedBorder)

            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    let items = entries.filter { matches($0) }
                    if items.isEmpty {
                        Text("No matching files")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(items) { entry in
                            row(entry)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 320)
        }
        .padding(16)
        .frame(width: 420)
        .onAppear {
            currentFolder = folderURL ?? workspaceRoot
            refresh()
        }
    }

    private func row(_ entry: FSEntry) -> some View {
        Button {
            if entry.isDirectory {
                currentFolder = entry.url
                refresh()
            } else {
                onResolve(entry.url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: iconName(entry))
                    .font(.system(size: 11))
                    .foregroundStyle(tint(entry))
                    .frame(width: 16)
                Text(entry.name)
                    .font(.system(size: 12.5, weight: entry.isDirectory ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if entry.isDirectory {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(FilePickerRowStyle())
    }

    private func matches(_ entry: FSEntry) -> Bool {
        let q = filter.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return true }
        return entry.name.localizedCaseInsensitiveContains(q)
    }

    private func refresh() {
        guard let url = currentFolder else { entries = []; return }
        entries = WorkspaceStore.readDirectory(url)
    }

    private func iconName(_ entry: FSEntry) -> String {
        if entry.isDirectory { return "folder.fill" }
        switch entry.url.pathExtension.lowercased() {
        case "md", "markdown", "mdx": return "doc.richtext.fill"
        case "mmd": return "point.3.filled.connected.trianglepath.dotted"
        case "png", "jpg", "jpeg", "heic", "gif": return "photo.fill"
        case "json", "yml", "yaml", "toml": return "curlybraces"
        default: return "doc.fill"
        }
    }

    private func tint(_ entry: FSEntry) -> Color {
        if entry.isDirectory { return Color(red: 0.95, green: 0.55, blue: 0.35) }
        switch entry.url.pathExtension.lowercased() {
        case "md", "markdown", "mdx": return Color(red: 0.38, green: 0.56, blue: 0.92)
        case "mmd": return Color(red: 0.60, green: 0.40, blue: 0.85)
        default: return .secondary
        }
    }
}

private struct FilePickerRowStyle: ButtonStyle {
    @State private var isHovered = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.accentColor.opacity(0.16) : Color.clear)
            )
            .onHover { isHovered = $0 }
    }
}
