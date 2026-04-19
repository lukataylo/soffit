import SwiftUI

struct FileProvider: PanelProvider {
    static let scheme = "file"
    static let displayName = "Markdown"

    func makeView(for source: PanelSource, context: PanelContext) -> AnyView {
        guard let url = source.url else {
            return AnyView(Text("Invalid file URL").foregroundStyle(.secondary))
        }
        return AnyView(MarkdownPanelView(fileURL: url, panelID: source.panelID, context: context))
    }
}
