import SwiftUI
import WebKit

/// WebKit-rendered markdown + KaTeX preview. Used for the "Math" mode of the
/// markdown panel. Loads the bundled `math-shim.html`, then posts the source
/// in via `postMessage`.
struct MathRenderedView: View {
    let source: String

    var body: some View {
        if mathAssetsAvailable {
            MathWebView(source: source)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "function")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Math rendering not enabled")
                    .font(.system(size: 16, weight: .semibold))
                Text("Run `./scripts/vendor-katex.sh` once to fetch the math libraries (KaTeX + marked.js, ~310KB) into the resource bundle.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 360, alignment: .leading)
                Text("After that, this view will render LaTeX math via $…$ and $$…$$ syntax inline with your markdown.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: 360, alignment: .leading)
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var mathAssetsAvailable: Bool {
        SoffitBundle.module.url(forResource: "katex.min", withExtension: "js") != nil
            && SoffitBundle.module.url(forResource: "marked.min", withExtension: "js") != nil
    }
}

private struct MathWebView: NSViewRepresentable {
    let source: String

    func makeNSView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = context.coordinator
        web.setValue(false, forKey: "drawsBackground")
        if let shim = SoffitBundle.module.url(forResource: "math-shim", withExtension: "html")
            ?? SoffitBundle.module.url(forResource: "math-shim", withExtension: "html", subdirectory: "Resources") {
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
