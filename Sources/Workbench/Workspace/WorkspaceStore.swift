import Combine
import Foundation

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published private(set) var root: URL
    @Published private(set) var entries: [FSEntry] = []

    private var watcher: FSEventsWatcher?

    init(root: URL) {
        self.root = root
        refresh()
        watcher = FSEventsWatcher(path: root.path) { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        entries = Self.readDirectory(root)
    }

    static func readDirectory(_ url: URL) -> [FSEntry] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
        guard let items = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return []
        }
        return items.map { entryURL -> FSEntry in
            let isDir = (try? entryURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return FSEntry(url: entryURL, isDirectory: isDir)
        }
        .sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
            return a.url.lastPathComponent.localizedCaseInsensitiveCompare(b.url.lastPathComponent) == .orderedAscending
        }
    }
}

struct FSEntry: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    var id: URL { url }
    var name: String { url.lastPathComponent }
}
