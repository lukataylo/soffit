import Combine
import Foundation

@MainActor
final class AppServices: ObservableObject {
    @Published var workspace: WorkspaceStore?
    @Published var layout: LayoutStore
    @Published var needsAPIKey: Bool = false
    @Published var needsWorkspace: Bool = false

    let registry: ProviderRegistry
    let keychain: KeychainStore
    let persistence: LayoutPersistence
    let notifications = PanelNotificationBus()

    private var cancellables: Set<AnyCancellable> = []

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
    }

    func openWorkspace(at url: URL) {
        let store = WorkspaceStore(root: url)
        workspace = store
        needsWorkspace = false
        if layout.tree.isEmpty {
            let panel = Panel(source: FolderURL.makeSource(for: url), title: url.lastPathComponent)
            layout.addTab(panel)
        }
    }

    func saveAPIKey(_ key: String) {
        keychain.apiKey = key
        needsAPIKey = false
    }

    // MARK: - File opening routes everything through the focused pane

    func openFile(_ url: URL, mode: MarkdownPanelMode = .preview) {
        let panel = makeFilePanel(url: url, mode: mode)
        layout.addTab(panel)
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
