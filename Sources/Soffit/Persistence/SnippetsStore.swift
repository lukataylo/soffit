import Combine
import Foundation

/// User-defined text snippets. Stored at `~/.soffit/snippets.json` so the user
/// can edit them in any editor; reloaded automatically when the file changes.
///
/// Default snippets:
///   ,date  → today's date YYYY-MM-DD
///   ,time  → HH:MM
///   ,now   → ISO-8601 timestamp
///   ,today → wiki-link to today's daily note
///
/// Triggered by typing the trigger followed by space or newline. The editor
/// rewinds the trigger and inserts the expansion.
@MainActor
final class SnippetsStore: ObservableObject {
    @Published private(set) var snippets: [String: String] = [:]
    private var fileWatcher: FSEventsWatcher?

    init() {
        load()
        watch()
    }

    static var configURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".soffit/snippets.json")
    }

    /// Resolve a trigger to its expansion. Substitutes `{{date}}` etc. patterns
    /// at expansion time so the user can write `# {{long_date}}` style.
    func expand(_ trigger: String) -> String? {
        guard let raw = snippets[trigger] ?? Self.builtinDefaults[trigger] else { return nil }
        return interpolate(raw)
    }

    private func interpolate(_ s: String) -> String {
        var out = s
        let now = Date()
        let isoFmt = DateFormatter()
        isoFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let isoStamp = ISO8601DateFormatter().string(from: now)
        let longFmt = DateFormatter()
        longFmt.dateStyle = .full
        longFmt.timeStyle = .none
        out = out.replacingOccurrences(of: "{{date}}", with: isoFmt.string(from: now))
        out = out.replacingOccurrences(of: "{{time}}", with: timeFmt.string(from: now))
        out = out.replacingOccurrences(of: "{{now}}",  with: isoStamp)
        out = out.replacingOccurrences(of: "{{long_date}}", with: longFmt.string(from: now))
        return out
    }

    private static let builtinDefaults: [String: String] = [
        ",date":  "{{date}}",
        ",time":  "{{time}}",
        ",now":   "{{now}}",
        ",today": "[[{{date}}]]"
    ]

    private func load() {
        let url = Self.configURL
        guard let data = try? Data(contentsOf: url),
              let parsed = try? JSONDecoder().decode([String: String].self, from: data) else {
            // No user file: leave defaults to be returned via expand().
            snippets = [:]
            return
        }
        snippets = parsed
    }

    private func watch() {
        let url = Self.configURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        fileWatcher = FSEventsWatcher(path: url.deletingLastPathComponent().path) { [weak self] in
            Task { @MainActor in self?.load() }
        }
    }
}
