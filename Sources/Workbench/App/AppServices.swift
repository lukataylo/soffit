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
        let keychain = KeychainStore(service: "com.workbench.app")
        let registry = ProviderRegistry()
        self.keychain = keychain
        self.registry = registry
        self.persistence = LayoutPersistence()
        self.layout = LayoutStore(tree: .empty)

        registry.register(FileProvider())
        registry.register(WebProvider())
        registry.register(MermaidProvider())
        registry.register(FolderProvider())
        registry.register(ChatProvider(keychain: keychain))
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

        if keychain.apiKey == nil {
            needsAPIKey = true
        }

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
            layout.insert(panel: panel)
        }
    }

    func saveAPIKey(_ key: String) {
        keychain.apiKey = key
        needsAPIKey = false
    }

    func openFile(_ url: URL, from parentPanel: PanelID? = nil, mode: MarkdownPanelMode = .preview) {
        let source = resolveFileSource(url)
        var state: Data? = nil
        let ext = url.pathExtension.lowercased()
        if ["md", "markdown", "mdx"].contains(ext) {
            state = try? JSONEncoder().encode(MarkdownPanelState(mode: mode))
        }
        let panel = Panel(source: source, title: url.lastPathComponent, state: state)
        if let parent = parentPanel, layout.tree.contains(parent) {
            layout.split(target: parent, direction: .horizontal, newPanel: panel, side: .second)
        } else {
            layout.insert(panel: panel)
        }
    }

    func openFolderPanel(_ url: URL, from parentPanel: PanelID? = nil) {
        let panel = Panel(source: FolderURL.makeSource(for: url), title: url.lastPathComponent)
        if let parent = parentPanel, layout.tree.contains(parent) {
            layout.split(target: parent, direction: .horizontal, newPanel: panel, side: .second)
        } else {
            layout.insert(panel: panel)
        }
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
