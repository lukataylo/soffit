import SwiftUI

struct FolderPanelView: View {
    let source: PanelSource
    let context: PanelContext

    @EnvironmentObject var services: AppServices
    @ObservedObject private var store: CanvasStore

    init(source: PanelSource, context: PanelContext) {
        self.source = source
        self.context = context
        _store = ObservedObject(wrappedValue: CanvasStateRegistry.shared.store(
            for: source.panelID,
            save: context.savePanelState
        ))
    }

    private var folderURL: URL? { FolderURL.folder(from: source) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if store.state.mode == .grid {
                FolderGridView(
                    folderURL: folderURL,
                    workspaceRoot: services.workspace?.root,
                    mode: Binding(
                        get: { store.state.mode },
                        set: { store.setMode($0) }
                    ),
                    onOpen: openEntry,
                    onNavigateFolder: navigateFolder,
                    onAddToCanvas: { entry in
                        store.setMode(.canvas)
                        let path = relativePath(for: entry.url)
                        store.addFile(at: path, position: CGPoint(x: 200, y: 200))
                    }
                )
            } else {
                CanvasFolderView(
                    store: store,
                    workspaceRoot: services.workspace?.root,
                    onOpen: { url in services.openFile(url, mode: .preview) }
                )
                .overlay(alignment: .topLeading) {
                    gridToggleFloatingButton
                        .padding(14)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var gridToggleFloatingButton: some View {
        Button {
            store.setMode(.grid)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 11, weight: .semibold))
                Text("Grid")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .help("Switch to grid")
    }

    private func openEntry(_ entry: FSEntry) {
        if entry.isDirectory {
            navigateFolder(entry.url)
        } else {
            services.openFile(entry.url, mode: .preview)
        }
    }

    private func navigateFolder(_ url: URL) {
        let updated = Panel(id: source.panelID, source: FolderURL.makeSource(for: url), title: url.lastPathComponent)
        services.layout.replacePanel(source.panelID, with: updated)
    }

    private func relativePath(for url: URL) -> String {
        if let root = services.workspace?.root, url.path.hasPrefix(root.path) {
            return String(url.path.dropFirst(root.path.count + (url.path.count > root.path.count ? 1 : 0)))
        }
        return url.path
    }
}
