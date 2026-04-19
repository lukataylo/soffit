import SwiftUI

struct PanelHeaderView: View {
    let panel: Panel
    @EnvironmentObject var services: AppServices
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(accent.opacity(0.18))
                    .frame(width: 20, height: 20)
                Image(systemName: iconName(for: panel.scheme))
                    .foregroundStyle(accent)
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(displayTitle)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.primary)

            Spacer(minLength: 4)

            Button {
                services.layout.close(panel.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isHovered ? Color.primary : Color.secondary.opacity(0.6))
                    .frame(width: 18, height: 18)
                    .background(
                        Circle()
                            .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close panel")
            .onHover { isHovered = $0 }
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(headerBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var displayTitle: String {
        if !panel.title.isEmpty { return panel.title }
        if let url = panel.url, let host = url.host, !host.isEmpty { return host }
        return panel.source
    }

    private var accent: Color {
        switch panel.scheme {
        case "file": return Color(red: 0.38, green: 0.56, blue: 0.92)
        case "folder": return Color(red: 0.95, green: 0.55, blue: 0.35)
        case "mermaid": return Color(red: 0.60, green: 0.40, blue: 0.85)
        case "web": return Color(red: 0.35, green: 0.65, blue: 0.55)
        case "chat": return Color(red: 0.85, green: 0.42, blue: 0.55)
        default: return .secondary
        }
    }

    private var headerBackground: some View {
        ZStack {
            if services.layout.focused == panel.id {
                accent.opacity(0.08)
            }
            Rectangle()
                .fill(Color(nsColor: .underPageBackgroundColor).opacity(0.7))
        }
    }

    private func iconName(for scheme: String) -> String {
        switch scheme {
        case "file": return "doc.richtext.fill"
        case "folder": return "folder.fill"
        case "web": return "globe"
        case "mermaid": return "point.3.filled.connected.trianglepath.dotted"
        case "chat": return "bubble.left.and.bubble.right.fill"
        default: return "rectangle.fill"
        }
    }
}
