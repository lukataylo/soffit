import AppKit
import Foundation

final class MarkdownHighlighter {
    private let heading = try! NSRegularExpression(pattern: "^(#{1,6})\\s.*$", options: [.anchorsMatchLines])
    private let bold = try! NSRegularExpression(pattern: "\\*\\*[^*]+\\*\\*")
    private let italic = try! NSRegularExpression(pattern: "(?<!\\*)\\*[^*]+\\*(?!\\*)")
    private let code = try! NSRegularExpression(pattern: "`[^`]+`")
    private let codeFence = try! NSRegularExpression(pattern: "```[\\s\\S]*?```")
    private let link = try! NSRegularExpression(pattern: "\\[[^\\]]+\\]\\([^)]+\\)")
    private let listMarker = try! NSRegularExpression(pattern: "^\\s*([-*+]|\\d+\\.)\\s", options: [.anchorsMatchLines])
    private let blockquote = try! NSRegularExpression(pattern: "^>\\s.*$", options: [.anchorsMatchLines])

    func apply(to storage: NSTextStorage) {
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.removeAttribute(.foregroundColor, range: full)
        storage.removeAttribute(.font, range: full)
        let base = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        storage.addAttribute(.font, value: base, range: full)
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)

        let s = storage.string as NSString

        color(heading, in: s, range: full, on: storage, color: .systemPurple, bold: true)
        color(bold, in: s, range: full, on: storage, color: .labelColor, bold: true)
        color(italic, in: s, range: full, on: storage, color: NSColor.labelColor.withAlphaComponent(0.85), italic: true)
        color(codeFence, in: s, range: full, on: storage, color: .systemOrange, mono: true)
        color(code, in: s, range: full, on: storage, color: .systemOrange, mono: true)
        color(link, in: s, range: full, on: storage, color: .systemBlue)
        color(listMarker, in: s, range: full, on: storage, color: .systemTeal)
        color(blockquote, in: s, range: full, on: storage, color: .systemGray)

        storage.endEditing()
    }

    private func color(_ regex: NSRegularExpression, in s: NSString, range: NSRange,
                       on storage: NSTextStorage, color: NSColor,
                       bold: Bool = false, italic: Bool = false, mono: Bool = false) {
        regex.enumerateMatches(in: s as String, options: [], range: range) { match, _, _ in
            guard let r = match?.range else { return }
            storage.addAttribute(.foregroundColor, value: color, range: r)
            if bold {
                let f = NSFont.boldSystemFont(ofSize: 13)
                storage.addAttribute(.font, value: f, range: r)
            } else if italic {
                let base = NSFont.systemFont(ofSize: 13)
                if let desc = base.fontDescriptor.withSymbolicTraits(.italic) as NSFontDescriptor?,
                   let f = NSFont(descriptor: desc, size: 13) {
                    storage.addAttribute(.font, value: f, range: r)
                }
            } else if mono {
                storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .medium), range: r)
            }
        }
    }
}
