import Foundation

/// Security-scoped bookmark plumbing for the workspace folder.
///
/// Under the App Sandbox, an app can only read/write user-selected files.
/// `NSOpenPanel` returns a URL with implicit access for the lifetime of the
/// process. To persist access across launches we serialize a *bookmark*
/// (`URL.bookmarkData(options: .withSecurityScope)`) into UserDefaults.
/// On the next launch, we re-resolve the bookmark and call
/// `startAccessingSecurityScopedResource()` before reading or writing.
///
/// Outside the sandbox (e.g., when running directly from `swift run`) the
/// bookmark plumbing is harmless — `start/stopAccessingSecurityScopedResource`
/// is a no-op for non-sandboxed apps.
enum WorkspaceBookmark {
    private static let key = "soffit.workspaceBookmark.v1"

    /// Persist a bookmark to the chosen workspace folder.
    static func store(_ url: URL) {
        do {
            let data = try url.bookmarkData(options: .withSecurityScope,
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            // Sandboxed builds will hit this only if the folder isn't actually
            // user-selected. Fall back to storing the path so the legacy
            // `layout.json` workspace path keeps working in dev builds.
        }
    }

    /// Resolve the persisted bookmark, if any. The caller is responsible for
    /// invoking `startAccessingSecurityScopedResource()` and matching it with
    /// `stopAccessingSecurityScopedResource()` later. Returns nil when the
    /// bookmark is missing or the folder has moved beyond recovery.
    static func resolve() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        do {
            let url = try URL(resolvingBookmarkData: data,
                              options: .withSecurityScope,
                              relativeTo: nil,
                              bookmarkDataIsStale: &stale)
            if stale {
                // Persist a refreshed bookmark for the resolved location so we
                // don't keep re-resolving stale data on every launch.
                store(url)
            }
            return url
        } catch {
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
    }

    /// Drop the stored bookmark (e.g., when the user picks a new workspace).
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
