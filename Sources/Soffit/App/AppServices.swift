import Combine
import Foundation

/// App-wide singleton services. Per-window state (layout, search palette,
/// find/replace) lives in `WindowSession` instead so multiple windows don't
/// step on each other's panes.
@MainActor
final class AppServices: ObservableObject {
    @Published var workspace: WorkspaceStore?
    @Published var needsAPIKey: Bool = false
    @Published var needsWorkspace: Bool = false

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

    init() {
        let keychain = KeychainStore(service: "com.soffit.app")
        let registry = ProviderRegistry()
        self.keychain = keychain
        self.registry = registry
        self.persistence = LayoutPersistence()

        registry.register(FileProvider())
        let web = WebProvider()
        registry.register(web)
        registry.register(web, forScheme: "http")
        registry.register(web, forScheme: "https")
        registry.register(MermaidProvider())
        registry.register(FolderProvider())
        registry.register(ChatProvider(keychain: keychain))
        registry.register(SketchProvider())
        #if SOFFIT_PRO
        registry.register(TerminalProvider())
        #endif

        // Eagerly resolve the workspace. Under the App Sandbox we use a
        // security-scoped bookmark; outside the sandbox we fall back to the
        // legacy path stored in layout.json. Either way, this must run before
        // WindowSession.bind() (called from RootView.onAppear) so the bind
        // restores against a live workspace.
        if let bookmarked = WorkspaceBookmark.resolve() {
            _ = bookmarked.startAccessingSecurityScopedResource()
            openWorkspace(at: bookmarked)
        } else if let snapshot = persistence.load(),
                  !snapshot.workspaceRoot.isEmpty,
                  FileManager.default.fileExists(atPath: snapshot.workspaceRoot) {
            openWorkspace(at: URL(fileURLWithPath: snapshot.workspaceRoot))
        } else {
            needsWorkspace = true
        }
    }

    // Note: we deliberately don't pair startAccessingSecurityScopedResource
    // with stopAccessingSecurityScopedResource — AppServices lives for the
    // app's lifetime, so the OS reclaims the access when the process exits.

    /// Kept as a no-op for SoffitApp's onAppear (call site preserved). All
    /// real startup work happens in init now.
    func start() {}

    func openWorkspace(at url: URL) {
        // Persist a sandbox-friendly bookmark for cross-launch access.
        WorkspaceBookmark.store(url)
        let store = WorkspaceStore(root: url)
        workspace = store
        needsWorkspace = false
        Task { await index.open(root: url) }
        git.bind(to: url)
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

    func promptForAPIKey() {
        needsAPIKey = true
    }
}
