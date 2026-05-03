import AppKit
import Foundation

/// Wiki-link click handler. Detects `[[Note Name]]` patterns at a click
/// location in an `NSTextView`'s string and routes to AppServices to open
/// the resolved file. The text view's existing find-bar / selection / drag
/// behaviour is unaffected; we only react to a one-shot "should-open" event
/// driven by `mouseDown` interception.
enum WikilinkPlumbing {
    /// Returns the wiki-link target under the given character index, or nil.
    static func target(at characterIndex: Int, in source: String) -> String? {
        let ns = source as NSString
        guard characterIndex >= 0, characterIndex < ns.length else { return nil }
        // Walk left looking for the nearest "[[" within the same line.
        let lineRange = ns.lineRange(for: NSRange(location: characterIndex, length: 0))
        let line = ns.substring(with: lineRange) as NSString
        let inLineIndex = characterIndex - lineRange.location

        var openIndex: Int? = nil
        var i = inLineIndex
        while i > 0 {
            i -= 1
            if i + 1 < line.length, line.character(at: i) == 0x5B /* [ */ , line.character(at: i + 1) == 0x5B {
                openIndex = i + 2
                break
            }
        }
        guard let open = openIndex else { return nil }
        // Walk right from cursor for the nearest "]]" on the same line.
        var closeIndex: Int? = nil
        var j = inLineIndex
        while j + 1 < line.length {
            if line.character(at: j) == 0x5D /* ] */ , line.character(at: j + 1) == 0x5D {
                closeIndex = j
                break
            }
            j += 1
        }
        guard let close = closeIndex, close > open else { return nil }
        let inner = line.substring(with: NSRange(location: open, length: close - open))
        // Drop alias if present: `Note|alias` → `Note`
        let target = inner.split(separator: "|").first.map { String($0) } ?? inner
        let trimmed = target.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Returns the inline-link `[text](url)` whose body the click index is over,
    /// or nil. Used to make markdown links openable from Source/Split mode.
    static func inlineLink(at characterIndex: Int, in source: String) -> (text: String, url: String)? {
        let ns = source as NSString
        let lineRange = ns.lineRange(for: NSRange(location: characterIndex, length: 0))
        let line = ns.substring(with: lineRange)
        let regex = try! NSRegularExpression(pattern: "\\[([^\\[\\]\\n]*?)\\]\\(([^)\\n]+)\\)")
        let inLineIndex = characterIndex - lineRange.location
        let lineNS = line as NSString
        for match in regex.matches(in: line, range: NSRange(location: 0, length: lineNS.length)) {
            if NSLocationInRange(inLineIndex, match.range) {
                let text = lineNS.substring(with: match.range(at: 1))
                let url = lineNS.substring(with: match.range(at: 2))
                return (text, url)
            }
        }
        return nil
    }
}
