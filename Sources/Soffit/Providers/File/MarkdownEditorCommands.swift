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
