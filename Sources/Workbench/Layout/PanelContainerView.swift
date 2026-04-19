import SwiftUI
import UniformTypeIdentifiers

struct PanelContainerView: View {
    let panel: Panel
    @EnvironmentObject var services: AppServices
    @State private var showTypePicker = false
    @State private var dropEdge: DropEdge? = nil

    var body: some View {
        VStack(spacing: 0) {
            PanelHeaderView(panel: panel)
            Divider()
            ZStack {
                providerView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                EdgeDropZones(dropEdge: $dropEdge) { edge in
                    dropEdge = edge
                    showTypePicker = true
                }
                .allowsHitTesting(true)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .overlay {
            if services.layout.focused == panel.id {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { services.layout.focused = panel.id }
        .sheet(isPresented: $showTypePicker) {
            PanelTypePicker { source, title in
                let newPanel = Panel(source: source, title: title)
                if let edge = dropEdge {
                    services.layout.splitAtEdge(of: panel.id, edge: edge, newPanel: newPanel)
                }
                dropEdge = nil
                showTypePicker = false
            } onCancel: {
                dropEdge = nil
                showTypePicker = false
            }
        }
    }

    @ViewBuilder
    private var providerView: some View {
        if let provider = services.registry.provider(for: panel) {
            provider.makeView(for: PanelSource(url: panel.url, panelID: panel.id),
                              context: services.panelContext())
        } else {
            UnknownPanelView(source: panel.source)
        }
    }
}

private struct UnknownPanelView: View {
    let source: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No provider for \(source)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
