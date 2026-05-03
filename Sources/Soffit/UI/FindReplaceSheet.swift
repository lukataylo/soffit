import SwiftUI

/// Find / replace across the entire workspace. Reads the workspace index for
/// case-insensitive matches; replace writes the changed files back to disk.
struct FindReplaceSheet: View {
    let onClose: () -> Void

    @EnvironmentObject var services: AppServices
    @EnvironmentObject var session: WindowSession
    @State private var find: String = ""
    @State private var replace: String = ""
    @State private var caseSensitive: Bool = false
    @State private var hits: [Hit] = []
    @State private var status: String = ""
    @FocusState private var findFocused: Bool

    struct Hit: Identifiable, Hashable {
        let id = UUID()
        let url: URL
        let line: Int
        let snippet: String
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Find in workspace", text: $find)
                    .textFieldStyle(.plain)
                    .focused($findFocused)
                    .onSubmit { runFind() }
                Button("Find") { runFind() }
                    .keyboardShortcut(.defaultAction)
                Button("Cancel") { onClose() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.secondary)
                TextField("Replace with (optional)", text: $replace)
                    .textFieldStyle(.plain)
                Toggle("Aa", isOn: $caseSensitive)
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .help("Case sensitive")
                Button("Replace All") { runReplace() }
                    .disabled(hits.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            if !status.isEmpty {
                Text(status)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(hits) { hit in
                        HStack(spacing: 8) {
                            Image(systemName: "doc.richtext")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(red: 0.38, green: 0.56, blue: 0.92))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hit.url.lastPathComponent)
                                    .font(.system(size: 12, weight: .medium))
                                Text("L\(hit.line + 1): \(hit.snippet)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            session.openFile(hit.url, mode: .edit)
                            onClose()
                        }
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .frame(width: 600)
        .onAppear { findFocused = true }
    }

    private func runFind() {
        let q = find.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { hits = []; status = ""; return }
        var collected: [Hit] = []
        let needle = caseSensitive ? q : q.lowercased()
        for entry in services.index.files.values {
            // We have lowercaseContent in the index. For case-sensitive search, re-read.
            let haystack: String
            if caseSensitive {
                haystack = (try? String(contentsOf: entry.url, encoding: .utf8)) ?? ""
            } else {
                haystack = entry.lowercaseContent
            }
            for (i, line) in haystack.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                if line.contains(needle) {
                    collected.append(Hit(url: entry.url,
                                         line: i,
                                         snippet: String(line.prefix(120))))
                    if collected.count > 500 { break }
                }
            }
            if collected.count > 500 { break }
        }
        hits = collected
        status = hits.isEmpty
            ? "No matches in \(services.index.files.count) files"
            : "\(hits.count) match\(hits.count == 1 ? "" : "es") in \(Set(hits.map { $0.url }).count) file\(Set(hits.map { $0.url }).count == 1 ? "" : "s")"
    }

    private func runReplace() {
        let q = find.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        let urls = Set(hits.map { $0.url })
        var changedFiles = 0
        var totalReplacements = 0
        for url in urls {
            guard let original = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let updated: String
            if caseSensitive {
                updated = original.replacingOccurrences(of: q, with: replace)
            } else {
                updated = original.replacingOccurrences(of: q, with: replace, options: .caseInsensitive)
            }
            if updated != original {
                if (try? updated.write(to: url, atomically: true, encoding: .utf8)) != nil {
                    changedFiles += 1
                    let countDiff = (original.components(separatedBy: q).count - 1)
                    totalReplacements += countDiff
                }
            }
        }
        Task { await services.index.refreshAll() }
        status = "Replaced \(totalReplacements) occurrence\(totalReplacements == 1 ? "" : "s") in \(changedFiles) file\(changedFiles == 1 ? "" : "s")"
        runFind()
    }
}
