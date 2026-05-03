import SwiftUI

/// Side panel listing files that wiki-link to the current one. Read straight
/// from the workspace index — refreshes automatically as the index updates.
struct BacklinksSidePanel: View {
    let fileURL: URL
    let onClose: () -> Void
    let onOpen: (URL) -> Void

    @EnvironmentObject var services: AppServices

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Backlinks")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let backlinks = services.index.backlinksTo(fileURL)
                    if backlinks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No backlinks yet")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.tertiary)
                            Text("Other notes link to this one with `[[\(fileURL.deletingPathExtension().lastPathComponent)]]`.")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    } else {
                        ForEach(backlinks, id: \.url) { entry in
                            row(entry)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
    }

    private func row(_ entry: WorkspaceIndex.IndexedFile) -> some View {
        Button {
            onOpen(entry.url)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(entry.url.lastPathComponent)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
