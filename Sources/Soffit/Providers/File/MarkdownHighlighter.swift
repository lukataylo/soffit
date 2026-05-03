import AppKit
import Foundation

final class MarkdownHighlighter {
    private let heading = try! NSRegularExpression(pattern: "^(#{1,6}\\s)(.*)$", options: [.anchorsMatchLines])
    private let bold = try! NSRegularExpression(pattern: "(\\*\\*)([^*]+)(\\*\\*)")
    private let italic = try! NSRegularExpression(pattern: "(?<!\\*)(\\*)([^*]+)(\\*)(?!\\*)")
    private let inlineCode = try! NSRegularExpression(pattern: "(`)([^`]+)(`)")
    private let codeFence = try! NSRegularExpression(pattern: "(```)([\\s\\S]*?)(```)")
    private let link = try! NSRegularExpression(pattern: "\\[[^\\]]+\\]\\([^)]+\\)")
    private let listMarker = try! NSRegularExpression(pattern: "^(\\s*(?:[-*+]|\\d+\\.)\\s)", options: [.anchorsMatchLines])
    private let blockquote = try! NSRegularExpression(pattern: "^(>\\s)(.*)$", options: [.anchorsMatchLines])

    /// Re-highlights the entire storage. Use on first attach and on style change.
    func apply(to storage: NSTextStorage, style: MarkdownSourceEditor.Style) {
        applyScoped(to: storage, style: style, range: NSRange(location: 0, length: storage.length))
    }

    /// Re-highlights only the paragraph(s) around the edit. Falls back to a full
    /// re-highlight if the edit straddles a code-fence boundary, since fences
    /// span paragraphs and a partial scope would mis-style content outside the edit.
    func applyIncremental(to storage: NSTextStorage,
                          style: MarkdownSourceEditor.Style,
                          editedRange: NSRange) {
        let length = storage.length
        let safe = NSRange(
            location: max(0, min(editedRange.location, length)),
            length: max(0, min(editedRange.length, length - max(0, min(editedRange.location, length))))
        )
        let scope = expandedScope(in: storage.string as NSString, around: safe, lineContext: 5)
        let s = storage.string as NSString
        if s.range(of: "```", options: [], range: scope).location != NSNotFound {
            apply(to: storage, style: style)
            return
        }
        applyScoped(to: storage, style: style, range: scope)
    }

    private func applyScoped(to storage: NSTextStorage,
                             style: MarkdownSourceEditor.Style,
                             range full: NSRange) {
        guard full.length > 0 else { return }
        storage.beginEditing()
        storage.removeAttribute(.foregroundColor, range: full)
        storage.removeAttribute(.font, range: full)
        storage.removeAttribute(.kern, range: full)

        let baseFont: NSFont
        switch style {
        case .rich, .rendered: baseFont = NSFont.systemFont(ofSize: 14)
        case .mono: baseFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        }
        storage.addAttribute(.font, value: baseFont, range: full)
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)

        let s = storage.string as NSString
        let hideSyntax = (style == .rendered)

        // Headings: # {text}
        heading.enumerateMatches(in: s as String, options: [], range: full) { match, _, _ in
            guard let m = match else { return }
            let markerRange = m.range(at: 1)
            let contentRange = m.range(at: 2)
            let level = markerRange.length - 1
            let size: CGFloat = headingSize(for: level, style: style)
            let font = NSFont.boldSystemFont(ofSize: size)
            storage.addAttribute(.font, value: font, range: contentRange)
            storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: contentRange)
            if hideSyntax {
                self.hideMarker(markerRange, on: storage)
            } else {
                storage.addAttribute(.font, value: font, range: markerRange)
                storage.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: markerRange)
            }
        }

        // Fenced code blocks — style content as mono orange, hide fences in rendered
        codeFence.enumerateMatches(in: s as String, options: [], range: full) { match, _, _ in
            guard let m = match else { return }
            let open = m.range(at: 1)
            let body = m.range(at: 2)
            let close = m.range(at: 3)
            let bodyFont = NSFont.monospacedSystemFont(ofSize: (style == .mono) ? 12.5 : 13, weight: .medium)
            storage.addAttribute(.font, value: bodyFont, range: body)
            storage.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: body)
            if hideSyntax {
                self.hideMarker(open, on: storage)
                self.hideMarker(close, on: storage)
            } else {
                storage.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: open)
                storage.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: close)
            }
        }

        // Bold **text**
        bold.enumerateMatches(in: s as String, options: [], range: full) { match, _, _ in
            guard let m = match else { return }
            let open = m.range(at: 1)
            let body = m.range(at: 2)
            let close = m.range(at: 3)
            if let base = storage.attribute(.font, at: body.location, effectiveRange: nil) as? NSFont {
                let boldFont = self.bold(font: base)
                storage.addAttribute(.font, value: boldFont, range: body)
            }
            if hideSyntax {
                self.hideMarker(open, on: storage)
                self.hideMarker(close, on: storage)
            }
        }

        // Italic *text*
        italic.enumerateMatches(in: s as String, options: [], range: full) { match, _, _ in
            guard let m = match else { return }
            let open = m.range(at: 1)
            let body = m.range(at: 2)
            let close = m.range(at: 3)
            if let base = storage.attribute(.font, at: body.location, effectiveRange: nil) as? NSFont {
                let italicFont = self.italic(font: base)
                storage.addAttribute(.font, value: italicFont, range: body)
            }
            if hideSyntax {
                self.hideMarker(open, on: storage)
                self.hideMarker(close, on: storage)
            }
        }

        // Inline code `text`
        inlineCode.enumerateMatches(in: s as String, options: [], range: full) { match, _, _ in
            guard let m = match else { return }
            let open = m.range(at: 1)
            let body = m.range(at: 2)
            let close = m.range(at: 3)
            let monoFont = NSFont.monospacedSystemFont(ofSize: (style == .mono) ? 12.5 : 13, weight: .medium)
            storage.addAttribute(.font, value: monoFont, range: body)
            storage.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: body)
            if hideSyntax {
                self.hideMarker(open, on: storage)
                self.hideMarker(close, on: storage)
            } else {
                storage.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: open)
                storage.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: close)
            }
        }

        // Links [text](url) — always keep the brackets, but color them
        link.enumerateMatches(in: s as String, options: [], range: full) { match, _, _ in
            guard let r = match?.range else { return }
            storage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: r)
        }

        // List marker
        listMarker.enumerateMatches(in: s as String, options: [], range: full) { match, _, _ in
            guard let r = match?.range(at: 1) else { return }
            if hideSyntax {
                // Keep the marker visible — bullet helps readability. Just color it.
                storage.addAttribute(.foregroundColor, value: NSColor.systemTeal, range: r)
            } else {
                storage.addAttribute(.foregroundColor, value: NSColor.systemTeal, range: r)
            }
        }

        // Blockquote > text
        blockquote.enumerateMatches(in: s as String, options: [], range: full) { match, _, _ in
            guard let m = match else { return }
            let marker = m.range(at: 1)
            let content = m.range(at: 2)
            storage.addAttribute(.foregroundColor, value: NSColor.systemGray, range: content)
            if hideSyntax {
                self.hideMarker(marker, on: storage)
            } else {
                storage.addAttribute(.foregroundColor, value: NSColor.systemGray, range: marker)
            }
        }

        storage.endEditing()
    }

    private func headingSize(for level: Int, style: MarkdownSourceEditor.Style) -> CGFloat {
        switch style {
        case .mono: return 13
        case .rich, .rendered:
            switch level {
            case 1: return 24
            case 2: return 20
            case 3: return 17
            case 4: return 15
            default: return 14
            }
        }
    }

    /// Hide syntax markers by making them invisible and very small — they still
    /// occupy text storage but don't render meaningfully.
    private func hideMarker(_ range: NSRange, on storage: NSTextStorage) {
        storage.addAttribute(.foregroundColor, value: NSColor.clear, range: range)
        storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 0.1), range: range)
    }

    private func bold(font: NSFont) -> NSFont {
        let desc = font.fontDescriptor.withSymbolicTraits(.bold)
        return NSFont(descriptor: desc, size: font.pointSize) ?? NSFont.boldSystemFont(ofSize: font.pointSize)
    }

    private func italic(font: NSFont) -> NSFont {
        let desc = font.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: desc, size: font.pointSize) ?? font
    }

    /// Expand `edit` outward by up to `lineContext` line breaks on each side.
    /// Bound to [0, length]. Used to re-highlight a paragraph-ish window around
    /// the user's typing without rescanning the whole file.
    private func expandedScope(in s: NSString, around edit: NSRange, lineContext: Int) -> NSRange {
        let length = s.length
        guard length > 0 else { return NSRange(location: 0, length: 0) }
        var start = max(0, min(edit.location, length))
        var end = max(start, min(edit.location + edit.length, length))

        for _ in 0..<lineContext {
            guard start > 0 else { break }
            let probe = NSRange(location: start - 1, length: 0)
            let lr = s.lineRange(for: probe)
            if lr.location >= start { break }
            start = lr.location
        }
        for _ in 0..<lineContext {
            guard end < length else { break }
            let lr = s.lineRange(for: NSRange(location: end, length: 0))
            let newEnd = min(length, lr.location + lr.length)
            if newEnd <= end { break }
            end = newEnd
        }
        return NSRange(location: start, length: end - start)
    }
}
