import SwiftUI

struct StickyNoteView: View {
    let text: String
    let color: StickyColor
    let onTextChange: (String) -> Void
    let onColorChange: (StickyColor) -> Void
    let onDelete: () -> Void
    let dragHandle: AnyGesture<Void>

    @State private var editingText: String
    @State private var isHovered = false

    init(text: String, color: StickyColor,
         onTextChange: @escaping (String) -> Void,
         onColorChange: @escaping (StickyColor) -> Void,
         onDelete: @escaping () -> Void,
         dragHandle: AnyGesture<Void>) {
        self.text = text
        self.color = color
        self.onTextChange = onTextChange
        self.onColorChange = onColorChange
        self.onDelete = onDelete
        self.dragHandle = dragHandle
        _editingText = State(initialValue: text)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            TextEditor(text: $editingText)
                .scrollContentBackground(.hidden)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .padding(10)
                .onChange(of: editingText) { _, new in
                    if new != text { onTextChange(new) }
                }
                .onChange(of: text) { _, new in
                    if new != editingText { editingText = new }
                }
            Divider().opacity(0.3)
            colorStrip
        }
        .background(noteBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "note.text")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Note")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.primary.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("Delete note")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .gesture(dragHandle)
    }

    private var colorStrip: some View {
        HStack(spacing: 6) {
            ForEach(StickyColor.allCases, id: \.self) { c in
                Circle()
                    .fill(swatch(for: c))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle().stroke(c == color ? Color.primary.opacity(0.5) : Color.primary.opacity(0.15),
                                        lineWidth: c == color ? 1.5 : 0.6)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onColorChange(c) }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var noteBackground: some View {
        Color(red: color.tint.r, green: color.tint.g, blue: color.tint.b, opacity: color.tint.bg)
    }

    private func swatch(for c: StickyColor) -> Color {
        Color(red: c.tint.r * 0.92, green: c.tint.g * 0.92, blue: c.tint.b * 0.92)
    }
}
