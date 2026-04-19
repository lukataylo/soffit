import SwiftUI

struct LayoutHostView: View {
    @EnvironmentObject var services: AppServices

    var body: some View {
        Group {
            switch services.layout.tree {
            case .empty:
                EmptyStateView()
            default:
                LayoutTreeView(node: services.layout.tree)
            }
        }
    }
}

private struct EmptyStateView: View {
    @EnvironmentObject var services: AppServices

    var body: some View {
        ZStack {
            WorkbenchSurface()
            VStack(spacing: 14) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("No panels open")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
                if let ws = services.workspace {
                    Button {
                        let panel = Panel(source: FolderURL.makeSource(for: ws.root), title: ws.root.lastPathComponent)
                        services.layout.insert(panel: panel)
                    } label: {
                        Label("Back to \(ws.root.lastPathComponent)", systemImage: "house.fill")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

struct LayoutTreeView: View {
    let node: LayoutTree

    var body: some View {
        switch node {
        case .empty:
            Color.clear
        case .leaf(let panel):
            PanelContainerView(panel: panel)
        case .split(let id, let orientation, let ratio, let first, let second):
            SplitHost(splitID: id, orientation: orientation, ratio: ratio,
                      first: first, second: second)
        }
    }
}

private struct SplitHost: View {
    let splitID: SplitID
    let orientation: Orientation
    let ratio: CGFloat
    let first: LayoutTree
    let second: LayoutTree

    @EnvironmentObject var services: AppServices

    var body: some View {
        NSSplitViewRepresentable(
            orientation: orientation,
            ratio: ratio,
            onRatioChange: { newRatio in
                services.layout.setRatio(for: splitID, to: newRatio)
            },
            first: { LayoutTreeView(node: first).environmentObject(services) },
            second: { LayoutTreeView(node: second).environmentObject(services) }
        )
    }
}
