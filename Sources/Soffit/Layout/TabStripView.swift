import SwiftUI
import UniformTypeIdentifiers

struct TabStripView: View {
    let pane: Pane
    let isFocused: Bool
    let onSelectTab: (PanelID) -> Void
    let onCloseTab: (PanelID) -> Void
    let onAddTab: () -> Void
    let onAddTabFromURL: () -> Void
    let onSplitRight: () -> Void
    let onSplitDown: () -> Void
    let onClosePane: () -> Void
    let onTabDropOnBar: (PanelID) -> Void

    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(pane.tabs) { tab in
                        TabPillView(
                            tab: tab,
                            isActive: pane.activeTabID == tab.id,
                            onSelect: { onSelectTab(tab.id) },
                            onClose: { onCloseTab(tab.id) }
                        )
                    }
                    Spacer(minLength: 4)
                }
                .padding(.leading, 8)
                .padding(.vertical, 6)
            }

            addTabButton.padding(.trailing, 4)
            paneMenu.padding(.trailing, 8)
        }
        .frame(height: 36)
        .background(
            Rectangle()
                .fill(isDropTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .overlay(alignment: .bottom) {
            if isDropTargeted {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isDropTargeted)
        .onDrop(of: [.text], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadObject(ofClass: NSString.self) { obj, _ in
                guard let str = obj as? String, let uuid = UUID(uuidString: str) else { return }
                Task { @MainActor in onTabDropOnBar(PanelID(uuid)) }
            }
            return true
        }
    }

    private var addTabButton: some View {
        Menu {
            Button { onAddTab() } label: { Label("Add File…", systemImage: "doc.fill") }
            Button { onAddTabFromURL() } label: { Label("Add URL or Diagram…", systemImage: "link") }
            Divider()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Add tab")
    }

    private var paneMenu: some View {
        Menu {
            Button { onSplitRight() } label: { Label("Split Right", systemImage: "rectangle.split.2x1") }
            Button { onSplitDown() } label: { Label("Split Down", systemImage: "rectangle.split.1x2") }
            Divider()
            Button(role: .destructive) { onClosePane() } label: { Label("Close Pane", systemImage: "xmark.rectangle") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Pane actions")
    }
}
