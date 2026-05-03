import SwiftUI

struct TabPillView: View {
    let tab: Panel
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false
    @State private var closeHovered = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(tab.title.isEmpty ? tab.source : tab.title)
                    .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 180)
            }
            .padding(.leading, 10)
            .padding(.trailing, 4)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
            .onDrag {
                NSItemProvider(object: tab.id.raw.uuidString as NSString)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(tab.title.isEmpty ? tab.source : tab.title))
            .accessibilityHint(Text("Double-click to activate"))
            .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(closeHovered ? Color.primary : Color.secondary.opacity(0.55))
                    .frame(width: 16, height: 16)
                    .background(
                        Circle().fill(closeHovered ? Color.primary.opacity(0.1) : Color.clear)
                    )
                    .padding(.trailing, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { closeHovered = $0 }
            .accessibilityLabel("Close tab")
            .help("Close tab")
        }
        .background(pillBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(isActive ? Color.primary.opacity(0.12) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }

    private var pillBackground: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(isActive
                ? Color(nsColor: .textBackgroundColor)
                : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
    }

    private var iconName: String {
        switch tab.scheme {
        case "file": return "doc.richtext.fill"
        case "folder": return "square.grid.2x2.fill"
        case "mermaid": return "point.3.filled.connected.trianglepath.dotted"
        case "https", "http", "web": return "globe"
        case "chat": return "bubble.left.and.bubble.right.fill"
        case "sketch": return "pencil.and.scribble"
        default: return "doc"
        }
    }

    private var tint: Color {
        switch tab.scheme {
        case "file": return Color(red: 0.38, green: 0.56, blue: 0.92)
        case "folder": return Color(red: 0.95, green: 0.55, blue: 0.35)
        case "mermaid": return Color(red: 0.60, green: 0.40, blue: 0.85)
        case "https", "http", "web": return Color(red: 0.35, green: 0.65, blue: 0.55)
        case "chat": return Color(red: 0.85, green: 0.42, blue: 0.55)
        case "sketch": return Color(red: 0.92, green: 0.55, blue: 0.45)
        default: return .secondary
        }
    }
}
