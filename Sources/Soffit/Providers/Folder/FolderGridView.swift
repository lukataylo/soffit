import SwiftUI

struct FolderGridView: View {
    let folderURL: URL?
    let workspaceRoot: URL?
    let onOpen: (FSEntry) -> Void
    let onNavigateFolder: (URL) -> Void
    let onCreateNewFile: (URL) -> Void

    @State private var entries: [FSEntry] = []
    @State private var sort: SortMode = .modified

    enum SortMode: String, CaseIterable, Identifiable {
        case name, modified, kind
        var id: String { rawValue }
        var label: String {
            switch self {
            case .name: return "Name"
            case .modified: return "Recent"
            case .kind: return "Kind"
            }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(width: proxy.size.width)
                    grid
                }
                .padding(.horizontal, 28)
                .padding(.top, 18)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { refresh() }
        .onChange(of: folderURL) { _, _ in refresh() }
        .onChange(of: sort) { _, _ in refresh() }
    }

    @ViewBuilder
    private func header(width: CGFloat) -> some View {
        let compact = width < 520
        VStack(alignment: .leading, spacing: 6) {
            if let url = folderURL {
                BreadcrumbView(url: url, workspaceRoot: workspaceRoot, onTap: onNavigateFolder)
            }
            if compact {
                // Stack vertically when there isn't room for title + pickers in a row.
                Text(folderURL?.lastPathComponent ?? "Folder")
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 10) {
                    Text("\(entries.count) item\(entries.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    newFileButton
                    sortPicker
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(folderURL?.lastPathComponent ?? "Folder")
                        .font(.system(size: 26, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                    Text("\(entries.count) item\(entries.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                    Spacer(minLength: 8)
                    newFileButton
                    sortPicker
                }
            }
        }
    }

    private var newFileButton: some View {
        Button {
            if let folder = folderURL { onCreateNewFile(folder) }
        } label: {
            Label("New File", systemImage: "doc.badge.plus")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help("New markdown file in this folder")
        .accessibilityLabel("Create new markdown file in this folder")
        .keyboardShortcut("n", modifiers: [.command])
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $sort) {
            ForEach(SortMode.allCases) { m in Text(m.label).tag(m) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 180)
        .fixedSize()
    }

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 16, alignment: .top)],
            alignment: .leading,
            spacing: 16
        ) {
            ForEach(entries) { entry in
                DocumentCard(entry: entry, onOpen: { onOpen(entry) })
                    .onDrag {
                        NSItemProvider(object: entry.url as NSURL)
                    }
                    .contextMenu {
                        Button("Open") { onOpen(entry) }
                        Divider()
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([entry.url])
                        }
                    }
            }
        }
    }

    private func refresh() {
        guard let url = folderURL else { entries = []; return }
        var items = WorkspaceStore.readDirectory(url)
        switch sort {
        case .name:
            items.sort { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        case .modified:
            items.sort { a, b in
                let am = (try? a.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let bm = (try? b.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return am > bm
            }
        case .kind:
            items.sort { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
                let ea = a.url.pathExtension.lowercased()
                let eb = b.url.pathExtension.lowercased()
                if ea != eb { return ea < eb }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }
        entries = items
    }
}

struct BreadcrumbView: View {
    let url: URL
    let workspaceRoot: URL?
    let onTap: (URL) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(segments().enumerated()), id: \.offset) { idx, seg in
                if idx > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                Button { onTap(seg.url) } label: {
                    Text(seg.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(idx == segments().count - 1 ? Color.primary : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func segments() -> [(label: String, url: URL)] {
        guard let root = workspaceRoot else {
            return [(url.lastPathComponent, url)]
        }
        guard url.path.hasPrefix(root.path) else {
            return [(url.lastPathComponent, url)]
        }
        let rel = String(url.path.dropFirst(root.path.count))
        var parts: [(String, URL)] = [(root.lastPathComponent, root)]
        var current = root
        for component in rel.split(separator: "/") where !component.isEmpty {
            current = current.appendingPathComponent(String(component))
            parts.append((String(component), current))
        }
        return parts
    }
}
