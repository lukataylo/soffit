import Combine
import Foundation

@MainActor
final class MarkdownActiveState: ObservableObject {
    @Published var mode: MarkdownPanelMode = .preview
    @Published var spellCheckEnabled: Bool = UserDefaults.standard.bool(forKey: "soffit.spellCheck") {
        didSet { UserDefaults.standard.set(spellCheckEnabled, forKey: "soffit.spellCheck") }
    }
    let commands = MarkdownEditorCommands()
    let panelID: PanelID

    init(panelID: PanelID) {
        self.panelID = panelID
    }
}

@MainActor
final class MarkdownStateRegistry {
    static let shared = MarkdownStateRegistry()
    private var map: [PanelID: MarkdownActiveState] = [:]

    func state(for panelID: PanelID) -> MarkdownActiveState {
        if let existing = map[panelID] { return existing }
        let state = MarkdownActiveState(panelID: panelID)
        map[panelID] = state
        return state
    }

    func existing(for panelID: PanelID) -> MarkdownActiveState? {
        map[panelID]
    }

    func cleanup(_ panelID: PanelID) {
        map.removeValue(forKey: panelID)
    }
}
