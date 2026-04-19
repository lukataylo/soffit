import Combine
import MarkdownUI
import SwiftUI

struct MarkdownPanelView: View {
    let fileURL: URL
    let panelID: PanelID
    let context: PanelContext

    @StateObject private var model: MarkdownPanelModel
    @State private var mode: MarkdownPanelMode = .preview

    init(fileURL: URL, panelID: PanelID, context: PanelContext) {
        self.fileURL = fileURL
        self.panelID = panelID
        self.context = context
        _model = StateObject(wrappedValue: MarkdownPanelModel(fileURL: fileURL, panelID: panelID, context: context))
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.isMarkdown {
                modeToolbar
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1)
            }
            content
        }
        .onAppear {
            model.load()
            restoreMode()
        }
        .onChange(of: mode) { _, _ in persistMode() }
        .onDisappear { model.flush() }
    }

    private var modeToolbar: some View {
        HStack(spacing: 6) {
            ForEach(MarkdownPanelMode.allCases) { m in
                Button { mode = m } label: {
                    HStack(spacing: 5) {
                        Image(systemName: m.icon)
                            .font(.system(size: 10, weight: .medium))
                        Text(m.label)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(mode == m ? Color.accentColor.opacity(0.16) : Color.clear)
                    )
                    .foregroundStyle(mode == m ? Color.accentColor : Color.secondary)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text(fileURL.lastPathComponent)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 30)
        .background(
            Color(nsColor: .underPageBackgroundColor).opacity(0.4)
        )
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
            switch mode {
            case .preview:
                previewPane
            case .edit:
                editorPane
            case .split:
                HSplitView {
                    editorPane.frame(minWidth: 220)
                    previewPane.frame(minWidth: 260)
                }
            }
        }
    }

    private var previewPane: some View {
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

    private var editorPane: some View {
        MarkdownSourceEditor(text: $model.text)
            .background(Color(nsColor: .textBackgroundColor))
    }

    private func restoreMode() {
        guard let data = InitialStateHolder.shared.read(panelID),
              let state = try? JSONDecoder().decode(MarkdownPanelState.self, from: data) else { return }
        mode = state.mode
    }

    private func persistMode() {
        let state = MarkdownPanelState(mode: mode)
        let data = try? JSONEncoder().encode(state)
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
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] value in self?.write(value) }
    }

    func flush() {
        debounce?.cancel()
    }

    private func write(_ value: String) {
        guard isMarkdown else { return }
        try? value.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
