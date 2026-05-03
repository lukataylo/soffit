import SwiftUI

struct SketchProvider: PanelProvider {
    static let scheme = "sketch"
    static let displayName = "Sketch"

    func makeView(for source: PanelSource, context: PanelContext) -> AnyView {
        AnyView(SketchPanelView(source: source, context: context))
    }
}

struct SketchState: Codable, Equatable {
    var strokes: [Stroke] = []

    // Equatable only — `[CGPoint]` synthesises Equatable but not Hashable
    // on Swift 5.10 (CI's Xcode 15.4 toolchain). Hashable isn't actually
    // needed on Stroke anywhere.
    struct Stroke: Codable, Equatable {
        var color: ColorRGB
        var width: CGFloat
        var points: [CGPoint]
    }

    // ColorRGB stays Hashable: it's used as `ForEach(id: \.self)` in the
    // colour palette below.
    struct ColorRGB: Codable, Hashable {
        var r: Double
        var g: Double
        var b: Double
        var a: Double
    }
}

struct SketchPanelView: View {
    let source: PanelSource
    let context: PanelContext

    @State private var state: SketchState
    @State private var currentStroke: SketchState.Stroke? = nil
    @State private var brushColor: SketchState.ColorRGB = .init(r: 0.13, g: 0.13, b: 0.13, a: 1.0)
    @State private var brushWidth: CGFloat = 3

    init(source: PanelSource, context: PanelContext) {
        self.source = source
        self.context = context
        if let data = InitialStateHolder.shared.read(source.panelID),
           let decoded = try? JSONDecoder().decode(SketchState.self, from: data) {
            _state = State(initialValue: decoded)
        } else {
            _state = State(initialValue: SketchState())
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { ctx, _ in
                for stroke in state.strokes { draw(stroke: stroke, in: &ctx) }
                if let s = currentStroke { draw(stroke: s, in: &ctx) }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in extendStroke(to: v.location) }
                    .onEnded { _ in commitStroke() }
            )
            .background(Color(nsColor: .textBackgroundColor))

            controls
                .padding(14)
        }
    }

    private func draw(stroke: SketchState.Stroke, in ctx: inout GraphicsContext) {
        guard let first = stroke.points.first else { return }
        var path = Path()
        path.move(to: first)
        for p in stroke.points.dropFirst() { path.addLine(to: p) }
        let color = Color(.sRGB, red: stroke.color.r, green: stroke.color.g, blue: stroke.color.b, opacity: stroke.color.a)
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
    }

    private func extendStroke(to point: CGPoint) {
        if currentStroke == nil {
            currentStroke = SketchState.Stroke(color: brushColor, width: brushWidth, points: [point])
        } else {
            currentStroke?.points.append(point)
        }
    }

    private func commitStroke() {
        guard let s = currentStroke else { return }
        state.strokes.append(s)
        currentStroke = nil
        persist()
    }

    private func persist() {
        let data = try? JSONEncoder().encode(state)
        context.savePanelState(source.panelID, data)
    }

    private var controls: some View {
        HStack(spacing: 6) {
            ForEach(palette, id: \.self) { rgb in
                Circle()
                    .fill(Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: rgb.a))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle().stroke(Color.primary.opacity(brushColor == rgb ? 0.6 : 0.15),
                                        lineWidth: brushColor == rgb ? 2 : 0.6)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { brushColor = rgb }
            }
            Divider().frame(height: 16)
            ForEach([1.5, 3.0, 6.0] as [CGFloat], id: \.self) { w in
                Circle()
                    .fill(Color.primary.opacity(0.7))
                    .frame(width: w * 2, height: w * 2)
                    .padding(.horizontal, 4)
                    .background(brushWidth == w ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                    .contentShape(Rectangle())
                    .onTapGesture { brushWidth = w }
            }
            Divider().frame(height: 16)
            Button(action: undoStroke) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 18)
            }
            .buttonStyle(.plain)
            .disabled(state.strokes.isEmpty)
            .help("Undo last stroke")
            Button(action: clearAll) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 18)
            }
            .buttonStyle(.plain)
            .disabled(state.strokes.isEmpty)
            .help("Clear sketch")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 0.8)
        )
    }

    private var palette: [SketchState.ColorRGB] {
        [
            .init(r: 0.13, g: 0.13, b: 0.13, a: 1.0),       // ink
            .init(r: 0.92, g: 0.36, b: 0.48, a: 1.0),       // pink
            .init(r: 0.96, g: 0.62, b: 0.42, a: 1.0),       // coral
            .init(r: 0.45, g: 0.75, b: 0.55, a: 1.0),       // green
            .init(r: 0.38, g: 0.56, b: 0.92, a: 1.0),       // blue
            .init(r: 0.60, g: 0.40, b: 0.85, a: 1.0)        // purple
        ]
    }

    private func undoStroke() {
        guard !state.strokes.isEmpty else { return }
        state.strokes.removeLast()
        persist()
    }

    private func clearAll() {
        state.strokes.removeAll()
        persist()
    }
}
