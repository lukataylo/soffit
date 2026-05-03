import Foundation

/// Helpers for handling iCloud Drive files. Files synced via iCloud Drive
/// can be in three states from the local filesystem's perspective:
///
/// - **Materialised** — the data is on disk; treat as a normal file.
/// - **Placeholder** — only metadata is on disk; the data has been evicted
///   to the cloud. `URLResourceKey.ubiquitousItemDownloadingStatusKey`
///   reports `.notDownloaded`. Calling `Data(contentsOf:)` on a placeholder
///   will *not* trigger a download in some macOS versions and may return
///   stale or empty data.
/// - **Downloading** — currently being fetched. Reads should wait or fail
///   gracefully.
///
/// `CloudFile.materialise(_:)` triggers a download if needed and waits up
/// to a few seconds for it to complete.
enum CloudFile {

    enum Status {
        case notInCloud         // ordinary local file
        case current            // in iCloud, fully downloaded
        case downloading        // download in progress
        case notDownloaded      // placeholder only — needs download
    }

    /// Inspect the iCloud download status for a URL. Returns `.notInCloud`
    /// if the file isn't part of an iCloud container.
    static func status(of url: URL) -> Status {
        let keys: [URLResourceKey] = [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey
        ]
        guard let values = try? url.resourceValues(forKeys: Set(keys)),
              values.isUbiquitousItem == true else {
            return .notInCloud
        }
        guard let status = values.ubiquitousItemDownloadingStatus else { return .current }
        switch status {
        case .current:        return .current
        case .downloaded:     return .current
        case .notDownloaded:  return .notDownloaded
        default:              return .downloading
        }
    }

    /// If the file is a placeholder, request a download and wait up to
    /// `timeout` seconds for it. Returns true on success or if no download
    /// was needed; false on timeout.
    @discardableResult
    static func materialise(_ url: URL, timeout: TimeInterval = 8) async -> Bool {
        switch status(of: url) {
        case .notInCloud, .current: return true
        case .notDownloaded, .downloading:
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            switch status(of: url) {
            case .notInCloud, .current: return true
            default: try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        return status(of: url) == .current
    }

    /// Filter file URLs that are at least *materialised enough to read*.
    /// Used by `WorkspaceIndex` to skip placeholders during the initial walk —
    /// they'd otherwise yield empty content and pollute the index.
    static func isReadable(_ url: URL) -> Bool {
        switch status(of: url) {
        case .notInCloud, .current: return true
        default: return false
        }
    }
}
