import SwiftUI

struct PaneView: View {
    let pane: Pane
    @EnvironmentObject var services: AppServices
    @State private var showSplitPickerFor: Orientation? = nil
    @State private var showAddPicker = false
    @State private var showURLPicker = false
    @State private var paneSize: CGSize = .zero
    @State private var isDropTargeted: Bool = false
    @State private var dropDirection: DropDirection? = nil

    private var isFocused: Bool { services.layout.focusedPane == pane.id }
    private let tabStripHeight: CGFloat = 36

    var body: some View {
        unifiedCard
            .padding(6)
        .sheet(isPresented: $showAddPicker) {
            FilePickerSheet(
                title: "Add tab",
                folderURL: currentFolderURL(),
                workspaceRoot: services.workspace?.root
            ) { url in
                showAddPicker = false
                if let url { openAsTab(url) }
            }
        }
        .sheet(isPresented: $showURLPicker) {
            PanelTypePicker(
                onChoose: { source, title in
                    showURLPicker = false
                    let panel = Panel(source: source, title: title)
                    services.layout.addTab(panel, toPane: pane.id)
                },
                onCancel: { showURLPicker = false }
            )
        }
        .sheet(isPresented: Binding(
            get: { showSplitPickerFor != nil },
            set: { if !$0 { showSplitPickerFor = nil } }
        )) {
            FilePickerSheet(
                title: showSplitPickerFor == .horizontal ? "Split right with…" : "Split down with…",
                folderURL: currentFolderURL(),
                workspaceRoot: services.workspace?.root
            ) { url in
                let direction = showSplitPickerFor
                showSplitPickerFor = nil
                if let url, let direction { splitWith(url, direction: direction) }
            }
        }
    }

    private var unifiedCard: some View {
        VStack(spacing: 0) {
            TabStripView(
                pane: pane,
                isFocused: isFocused,
                onSelectTab: { services.layout.setActiveTab(in: pane.id, to: $0) },
                onCloseTab: { services.layout.closeTab($0) },
                onAddTab: { showAddPicker = true },
                onAddTabFromURL: { showURLPicker = true },
                onAddTerminal: { services.openTerminal(in: services.workspace?.root) },
                onAddChat: {
                    let panel = Panel(source: "chat://claude", title: "Claude")
                    services.layout.addTab(panel, toPane: pane.id)
                },
                onSplitRight: { showSplitPickerFor = .horizontal },
                onSplitDown: { showSplitPickerFor = .vertical },
                onClosePane: { services.layout.closePane(pane.id) },
                onTabDropOnBar: { panelID in
                    services.layout.moveTabToPane(panelID, targetPaneID: pane.id)
                }
            )
            .frame(height: tabStripHeight)

            if let state = markdownStateForActiveTab, let fileName = activeTabFileName {
                MarkdownToolbarPill(state: state, fileName: fileName)
                    .padding(.horizontal, 6)
                    .padding(.top, 6)
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }

            content
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.97))
        )
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { paneSize = proxy.size }
                    .onChange(of: proxy.size) { _, new in paneSize = new }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? Color.accentColor.opacity(0.32) : Color.primary.opacity(0.05),
                        lineWidth: isFocused ? 1.2 : 0.6)
                .allowsHitTesting(false)
        )
        .overlay {
            if isDropTargeted {
                CompassOverlay(direction: dropDirection)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isDropTargeted)
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 2)
        .onDrop(of: [.text], delegate: TabDropDelegate(
            paneID: pane.id,
            services: services,
            paneSizeProvider: { paneSize },
            tabBarInset: tabStripHeight,
            isTargeted: $isDropTargeted,
            dropDirection: $dropDirection
        ))
    }

    @ViewBuilder
    private var content: some View {
        if let active = pane.activeTab {
            activeTabContent(active)
                .id(active.id)
        } else {
            EmptyPaneView()
        }
    }

    @ViewBuilder
    private func activeTabContent(_ panel: Panel) -> some View {
        if let provider = services.registry.provider(for: panel) {
            provider.makeView(
                for: PanelSource(url: panel.url, panelID: panel.id),
                context: services.panelContext()
            )
        } else {
            UnknownPanelView(source: panel.source)
        }
    }

    // MARK: - Active-tab helpers

    private var markdownStateForActiveTab: MarkdownActiveState? {
        guard let active = pane.activeTab,
              active.scheme == "file",
              let url = active.url,
              ["md", "markdown", "mdx"].contains(url.pathExtension.lowercased()) else { return nil }
        return MarkdownStateRegistry.shared.state(for: active.id)
    }

    private var activeTabFileName: String? {
        guard let active = pane.activeTab,
              let url = active.url else { return nil }
        return url.lastPathComponent
    }

    private func currentFolderURL() -> URL? {
        if let active = pane.activeTab,
           active.scheme == "folder",
           let url = FolderURL.folder(from: PanelSource(url: active.url, panelID: active.id)) {
            return url
        }
        return services.workspace?.root
    }

    private func openAsTab(_ url: URL) {
        services.openFile(url, mode: .preview)
    }

    private func splitWith(_ url: URL, direction: Orientation) {
        services.splitPaneWithFile(pane.id, direction: direction, url: url)
    }
}

private struct EmptyPaneView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.dashed")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Empty pane")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
