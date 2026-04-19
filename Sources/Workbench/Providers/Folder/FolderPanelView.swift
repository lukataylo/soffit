import SwiftUI

struct FolderPanelView: View {
    let source: PanelSource
    let context: PanelContext

    @EnvironmentObject var services: AppServices
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

    var folderURL: URL? { FolderURL.folder(from: source) }

    var body: some View {
        ZStack {
            WorkbenchSurface()
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    headerBlock
                    cardGrid
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { refresh() }
        .onChange(of: folderURL) { _, _ in refresh() }
        .onChange(of: sort) { _, _ in refresh() }
    }

    private var headerBlock: some View {
        let folder = folderURL
        return VStack(alignment: .leading, spacing: 6) {
            if let url = folder {
                BreadcrumbView(url: url, workspaceRoot: services.workspace?.root) { target in
                    navigate(to: target)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(folder?.lastPathComponent ?? "Folder")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                Text("\(entries.count) item\(entries.count == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                sortControl
            }
        }
    }

    private var sortControl: some View {
        Picker("Sort", selection: $sort) {
            ForEach(SortMode.allCases) { m in Text(m.label).tag(m) }
        }
        .pickerStyle(.segmented)
        .frame(width: 220)
        .labelsHidden()
    }

    private var cardGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 18, alignment: .top)],
            alignment: .leading,
            spacing: 18
        ) {
            ForEach(entries) { entry in
                DocumentCard(
                    entry: entry,
                    onSingle: { open(entry, mode: .preview) },
                    onDouble: { open(entry, mode: .split) }
                )
                .contextMenu {
                    Button("Open Preview") { open(entry, mode: .preview) }
                    Button("Open in Editor") { open(entry, mode: .split) }
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

    private func open(_ entry: FSEntry, mode: MarkdownPanelMode) {
        if entry.isDirectory {
            navigate(to: entry.url)
        } else {
            services.openFile(entry.url, from: source.panelID, mode: mode)
        }
    }

    private func navigate(to folder: URL) {
        let new = Panel(id: source.panelID, source: FolderURL.makeSource(for: folder), title: folder.lastPathComponent)
        services.layout.replacePanel(source.panelID, with: new)
    }

}

private struct BreadcrumbView: View {
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
                        .foregroundStyle(idx == segments().count - 1 ? .primary : .secondary)
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
