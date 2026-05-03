import SwiftUI
import UniformTypeIdentifiers

struct CanvasFolderView: View {
    @ObservedObject var store: CanvasStore
    let workspaceRoot: URL?
    let onOpen: (URL) -> Void

    @State private var panStart: CGPoint? = nil
    @State private var zoomStart: CGFloat? = nil
    @State private var isDroppingTargeted = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                dottedGrid(size: proxy.size)

                itemsLayer
                    .scaleEffect(store.state.zoom, anchor: .topLeading)
                    .offset(x: store.state.pan.x, y: store.state.pan.y)

                floatingControls
                    .padding(14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
            .overlay {
                if isDroppingTargeted {
                    Rectangle()
                        .stroke(Color.accentColor.opacity(0.45), lineWidth: 2)
                        .background(Color.accentColor.opacity(0.05))
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(panGesture)
            .simultaneousGesture(zoomGesture)
            .onDrop(of: [.fileURL], isTargeted: $isDroppingTargeted) { providers, location in
                handleDrop(providers: providers, at: location, in: proxy.size)
            }
        }
    }

    // MARK: - Items

    private var itemsLayer: some View {
        ZStack(alignment: .topLeading) {
            ForEach(store.state.items) { item in
                CanvasItemView(
                    item: item,
                    workspaceRoot: workspaceRoot,
                    zoom: store.state.zoom,
                    onMove: { store.move(item.id, to: $0) },
                    onDelete: { store.remove(item.id) },
                    onOpen: onOpen,
                    onStickyText: { store.updateStickyText(item.id, text: $0) },
                    onStickyColor: { store.updateStickyColor(item.id, color: $0) }
                )
                .position(x: item.position.x + item.size.width / 2,
                          y: item.position.y + item.size.height / 2)
            }
        }
    }

    // MARK: - Background grid

    private func dottedGrid(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let zoom = store.state.zoom
            let spacing: CGFloat = 32 * zoom
            guard spacing > 6 else { return }
            let pan = store.state.pan
            let ox = pan.x.truncatingRemainder(dividingBy: spacing)
            let oy = pan.y.truncatingRemainder(dividingBy: spacing)
            let startX = (ox > 0 ? ox - spacing : ox)
            let startY = (oy > 0 ? oy - spacing : oy)
            let color = Color.secondary.opacity(0.18)
            let dotSize: CGFloat = 1.5
            var x = startX
            while x < canvasSize.width {
                var y = startY
                while y < canvasSize.height {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: dotSize, height: dotSize)),
                        with: .color(color)
                    )
                    y += spacing
                }
                x += spacing
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    // MARK: - Controls

    private var floatingControls: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Spacer()
            HStack(spacing: 8) {
                controlButton("plus.square.on.square", help: "Add sticky note") {
                    let center = viewportCenter()
                    store.addStickyNote(at: center)
                }
                controlButton("minus.magnifyingglass", help: "Zoom out") {
                    store.setZoom(store.state.zoom - 0.1)
                }
                Text("\(Int(store.state.zoom * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44)
                controlButton("plus.magnifyingglass", help: "Zoom in") {
                    store.setZoom(store.state.zoom + 0.1)
                }
                controlButton("viewfinder", help: "Reset view") {
                    store.setZoom(1.0); store.setPan(.zero)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
            )
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func controlButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 22)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if panStart == nil { panStart = store.state.pan }
                let start = panStart ?? .zero
                store.state.pan = CGPoint(x: start.x + value.translation.width,
                                          y: start.y + value.translation.height)
            }
            .onEnded { _ in
                panStart = nil
                store.setPan(store.state.pan)
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if zoomStart == nil { zoomStart = store.state.zoom }
                let start = zoomStart ?? 1.0
                store.state.zoom = clamp(start * value.magnification, CanvasState.zoomRange)
            }
            .onEnded { _ in
                zoomStart = nil
                store.setZoom(store.state.zoom)
            }
    }

    // MARK: - Drops

    private func handleDrop(providers: [NSItemProvider], at screenPoint: CGPoint, in size: CGSize) -> Bool {
        let canvasPoint = screenToCanvas(screenPoint)
        var handled = false
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        Task { @MainActor in
                            let path = relativePath(for: url)
                            store.addFile(at: path, position: canvasPoint)
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }

    private func relativePath(for url: URL) -> String {
        if let root = workspaceRoot, url.path.hasPrefix(root.path) {
            return String(url.path.dropFirst(root.path.count + (url.path.count > root.path.count ? 1 : 0)))
        }
        return url.path
    }

    private func screenToCanvas(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - store.state.pan.x) / store.state.zoom - 160,
                y: (p.y - store.state.pan.y) / store.state.zoom - 130)
    }

    private func viewportCenter() -> CGPoint {
        // Approx center of current viewport in canvas space
        CGPoint(x: -store.state.pan.x / store.state.zoom + 200,
                y: -store.state.pan.y / store.state.zoom + 200)
    }
}

private func clamp<T: Comparable>(_ v: T, _ range: ClosedRange<T>) -> T {
    min(max(v, range.lowerBound), range.upperBound)
}
