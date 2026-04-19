import SwiftUI

struct FolderProvider: PanelProvider {
    static let scheme = "folder"
    static let displayName = "Folder"

    func makeView(for source: PanelSource, context: PanelContext) -> AnyView {
        AnyView(FolderPanelView(source: source, context: context))
    }
}

enum FolderURL {
    static func makeSource(for folder: URL) -> String {
        var comps = URLComponents()
        comps.scheme = "folder"
        comps.host = ""
        comps.path = folder.path
        return comps.string ?? "folder://\(folder.path)"
    }

    static func folder(from source: PanelSource) -> URL? {
        guard let url = source.url, url.scheme?.lowercased() == "folder" else { return nil }
        var path = url.path
        if path.isEmpty, let host = url.host, !host.isEmpty { path = "/" + host }
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
    }
}
