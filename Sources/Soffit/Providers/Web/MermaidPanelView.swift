import Combine
import SwiftUI
import WebKit

/// Mermaid editor + preview. Reads/writes the underlying `.mmd` file and
/// re-renders the preview WKWebView with debounced source updates.
///
/// Three modes (toggle via the floating pill above the pane):
///   • Source — NSTextView with the raw `.mmd` source.
///   • Render — WKWebView with the rendered diagram.
///   • Split  — source on the left, rendered on the right.
struct MermaidPanelView: View {
    let source: PanelSource
    let context: PanelContext

    @StateObject private var model: MermaidPanelModel
    @State private var mode: Mode = .render

    enum Mode: String, CaseIterable, Identifiable {
        case source, render, split
        var id: String { rawValue }
        var label: String {
            switch self {
            case .source: return "Source"
            case .render: return "Render"
            case .split:  return "Split"
            }
        }
        var icon: String {
            switch self {
            case .source: return "chevron.left.forwardslash.chevron.right"
            case .render: return "eye"
            case .split:  return "rectangle.split.2x1"
            }
        }
    }

    init(source: PanelSource, context: PanelContext) {
        self.source = source
        self.context = context
        _model = StateObject(wrappedValue: MermaidPanelModel(source: source, context: context))
    }

    var body: some View {
        VStack(spacing: 0) {
            modeBar
            Divider()
            content
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear { model.load() }
        .onDisappear { model.flush() }
    }

    private var modeBar: some View {
        HStack(spacing: 6) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Label(m.label, systemImage: m.icon).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
            .fixedSize()

            Spacer()

            if model.isDirty {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.tertiary)
                    .help("Unsaved changes")
            }

            Text(model.fileName)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .source: sourceEditor
        case .render: rendered
        case .split:
            HSplitView {
                sourceEditor.frame(minWidth: 220)
                rendered.frame(minWidth: 240)
            }
        }
    }

    private var sourceEditor: some View {
        // Reuse MarkdownSourceEditor in mono mode — gives us syntax-style
        // highlighting (which is fine for mermaid's keyword-y look) and the
        // standard editing affordances.
        MarkdownSourceEditor(text: $model.source,
                             commands: MarkdownEditorCommands(),
                             style: .mono)
            .background(Color(nsColor: .textBackgroundColor))
    }

    private var rendered: some View {
        MermaidRenderView(source: model.source)
    }
}

@MainActor
final class MermaidPanelModel: ObservableObject {
    @Published var source: String = ""
    @Published private(set) var isDirty: Bool = false

    let panelSource: PanelSource
    let context: PanelContext

    private var fileURL: URL?
    private var debounce: AnyCancellable?
    private var loaded = false

    init(source: PanelSource, context: PanelContext) {
        self.panelSource = source
        self.context = context
        self.fileURL = Self.resolveFileURL(panelSource: source, context: context)
    }

    var fileName: String {
        fileURL?.lastPathComponent ?? "(unknown).mmd"
    }

    func load() {
        guard !loaded else { return }
        loaded = true
        if let url = fileURL,
           let data = try? Data(contentsOf: url),
           let text = String(data: data, encoding: .utf8) {
            source = text
        }
        debounce = $source
            .dropFirst()
            .handleEvents(receiveOutput: { [weak self] _ in self?.isDirty = true })
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] value in
                self?.write(value)
                self?.isDirty = false
            }
    }

    func flush() {
        debounce?.cancel()
        debounce = nil
        if isDirty {
            write(source)
            isDirty = false
        }
    }

    private func write(_ value: String) {
        guard let url = fileURL else { return }
        Task.detached(priority: .utility) {
            try? value.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private static func resolveFileURL(panelSource: PanelSource, context: PanelContext) -> URL? {
        guard let url = panelSource.url else { return nil }
        guard let root = context.workspaceRoot else {
            return URL(fileURLWithPath: url.path)
        }
        var rel = url.path
        if rel.hasPrefix("/") { rel.removeFirst() }
        if rel.isEmpty, let host = url.host, !host.isEmpty { rel = host }
        return root.appendingPathComponent(rel)
    }
}

/// Standalone WKWebView wrapper that reads `source` from a `@State`-backed
/// String and re-posts it into the mermaid shim whenever it changes. Uses
/// the same shim/JS that the legacy WebPanelView used for `.mermaid` URLs.
private struct MermaidRenderView: NSViewRepresentable {
    let source: String

    func makeNSView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = context.coordinator
        web.setValue(false, forKey: "drawsBackground")
        if let shim = Bundle.module.url(forResource: "mermaid-shim", withExtension: "html")
            ?? Bundle.module.url(forResource: "mermaid-shim", withExtension: "html", subdirectory: "Resources") {
            web.loadFileURL(shim, allowingReadAccessTo: shim.deletingLastPathComponent())
        }
        context.coordinator.web = web
        context.coordinator.pendingSource = source
        return web
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.pendingSource = source
        if context.coordinator.didFinishLoad {
            context.coordinator.flush()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var web: WKWebView?
        var pendingSource: String = ""
        var didFinishLoad: Bool = false

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            didFinishLoad = true
            flush()
        }

        func flush() {
            guard let web else { return }
            let escaped = pendingSource
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            let js = "window.postMessage({ source: `\(escaped)` }, '*');"
            web.evaluateJavaScript(js)
        }
    }
}
