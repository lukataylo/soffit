import Foundation

enum WebLoadSpec {
    case url(URL)
    case mermaid(shim: URL, diagram: String, fileURL: URL?)
    case error(String)
}

enum WebURLResolver {
    static func resolve(url: URL, workspaceRoot: URL?) -> WebLoadSpec {
        switch url.scheme?.lowercased() {
        case "mermaid":
            return resolveMermaid(url: url, workspaceRoot: workspaceRoot)
        case "http", "https":
            return .url(figmaEmbedIfNeeded(url))
        case "file":
            return .url(url)
        case nil, "":
            if let u = URL(string: "https://" + url.absoluteString) { return .url(u) }
            return .error("Invalid URL: \(url.absoluteString)")
        default:
            return .url(url)
        }
    }

    private static func figmaEmbedIfNeeded(_ url: URL) -> URL {
        guard let host = url.host, host.contains("figma.com") else { return url }
        if url.path.hasPrefix("/embed") { return url }
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.scheme = "https"
        comps.host = "www.figma.com"
        comps.path = "/embed"
        var items = comps.queryItems ?? []
        items.removeAll { $0.name == "embed_host" || $0.name == "url" }
        items.append(URLQueryItem(name: "embed_host", value: "soffit"))
        items.append(URLQueryItem(name: "url", value: url.absoluteString))
        comps.queryItems = items
        return comps.url ?? url
    }

    private static func resolveMermaid(url: URL, workspaceRoot: URL?) -> WebLoadSpec {
        guard let shim = SoffitBundle.module.url(forResource: "mermaid-shim", withExtension: "html", subdirectory: "Resources")
            ?? SoffitBundle.module.url(forResource: "mermaid-shim", withExtension: "html") else {
            return .error("mermaid-shim.html missing from bundle")
        }

        guard let root = workspaceRoot else {
            return .mermaid(shim: shim, diagram: "graph TD; A[No workspace] --> B[pick a folder first];", fileURL: nil)
        }

        var rel = url.path
        if rel.hasPrefix("/") { rel.removeFirst() }
        if rel.isEmpty, let host = url.host, !host.isEmpty { rel = host }
        let fileURL = root.appendingPathComponent(rel)
        guard let data = try? Data(contentsOf: fileURL),
              let diagram = String(data: data, encoding: .utf8) else {
            return .mermaid(shim: shim,
                            diagram: "graph TD; A[Cannot read] --> B[\(rel)];",
                            fileURL: fileURL)
        }
        return .mermaid(shim: shim, diagram: diagram, fileURL: fileURL)
    }
}
