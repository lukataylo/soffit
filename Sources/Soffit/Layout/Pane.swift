import Foundation

struct PaneID: Hashable, Codable, CustomStringConvertible {
    let raw: UUID
    init(_ raw: UUID = UUID()) { self.raw = raw }
    var description: String { "pane-\(raw.uuidString.prefix(8))" }
}

struct Pane: Hashable, Codable, Identifiable {
    let id: PaneID
    var tabs: [Panel]
    var activeTabID: PanelID?

    init(id: PaneID = PaneID(), tabs: [Panel] = [], activeTabID: PanelID? = nil) {
        self.id = id
        self.tabs = tabs
        self.activeTabID = activeTabID ?? tabs.first?.id
    }

    var activeTab: Panel? {
        if let id = activeTabID, let t = tabs.first(where: { $0.id == id }) { return t }
        return tabs.first
    }

    var isEmpty: Bool { tabs.isEmpty }

    func contains(_ panelID: PanelID) -> Bool { tabs.contains(where: { $0.id == panelID }) }

    mutating func addTab(_ panel: Panel, focus: Bool = true) {
        tabs.append(panel)
        if focus { activeTabID = panel.id }
    }

    mutating func removeTab(_ panelID: PanelID) {
        guard let idx = tabs.firstIndex(where: { $0.id == panelID }) else { return }
        tabs.remove(at: idx)
        if activeTabID == panelID {
            if tabs.isEmpty {
                activeTabID = nil
            } else {
                let next = min(idx, tabs.count - 1)
                activeTabID = tabs[next].id
            }
        }
    }

    mutating func setActive(_ panelID: PanelID) {
        if tabs.contains(where: { $0.id == panelID }) {
            activeTabID = panelID
        }
    }
}
