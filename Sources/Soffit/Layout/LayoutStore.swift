import Combine
import CoreGraphics
import Foundation

@MainActor
final class LayoutStore: ObservableObject {
    @Published private(set) var tree: LayoutTree
    @Published var focusedPane: PaneID?

    init(tree: LayoutTree) {
        self.tree = tree
        self.focusedPane = tree.firstPaneID
    }

    func replace(with newTree: LayoutTree) {
        tree = newTree
        if let f = focusedPane, !newTree.contains(f) { focusedPane = newTree.firstPaneID }
        if focusedPane == nil { focusedPane = newTree.firstPaneID }
    }

    // MARK: - Tab operations

    /// Add a tab to the focused pane. If no pane exists, creates one.
    @discardableResult
    func addTab(_ panel: Panel, toPane paneID: PaneID? = nil, focus: Bool = true) -> PaneID {
        seedStateHolder(panel)
        let target = paneID ?? focusedPane
        if let t = target, tree.pane(t) != nil {
            tree = tree.addingTab(panel, toPane: t, focus: focus)
            if focus { focusedPane = t }
            return t
        }
        // No pane exists — create one.
        let pane = Pane(tabs: [panel], activeTabID: panel.id)
        tree = tree.inserting(pane)
        focusedPane = pane.id
        return pane.id
    }

    func closeTab(_ panelID: PanelID) {
        let containingPane = tree.paneContaining(panelID)
        tree = tree.removingTab(panelID)
        if let c = containingPane, tree.pane(c) == nil {
            // Pane collapsed — move focus to first remaining pane.
            focusedPane = tree.firstPaneID
        }
    }

    func setActiveTab(in paneID: PaneID, to panelID: PanelID) {
        tree = tree.settingActiveTab(in: paneID, to: panelID)
        focusedPane = paneID
    }

    func focusPane(_ paneID: PaneID) {
        focusedPane = paneID
    }

    // MARK: - Pane operations

    /// Split the focused (or given) pane with a single-tab new pane containing `newPanel`.
    func splitPane(_ paneID: PaneID? = nil, direction: Orientation, newPanel: Panel, side: InsertSide = .second) {
        let target = paneID ?? focusedPane
        guard let t = target, tree.pane(t) != nil else {
            // Fallback: just add to tree.
            addTab(newPanel)
            return
        }
        seedStateHolder(newPanel)
        let newPane = Pane(tabs: [newPanel], activeTabID: newPanel.id)
        tree = tree.splittingPane(t, direction: direction, newPane: newPane, side: side)
        focusedPane = newPane.id
    }

    /// Split a pane by moving a tab into a new sibling pane on the chosen side.
    /// Edge case: if the dragged tab is the only tab in the source pane and the
    /// source == target, we can't actually move it (the source would collapse
    /// leaving nothing to split). Instead we create an empty sibling pane — the
    /// user gets the split they asked for and can populate the new pane with [+].
    func splitPaneByMoving(_ panelID: PanelID, into targetPaneID: PaneID, direction: DropDirection) {
        guard tree.panel(panelID) != nil else { return }
        guard let sourcePaneID = tree.paneContaining(panelID) else { return }

        let orientation: Orientation = (direction == .left || direction == .right) ? .horizontal : .vertical
        let side: InsertSide = (direction == .left || direction == .above) ? .first : .second

        if sourcePaneID == targetPaneID,
           let srcPane = tree.pane(sourcePaneID), srcPane.tabs.count <= 1 {
            let emptyPane = Pane(tabs: [], activeTabID: nil)
            tree = tree.splittingPane(targetPaneID, direction: orientation, newPane: emptyPane, side: side)
            focusedPane = emptyPane.id
            return
        }

        guard let panel = tree.panel(panelID) else { return }
        var newTree = tree.removingTab(panelID)

        if newTree.pane(targetPaneID) == nil {
            let newPane = Pane(tabs: [panel], activeTabID: panel.id)
            newTree = newTree.inserting(newPane)
            tree = newTree
            focusedPane = newPane.id
            return
        }

        let newPane = Pane(tabs: [panel], activeTabID: panel.id)
        newTree = newTree.splittingPane(targetPaneID, direction: orientation, newPane: newPane, side: side)
        tree = newTree
        focusedPane = newPane.id
    }

    /// Move a tab into a pane's tab strip (no split — just becomes another tab there).
    func moveTabToPane(_ panelID: PanelID, targetPaneID: PaneID) {
        guard let panel = tree.panel(panelID) else { return }
        guard let sourcePaneID = tree.paneContaining(panelID) else { return }
        if sourcePaneID == targetPaneID { return }

        var newTree = tree.removingTab(panelID)
        if newTree.pane(targetPaneID) == nil {
            let newPane = Pane(tabs: [panel], activeTabID: panel.id)
            newTree = newTree.inserting(newPane)
            tree = newTree
            focusedPane = newPane.id
            return
        }
        newTree = newTree.addingTab(panel, toPane: targetPaneID)
        tree = newTree
        focusedPane = targetPaneID
    }

    func closePane(_ paneID: PaneID) {
        tree = tree.closingPane(paneID)
        if focusedPane == paneID { focusedPane = tree.firstPaneID }
    }

    func setRatio(for split: SplitID, to ratio: CGFloat) {
        tree = tree.settingRatio(for: split, to: ratio)
    }

    func replacePanel(_ id: PanelID, with newPanel: Panel) {
        tree = tree.replacingPanel(id, with: newPanel)
    }

    func updateState(for id: PanelID, state: Data?) {
        tree = tree.updatingPanelState(id, state: state)
    }

    // MARK: - Keyboard commands

    func closeFocusedTab() {
        guard let paneID = focusedPane,
              let pane = tree.pane(paneID),
              let active = pane.activeTab else { return }
        closeTab(active.id)
    }

    func focusNextPane() {
        let ids = tree.paneIDs
        guard !ids.isEmpty else { return }
        guard let f = focusedPane, let idx = ids.firstIndex(of: f) else {
            focusedPane = ids.first; return
        }
        focusedPane = ids[(idx + 1) % ids.count]
    }

    func focusPreviousPane() {
        let ids = tree.paneIDs
        guard !ids.isEmpty else { return }
        guard let f = focusedPane, let idx = ids.firstIndex(of: f) else {
            focusedPane = ids.last; return
        }
        focusedPane = ids[(idx - 1 + ids.count) % ids.count]
    }

    // MARK: - Internal

    private func seedStateHolder(_ panel: Panel) {
        if let state = panel.state {
            InitialStateHolder.shared.write(panel.id, state)
        }
    }
}
