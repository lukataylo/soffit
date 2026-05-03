import SwiftUI

struct RootView: View {
    @EnvironmentObject var services: AppServices
    @State private var sidebarCollapsed: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            SoffitSurface()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                titleBar

                if services.needsWorkspace {
                    WorkspacePickerView()
                } else {
                    WorkspaceLayout(sidebarCollapsed: $sidebarCollapsed)
                }
            }
            .ignoresSafeArea()

            if services.needsAPIKey {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: services.needsAPIKey)
        .animation(.easeInOut(duration: 0.15), value: services.needsWorkspace)
        .animation(.easeInOut(duration: 0.22), value: sidebarCollapsed)
    }

    private var titleBar: some View {
        TitleBarDragRegion()
            .frame(height: 28)
            .overlay(alignment: .leading) {
                if services.workspace != nil {
                    SidebarToggleButton(collapsed: $sidebarCollapsed)
                        .padding(.leading, 84)
                }
            }
    }
}

private struct WorkspaceLayout: View {
    @EnvironmentObject var services: AppServices
    @Binding var sidebarCollapsed: Bool

    var body: some View {
        HStack(spacing: 0) {
            if let ws = services.workspace, !sidebarCollapsed {
                FileTreeView(workspace: ws)
                    .frame(width: 240)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            LayoutHostView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct SidebarToggleButton: View {
    @Binding var collapsed: Bool
    @State private var isHovered = false

    var body: some View {
        Button {
            collapsed.toggle()
        } label: {
            Image(systemName: "sidebar.leading")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isHovered ? Color.primary : Color.secondary)
                .frame(width: 26, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(collapsed ? "Show sidebar" : "Hide sidebar")
    }
}
