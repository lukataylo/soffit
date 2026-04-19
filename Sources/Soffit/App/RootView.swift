import SwiftUI

struct RootView: View {
    @EnvironmentObject var services: AppServices

    var body: some View {
        ZStack(alignment: .top) {
            SoffitSurface()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TitleBarDragRegion()
                    .frame(height: 28)

                if services.needsWorkspace {
                    WorkspacePickerView()
                } else {
                    WorkspaceLayout()
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
    }
}

private struct WorkspaceLayout: View {
    @EnvironmentObject var services: AppServices

    var body: some View {
        HStack(spacing: 0) {
            if let ws = services.workspace {
                FileTreeView(workspace: ws)
                    .frame(width: 240)
            }
            LayoutHostView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
