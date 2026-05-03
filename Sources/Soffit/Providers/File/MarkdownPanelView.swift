import Combine
import MarkdownUI
import SwiftUI

struct MarkdownPanelView: View {
    let fileURL: URL
    let panelID: PanelID
    let context: PanelContext

    @StateObject private var model: MarkdownPanelModel
    @ObservedObject private var state: MarkdownActiveState

    init(fileURL: URL, panelID: PanelID, context: PanelContext) {
        self.fileURL = fileURL
        self.panelID = panelID
        self.context = context
        _model = StateObject(wrappedValue: MarkdownPanelModel(fileURL: fileURL, panelID: panelID, context: context))
        _state = ObservedObject(wrappedValue: MarkdownStateRegistry.shared.state(for: panelID))
    }

    var body: some View {
        content
            .onAppear {
                model.load()
                restoreMode()
            }
            .onChange(of: state.mode) { _, _ in persistMode() }
            .onDisappear { model.flush() }
    }

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
            }
        }
    }

    private var sourceEditorPane: some View {
        MarkdownSourceEditor(text: $model.text, commands: state.commands, style: .mono)
            .background(Color(nsColor: .textBackgroundColor))
    }

    private var renderedReadOnlyPane: some View {
        ScrollView {
            Markdown(model.text)
                .markdownTheme(.gitHub)
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .background(Color(nsColor: .textBackgroundColor))
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
        if let data = try? Data(contentsOf: fileURL), let s = String(data: data, encoding: .utf8) {
            text = s
        }
        debounce = $text
            .dropFirst()
            .handleEvents(receiveOutput: { [weak self] _ in self?.dirty = true })
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] value in
                self?.write(value)
                self?.dirty = false
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
        // Atomic write off the main thread: a 10k-line markdown file would otherwise
        // stall typing for tens of milliseconds on every save tick.
        Task.detached(priority: .utility) {
            try? value.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
