import SwiftUI
import WebKit

struct WebViewRepresentable: NSViewRepresentable {
    @ObservedObject var model: WebPanelModel
    let spec: WebLoadSpec

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        model.webView = webView
        context.coordinator.applySpec(spec, in: webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.applySpec(spec, in: nsView)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let model: WebPanelModel
        private var lastKey: String?

        init(model: WebPanelModel) { self.model = model }

        func applySpec(_ spec: WebLoadSpec, in webView: WKWebView) {
            let key: String
            switch spec {
            case .url(let u): key = "url:" + u.absoluteString
            case .mermaid(let shim, let diagram, _): key = "mermaid:" + shim.absoluteString + "#" + String(diagram.hashValue)
            case .error(let s): key = "error:" + s
            }
            guard key != lastKey else { return }
            lastKey = key

            switch spec {
            case .url(let url):
                model.pendingDiagram = nil
                if url.isFileURL {
                    webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
                } else {
                    webView.load(URLRequest(url: url))
                }
            case .mermaid(let shim, let diagram, _):
                model.pendingDiagram = diagram
                webView.loadFileURL(shim, allowingReadAccessTo: shim.deletingLastPathComponent())
            case .error(let message):
                let html = "<html><body style='font-family:-apple-system;padding:20px;color:#b91c1c;'>\(escaped(message))</body></html>"
                webView.loadHTMLString(html, baseURL: nil)
            }
        }

        private func escaped(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
        }

        // WKNavigationDelegate methods are called on the main thread. Marking
        // the Coordinator @MainActor lets us touch `model.pendingDiagram` and
        // friends synchronously without `Task { @MainActor in … }` wrappers.
        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            MainActor.assumeIsolated {
                model.canGoBack = webView.canGoBack
                model.canGoForward = webView.canGoForward
                model.currentURLDisplay = webView.url?.absoluteString ?? ""
                if let diagram = model.pendingDiagram {
                    let escaped = diagram
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "`", with: "\\`")
                        .replacingOccurrences(of: "$", with: "\\$")
                    let js = "window.postMessage({ source: `\(escaped)` }, '*');"
                    webView.evaluateJavaScript(js, completionHandler: nil)
                }
            }
        }

        nonisolated func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            MainActor.assumeIsolated {
                model.currentURLDisplay = webView.url?.absoluteString ?? ""
            }
        }
    }
}
