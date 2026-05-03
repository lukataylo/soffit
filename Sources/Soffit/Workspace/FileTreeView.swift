import SwiftUI

struct FileTreeView: View {
    @ObservedObject var workspace: WorkspaceStore
    @EnvironmentObject var services: AppServices
    @EnvironmentObject var session: WindowSession
    @State private var expanded: Set<URL> = []
    @State private var children: [URL: [FSEntry]] = [:]
    @State private var recentExpanded: Bool = false

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
        .onChange(of: workspace.entries) { _, _ in
            // FSEvents fired — refresh any expanded subdirectory caches.
            for url in expanded { loadChildren(url) }
        }
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
            recentSection
            sectionRow(icon: "terminal.fill", label: "New Terminal", tint: Color(red: 0.35, green: 0.65, blue: 0.55)) {
                session.openTerminal()
            }
            sectionRow(icon: "calendar", label: "Today's Daily Note", tint: Color(red: 0.50, green: 0.65, blue: 0.95)) {
                session.openDailyNote()
            }
            tagsSection
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    @State private var tagsExpanded: Bool = false

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 9) {
                Image(systemName: "number")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.85, green: 0.42, blue: 0.55))
                    .frame(width: 18)
                Text("Tags")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                if !services.index.allTags.isEmpty {
                    Text("\(services.index.allTags.count)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(tagsExpanded ? 90 : 0))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .onTapGesture { tagsExpanded.toggle() }

            if tagsExpanded {
                if services.index.allTags.isEmpty {
                    Text("No tags yet")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 35)
                        .padding(.vertical, 4)
                } else {
                    ForEach(services.index.allTags.sorted { $0.value > $1.value }, id: \.key) { tag, count in
                        tagRow(tag: tag, count: count)
                    }
                }
            }
        }
    }

    private func tagRow(tag: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text("#\(tag)")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color(red: 0.85, green: 0.42, blue: 0.55))
            Text("\(count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.leading, 35)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            // Open the first matching file as a quick way to dive in.
            if let first = services.index.filesWithTag(tag).first {
                session.openFile(first.url, mode: .preview)
            }
        }
        .contextMenu {
            ForEach(services.index.filesWithTag(tag), id: \.url) { entry in
                Button(entry.title) { session.openFile(entry.url, mode: .preview) }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 9) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.38, green: 0.56, blue: 0.92))
                    .frame(width: 18)
                Text("Recent")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                if !services.recents.entries.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(recentExpanded ? 90 : 0))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .onTapGesture {
                services.recents.prune()
                recentExpanded.toggle()
            }

            if recentExpanded {
                if services.recents.entries.isEmpty {
                    Text("No recent files yet")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 35)
                        .padding(.vertical, 4)
                } else {
                    ForEach(services.recents.entries, id: \.self) { url in
                        recentRow(url)
                    }
                    HStack {
                        Spacer()
                        Button("Clear") { services.recents.clear() }
                            .buttonStyle(.plain)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                            .padding(.trailing, 12)
                            .padding(.top, 2)
                    }
                }
            }
        }
    }

    private func recentRow(_ url: URL) -> some View {
        HStack(spacing: 7) {
            Image(systemName: iconName(for: url))
                .font(.system(size: 10.5))
                .foregroundStyle(tintColor(for: url))
                .frame(width: 14)
            Text(url.lastPathComponent)
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.leading, 35)
        .padding(.trailing, 8)
        .padding(.vertical, 3.5)
        .contentShape(Rectangle())
        .onTapGesture { session.openFile(url, mode: .preview) }
        .contextMenu {
            Button("Open") { session.openFile(url, mode: .preview) }
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
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

                    if expanded.contains(entry.url), let kids = children[entry.url] {
                        ForEach(kids) { child in
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
                    gitDot(for: entry.url)
                }
                .padding(.leading, CGFloat(depth) * 12 + 20)
                .padding(.trailing, 8)
                .padding(.vertical, 3.5)
                .contentShape(Rectangle())
                .onDrag {
                    NSItemProvider(object: entry.url as NSURL)
                }
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

    @ViewBuilder
    private func gitDot(for url: URL) -> some View {
        let status = services.git.status(for: url)
        if status != .clean {
            Circle()
                .fill(gitColor(status))
                .frame(width: 6, height: 6)
                .help(gitTooltip(status))
        }
    }

    private func gitColor(_ s: GitStatusService.Status) -> Color {
        switch s {
        case .modified:   return Color(red: 0.95, green: 0.65, blue: 0.20)
        case .untracked:  return Color(red: 0.40, green: 0.75, blue: 0.45)
        case .staged:     return Color(red: 0.40, green: 0.65, blue: 0.95)
        case .conflicted: return Color(red: 0.90, green: 0.30, blue: 0.30)
        case .ignored:    return Color.secondary.opacity(0.4)
        case .clean:      return .clear
        }
    }

    private func gitTooltip(_ s: GitStatusService.Status) -> String {
        switch s {
        case .modified:   return "Modified"
        case .untracked:  return "Untracked"
        case .staged:     return "Staged"
        case .conflicted: return "Conflicted"
        case .ignored:    return "Ignored"
        case .clean:      return ""
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
        if expanded.contains(url) {
            expanded.remove(url)
        } else {
            expanded.insert(url)
            loadChildren(url)
        }
    }

    private func loadChildren(_ url: URL) {
        Task.detached(priority: .userInitiated) {
            let kids = WorkspaceStore.readDirectory(url)
            await MainActor.run { children[url] = kids }
        }
    }

    private func openFile(_ url: URL, mode: MarkdownPanelMode = .preview) {
        session.openFile(url, mode: mode)
    }

    private func openFolder(_ url: URL) {
        session.openFolderPanel(url)
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

