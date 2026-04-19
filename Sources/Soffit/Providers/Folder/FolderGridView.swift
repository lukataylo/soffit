import SwiftUI

struct FolderGridView: View {
    let folderURL: URL?
    let workspaceRoot: URL?
    let onOpen: (FSEntry) -> Void
    let onNavigateFolder: (URL) -> Void

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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                grid
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { refresh() }
        .onChange(of: folderURL) { _, _ in refresh() }
        .onChange(of: sort) { _, _ in refresh() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let url = folderURL {
                BreadcrumbView(url: url, workspaceRoot: workspaceRoot, onTap: onNavigateFolder)
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(folderURL?.lastPathComponent ?? "Folder")
                    .font(.system(size: 26, weight: .bold))
                Text("\(entries.count) item\(entries.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Sort", selection: $sort) {
                    ForEach(SortMode.allCases) { m in Text(m.label).tag(m) }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                .labelsHidden()
            }
        }
    }

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 16, alignment: .top)],
            alignment: .leading,
            spacing: 16
        ) {
            ForEach(entries) { entry in
                DocumentCard(entry: entry, onOpen: { onOpen(entry) })
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
