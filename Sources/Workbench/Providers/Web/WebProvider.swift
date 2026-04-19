import SwiftUI

struct WebProvider: PanelProvider {
    static let scheme = "web"
    static let displayName = "Web"

    func makeView(for source: PanelSource, context: PanelContext) -> AnyView {
        AnyView(WebPanelView(source: source, context: context))
    }
}

struct MermaidProvider: PanelProvider {
    static let scheme = "mermaid"
    static let displayName = "Mermaid"

    func makeView(for source: PanelSource, context: PanelContext) -> AnyView {
        AnyView(WebPanelView(source: source, context: context))
    }
}
