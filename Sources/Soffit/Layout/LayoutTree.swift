import CoreGraphics
import Foundation

enum Orientation: String, Codable {
    case horizontal   // left | right  (NSSplitView.isVertical = true)
    case vertical     // top / bottom
}

enum DropEdge: String, Codable {
    case left, right, top, bottom
}

enum InsertSide: String {
    case first
    case second
}

indirect enum LayoutTree: Hashable, Codable {
    case empty
    case leaf(Pane)
    case split(id: SplitID, orientation: Orientation, ratio: CGFloat, first: LayoutTree, second: LayoutTree)

    static let defaultRatio: CGFloat = 0.5

    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }

    // MARK: - Enumeration

    var paneIDs: [PaneID] {
        switch self {
        case .empty: return []
        case .leaf(let pane): return [pane.id]
        case .split(_, _, _, let a, let b): return a.paneIDs + b.paneIDs
        }
    }

    var panelIDs: [PanelID] {
        switch self {
        case .empty: return []
        case .leaf(let pane): return pane.tabs.map { $0.id }
        case .split(_, _, _, let a, let b): return a.panelIDs + b.panelIDs
        }
    }

    func pane(_ id: PaneID) -> Pane? {
        switch self {
        case .empty: return nil
        case .leaf(let pane): return pane.id == id ? pane : nil
        case .split(_, _, _, let a, let b): return a.pane(id) ?? b.pane(id)
        }
    }

    func panel(_ id: PanelID) -> Panel? {
        switch self {
        case .empty: return nil
        case .leaf(let pane): return pane.tabs.first(where: { $0.id == id })
        case .split(_, _, _, let a, let b): return a.panel(id) ?? b.panel(id)
        }
    }

    func paneContaining(_ panelID: PanelID) -> PaneID? {
        switch self {
        case .empty: return nil
        case .leaf(let pane): return pane.contains(panelID) ? pane.id : nil
        case .split(_, _, _, let a, let b): return a.paneContaining(panelID) ?? b.paneContaining(panelID)
        }
    }

    var firstPaneID: PaneID? { paneIDs.first }

    func contains(_ paneID: PaneID) -> Bool { pane(paneID) != nil }
}

// MARK: - Mutations

extension LayoutTree {
    /// Insert a new pane anywhere sensible. If tree is empty, becomes the root leaf.
    /// Otherwise splits the root horizontally with the new pane on the right.
    func inserting(_ pane: Pane) -> LayoutTree {
        switch self {
        case .empty:
            return .leaf(pane)
        default:
            return .split(id: SplitID(), orientation: .horizontal, ratio: LayoutTree.defaultRatio,
                          first: self, second: .leaf(pane))
        }
    }

    /// Add a tab to an existing pane.
    func addingTab(_ panel: Panel, toPane paneID: PaneID, focus: Bool = true) -> LayoutTree {
        switch self {
        case .empty: return self
        case .leaf(var pane):
            if pane.id == paneID {
                pane.addTab(panel, focus: focus)
                return .leaf(pane)
            }
            return self
        case .split(let id, let o, let r, let a, let b):
            return .split(id: id, orientation: o, ratio: r,
                          first: a.addingTab(panel, toPane: paneID, focus: focus),
                          second: b.addingTab(panel, toPane: paneID, focus: focus))
        }
    }

    /// Remove a tab. If the tab was the last in its pane, the pane leaf is removed
    /// (the sibling subtree promotes up).
    func removingTab(_ panelID: PanelID) -> LayoutTree {
        switch self {
        case .empty: return .empty
        case .leaf(var pane):
            guard pane.contains(panelID) else { return self }
            pane.removeTab(panelID)
            return pane.isEmpty ? .empty : .leaf(pane)
        case .split(let id, let o, let r, let a, let b):
            let newA = a.removingTab(panelID)
            let newB = b.removingTab(panelID)
            if case .empty = newA { return newB }
            if case .empty = newB { return newA }
            return .split(id: id, orientation: o, ratio: r, first: newA, second: newB)
        }
    }

    /// Explicitly close a pane (removes the whole leaf, all its tabs go with it).
    func closingPane(_ paneID: PaneID) -> LayoutTree {
        switch self {
        case .empty: return .empty
        case .leaf(let pane): return pane.id == paneID ? .empty : self
        case .split(let id, let o, let r, let a, let b):
            let newA = a.closingPane(paneID)
            let newB = b.closingPane(paneID)
            if case .empty = newA { return newB }
            if case .empty = newB { return newA }
            return .split(id: id, orientation: o, ratio: r, first: newA, second: newB)
        }
    }

    func settingActiveTab(in paneID: PaneID, to panelID: PanelID) -> LayoutTree {
        switch self {
        case .empty: return self
        case .leaf(var pane):
            if pane.id == paneID {
                pane.setActive(panelID)
                return .leaf(pane)
            }
            return self
        case .split(let id, let o, let r, let a, let b):
            return .split(id: id, orientation: o, ratio: r,
                          first: a.settingActiveTab(in: paneID, to: panelID),
                          second: b.settingActiveTab(in: paneID, to: panelID))
        }
    }

    /// Split the given pane into two; the new pane holds `newPane.tabs` on the chosen side.
    func splittingPane(_ paneID: PaneID, direction: Orientation, newPane: Pane, side: InsertSide = .second) -> LayoutTree {
        switch self {
        case .empty: return .leaf(newPane)
        case .leaf(let pane):
            guard pane.id == paneID else { return self }
            let existing = LayoutTree.leaf(pane)
            let new = LayoutTree.leaf(newPane)
            let (first, second) = side == .second ? (existing, new) : (new, existing)
            return .split(id: SplitID(), orientation: direction, ratio: LayoutTree.defaultRatio,
                          first: first, second: second)
        case .split(let id, let o, let r, let a, let b):
            return .split(id: id, orientation: o, ratio: r,
                          first: a.splittingPane(paneID, direction: direction, newPane: newPane, side: side),
                          second: b.splittingPane(paneID, direction: direction, newPane: newPane, side: side))
        }
    }

    func settingRatio(for split: SplitID, to ratio: CGFloat) -> LayoutTree {
        let clamped = min(max(ratio, 0.05), 0.95)
        switch self {
        case .empty, .leaf: return self
        case .split(let id, let o, let r, let a, let b):
            if id == split {
                return .split(id: id, orientation: o, ratio: clamped, first: a, second: b)
            }
            return .split(id: id, orientation: o, ratio: r,
                          first: a.settingRatio(for: split, to: ratio),
                          second: b.settingRatio(for: split, to: ratio))
        }
    }

    func updatingPanelState(_ target: PanelID, state: Data?) -> LayoutTree {
        switch self {
        case .empty: return .empty
        case .leaf(var pane):
            if let idx = pane.tabs.firstIndex(where: { $0.id == target }) {
                pane.tabs[idx].state = state
                return .leaf(pane)
            }
            return self
        case .split(let id, let o, let r, let a, let b):
            return .split(id: id, orientation: o, ratio: r,
                          first: a.updatingPanelState(target, state: state),
                          second: b.updatingPanelState(target, state: state))
        }
    }

    func replacingPanel(_ target: PanelID, with newPanel: Panel) -> LayoutTree {
        switch self {
        case .empty: return .empty
        case .leaf(var pane):
            if let idx = pane.tabs.firstIndex(where: { $0.id == target }) {
                pane.tabs[idx] = newPanel
                if pane.activeTabID == target { pane.activeTabID = newPanel.id }
                return .leaf(pane)
            }
            return self
        case .split(let id, let o, let r, let a, let b):
            return .split(id: id, orientation: o, ratio: r,
                          first: a.replacingPanel(target, with: newPanel),
                          second: b.replacingPanel(target, with: newPanel))
        }
    }
}

// MARK: - Codable

extension LayoutTree {
    private enum Kind: String, Codable { case empty, leaf, split }

    private enum CodingKeys: String, CodingKey {
        case kind, pane, id, orientation, ratio, first, second
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .empty:
            self = .empty
        case .leaf:
            self = .leaf(try c.decode(Pane.self, forKey: .pane))
        case .split:
            self = .split(
                id: try c.decode(SplitID.self, forKey: .id),
                orientation: try c.decode(Orientation.self, forKey: .orientation),
                ratio: try c.decode(CGFloat.self, forKey: .ratio),
                first: try c.decode(LayoutTree.self, forKey: .first),
                second: try c.decode(LayoutTree.self, forKey: .second)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .empty:
            try c.encode(Kind.empty, forKey: .kind)
        case .leaf(let pane):
            try c.encode(Kind.leaf, forKey: .kind)
            try c.encode(pane, forKey: .pane)
        case .split(let id, let orientation, let ratio, let first, let second):
            try c.encode(Kind.split, forKey: .kind)
            try c.encode(id, forKey: .id)
            try c.encode(orientation, forKey: .orientation)
            try c.encode(ratio, forKey: .ratio)
            try c.encode(first, forKey: .first)
            try c.encode(second, forKey: .second)
        }
    }
}
