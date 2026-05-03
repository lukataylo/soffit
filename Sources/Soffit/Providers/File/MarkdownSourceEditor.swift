import AppKit
import SwiftUI

struct MarkdownSourceEditor: NSViewRepresentable {
    @Binding var text: String
    let commands: MarkdownEditorCommands
    let style: Style

    enum Style {
        case rendered   // WYSIWYG-ish: syntax markers hidden, styled text visible
        case rich       // Variable-font with syntax visible but styled (rich preview)
        case mono       // Monospace, raw markdown
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, style: style) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let textView = scroll.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.textStorage?.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 20, height: 18)
        textView.backgroundColor = .textBackgroundColor
        textView.usesFindBar = true
        applyBaseFont(to: textView)
        textView.string = text
        context.coordinator.textView = textView
        context.coordinator.applyFullHighlighting(to: textView.textStorage)
        DispatchQueue.main.async { commands.textView = textView }
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if commands.textView !== textView {
            commands.textView = textView
        }
        if context.coordinator.style != style {
            context.coordinator.style = style
            applyBaseFont(to: textView)
            context.coordinator.applyFullHighlighting(to: textView.textStorage)
        }
        if textView.string != text {
            let selected = textView.selectedRange()
            textView.string = text
            // Selection may now be out of bounds if `text` shrank (e.g., external
            // edit, restored from disk). Clamp before re-applying.
            let length = (text as NSString).length
            let loc = min(selected.location, length)
            let len = min(selected.length, max(0, length - loc))
            textView.setSelectedRange(NSRange(location: loc, length: len))
            context.coordinator.applyFullHighlighting(to: textView.textStorage)
        }
    }

    private func applyBaseFont(to textView: NSTextView) {
        switch style {
        case .rendered, .rich:
            textView.font = NSFont.systemFont(ofSize: 14)
        case .mono:
            textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        @Binding var text: String
        weak var textView: NSTextView?
        var style: Style
        private let highlighter = MarkdownHighlighter()
        private var lastEditedRange: NSRange?

        init(text: Binding<String>, style: Style) {
            self._text = text
            self.style = style
        }

        func textStorage(_ textStorage: NSTextStorage,
                         didProcessEditing editedMask: NSTextStorageEditActions,
                         range editedRange: NSRange,
                         changeInLength delta: Int) {
            // Only interested in user-initiated character edits, not our own attribute changes.
            guard editedMask.contains(.editedCharacters) else { return }
            lastEditedRange = editedRange
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView,
                  let storage = tv.textStorage else { return }
            text = tv.string
            if let edited = lastEditedRange {
                lastEditedRange = nil
                highlighter.applyIncremental(to: storage, style: style, editedRange: edited)
            } else {
                highlighter.apply(to: storage, style: style)
            }
        }

        func applyFullHighlighting(to storage: NSTextStorage?) {
            guard let storage else { return }
            lastEditedRange = nil
            highlighter.apply(to: storage, style: style)
        }
    }
}
