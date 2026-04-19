import Foundation

struct PanelID: Hashable, Codable, CustomStringConvertible {
    let raw: UUID
    init(_ raw: UUID = UUID()) { self.raw = raw }
    var description: String { "panel-\(raw.uuidString.prefix(8))" }
}

struct SplitID: Hashable, Codable, CustomStringConvertible {
    let raw: UUID
    init(_ raw: UUID = UUID()) { self.raw = raw }
    var description: String { "split-\(raw.uuidString.prefix(8))" }
}
