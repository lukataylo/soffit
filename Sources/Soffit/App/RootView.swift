import AppKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject var services: AppServices
    @StateObject private var session = WindowSession()
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

            if let mode = session.paletteMode {
                paletteOverlay(mode: mode)
            }

            if session.findReplaceVisible {
                findReplaceOverlay
            }
        }
        .environmentObject(session)
        .focusedSceneObject(session)
        .onAppear { session.bind(to: services) }
        .animation(.easeInOut(duration: 0.15), value: services.needsAPIKey)
        .animation(.easeInOut(duration: 0.15), value: services.needsWorkspace)
        .animation(.easeInOut(duration: 0.22), value: sidebarCollapsed)
        .animation(.easeOut(duration: 0.12), value: session.paletteMode)
        .animation(.easeOut(duration: 0.12), value: session.findReplaceVisible)
    }

    private func paletteOverlay(mode: SearchPaletteMode) -> some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { session.paletteMode = nil }
            SearchPalette(mode: mode,
                          onPick: { url in
                              session.paletteMode = nil
                              session.openFile(url, mode: .preview)
                          },
                          onClose: { session.paletteMode = nil })
                .padding(.top, 100)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var findReplaceOverlay: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { session.findReplaceVisible = false }
            FindReplaceSheet(onClose: { session.findReplaceVisible = false })
                .padding(.top, 100)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var titleBar: some View {
        TitleBarDragRegion()
            .frame(height: 28)
            .overlay(alignment: .leading) {
                if services.workspace != nil {
                    SidebarToggleButton(collapsed: $sidebarCollapsed)
                        .padding(.leading, 84)
                        .padding(.top, 6)
                }
            }
    }
}

private struct WorkspaceLayout: View {
    @EnvironmentObject var services: AppServices
    @Binding var sidebarCollapsed: Bool
    @State private var sidebarWidth: CGFloat = SidebarWidth.load()

    private static let minWidth: CGFloat = 180
    private static let maxWidth: CGFloat = 480

    var body: some View {
        HStack(spacing: 0) {
            if let ws = services.workspace, !sidebarCollapsed {
                FileTreeView(workspace: ws)
                    .frame(width: sidebarWidth)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                SidebarResizeHandle(width: $sidebarWidth,
                                    minWidth: Self.minWidth,
                                    maxWidth: Self.maxWidth)
            }
            LayoutHostView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private enum SidebarWidth {
    static let key = "soffit.sidebarWidth"

    static func load() -> CGFloat {
        let v = UserDefaults.standard.double(forKey: key)
        return v > 0 ? CGFloat(v) : 240
    }

    static func save(_ width: CGFloat) {
        UserDefaults.standard.set(Double(width), forKey: key)
    }
}

/// 5pt-wide invisible drag handle on the sidebar's right edge. Cursor flips to
/// the resize chevron on hover; drag updates a clamped width and persists on
/// release. No visible chrome — the gradient gutter between sidebar and panes
/// is the affordance.
private struct SidebarResizeHandle: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    @State private var dragStart: CGFloat?
    @State private var isHovered = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 5)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.resizeLeftRight.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStart == nil { dragStart = width }
                        let proposed = (dragStart ?? width) + value.translation.width
                        width = min(max(minWidth, proposed), maxWidth)
                    }
                    .onEnded { _ in
                        dragStart = nil
                        SidebarWidth.save(width)
                    }
            )
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
