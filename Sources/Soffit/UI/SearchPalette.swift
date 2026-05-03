import SwiftUI

enum SearchPaletteMode: Hashable {
    case fileName
    case content
}

struct SearchPalette: View {
    let mode: SearchPaletteMode
    let onPick: (URL) -> Void
    let onClose: () -> Void

    @EnvironmentObject var services: AppServices
    @State private var query: String = ""
    @State private var hits: [WorkspaceIndex.SearchHit] = []
    @State private var selection: Int = 0
    @FocusState private var queryFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: mode == .fileName ? "magnifyingglass" : "text.magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($queryFocused)
                    .onSubmit { commit() }
                if !hits.isEmpty {
                    Text("\(hits.count)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Button("Cancel") { onClose() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(hits.enumerated()), id: \.element.id) { idx, hit in
                            row(hit, isSelected: idx == selection)
                                .id(idx)
                                .onTapGesture { selection = idx; commit() }
                        }
                    }
                }
                .onChange(of: selection) { _, new in
                    withAnimation(.easeOut(duration: 0.08)) { proxy.scrollTo(new, anchor: .center) }
                }
            }
            .frame(maxHeight: 360)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .frame(width: 560)
        .onAppear {
            queryFocused = true
            refresh()
        }
        .onChange(of: query) { _, _ in
            selection = 0
            refresh()
        }
        .onKeyPress(.upArrow) { selection = max(0, selection - 1); return .handled }
        .onKeyPress(.downArrow) { selection = min(max(0, hits.count - 1), selection + 1); return .handled }
        .onKeyPress(.return) { commit(); return .handled }
        .onKeyPress(.escape) { onClose(); return .handled }
    }

    private var placeholder: String {
        switch mode {
        case .fileName: return "Jump to file…"
        case .content: return "Search in workspace…"
        }
    }

    private func row(_ hit: WorkspaceIndex.SearchHit, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.richtext.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.38, green: 0.56, blue: 0.92))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(hit.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                if mode == .content {
                    Text(hit.snippet)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let h = hit.matchedHeading, !h.isEmpty {
                    Text("# " + h)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                } else {
                    Text(relativePath(hit.url))
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        .contentShape(Rectangle())
    }

    private func relativePath(_ url: URL) -> String {
        guard let root = services.workspace?.root else { return url.path }
        if url.path.hasPrefix(root.path) {
            let rel = url.path.dropFirst(root.path.count)
            return rel.hasPrefix("/") ? String(rel.dropFirst()) : String(rel)
        }
        return url.path
    }

    private func refresh() {
        switch mode {
        case .fileName:
            hits = services.index.searchByName(query)
        case .content:
            hits = services.index.searchByContent(query)
        }
    }

    private func commit() {
        guard hits.indices.contains(selection) else { return }
        onPick(hits[selection].url)
    }
}
