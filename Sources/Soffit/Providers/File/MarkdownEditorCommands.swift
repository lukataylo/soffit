import AppKit
import Combine
import Foundation

@MainActor
final class MarkdownEditorCommands: ObservableObject {
    weak var textView: NSTextView?

    func wrap(prefix: String, suffix: String, placeholder: String = "") {
        guard let tv = textView else { return }
        let range = tv.selectedRange()
        let fullText = tv.string as NSString
        let selected = range.length > 0 ? fullText.substring(with: range) : placeholder
        let replacement = prefix + selected + suffix
        tv.insertText(replacement, replacementRange: range)
        if range.length == 0 {
            let caret = range.location + (prefix as NSString).length
            tv.setSelectedRange(NSRange(location: caret, length: (placeholder as NSString).length))
        } else {
            let newEnd = range.location + (replacement as NSString).length
            tv.setSelectedRange(NSRange(location: newEnd, length: 0))
        }
    }

    func prefixLines(_ prefix: String) {
        guard let tv = textView else { return }
        let fullText = tv.string as NSString
        let range = tv.selectedRange()
        let lineRange = fullText.lineRange(for: range)
        let line = fullText.substring(with: lineRange)
        let hasTrailingNewline = line.hasSuffix("\n")
        var lines = line.components(separatedBy: "\n")
        if hasTrailingNewline { lines.removeLast() }
        let prefixed = lines.map { prefix + $0 }.joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")
        tv.insertText(prefixed, replacementRange: lineRange)
    }

    func insert(_ text: String) {
        guard let tv = textView else { return }
        tv.insertText(text, replacementRange: tv.selectedRange())
    }

    /// Scroll the editor to the given line (0-indexed) and place the caret there.
    func scrollTo(line: Int) {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let s = storage.string as NSString
        var charIndex = 0
        var current = 0
        while current < line, charIndex < s.length {
            let range = s.lineRange(for: NSRange(location: charIndex, length: 0))
            charIndex = range.location + range.length
            current += 1
        }
        let target = NSRange(location: min(charIndex, s.length), length: 0)
        tv.setSelectedRange(target)
        tv.scrollRangeToVisible(target)
        tv.window?.makeFirstResponder(tv)
    }

    func insertTable(rows: Int, cols: Int) {
        guard rows > 0, cols > 0 else { return }
        let header = "| " + Array(1...cols).map { "Col \($0)" }.joined(separator: " | ") + " |"
        let sep = "|" + String(repeating: "------|", count: cols)
        var body: [String] = []
        for _ in 0..<rows {
            let row = "| " + Array(repeating: "   ", count: cols).joined(separator: " | ") + " |"
            body.append(row)
        }
        let table = "\n" + ([header, sep] + body).joined(separator: "\n") + "\n"
        insert(table)
    }
}
