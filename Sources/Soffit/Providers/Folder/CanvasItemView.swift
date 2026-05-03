import SwiftUI

struct CanvasItemView: View {
    let item: CanvasItem
    let workspaceRoot: URL?
    let zoom: CGFloat
    let onMove: (CGPoint) -> Void
    let onDelete: () -> Void
    let onOpen: (URL) -> Void
    let onStickyText: (String) -> Void
    let onStickyColor: (StickyColor) -> Void

    @State private var dragOrigin: CGPoint? = nil

    var body: some View {
        Group {
            switch item.kind {
            case .file(let path):
                let url = absoluteURL(for: path)
                FilePreviewCard(
                    fileURL: url,
                    workspaceRoot: workspaceRoot,
                    onDelete: onDelete,
                    onOpen: { onOpen(url) },
                    dragHandle: dragGesture
                )
            case .stickyNote(let text, let color):
                StickyNoteView(
                    text: text,
                    color: color,
                    onTextChange: onStickyText,
                    onColorChange: onStickyColor,
                    onDelete: onDelete,
                    dragHandle: dragGesture
                )
            }
        }
        .frame(width: item.size.width, height: item.size.height)
    }

    private var dragGesture: AnyGesture<Void> {
        AnyGesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .global)
                .onChanged { value in
                    let origin = dragOrigin ?? item.position
                    if dragOrigin == nil { dragOrigin = origin }
                    let dx = value.translation.width / zoom
                    let dy = value.translation.height / zoom
                    onMove(CGPoint(x: origin.x + dx, y: origin.y + dy))
                }
                .onEnded { _ in dragOrigin = nil }
                .map { _ in () }
        )
    }

    private func absoluteURL(for path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        if let root = workspaceRoot {
            return root.appendingPathComponent(path)
        }
        return URL(fileURLWithPath: path)
    }
}
