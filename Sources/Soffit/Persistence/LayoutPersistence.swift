import Foundation

struct LayoutSnapshot: Codable {
    var workspaceRoot: String
    var tree: LayoutTree
}

final class LayoutPersistence {
    private let url: URL

    init() {
        let fm = FileManager.default
        let base = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = (base ?? fm.temporaryDirectory).appendingPathComponent("Soffit", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent("layout.json")
    }

    func load() -> LayoutSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LayoutSnapshot.self, from: data)
    }

    func save(_ snapshot: LayoutSnapshot) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
