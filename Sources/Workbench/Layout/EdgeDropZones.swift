import SwiftUI

struct EdgeDropZones: View {
    @Binding var dropEdge: DropEdge?
    let onSelect: (DropEdge) -> Void
    @State private var hover: DropEdge? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                zone(.left, rect: CGRect(x: 0, y: 0, width: 18, height: geo.size.height))
                zone(.right, rect: CGRect(x: geo.size.width - 18, y: 0, width: 18, height: geo.size.height))
                zone(.top, rect: CGRect(x: 0, y: 0, width: geo.size.width, height: 18))
                zone(.bottom, rect: CGRect(x: 0, y: geo.size.height - 18, width: geo.size.width, height: 18))
            }
            .overlay(alignment: .topTrailing) {
                if hover != nil {
                    VStack(spacing: 4) {
                        Text("Drop to split")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .padding(6)
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private func zone(_ edge: DropEdge, rect: CGRect) -> some View {
        Rectangle()
            .fill(hover == edge ? Color.accentColor.opacity(0.25) : Color.clear)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .contentShape(Rectangle())
            .onHover { hover = $0 ? edge : (hover == edge ? nil : hover) }
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onEnded { _ in
                        onSelect(edge)
                        hover = nil
                    }
            )
    }
}
