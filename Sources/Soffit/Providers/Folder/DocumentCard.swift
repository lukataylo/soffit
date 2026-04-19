import MarkdownUI
import SwiftUI

struct DocumentCard: View {
    let entry: FSEntry
    let onOpen: () -> Void

    @State private var preview: CardPreview = .loading
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1)
            contentBody
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 210, alignment: .topLeading)
                .clipped()
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(isHovered ? 0.16 : 0.07), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.10 : 0.05), radius: isHovered ? 10 : 4, x: 0, y: isHovered ? 4 : 1)
        .scaleEffect(isHovered ? 1.008 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(count: 2) { onOpen() }
        .onTapGesture(count: 1) { /* consume single-click so it doesn't fall through */ }
        .onAppear { loadPreview() }
    }

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(tint.opacity(0.18))
                    .frame(width: 26, height: 26)
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private var contentBody: some View {
        switch preview {
        case .loading:
            Color.clear
        case .markdown(let excerpt):
            Markdown(excerpt)
                .markdownTextStyle(\.text) {
                    FontSize(11.5)
                    ForegroundColor(.primary.opacity(0.8))
                }
                .markdownTextStyle(\.code) {
                    FontFamilyVariant(.monospaced)
                    FontSize(10.5)
                }
                .markdownTextStyle(\.emphasis) { FontStyle(.italic) }
                .markdownTextStyle(\.strong) { FontWeight(.semibold) }
                .markdownBlockStyle(\.heading1) { configuration in
                    configuration.label
                        .markdownTextStyle { FontWeight(.bold); FontSize(13.5) }
                        .padding(.bottom, 4)
                }
                .markdownBlockStyle(\.heading2) { configuration in
                    configuration.label
                        .markdownTextStyle { FontWeight(.semibold); FontSize(12.5) }
                        .padding(.bottom, 3)
                }
                .lineLimit(nil)
        case .mermaid(let source):
            VStack(alignment: .leading, spacing: 6) {
                Text("DIAGRAM")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)
                Text(source)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
            }
        case .folder(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.prefix(6), id: \.name) { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.isDirectory ? "folder" : "doc")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text(item.name)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if items.count > 6 {
                    Text("… and \(items.count - 6) more")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
        case .plain(let text):
            Text(text)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(nil)
        case .empty:
            HStack {
                Image(systemName: "doc.questionmark").foregroundStyle(.tertiary)
                Text("Empty").foregroundStyle(.tertiary).font(.system(size: 11))
            }
        }
    }

    private var displayName: String {
        if entry.isDirectory { return entry.name }
        if case .markdown = preview, let heading = extractMarkdownHeading(), !heading.isEmpty {
            return heading
        }
        return entry.url.deletingPathExtension().lastPathComponent
    }

    private var subtitle: String {
        if entry.isDirectory {
            if case .folder(let items) = preview { return "\(items.count) items" }
            return "Folder"
        }
        let ext = entry.url.pathExtension.lowercased()
        switch ext {
        case "md", "markdown", "mdx": return "Markdown · \(entry.name)"
        case "mmd": return "Mermaid · \(entry.name)"
        default: return ext.isEmpty ? entry.name : ext.uppercased() + " · " + entry.name
        }
    }

    private var iconName: String {
        if entry.isDirectory { return "folder.fill" }
        switch entry.url.pathExtension.lowercased() {
        case "md", "markdown", "mdx": return "doc.richtext.fill"
        case "mmd": return "point.3.filled.connected.trianglepath.dotted"
        case "png", "jpg", "jpeg", "heic", "gif": return "photo.fill"
        case "json", "yml", "yaml", "toml": return "curlybraces"
        case "txt": return "doc.text.fill"
        default: return "doc.fill"
        }
    }

    private var tint: Color {
        if entry.isDirectory { return Color(red: 0.95, green: 0.55, blue: 0.35) }
        switch entry.url.pathExtension.lowercased() {
        case "md", "markdown", "mdx": return Color(red: 0.38, green: 0.56, blue: 0.92)
        case "mmd": return Color(red: 0.60, green: 0.40, blue: 0.85)
        case "png", "jpg", "jpeg", "heic", "gif": return Color(red: 0.45, green: 0.75, blue: 0.55)
        default: return Color.secondary
        }
    }

    private func extractMarkdownHeading() -> String? {
        if case .markdown(let text) = preview {
            for line in text.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("#") {
                    return trimmed.drop(while: { $0 == "#" || $0 == " " }).description
                }
            }
        }
        return nil
    }

    private func loadPreview() {
        if entry.isDirectory {
            let items = WorkspaceStore.readDirectory(entry.url)
                .map { FolderItem(name: $0.name, isDirectory: $0.isDirectory) }
            preview = .folder(items)
            return
        }
        let ext = entry.url.pathExtension.lowercased()
        if ["md", "markdown", "mdx"].contains(ext) {
            if let content = try? String(contentsOf: entry.url, encoding: .utf8) {
                preview = .markdown(String(content.prefix(600)))
            } else { preview = .empty }
        } else if ext == "mmd" {
            if let content = try? String(contentsOf: entry.url, encoding: .utf8) {
                preview = .mermaid(String(content.prefix(400)))
            } else { preview = .empty }
        } else if let content = try? String(contentsOf: entry.url, encoding: .utf8) {
            preview = .plain(String(content.prefix(300)))
        } else {
            preview = .empty
        }
    }

    struct FolderItem: Hashable {
        let name: String
        let isDirectory: Bool
    }

    enum CardPreview {
        case loading
        case markdown(String)
        case mermaid(String)
        case folder([FolderItem])
        case plain(String)
        case empty
    }
}
