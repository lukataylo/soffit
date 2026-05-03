import Combine
import Foundation

/// Tracks the last N files the user opened. Persisted as a flat list of paths in
/// UserDefaults — small, append/dedup is O(N), no separate file to manage.
@MainActor
final class RecentFilesStore: ObservableObject {
    @Published private(set) var entries: [URL] = []

    private let key = "soffit.recentFiles.v1"
    private let limit = 20

    init() { load() }

    func record(_ url: URL) {
        // De-dupe and move-to-front so the most recently used wins.
        let resolved = url.standardizedFileURL
        var next = entries.filter { $0.standardizedFileURL != resolved }
        next.insert(resolved, at: 0)
        if next.count > limit { next.removeLast(next.count - limit) }
        entries = next
        save()
    }

    func clear() {
        entries = []
        save()
    }

    /// Drop entries that no longer exist on disk. Cheap to run on demand
    /// (when the user expands the Recent section).
    func prune() {
        let fm = FileManager.default
        let live = entries.filter { fm.fileExists(atPath: $0.path) }
        if live.count != entries.count {
            entries = live
            save()
        }
    }

    private func load() {
        guard let paths = UserDefaults.standard.array(forKey: key) as? [String] else { return }
        entries = paths.map { URL(fileURLWithPath: $0) }
    }

    private func save() {
        let paths = entries.map { $0.path }
        UserDefaults.standard.set(paths, forKey: key)
    }
}
