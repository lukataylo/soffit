#if SOFFIT_PRO
import SwiftUI

struct TerminalProvider: PanelProvider {
    static let scheme = "terminal"
    static let displayName = "Terminal"

    func makeView(for source: PanelSource, context: PanelContext) -> AnyView {
        AnyView(TerminalPanelView(source: source, context: context))
    }
}

enum TerminalSource {
    static func makeSource(for folder: URL) -> String {
        var comps = URLComponents()
        comps.scheme = "terminal"
        comps.host = ""
        comps.path = folder.path
        return comps.string ?? "terminal://\(folder.path)"
    }

    static func folder(from panelSource: PanelSource) -> URL? {
        guard let url = panelSource.url, url.scheme?.lowercased() == "terminal" else { return nil }
        var path = url.path
        if path.isEmpty, let host = url.host, !host.isEmpty { path = "/" + host }
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
    }
}
#endif
