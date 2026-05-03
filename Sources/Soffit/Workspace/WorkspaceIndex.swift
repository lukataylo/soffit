import Combine
import Foundation

/// In-memory index of every markdown file in the workspace. Built async on
/// open + maintained on FSEvents. Powers global search, the quick-switcher,
/// wikilinks/backlinks, tag browsing, and the outline.
@MainActor
final class WorkspaceIndex: ObservableObject {
    @Published private(set) var files: [URL: IndexedFile] = [:]
    @Published private(set) var allTags: [String: Int] = [:]
    @Published private(set) var isIndexing: Bool = false

    private var root: URL?
    private var fileManager: FileManager { .default }

    struct IndexedFile {
        let url: URL
        let title: String           // first H1 if present, else file stem
        let frontmatter: [String: String]
        let headings: [MarkdownParser.Heading]
        let wikilinks: [String]
        let tags: [String]
        let inlineLinks: [MarkdownParser.InlineLink]
        let wordCount: Int
        let modified: Date
        let lowercaseContent: String   // for full-text grep
    }

    // MARK: - Lifecycle

    func open(root: URL) async {
        self.root = root
        files.removeAll()
        allTags.removeAll()
        await refreshAll()
    }

    func refreshAll() async {
        guard let root else { return }
        isIndexing = true
        let urls = await Self.collectMarkdown(at: root)
        var built: [URL: IndexedFile] = [:]
        var tagCounts: [String: Int] = [:]
        for url in urls {
            if let entry = await Self.indexOne(url: url) {
                built[url] = entry
                for t in entry.tags { tagCounts[t, default: 0] += 1 }
            }
        }
        files = built
        allTags = tagCounts
        isIndexing = false
    }

    /// Re-index a single file. Cheaper than a full refresh when FSEvents fires
    /// for a known url.
    func touch(_ url: URL) async {
        guard isMarkdown(url) else { return }
        if let updated = await Self.indexOne(url: url) {
            // Tag-count maintenance: subtract old, add new.
            if let old = files[url] {
                for t in old.tags { allTags[t] = (allTags[t] ?? 1) - 1; if allTags[t] == 0 { allTags.removeValue(forKey: t) } }
            }
            for t in updated.tags { allTags[t, default: 0] += 1 }
            files[url] = updated
        } else {
            // File disappeared.
            if let old = files.removeValue(forKey: url) {
                for t in old.tags { allTags[t] = (allTags[t] ?? 1) - 1; if allTags[t] == 0 { allTags.removeValue(forKey: t) } }
            }
        }
    }

    // MARK: - Queries

    struct SearchHit: Identifiable, Hashable {
        let id = UUID()
        let url: URL
        let title: String
        let snippet: String
        let matchedHeading: String?
        let score: Double
        static func == (lhs: SearchHit, rhs: SearchHit) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    /// Fuzzy-match by file name, title, and headings. Cheap, ranks by overlap.
    func searchByName(_ query: String, limit: Int = 50) -> [SearchHit] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            // No query: return MRU by modification date.
            return files.values
                .sorted { $0.modified > $1.modified }
                .prefix(limit)
                .map { SearchHit(url: $0.url, title: $0.title, snippet: $0.url.lastPathComponent, matchedHeading: nil, score: 0) }
        }
        var hits: [SearchHit] = []
        for entry in files.values {
            let name = entry.url.lastPathComponent.lowercased()
            let title = entry.title.lowercased()
            let nameMatch = fuzzyScore(q, in: name)
            let titleMatch = fuzzyScore(q, in: title)
            var headingHit: String? = nil
            var headingScore = 0.0
            for h in entry.headings {
                let s = fuzzyScore(q, in: h.text.lowercased())
                if s > headingScore {
                    headingScore = s
                    headingHit = h.text
                }
            }
            let score = max(nameMatch, titleMatch * 0.95, headingScore * 0.7)
            if score > 0 {
                hits.append(SearchHit(url: entry.url,
                                      title: entry.title,
                                      snippet: entry.url.lastPathComponent,
                                      matchedHeading: headingHit,
                                      score: score))
            }
        }
        return hits.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
    }

    /// Full-text search across the indexed content. Returns one hit per file
    /// with a snippet of the first matching line.
    func searchByContent(_ query: String, limit: Int = 200) -> [SearchHit] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        var hits: [SearchHit] = []
        for entry in files.values {
            guard let range = entry.lowercaseContent.range(of: q) else { continue }
            // Build a snippet — surrounding ~80 chars, single-line.
            let lineStart = entry.lowercaseContent[..<range.lowerBound].lastIndex(of: "\n")
                .map { entry.lowercaseContent.index(after: $0) } ?? entry.lowercaseContent.startIndex
            let lineEnd = entry.lowercaseContent[range.upperBound...].firstIndex(of: "\n") ?? entry.lowercaseContent.endIndex
            let lineRange = lineStart..<lineEnd
            let snippet = String(entry.lowercaseContent[lineRange])
                .trimmingCharacters(in: .whitespaces)
            let score = 1.0 - Double(entry.lowercaseContent.distance(from: entry.lowercaseContent.startIndex, to: range.lowerBound)) / Double(max(1, entry.lowercaseContent.count))
            hits.append(SearchHit(url: entry.url,
                                  title: entry.title,
                                  snippet: snippet,
                                  matchedHeading: nil,
                                  score: score))
        }
        return hits.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
    }

    /// Files that link to `target` via [[wiki-link]]. The target is matched
    /// case-insensitively against (a) the file stem and (b) any explicit
    /// frontmatter `aliases`.
    func backlinksTo(_ url: URL) -> [IndexedFile] {
        let stem = url.deletingPathExtension().lastPathComponent.lowercased()
        return files.values.filter { entry in
            guard entry.url != url else { return false }
            return entry.wikilinks.contains { link in
                link.lowercased() == stem
            }
        }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Files matching a tag (with or without leading '#').
    func filesWithTag(_ tag: String) -> [IndexedFile] {
        let bare = tag.hasPrefix("#") ? String(tag.dropFirst()) : tag
        return files.values
            .filter { $0.tags.contains(bare) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Resolve a wiki-link target to a file URL, if possible.
    func resolve(wikilink: String) -> URL? {
        let target = wikilink.lowercased()
        return files.keys.first { url in
            url.deletingPathExtension().lastPathComponent.lowercased() == target
        }
    }

    /// All known wiki-link targets (for autocomplete) — unique stems sorted.
    var allKnownStems: [String] {
        let stems = Set(files.keys.map { $0.deletingPathExtension().lastPathComponent })
        return stems.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    // MARK: - Index a single file (off main)

    private nonisolated static func indexOne(url: URL) async -> IndexedFile? {
        guard let data = try? Data(contentsOf: url),
              let source = String(data: data, encoding: .utf8) else { return nil }
        let parsed = MarkdownParser.parse(source)
        let modified = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? .distantPast
        let firstH1 = parsed.headings.first(where: { $0.level == 1 })?.text
        let title = firstH1 ?? url.deletingPathExtension().lastPathComponent
        return IndexedFile(url: url,
                           title: title,
                           frontmatter: parsed.frontmatter,
                           headings: parsed.headings,
                           wikilinks: parsed.wikilinks,
                           tags: parsed.tags,
                           inlineLinks: parsed.inlineLinks,
                           wordCount: parsed.bodyWordCount,
                           modified: modified,
                           lowercaseContent: source.lowercased())
    }

    private nonisolated static func collectMarkdown(at root: URL) async -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root,
                                             includingPropertiesForKeys: [.isRegularFileKey],
                                             options: [.skipsHiddenFiles]) else {
            return []
        }
        var out: [URL] = []
        for case let url as URL in enumerator {
            // Skip common ignore dirs.
            let path = url.path
            if path.contains("/.git/") || path.contains("/.build/") || path.contains("/node_modules/") {
                enumerator.skipDescendants()
                continue
            }
            let ext = url.pathExtension.lowercased()
            if ["md", "markdown", "mdx"].contains(ext) {
                out.append(url)
            }
        }
        return out
    }

    private func isMarkdown(_ url: URL) -> Bool {
        ["md", "markdown", "mdx"].contains(url.pathExtension.lowercased())
    }

    /// Char-by-char fuzzy: returns 0..1 where 1 is perfect prefix match.
    private func fuzzyScore(_ query: String, in target: String) -> Double {
        guard !query.isEmpty, !target.isEmpty else { return 0 }
        if target == query { return 1 }
        if target.hasPrefix(query) { return 0.95 }
        if target.contains(query) { return 0.85 }
        // Subsequence match: every char in q appears in order in target.
        var ti = target.startIndex
        for c in query {
            guard let next = target[ti...].firstIndex(of: c) else { return 0 }
            ti = target.index(after: next)
        }
        return 0.5 - Double(target.count) / 10000
    }
}
