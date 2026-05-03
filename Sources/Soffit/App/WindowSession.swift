import Combine
import Foundation

/// Per-window state. `LayoutStore` (the pane tree), the search-palette mode,
/// and the find/replace visibility all live here so a second window has its
/// own panes/tabs without disturbing the first.
///
/// Persistence: only the first window opened in a session is "primary" and
/// reads/writes `layout.json`. Subsequent windows are ephemeral — closing one
/// loses its layout, which is the standard macOS new-window behaviour.
@MainActor
final class WindowSession: ObservableObject {
    @Published var layout: LayoutStore
    @Published var paletteMode: SearchPaletteMode? = nil
    @Published var findReplaceVisible: Bool = false

    let isPrimary: Bool

    private weak var services: AppServices?
    private var cancellables: Set<AnyCancellable> = []
    private var trackedPanelIDs: Set<PanelID> = []
    private var bound = false

    /// Bumps every time a new WindowSession is created. The very first one
    /// becomes the primary (disk-backed) window; the rest are ephemeral.
    private static var sessionCount = 0

    init() {
        Self.sessionCount += 1
        self.isPrimary = (Self.sessionCount == 1)
        self.layout = LayoutStore(tree: .empty)

        // SwiftUI's @EnvironmentObject only observes the immediate ObservableObject.
        // Without this re-publish, mutations to `layout.tree` (which keep the same
        // LayoutStore reference) wouldn't trigger WindowSession.objectWillChange,
        // so PaneView / LayoutHostView would never re-render after addTab/closeTab.
        layout.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// Wire this session to AppServices. Called from RootView.onAppear, since
    /// EnvironmentObject isn't available during a SwiftUI view's init.
    func bind(to services: AppServices) {
        guard !bound else { return }
        bound = true
        self.services = services

        if isPrimary {
            // Primary window: restore the persisted layout snapshot.
            if let snapshot = services.persistence.load(),
               let root = services.workspace?.root,
               snapshot.workspaceRoot == root.path {
                layout.replace(with: snapshot.tree)
                seedPanelState(from: snapshot.tree)
            } else if let root = services.workspace?.root, layout.tree.isEmpty {
                let panel = Panel(source: FolderURL.makeSource(for: root),
                                  title: root.lastPathComponent)
                layout.addTab(panel)
            }

            // Persist tree changes (debounced).
            layout.$tree
                .removeDuplicates()
                .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
                .sink { [weak self] tree in
                    guard let self,
                          let services = self.services,
                          let ws = services.workspace else { return }
                    services.persistence.save(.init(workspaceRoot: ws.root.path, tree: tree))
                }
                .store(in: &cancellables)
        } else {
            // Ephemeral window: start with the workspace folder open as a tab.
            if let root = services.workspace?.root, layout.tree.isEmpty {
                let panel = Panel(source: FolderURL.makeSource(for: root),
                                  title: root.lastPathComponent)
                layout.addTab(panel)
            }
        }

        // Per-panel registry cleanup applies to every window — when a panel
        // leaves *this* window's tree, drop its state.
        trackedPanelIDs = Set(layout.tree.panelIDs)
        layout.$tree
            .sink { [weak self] tree in
                guard let self else { return }
                let current = Set(tree.panelIDs)
                for id in self.trackedPanelIDs.subtracting(current) {
                    MarkdownStateRegistry.shared.cleanup(id)
                    InitialStateHolder.shared.write(id, nil)
                }
                self.trackedPanelIDs = current
            }
            .store(in: &cancellables)
    }

    // MARK: - Per-window file operations

    func openFile(_ url: URL, mode: MarkdownPanelMode = .preview) {
        guard let services else { return }
        let panel = makeFilePanel(url: url, mode: mode, services: services)
        layout.addTab(panel)
        services.recents.record(url)
    }

    func openFolderPanel(_ url: URL) {
        let panel = Panel(source: FolderURL.makeSource(for: url), title: url.lastPathComponent)
        layout.addTab(panel)
    }

    func openDailyNote() {
        guard let root = services?.workspace?.root else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let stamp = formatter.string(from: Date())
        let dailyDir = root.appendingPathComponent("daily", isDirectory: true)
        try? FileManager.default.createDirectory(at: dailyDir, withIntermediateDirectories: true)
        let target = dailyDir.appendingPathComponent("\(stamp).md")
        if !FileManager.default.fileExists(atPath: target.path) {
            let templatePath = root.appendingPathComponent(".soffit/templates/daily.md")
            let body: String
            if let template = try? String(contentsOf: templatePath, encoding: .utf8) {
                let prettyDate = DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .none)
                body = template
                    .replacingOccurrences(of: "{{date}}", with: stamp)
                    .replacingOccurrences(of: "{{long_date}}", with: prettyDate)
            } else {
                body = "# \(stamp)\n\n"
            }
            try? body.write(to: target, atomically: true, encoding: .utf8)
        }
        openFile(target, mode: .split)
    }

    func openSketch() {
        let panel = Panel(source: "sketch://new", title: "Sketch")
        layout.addTab(panel)
    }

    #if SOFFIT_PRO
    /// Pro build only: open an embedded terminal pane rooted in the workspace.
    /// Not available in App Store / Free builds — Apple rejects subprocess
    /// execution under the App Sandbox.
    func openTerminal(in folder: URL? = nil) {
        let dir = folder ?? services?.workspace?.root ?? FileManager.default.homeDirectoryForCurrentUser
        let panel = Panel(source: TerminalSource.makeSource(for: dir), title: "Terminal")
        layout.addTab(panel)
    }
    #endif

    /// Create a new markdown file in the active folder pane (or the workspace
    /// root if no folder pane is focused), then open it. Names like
    /// "Untitled.md", "Untitled 2.md" etc. — collision-safe.
    func newMarkdownFileInWorkspace() {
        let folder = activeFolderURL() ?? services?.workspace?.root
        guard let folder else { return }
        createNewFile(in: folder)
    }

    /// Create a new markdown file in `folder`. Used by the folder grid's "+"
    /// button as well as the menu / keyboard shortcut.
    func createNewFile(in folder: URL) {
        let url = nextAvailableURL(in: folder, base: "Untitled", ext: "md")
        let body = "# \(url.deletingPathExtension().lastPathComponent)\n\n"
        try? body.write(to: url, atomically: true, encoding: .utf8)
        Task { await services?.index.touch(url) }
        openFile(url, mode: .split)
    }

    private func activeFolderURL() -> URL? {
        guard let pane = layout.focusedPane.flatMap({ layout.tree.pane($0) }),
              let active = pane.activeTab,
              active.scheme == "folder" else { return nil }
        return FolderURL.folder(from: PanelSource(url: active.url, panelID: active.id))
    }

    private func nextAvailableURL(in folder: URL, base: String, ext: String) -> URL {
        let fm = FileManager.default
        var candidate = folder.appendingPathComponent("\(base).\(ext)")
        var counter = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) \(counter).\(ext)")
            counter += 1
        }
        return candidate
    }

    func splitPaneWithFile(_ paneID: PaneID, direction: Orientation, url: URL) {
        guard let services else { return }
        let panel: Panel
        if Self.isFolder(url) {
            panel = Panel(source: FolderURL.makeSource(for: url), title: url.lastPathComponent)
        } else {
            panel = makeFilePanel(url: url, mode: .preview, services: services)
        }
        layout.splitPane(paneID, direction: direction, newPanel: panel, side: .second)
    }

    func panelContext() -> PanelContext {
        PanelContext(
            workspaceRoot: services?.workspace?.root,
            keychain: services?.keychain ?? KeychainStore(service: "com.soffit.app"),
            notifications: services?.notifications ?? PanelNotificationBus(),
            savePanelState: { [weak self] id, data in
                self?.layout.updateState(for: id, state: data)
            }
        )
    }

    // MARK: - Helpers

    private func seedPanelState(from tree: LayoutTree) {
        for id in tree.panelIDs {
            InitialStateHolder.shared.write(id, tree.panel(id)?.state)
        }
    }

    private func makeFilePanel(url: URL, mode: MarkdownPanelMode, services: AppServices) -> Panel {
        let source = resolveFileSource(url, services: services)
        var state: Data? = nil
        let ext = url.pathExtension.lowercased()
        if ["md", "markdown", "mdx"].contains(ext) {
            state = try? JSONEncoder().encode(MarkdownPanelState(mode: mode))
        }
        return Panel(source: source, title: url.lastPathComponent, state: state)
    }

    private func resolveFileSource(_ url: URL, services: AppServices) -> String {
        if url.pathExtension.lowercased() == "mmd" {
            return "mermaid://\(workspaceRelativePath(for: url, services: services))"
        }
        return url.absoluteString
    }

    private func workspaceRelativePath(for url: URL, services: AppServices) -> String {
        guard let root = services.workspace?.root else { return url.path }
        if url.path.hasPrefix(root.path) {
            var rel = String(url.path.dropFirst(root.path.count))
            if !rel.hasPrefix("/") { rel = "/" + rel }
            return rel
        }
        return url.path
    }

    private static func isFolder(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
