import Combine
import CoreGraphics
import Foundation

@MainActor
final class LayoutStore: ObservableObject {
    @Published private(set) var tree: LayoutTree
    @Published var focused: PanelID?

    init(tree: LayoutTree) {
        self.tree = tree
        self.focused = tree.firstPanelID()
    }

    func replace(with newTree: LayoutTree) {
        tree = newTree
        if let f = focused, !newTree.contains(f) { focused = newTree.firstPanelID() }
        if focused == nil { focused = newTree.firstPanelID() }
    }

    func insert(panel: Panel) {
        seedStateHolder(panel)
        tree = tree.inserting(panel)
        focused = panel.id
    }

    func split(target: PanelID, direction: Orientation, newPanel: Panel, side: InsertSide = .second) {
        seedStateHolder(newPanel)
        tree = tree.splitting(at: target, direction: direction, newPanel: newPanel, insertOn: side)
        focused = newPanel.id
    }

    func splitAtEdge(of target: PanelID, edge: DropEdge, newPanel: Panel) {
        seedStateHolder(newPanel)
        tree = tree.splittingAtEdge(of: target, edge: edge, newPanel: newPanel)
        focused = newPanel.id
    }

    private func seedStateHolder(_ panel: Panel) {
        if let state = panel.state {
            InitialStateHolder.shared.write(panel.id, state)
        }
    }

    func close(_ id: PanelID) {
        tree = tree.closing(id)
        if focused == id { focused = tree.firstPanelID() }
    }

    func setRatio(for split: SplitID, to ratio: CGFloat) {
        tree = tree.settingRatio(for: split, to: ratio)
    }

    func replacePanel(_ id: PanelID, with newPanel: Panel) {
        tree = tree.replacingPanel(id, with: newPanel)
        if focused == id { focused = newPanel.id }
    }

    func updateState(for id: PanelID, state: Data?) {
        tree = tree.updatingPanelState(id, state: state)
    }

    func splitFocused(_ direction: Orientation, insertOn side: InsertSide) {
        guard let f = focused else { return }
        let panel = Panel(source: "chat://claude/new", title: "New Panel")
        split(target: f, direction: direction, newPanel: panel, side: side)
    }

    func closeFocused() {
        guard let f = focused else { return }
        close(f)
    }

    func focusNext() {
        let ids = tree.panelIDs
        guard !ids.isEmpty else { return }
        guard let f = focused, let idx = ids.firstIndex(of: f) else {
            focused = ids.first; return
        }
        focused = ids[(idx + 1) % ids.count]
    }
}
