import Combine
import Foundation

@MainActor
final class AppServices: ObservableObject {
    @Published var workspace: WorkspaceStore?
    @Published var layout: LayoutStore
    @Published var needsAPIKey: Bool = false
    @Published var needsWorkspace: Bool = false
    @Published var paletteMode: SearchPaletteMode? = nil
    @Published var findReplaceVisible: Bool = false

    let registry: ProviderRegistry
    let keychain: KeychainStore
    let persistence: LayoutPersistence
    let notifications = PanelNotificationBus()
    let recents = RecentFilesStore()
    let index = WorkspaceIndex()
    let snippets = SnippetsStore()
    let git = GitStatusService()
    let themes = ThemesLoader()

    private var cancellables: Set<AnyCancellable> = []
    private var trackedPanelIDs: Set<PanelID> = []

    init() {
        let keychain = KeychainStore(service: "com.soffit.app")
        let registry = ProviderRegistry()
        self.keychain = keychain
        self.registry = registry
        self.persistence = LayoutPersistence()
        self.layout = LayoutStore(tree: .empty)

        registry.register(FileProvider())
        let web = WebProvider()
        registry.register(web)
        registry.register(web, forScheme: "http")
        registry.register(web, forScheme: "https")
        registry.register(MermaidProvider())
        registry.register(FolderProvider())
        registry.register(TerminalProvider())
        registry.register(ChatProvider(keychain: keychain))
        registry.register(SketchProvider())

        // Re-publish nested LayoutStore changes so @EnvironmentObject consumers
        // of AppServices re-render when layout.tree or layout.focusedPane mutates.
        layout.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func start() {
        let snapshot = persistence.load()
        if let rootPath = snapshot?.workspaceRoot,
           FileManager.default.fileExists(atPath: rootPath) {
            openWorkspace(at: URL(fileURLWithPath: rootPath))
            if let tree = snapshot?.tree {
                layout.replace(with: tree)
                seedPanelState(from: tree)
            }
        } else {
            needsWorkspace = true
        }

        // Don't auto-prompt for API key. Users invoke it explicitly from the
        // menu (Soffit → Set Anthropic API Key…) if/when they want chat.
        layout.$tree
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] tree in
                guard let self, let ws = self.workspace else { return }
                self.persistence.save(.init(workspaceRoot: ws.root.path, tree: tree))
            }
            .store(in: &cancellables)

        // Release per-panel registries (canvas, markdown, initial-state) when a panel
        // leaves the tree. Without this, every closed folder/markdown pane would hold
        // its store forever in shared registries.
        trackedPanelIDs = Set(layout.tree.panelIDs)
        layout.$tree
            .sink { [weak self] tree in
                guard let self else { return }
                let current = Set(tree.panelIDs)
                for id in self.trackedPanelIDs.subtracting(current) {
                    CanvasStateRegistry.shared.cleanup(id)
                    MarkdownStateRegistry.shared.cleanup(id)
                    InitialStateHolder.shared.write(id, nil)
                }
                self.trackedPanelIDs = current
            }
            .store(in: &cancellables)
    }

    func openWorkspace(at url: URL) {
        let store = WorkspaceStore(root: url)
        workspace = store
        needsWorkspace = false
        if layout.tree.isEmpty {
            let panel = Panel(source: FolderURL.makeSource(for: url), title: url.lastPathComponent)
            layout.addTab(panel)
        }
        // Build the workspace index in the background so search/wikilinks/tags
        // are ready as soon as the file tree finishes its first render.
        Task { await index.open(root: url) }
        git.bind(to: url)
        // FSEvents on the workspace store also nudge the index. WorkspaceStore
        // currently only emits a coarse "something changed" signal, so we
        // re-walk markdown files on every notification — it's bounded by the
        // 0.5s FSEventStream latency.
        store.objectWillChange
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] in
                guard let self else { return }
                Task { await self.index.refreshAll() }
                self.git.notifyChange()
            }
            .store(in: &cancellables)
    }

    func saveAPIKey(_ key: String) {
        keychain.apiKey = key
        needsAPIKey = false
    }

    // MARK: - File opening routes everything through the focused pane

    func openFile(_ url: URL, mode: MarkdownPanelMode = .preview) {
        let panel = makeFilePanel(url: url, mode: mode)
        layout.addTab(panel)
        recents.record(url)
    }

    func openFolderPanel(_ url: URL) {
        let panel = Panel(source: FolderURL.makeSource(for: url), title: url.lastPathComponent)
        layout.addTab(panel)
    }

    func openTerminal(in folder: URL? = nil) {
        let dir = folder ?? workspace?.root ?? FileManager.default.homeDirectoryForCurrentUser
        let panel = Panel(source: TerminalSource.makeSource(for: dir), title: "Terminal")
        layout.addTab(panel)
    }

    /// Open today's daily note (creates it if needed under daily/YYYY-MM-DD.md).
    /// Optionally seeded from .soffit/templates/daily.md.
    func openDailyNote() {
        guard let root = workspace?.root else { return }
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

    /// Open a fresh sketch panel for ad-hoc drawing.
    func openSketch() {
        let panel = Panel(source: "sketch://new", title: "Sketch")
        layout.addTab(panel)
    }

    func promptForAPIKey() {
        needsAPIKey = true
    }

    func splitPaneWithFile(_ paneID: PaneID, direction: Orientation, url: URL) {
        let panel: Panel
        if isFolder(url) {
            panel = Panel(source: FolderURL.makeSource(for: url), title: url.lastPathComponent)
        } else {
            panel = makeFilePanel(url: url, mode: .preview)
        }
        layout.splitPane(paneID, direction: direction, newPanel: panel, side: .second)
    }

    private func makeFilePanel(url: URL, mode: MarkdownPanelMode) -> Panel {
        let source = resolveFileSource(url)
        var state: Data? = nil
        let ext = url.pathExtension.lowercased()
        if ["md", "markdown", "mdx"].contains(ext) {
            state = try? JSONEncoder().encode(MarkdownPanelState(mode: mode))
        }
        return Panel(source: source, title: url.lastPathComponent, state: state)
    }

    private func resolveFileSource(_ url: URL) -> String {
        if url.pathExtension.lowercased() == "mmd" {
            return "mermaid://\(workspaceRelativePath(for: url))"
        }
        return url.absoluteString
    }

    private func workspaceRelativePath(for url: URL) -> String {
        guard let root = workspace?.root else { return url.path }
        if url.path.hasPrefix(root.path) {
            var rel = String(url.path.dropFirst(root.path.count))
            if !rel.hasPrefix("/") { rel = "/" + rel }
            return rel
        }
        return url.path
    }

    private func isFolder(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private func seedPanelState(from tree: LayoutTree) {
        for id in tree.panelIDs {
            InitialStateHolder.shared.write(id, tree.panel(id)?.state)
        }
    }

    func panelContext() -> PanelContext {
        PanelContext(
            workspaceRoot: workspace?.root,
            keychain: keychain,
            notifications: notifications,
            savePanelState: { [weak self] id, data in
                self?.layout.updateState(for: id, state: data)
            }
        )
    }
}
