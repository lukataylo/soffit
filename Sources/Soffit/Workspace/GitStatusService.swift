import Combine
import Foundation

/// Lightweight git status reader. Shells out to `git status --porcelain=v1`
/// in the workspace root and exposes a per-file status map.
///
/// Pro variant only. The App Store build is sandboxed and forbids
/// subprocess execution; under `!SOFFIT_PRO` this class is a no-op stub
/// that satisfies the API surface (`status(for:)`, `bind(to:)`,
/// `notifyChange()`) but never invokes `Process`.
@MainActor
final class GitStatusService: ObservableObject {
    enum Status: String {
        case modified, untracked, staged, ignored, conflicted, clean
    }

    @Published private(set) var statuses: [URL: Status] = [:]
    @Published private(set) var isGitRepo: Bool = false
    @Published private(set) var branch: String = ""

    func status(for url: URL) -> Status {
        statuses[url.standardizedFileURL] ?? .clean
    }

    #if SOFFIT_PRO
    private var workspaceRoot: URL?
    private var timer: Timer?
    private var debounce: AnyCancellable?
    private let trigger = PassthroughSubject<Void, Never>()

    init() {
        debounce = trigger
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.refresh() }
    }

    func bind(to root: URL) {
        workspaceRoot = root
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    func notifyChange() {
        trigger.send()
    }

    private func refresh() {
        guard let root = workspaceRoot else { return }
        Task.detached { [weak self] in
            let porcelain = Self.runGit(["status", "--porcelain=v1", "--ignored=no"], in: root)
            let branch = Self.runGit(["rev-parse", "--abbrev-ref", "HEAD"], in: root).trimmingCharacters(in: .whitespacesAndNewlines)
            let parsed = Self.parsePorcelain(porcelain, root: root)
            await MainActor.run {
                guard let self else { return }
                self.statuses = parsed
                self.isGitRepo = !branch.isEmpty && !branch.hasPrefix("fatal:")
                self.branch = self.isGitRepo ? branch : ""
            }
        }
    }

    private nonisolated static func runGit(_ args: [String], in root: URL) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["git", "-C", root.path] + args
        proc.standardError = Pipe()
        let outPipe = Pipe()
        proc.standardOutput = outPipe
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return ""
        }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private nonisolated static func parsePorcelain(_ raw: String, root: URL) -> [URL: Status] {
        var out: [URL: Status] = [:]
        for line in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            guard line.count > 3 else { continue }
            let xy = line.prefix(2)
            let path = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
            // Handle renames like "R  old -> new"
            let resolved = path.contains(" -> ")
                ? path.components(separatedBy: " -> ").last ?? String(path)
                : String(path)
            let url = root.appendingPathComponent(resolved).standardizedFileURL
            let status: Status
            switch xy {
            case "??":  status = .untracked
            case "!!":  status = .ignored
            case "UU", "AA", "DD", "AU", "UA", "UD", "DU": status = .conflicted
            default:
                let staged = xy.first ?? " "
                let unstaged = xy.dropFirst().first ?? " "
                if staged != " " && unstaged == " " {
                    status = .staged
                } else if unstaged != " " {
                    status = .modified
                } else {
                    status = .clean
                }
            }
            out[url] = status
        }
        return out
    }
    #else
    init() {}
    func bind(to root: URL) {}
    func notifyChange() {}
    #endif
}
