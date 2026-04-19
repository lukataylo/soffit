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
        context.coordinator.applyHighlighting(to: textView.textStorage)
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
            context.coordinator.applyHighlighting(to: textView.textStorage)
        }
        if textView.string != text {
            let selected = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selected)
            context.coordinator.applyHighlighting(to: textView.textStorage)
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

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: NSTextView?
        var style: Style
        private let highlighter = MarkdownHighlighter()

        init(text: Binding<String>, style: Style) {
            self._text = text
            self.style = style
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text = tv.string
            applyHighlighting(to: tv.textStorage)
        }

        func applyHighlighting(to storage: NSTextStorage?) {
            guard let storage else { return }
            highlighter.apply(to: storage, style: style)
        }
    }
}
