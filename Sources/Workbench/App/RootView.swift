import SwiftUI

struct RootView: View {
    @EnvironmentObject var services: AppServices

    var body: some View {
        ZStack {
            WorkbenchSurface()

            if services.needsWorkspace {
                WorkspacePickerView()
            } else {
                WorkspaceLayout()
            }

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
        HSplitView {
            if let ws = services.workspace {
                FileTreeView(workspace: ws)
                    .frame(minWidth: 220, idealWidth: 260, maxWidth: 340)
            }

            LayoutHostView()
                .frame(minWidth: 400)
        }
    }
}
