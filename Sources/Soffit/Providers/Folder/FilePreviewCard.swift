import AppKit
import MarkdownUI
import PDFKit
import SwiftUI

/// Renders live preview content for a file URL inside a canvas card.
/// Extension-dispatched: markdown, PDF, image, mermaid, plain text, unknown.
struct FilePreviewCard: View {
    let fileURL: URL
    let workspaceRoot: URL?
    let onDelete: () -> Void
    let onOpen: () -> Void
    let dragHandle: AnyGesture<Void>

    @State private var isHeaderHovered = false
    @State private var loadedText: String? = nil
    @State private var loadedImage: NSImage? = nil
    @State private var loadFailed: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
        .onAppear { loadIfNeeded() }
        .onChange(of: fileURL) { _, _ in
            loadedText = nil
            loadedImage = nil
            loadFailed = false
            loadIfNeeded()
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(fileURL.lastPathComponent)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if isHeaderHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Remove from canvas")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { isHeaderHovered = $0 }
        .onTapGesture(count: 2) { onOpen() }
        .gesture(dragHandle)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .markdown:
            markdownPreview
        case .pdf:
            PDFPreview(url: fileURL)
        case .image:
            imagePreview
        case .mermaid:
            mermaidPreview
        case .text:
            textPreview
        case .unknown:
            unknownFallback
        }
    }

    // MARK: - Content types

    private var markdownPreview: some View {
        ScrollView {
            Markdown(loadedText ?? "")
                .markdownTheme(.gitHub)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let nsImage = loadedImage {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.02))
        } else if loadFailed {
            unknownFallback
        } else {
            Color.clear
        }
    }

    private var mermaidPreview: some View {
        let url = URL(string: "mermaid://\(relativeMermaidPath())") ?? fileURL
        let spec = WebURLResolver.resolve(url: url, workspaceRoot: workspaceRoot)
        return MermaidMini(spec: spec)
    }

    private var textPreview: some View {
        ScrollView {
            Text(loadedText ?? "")
                .font(.system(size: 11.5, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .textSelection(.enabled)
        }
    }

    // MARK: - Loading

    private func loadIfNeeded() {
        let url = fileURL
        let kind = self.kind
        switch kind {
        case .markdown, .text:
            guard loadedText == nil, !loadFailed else { return }
            Task.detached(priority: .userInitiated) {
                let text = try? String(contentsOf: url, encoding: .utf8)
                await MainActor.run {
                    if let text { self.loadedText = text } else { self.loadFailed = true }
                }
            }
        case .image:
            guard loadedImage == nil, !loadFailed else { return }
            Task.detached(priority: .userInitiated) {
                let image = NSImage(contentsOf: url)
                await MainActor.run {
                    if let image { self.loadedImage = image } else { self.loadFailed = true }
                }
            }
        case .pdf, .mermaid, .unknown:
            // PDFKit and the mermaid shim load asynchronously themselves.
            break
        }
    }

    private var unknownFallback: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text(fileURL.pathExtension.uppercased().isEmpty ? "FILE" : fileURL.pathExtension.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private enum Kind { case markdown, pdf, image, mermaid, text, unknown }

    private var kind: Kind {
        switch fileURL.pathExtension.lowercased() {
        case "md", "markdown", "mdx": return .markdown
        case "pdf": return .pdf
        case "png", "jpg", "jpeg", "heic", "gif", "tiff", "bmp": return .image
        case "mmd": return .mermaid
        case "txt", "json", "yml", "yaml", "toml", "swift", "py", "js", "ts", "rb", "go", "rs", "c", "h", "m", "sh":
            return .text
        default: return .unknown
        }
    }

    private var iconName: String {
        switch kind {
        case .markdown: return "doc.richtext.fill"
        case .pdf: return "doc.fill"
        case .image: return "photo.fill"
        case .mermaid: return "point.3.filled.connected.trianglepath.dotted"
        case .text: return "doc.plaintext.fill"
        case .unknown: return "doc"
        }
    }

    private var tint: Color {
        switch kind {
        case .markdown: return Color(red: 0.38, green: 0.56, blue: 0.92)
        case .pdf: return Color(red: 0.85, green: 0.35, blue: 0.35)
        case .image: return Color(red: 0.45, green: 0.75, blue: 0.55)
        case .mermaid: return Color(red: 0.60, green: 0.40, blue: 0.85)
        case .text: return .secondary
        case .unknown: return .secondary
        }
    }

    private func relativeMermaidPath() -> String {
        guard let root = workspaceRoot else { return fileURL.path }
        if fileURL.path.hasPrefix(root.path) {
            var rel = String(fileURL.path.dropFirst(root.path.count))
            if !rel.hasPrefix("/") { rel = "/" + rel }
            return rel
        }
        return fileURL.path
    }
}

// MARK: - PDF preview

private struct PDFPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let pdf = PDFView()
        pdf.autoScales = true
        pdf.backgroundColor = .clear
        pdf.displayMode = .singlePageContinuous
        pdf.displayDirection = .vertical
        pdf.document = PDFDocument(url: url)
        return pdf
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document?.documentURL != url {
            nsView.document = PDFDocument(url: url)
        }
    }
}

// MARK: - Mermaid mini view (reuses WebViewRepresentable)

private struct MermaidMini: View {
    let spec: WebLoadSpec

    var body: some View {
        WebViewRepresentable(model: model, spec: spec)
    }

    @StateObject private var model = WebPanelModel()
}
