import Combine
import MarkdownUI
import SwiftUI

struct MarkdownPanelView: View {
    let fileURL: URL
    let panelID: PanelID
    let context: PanelContext

    @EnvironmentObject var services: AppServices
    @EnvironmentObject var session: WindowSession
    @StateObject private var model: MarkdownPanelModel
    @ObservedObject private var state: MarkdownActiveState
    @State private var sideOpen: SidePanel = .none

    enum SidePanel: Hashable {
        case none, outline, backlinks
    }

    init(fileURL: URL, panelID: PanelID, context: PanelContext) {
        self.fileURL = fileURL
        self.panelID = panelID
        self.context = context
        _model = StateObject(wrappedValue: MarkdownPanelModel(fileURL: fileURL, panelID: panelID, context: context))
        _state = ObservedObject(wrappedValue: MarkdownStateRegistry.shared.state(for: panelID))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if sideOpen != .none {
                    Divider()
                    sidePanel
                        .frame(width: 240)
                }
            }
            statusBar
        }
        .onAppear {
            model.load()
            restoreMode()
        }
        .onChange(of: state.mode) { _, _ in persistMode() }
        .onDisappear { model.flush() }
    }

    // MARK: - Main content

    @ViewBuilder
    private var content: some View {
        if !model.isMarkdown {
            ScrollView {
                Text(model.text)
                    .font(.system(size: 12.5, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .textSelection(.enabled)
            }
        } else {
            switch state.mode {
            case .preview:
                renderedReadOnlyPane
            case .edit:
                sourceEditorPane
            case .split:
                HSplitView {
                    sourceEditorPane.frame(minWidth: 220)
                    renderedReadOnlyPane.frame(minWidth: 260)
                }
            case .math:
                MathRenderedView(source: model.text)
                    .background(Color(nsColor: .textBackgroundColor))
            }
        }
    }

    private var sourceEditorPane: some View {
        MarkdownSourceEditor(text: $model.text,
                             commands: state.commands,
                             style: .mono,
                             onClickRequestOpen: handleEditorOpen,
                             onPasteImage: handlePastedImage,
                             spellCheckEnabled: state.spellCheckEnabled,
                             expandSnippet: { services.snippets.expand($0) })
            .background(Color(nsColor: .textBackgroundColor))
    }

    /// Save a pasted image to `<workspace>/attachments/` and return the
    /// markdown to splice in at the cursor.
    private func handlePastedImage(_ data: Data) -> String? {
        let folder = (services.workspace?.root ?? fileURL.deletingLastPathComponent())
            .appendingPathComponent("attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let filename = "paste-\(stamp).png"
        let dest = folder.appendingPathComponent(filename)
        do {
            try data.write(to: dest)
        } catch {
            return nil
        }
        // Build a workspace-relative path if possible.
        let path: String
        if let root = services.workspace?.root, dest.path.hasPrefix(root.path) {
            let rel = String(dest.path.dropFirst(root.path.count + 1))
            path = rel
        } else {
            path = dest.path
        }
        return "![](\(path))"
    }

    @Environment(\.colorScheme) private var colorScheme

    private var renderedReadOnlyPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if let fmCard = frontmatterCard {
                    fmCard.padding(.horizontal, 28).padding(.top, 22).padding(.bottom, 8)
                }
                Markdown(processedSource)
                    .markdownTheme(soffitMarkdownTheme(dark: colorScheme == .dark))
                    .padding(.horizontal, 28)
                    .padding(.vertical, frontmatterCard == nil ? 22 : 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .environment(\.openURL, OpenURLAction { url in
                        handleRenderedURL(url)
                    })
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    /// Pre-process the markdown source for things MarkdownUI doesn't handle:
    /// - `[[wiki-link]]` → `[wiki-link](soffit-wiki://wiki-link)` so they render
    ///   as clickable links and route through OpenURLAction.
    /// - Strip the YAML frontmatter (we render it as a card separately).
    private var processedSource: String {
        var s = model.text
        if s.hasPrefix("---\n") || s.hasPrefix("---\r\n") {
            // Strip frontmatter — it's rendered as a card above.
            if let parsedRange = stripFrontmatter(in: s) {
                s = String(s[parsedRange...])
            }
        }
        let regex = try! NSRegularExpression(pattern: "\\[\\[([^\\[\\]\\n|]+)(?:\\|([^\\[\\]\\n]+))?\\]\\]")
        let ns = s as NSString
        let result = NSMutableString(string: s)
        var offset = 0
        for match in regex.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            let target = ns.substring(with: match.range(at: 1))
            let alias = match.range(at: 2).location == NSNotFound
                ? target
                : ns.substring(with: match.range(at: 2))
            let encoded = target.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? target
            let replacement = "[\(alias)](soffit-wiki://\(encoded))"
            let range = NSRange(location: match.range.location + offset, length: match.range.length)
            result.replaceCharacters(in: range, with: replacement)
            offset += replacement.count - match.range.length
        }
        return result as String
    }

    private func stripFrontmatter(in source: String) -> String.Index? {
        guard source.hasPrefix("---\n") || source.hasPrefix("---\r\n") else { return nil }
        let firstNewline = source.hasPrefix("---\r\n") ? 5 : 4
        var idx = source.index(source.startIndex, offsetBy: firstNewline)
        while idx < source.endIndex {
            let lineEnd = source[idx...].firstIndex(of: "\n") ?? source.endIndex
            if source[idx..<lineEnd].trimmingCharacters(in: .whitespaces) == "---" {
                let next = lineEnd < source.endIndex ? source.index(after: lineEnd) : source.endIndex
                return next
            }
            idx = lineEnd < source.endIndex ? source.index(after: lineEnd) : source.endIndex
        }
        return nil
    }

    // MARK: - Frontmatter card

    private var frontmatterCard: AnyView? {
        let parsed = MarkdownParser.parse(model.text)
        guard !parsed.frontmatter.isEmpty else { return nil }
        let entries = parsed.frontmatter.sorted { $0.key < $1.key }
        return AnyView(
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entries, id: \.key) { kv in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(kv.key.uppercased())
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(width: 80, alignment: .leading)
                        if kv.key == "tags" {
                            tagPills(for: kv.value)
                        } else {
                            Text(kv.value)
                                .font(.system(size: 12))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                        }
                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 0.6)
            )
        )
    }

    private func tagPills(for raw: String) -> some View {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let inner: String
        if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
            inner = String(trimmed.dropFirst().dropLast())
        } else { inner = trimmed }
        let tags = inner.split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"' ")) }
        return HStack(spacing: 4) {
            ForEach(tags, id: \.self) { t in
                Text("#\(t)")
                    .font(.system(size: 10.5, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    // MARK: - Side panel

    @ViewBuilder
    private var sidePanel: some View {
        switch sideOpen {
        case .none: EmptyView()
        case .outline:
            OutlineSidePanel(text: model.text,
                             onClose: { sideOpen = .none },
                             onSelect: { line in
                                 if state.mode == .preview { state.mode = .split }
                                 state.commands.scrollTo(line: line)
                             })
        case .backlinks:
            BacklinksSidePanel(fileURL: fileURL,
                               onClose: { sideOpen = .none },
                               onOpen: { url in session.openFile(url, mode: .preview) })
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            statusButton(icon: "list.bullet.indent",
                         active: sideOpen == .outline,
                         help: "Outline") {
                sideOpen = (sideOpen == .outline) ? .none : .outline
            }
            statusButton(icon: "link",
                         active: sideOpen == .backlinks,
                         help: "Backlinks") {
                sideOpen = (sideOpen == .backlinks) ? .none : .backlinks
            }
            statusButton(icon: state.spellCheckEnabled ? "textformat.abc.dottedunderline" : "textformat.abc",
                         active: state.spellCheckEnabled,
                         help: "Spell check") {
                state.spellCheckEnabled.toggle()
            }
            Spacer()
            Text("\(wordCount) words · \(charCount) chars")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.04))
        .overlay(Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5), alignment: .top)
    }

    private func statusButton(icon: String, active: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(active ? Color.accentColor : .secondary)
                .frame(width: 22, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(active ? Color.accentColor.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var wordCount: Int {
        model.text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    private var charCount: Int { model.text.count }

    // MARK: - Click handling

    private func handleEditorOpen(_ characterIndex: Int) {
        let source = model.text
        if let target = WikilinkPlumbing.target(at: characterIndex, in: source) {
            openWikilink(target)
            return
        }
        if let inline = WikilinkPlumbing.inlineLink(at: characterIndex, in: source) {
            openInlineLink(inline.url)
        }
    }

    private func handleRenderedURL(_ url: URL) -> OpenURLAction.Result {
        if url.scheme == "soffit-wiki" {
            let target = url.host ?? url.path
            let decoded = target.removingPercentEncoding ?? target
            openWikilink(decoded)
            return .handled
        }
        if url.isFileURL || (url.scheme == nil) || url.scheme == "" {
            openInlineLink(url.absoluteString)
            return .handled
        }
        // Relative paths arrive as opaque schemes (`./other.md` etc.) — try to
        // resolve relative to the current file before falling through to the
        // system browser.
        if url.host == nil, !url.absoluteString.contains("://") {
            openInlineLink(url.absoluteString)
            return .handled
        }
        return .systemAction
    }

    private func openWikilink(_ target: String) {
        if let resolved = services.index.resolve(wikilink: target) {
            session.openFile(resolved, mode: .preview)
            return
        }
        // Unresolved: create a new file in the same folder as the active one.
        let folder = fileURL.deletingLastPathComponent()
        let safeName = target.replacingOccurrences(of: "/", with: "-")
        let targetURL = folder.appendingPathComponent("\(safeName).md")
        if !FileManager.default.fileExists(atPath: targetURL.path) {
            try? "# \(target)\n".write(to: targetURL, atomically: true, encoding: .utf8)
        }
        Task { await services.index.touch(targetURL) }
        session.openFile(targetURL, mode: .preview)
    }

    private func openInlineLink(_ raw: String) {
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            if let url = URL(string: raw) {
                NSWorkspace.shared.open(url)
            }
            return
        }
        // Strip in-doc anchor like file.md#section
        let path = raw.split(separator: "#", maxSplits: 1).first.map { String($0) } ?? raw
        // Resolve relative to the current file.
        let candidate: URL
        if path.hasPrefix("/") {
            candidate = URL(fileURLWithPath: path)
        } else {
            candidate = fileURL.deletingLastPathComponent().appendingPathComponent(path)
        }
        if FileManager.default.fileExists(atPath: candidate.path) {
            session.openFile(candidate, mode: .preview)
        } else if let url = URL(string: raw) {
            NSWorkspace.shared.open(url)
        }
    }

    private func restoreMode() {
        guard let data = InitialStateHolder.shared.read(panelID),
              let stored = try? JSONDecoder().decode(MarkdownPanelState.self, from: data) else { return }
        state.mode = stored.mode
    }

    private func persistMode() {
        let stored = MarkdownPanelState(mode: state.mode)
        let data = try? JSONEncoder().encode(stored)
        context.savePanelState(panelID, data)
    }
}

@MainActor
final class MarkdownPanelModel: ObservableObject {
    @Published var text: String = ""
    let fileURL: URL
    let panelID: PanelID
    let context: PanelContext

    private var debounce: AnyCancellable?
    private var loaded = false
    private var dirty = false

    var isMarkdown: Bool {
        let ext = fileURL.pathExtension.lowercased()
        return ["md", "markdown", "mdx"].contains(ext)
    }

    init(fileURL: URL, panelID: PanelID, context: PanelContext) {
        self.fileURL = fileURL
        self.panelID = panelID
        self.context = context
    }

    func load() {
        guard !loaded else { return }
        loaded = true
        let url = fileURL
        Task { [weak self] in
            // For iCloud Drive placeholder files, request a download and wait
            // before reading. For ordinary files this is an immediate no-op.
            await CloudFile.materialise(url)
            let s: String? = (try? Data(contentsOf: url))
                .flatMap { String(data: $0, encoding: .utf8) }
            await MainActor.run {
                guard let self else { return }
                if let s { self.text = s }
                self.debounce = self.$text
                    .dropFirst()
                    .handleEvents(receiveOutput: { [weak self] _ in self?.dirty = true })
                    .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
                    .sink { [weak self] value in
                        self?.write(value)
                        self?.dirty = false
                    }
            }
        }
    }

    func flush() {
        debounce?.cancel()
        debounce = nil
        if dirty {
            write(text)
            dirty = false
        }
    }

    private func write(_ value: String) {
        guard isMarkdown else { return }
        let url = fileURL
        // Atomic write off the main thread: a 10k-line markdown file would
        // otherwise stall typing for tens of milliseconds on every save tick.
        Task.detached(priority: .utility) {
            try? value.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
