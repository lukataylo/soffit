import Foundation

/// Lightweight markdown parser for indexing. Doesn't try to render — just
/// extracts structural metadata: frontmatter, headings, wiki-links, tags,
/// inline links, word count.
enum MarkdownParser {
    struct Parsed {
        var frontmatter: [String: String]
        var headings: [Heading]
        var wikilinks: [String]   // raw target name as written between [[…]]
        var tags: [String]        // bare tag, no leading '#'
        var inlineLinks: [InlineLink]
        var bodyWordCount: Int
    }

    struct Heading: Hashable {
        let text: String
        let level: Int      // 1...6
        let lineOffset: Int // line number in the source (0-indexed)
        let charOffset: Int // utf16 character offset in the source
    }

    struct InlineLink: Hashable {
        let text: String
        let url: String
    }

    /// Parses one markdown document. Cheap enough to run on every save and
    /// every full re-index of the workspace; ~10ms for a 1000-line PRD.
    static func parse(_ source: String) -> Parsed {
        var frontmatter: [String: String] = [:]
        var headings: [Heading] = []
        var wikilinks: [String] = []
        var tags: [String] = []
        var inlineLinks: [InlineLink] = []

        let (frontmatterRange, bodyStart) = scanFrontmatter(source)
        if let frange = frontmatterRange {
            frontmatter = parseFrontmatter(String(source[frange]))
        }

        let body = bodyStart < source.endIndex ? String(source[bodyStart...]) : ""

        // Heading scan — track line + char offset in the body.
        var lineIndex = 0
        var charIndex = (bodyStart.utf16Offset(in: source))
        body.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix(while: { $0 == "#" })
                let level = hashes.count
                if level <= 6, trimmed.dropFirst(level).first == " " {
                    let text = trimmed.dropFirst(level)
                        .trimmingCharacters(in: .whitespaces)
                    headings.append(Heading(text: text,
                                            level: level,
                                            lineOffset: lineIndex,
                                            charOffset: charIndex))
                }
            }
            lineIndex += 1
            charIndex += (line as NSString).length + 1   // +1 for the newline
        }

        // Wiki-links: [[Note]] or [[Note|alias]] — alias is ignored for the index.
        let wikiRegex = try! NSRegularExpression(pattern: "\\[\\[([^\\[\\]\\n|]+)(?:\\|[^\\[\\]\\n]+)?\\]\\]")
        let bodyNS = body as NSString
        wikiRegex.enumerateMatches(in: body, range: NSRange(location: 0, length: bodyNS.length)) { match, _, _ in
            guard let m = match, m.numberOfRanges > 1 else { return }
            let target = bodyNS.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
            if !target.isEmpty { wikilinks.append(target) }
        }

        // Inline tags: #word — but skip URL fragments like https://x#y and code fences.
        let tagRegex = try! NSRegularExpression(pattern: "(?<![\\w/&])#([\\p{L}\\p{N}_/-]+)")
        // Strip code fences first so we don't pick up #include etc.
        let bodyWithoutFences = stripCodeFences(body)
        let stripped = bodyWithoutFences as NSString
        tagRegex.enumerateMatches(in: bodyWithoutFences, range: NSRange(location: 0, length: stripped.length)) { match, _, _ in
            guard let m = match, m.numberOfRanges > 1 else { return }
            let tag = stripped.substring(with: m.range(at: 1))
            tags.append(tag)
        }

        // Frontmatter `tags:` field also contributes tags.
        if let fmTags = frontmatter["tags"] {
            for t in splitFrontmatterList(fmTags) where !t.isEmpty {
                tags.append(t.trimmingCharacters(in: CharacterSet(charactersIn: "\"' ")))
            }
        }

        // Inline links: [text](url) — the url is what we care about for
        // in-app navigation.
        let linkRegex = try! NSRegularExpression(pattern: "\\[([^\\[\\]\\n]*?)\\]\\(([^)\\n]+)\\)")
        linkRegex.enumerateMatches(in: body, range: NSRange(location: 0, length: bodyNS.length)) { match, _, _ in
            guard let m = match, m.numberOfRanges > 2 else { return }
            let text = bodyNS.substring(with: m.range(at: 1))
            let url = bodyNS.substring(with: m.range(at: 2))
            inlineLinks.append(InlineLink(text: text, url: url))
        }

        let words = body
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count

        return Parsed(frontmatter: frontmatter,
                      headings: headings,
                      wikilinks: Array(Set(wikilinks)),
                      tags: Array(Set(tags)),
                      inlineLinks: inlineLinks,
                      bodyWordCount: words)
    }

    // MARK: - Helpers

    /// Returns (frontmatterContentRange, indexAfterFrontmatter).
    private static func scanFrontmatter(_ source: String) -> (Range<String.Index>?, String.Index) {
        guard source.hasPrefix("---\n") || source.hasPrefix("---\r\n") else {
            return (nil, source.startIndex)
        }
        let afterOpen = source.index(source.startIndex, offsetBy: source.hasPrefix("---\r\n") ? 5 : 4)
        // Find the closing --- on its own line.
        var search = afterOpen
        while search < source.endIndex {
            let lineStart = search
            let lineEnd = source[lineStart...].firstIndex(of: "\n") ?? source.endIndex
            let line = source[lineStart..<lineEnd]
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                let bodyStart = lineEnd < source.endIndex ? source.index(after: lineEnd) : source.endIndex
                return (afterOpen..<lineStart, bodyStart)
            }
            search = lineEnd < source.endIndex ? source.index(after: lineEnd) : source.endIndex
        }
        return (nil, source.startIndex)
    }

    private static func parseFrontmatter(_ block: String) -> [String: String] {
        var out: [String: String] = [:]
        for rawLine in block.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if !key.isEmpty { out[key] = value }
        }
        return out
    }

    private static func splitFrontmatterList(_ raw: String) -> [String] {
        // Supports either YAML flow (`[a, b, c]`) or comma-separated.
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let inner: String
        if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
            inner = String(trimmed.dropFirst().dropLast())
        } else {
            inner = trimmed
        }
        return inner
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"' ")) }
    }

    private static func stripCodeFences(_ source: String) -> String {
        // Replace fenced code-block content (and inline `code`) with spaces of
        // the same length so we don't pick up hashes inside code.
        var out = ""
        out.reserveCapacity(source.count)
        var inFence = false
        var inInline = false
        var i = source.startIndex
        while i < source.endIndex {
            let c = source[i]
            // Detect ```
            if c == "`" {
                let three = source.index(i, offsetBy: 3, limitedBy: source.endIndex)
                if let three, source[i..<three] == "```" {
                    inFence.toggle()
                    out.append("   ")   // preserve length
                    i = three
                    continue
                }
                inInline.toggle()
                out.append("`")
                i = source.index(after: i)
                continue
            }
            if inFence || inInline {
                out.append(c == "\n" ? "\n" : " ")
            } else {
                out.append(c)
            }
            i = source.index(after: i)
        }
        return out
    }
}
