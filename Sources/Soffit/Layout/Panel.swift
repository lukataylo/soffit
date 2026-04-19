import Foundation

struct Panel: Codable, Hashable, Identifiable {
    let id: PanelID
    var source: String
    var title: String
    var state: Data?

    init(id: PanelID = PanelID(), source: String, title: String, state: Data? = nil) {
        self.id = id
        self.source = source
        self.title = title
        self.state = state
    }

    var url: URL? { URL(string: source) }
    var scheme: String { url?.scheme ?? "" }
}
