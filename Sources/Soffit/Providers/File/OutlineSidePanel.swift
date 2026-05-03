import SwiftUI

/// Side panel showing the active document's heading outline. Clicking a row
/// scrolls the editor — the parent owns the scroll target so this view stays
/// stateless.
struct OutlineSidePanel: View {
    let text: String
    let onClose: () -> Void
    let onSelect: (Int) -> Void   // line offset

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Outline")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let parsed = MarkdownParser.parse(text)
                    if parsed.headings.isEmpty {
                        Text("No headings yet")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(parsed.headings, id: \.charOffset) { h in
                            row(h)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
    }

    private func row(_ h: MarkdownParser.Heading) -> some View {
        Button {
            onSelect(h.lineOffset)
        } label: {
            HStack(spacing: 6) {
                Text(String(repeating: "  ", count: max(0, h.level - 1)))
                Text(h.text)
                    .font(.system(size: 12, weight: h.level == 1 ? .semibold : .regular))
                    .foregroundStyle(h.level <= 2 ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
