import SwiftUI

struct FolderPanelView: View {
    let source: PanelSource
    let context: PanelContext

    @EnvironmentObject var services: AppServices

    private var folderURL: URL? { FolderURL.folder(from: source) }

    var body: some View {
        FolderGridView(
            folderURL: folderURL,
            workspaceRoot: services.workspace?.root,
            onOpen: openEntry,
            onNavigateFolder: navigateFolder
        )
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func openEntry(_ entry: FSEntry) {
        if entry.isDirectory {
            navigateFolder(entry.url)
        } else {
            services.openFile(entry.url, mode: .preview)
        }
    }

    private func navigateFolder(_ url: URL) {
        // Replace this panel's source URL with the new folder (in-place navigation).
        let updated = Panel(id: source.panelID, source: FolderURL.makeSource(for: url), title: url.lastPathComponent)
        services.layout.replacePanel(source.panelID, with: updated)
    }
}
