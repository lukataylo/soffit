import SwiftUI
import WebKit

struct WebPanelView: View {
    let source: PanelSource
    let context: PanelContext

    @StateObject private var model = WebPanelModel()

    var body: some View {
        VStack(spacing: 0) {
            WebToolbar(model: model)
            Divider()
            WebViewRepresentable(model: model, spec: currentSpec())
        }
    }

    private func currentSpec() -> WebLoadSpec {
        guard let url = source.url else { return .error("Invalid URL") }
        return WebURLResolver.resolve(url: url, workspaceRoot: context.workspaceRoot)
    }
}

private struct WebToolbar: View {
    @ObservedObject var model: WebPanelModel

    var body: some View {
        HStack(spacing: 8) {
            Button { model.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(!model.canGoBack)
            Button { model.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(!model.canGoForward)
            Button { model.reload() } label: { Image(systemName: "arrow.clockwise") }
            Text(model.currentURLDisplay)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.4))
    }
}

@MainActor
final class WebPanelModel: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var currentURLDisplay = ""
    weak var webView: WKWebView?
    var pendingDiagram: String?

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
}
