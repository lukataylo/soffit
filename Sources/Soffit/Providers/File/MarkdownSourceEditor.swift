import AppKit
import SwiftUI

struct MarkdownSourceEditor: NSViewRepresentable {
    @Binding var text: String
    let commands: MarkdownEditorCommands
    let style: Style
    /// Called when the user ⌘-clicks (or single-clicks) on a wikilink or
    /// inline-link target. The character index is in the source string.
    var onClickRequestOpen: ((Int) -> Void)? = nil
    /// Called when the user pastes an image; receives the image data and
    /// returns the markdown to insert (or nil to fall back to default behaviour).
    var onPasteImage: ((Data) -> String?)? = nil
    /// Whether to allow OS spell-check + grammar (defaults to off — the user
    /// can toggle it from the markdown panel's status bar).
    var spellCheckEnabled: Bool = false
    /// Snippet expansion lookup: given a trigger like ",date", returns its
    /// expansion, or nil if no snippet matches.
    var expandSnippet: ((String) -> String?)? = nil

    enum Style {
        case rendered
        case rich
        case mono
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text,
                    style: style,
                    onClickRequestOpen: onClickRequestOpen,
                    onPasteImage: onPasteImage,
                    expandSnippet: expandSnippet)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder

        let textView = SoffitTextView()
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = .width
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        textView.delegate = context.coordinator
        textView.textStorage?.delegate = context.coordinator
        textView.coordinator = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = spellCheckEnabled
        textView.isContinuousSpellCheckingEnabled = spellCheckEnabled
        textView.isGrammarCheckingEnabled = spellCheckEnabled
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 20, height: 18)
        textView.backgroundColor = .textBackgroundColor
        textView.usesFindBar = true
        applyBaseFont(to: textView)
        textView.string = text
        context.coordinator.textView = textView
        context.coordinator.applyFullHighlighting(to: textView.textStorage)
        scroll.documentView = textView
        DispatchQueue.main.async { commands.textView = textView }
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? SoffitTextView else { return }
        if commands.textView !== textView {
            commands.textView = textView
        }
        textView.coordinator = context.coordinator
        context.coordinator.onClickRequestOpen = onClickRequestOpen
        context.coordinator.onPasteImage = onPasteImage
        context.coordinator.expandSnippet = expandSnippet
        if textView.isContinuousSpellCheckingEnabled != spellCheckEnabled {
            textView.isContinuousSpellCheckingEnabled = spellCheckEnabled
            textView.isAutomaticSpellingCorrectionEnabled = spellCheckEnabled
            textView.isGrammarCheckingEnabled = spellCheckEnabled
        }
        if context.coordinator.style != style {
            context.coordinator.style = style
            applyBaseFont(to: textView)
            context.coordinator.applyFullHighlighting(to: textView.textStorage)
        }
        if textView.string != text {
            let selected = textView.selectedRange()
            textView.string = text
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
        var onClickRequestOpen: ((Int) -> Void)?
        var onPasteImage: ((Data) -> String?)?
        var expandSnippet: ((String) -> String?)?
        private let highlighter = MarkdownHighlighter()
        private var lastEditedRange: NSRange?

        init(text: Binding<String>,
             style: Style,
             onClickRequestOpen: ((Int) -> Void)?,
             onPasteImage: ((Data) -> String?)?,
             expandSnippet: ((String) -> String?)?) {
            self._text = text
            self.style = style
            self.onClickRequestOpen = onClickRequestOpen
            self.onPasteImage = onPasteImage
            self.expandSnippet = expandSnippet
        }

        /// Detect a snippet trigger that just got terminated (by space or newline)
        /// and replace it with the expansion. Runs on every text mutation —
        /// cheap because it only inspects the chars near the caret.
        func tryExpandSnippet(in textView: NSTextView, lastTyped: String) {
            guard let storage = textView.textStorage,
                  let expand = expandSnippet,
                  lastTyped == " " || lastTyped == "\n" else { return }
            let s = storage.string as NSString
            let caret = textView.selectedRange().location
            // Inspect up to 16 chars before the caret for a `,word` pattern.
            let scanLen = min(caret, 16)
            let scanStart = caret - scanLen
            let chunk = s.substring(with: NSRange(location: scanStart, length: scanLen))
            // Find the last comma before whitespace.
            guard let commaIdx = chunk.lastIndex(of: ",") else { return }
            let after = chunk[chunk.index(after: commaIdx)...]
            let trigger = "," + String(after.prefix { $0.isLetter || $0.isNumber || $0 == "_" })
            guard let expansion = expand(trigger) else { return }
            // Replace the trigger (including the trailing terminator just typed).
            let triggerRange = NSRange(location: caret - trigger.count - 1,
                                       length: trigger.count + 1) // +1 for terminator
            textView.insertText(expansion + lastTyped, replacementRange: triggerRange)
        }

        func textStorage(_ textStorage: NSTextStorage,
                         didProcessEditing editedMask: NSTextStorageEditActions,
                         range editedRange: NSRange,
                         changeInLength delta: Int) {
            guard editedMask.contains(.editedCharacters) else { return }
            lastEditedRange = editedRange
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView,
                  let storage = tv.textStorage else { return }
            // If the user just typed a snippet terminator, expand and let the
            // induced edit re-trigger this delegate naturally.
            if let edited = lastEditedRange,
               edited.length == 1,
               edited.location + edited.length <= storage.length {
                let lastChar = (storage.string as NSString)
                    .substring(with: NSRange(location: edited.location, length: 1))
                if lastChar == " " || lastChar == "\n" {
                    tryExpandSnippet(in: tv, lastTyped: lastChar)
                }
            }
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

/// NSTextView subclass that intercepts ⌘-click (so wikilinks become clickable)
/// and ⌘V image paste (so dropped clipboard images get auto-saved).
final class SoffitTextView: NSTextView {
    weak var coordinator: MarkdownSourceEditor.Coordinator?

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), let coord = coordinator {
            let point = convert(event.locationInWindow, from: nil)
            let charIndex = self.characterIndexForInsertion(at: point)
            if charIndex < (self.string as NSString).length {
                coord.onClickRequestOpen?(charIndex)
                return
            }
        }
        super.mouseDown(with: event)
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        if let coord = coordinator,
           let onPaste = coord.onPasteImage,
           let imageData = imageDataFromPasteboard(pasteboard),
           let markdown = onPaste(imageData) {
            insertText(markdown, replacementRange: selectedRange())
            return
        }
        super.paste(sender)
    }

    private func imageDataFromPasteboard(_ pb: NSPasteboard) -> Data? {
        // Direct image data first.
        if let png = pb.data(forType: .png) { return png }
        if let tiff = pb.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            return png
        }
        // File URL of an image.
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let imageURL = urls.first(where: { ["png","jpg","jpeg","gif","heic","tiff"].contains($0.pathExtension.lowercased()) }),
           let data = try? Data(contentsOf: imageURL) {
            return data
        }
        return nil
    }
}
