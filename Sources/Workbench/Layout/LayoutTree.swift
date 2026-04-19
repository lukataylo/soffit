import Foundation
import CoreGraphics

enum Orientation: String, Codable {
    case horizontal   // left | right
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
    case leaf(Panel)
    case split(id: SplitID, orientation: Orientation, ratio: CGFloat, first: LayoutTree, second: LayoutTree)

    static let defaultRatio: CGFloat = 0.5

    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }

    var panelIDs: [PanelID] {
        switch self {
        case .empty: return []
        case .leaf(let p): return [p.id]
        case .split(_, _, _, let a, let b): return a.panelIDs + b.panelIDs
        }
    }

    func panel(_ id: PanelID) -> Panel? {
        switch self {
        case .empty: return nil
        case .leaf(let p): return p.id == id ? p : nil
        case .split(_, _, _, let a, let b): return a.panel(id) ?? b.panel(id)
        }
    }

    func firstPanelID() -> PanelID? { panelIDs.first }

    func contains(_ id: PanelID) -> Bool { panel(id) != nil }
}

// MARK: - Mutations

extension LayoutTree {
    func inserting(_ panel: Panel) -> LayoutTree {
        switch self {
        case .empty:
            return .leaf(panel)
        default:
            return .split(id: SplitID(), orientation: .horizontal, ratio: LayoutTree.defaultRatio,
                          first: self, second: .leaf(panel))
        }
    }

    func splitting(at target: PanelID, direction: Orientation, newPanel: Panel, insertOn side: InsertSide = .second) -> LayoutTree {
        switch self {
        case .empty:
            return .leaf(newPanel)
        case .leaf(let p):
            guard p.id == target else { return self }
            let newLeaf = LayoutTree.leaf(newPanel)
            let existing = LayoutTree.leaf(p)
            let (first, second) = side == .second ? (existing, newLeaf) : (newLeaf, existing)
            return .split(id: SplitID(), orientation: direction, ratio: LayoutTree.defaultRatio,
                          first: first, second: second)
        case .split(let id, let o, let r, let a, let b):
            return .split(id: id, orientation: o, ratio: r,
                          first: a.splitting(at: target, direction: direction, newPanel: newPanel, insertOn: side),
                          second: b.splitting(at: target, direction: direction, newPanel: newPanel, insertOn: side))
        }
    }

    func closing(_ target: PanelID) -> LayoutTree {
        switch self {
        case .empty: return .empty
        case .leaf(let p): return p.id == target ? .empty : self
        case .split(let id, let o, let r, let a, let b):
            let newA = a.closing(target)
            let newB = b.closing(target)
            if case .empty = newA { return newB }
            if case .empty = newB { return newA }
            return .split(id: id, orientation: o, ratio: r, first: newA, second: newB)
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
        case .leaf(var p):
            if p.id == target {
                p.state = state
                return .leaf(p)
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
        case .leaf(let p): return p.id == target ? .leaf(newPanel) : self
        case .split(let id, let o, let r, let a, let b):
            return .split(id: id, orientation: o, ratio: r,
                          first: a.replacingPanel(target, with: newPanel),
                          second: b.replacingPanel(target, with: newPanel))
        }
    }

    func splittingAtEdge(of target: PanelID, edge: DropEdge, newPanel: Panel) -> LayoutTree {
        let orientation: Orientation = (edge == .left || edge == .right) ? .horizontal : .vertical
        let side: InsertSide = (edge == .left || edge == .top) ? .first : .second
        return splitting(at: target, direction: orientation, newPanel: newPanel, insertOn: side)
    }
}

// MARK: - Codable

extension LayoutTree {
    private enum Kind: String, Codable { case empty, leaf, split }

    private enum CodingKeys: String, CodingKey {
        case kind, panel, id, orientation, ratio, first, second
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .empty:
            self = .empty
        case .leaf:
            self = .leaf(try c.decode(Panel.self, forKey: .panel))
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
        case .leaf(let panel):
            try c.encode(Kind.leaf, forKey: .kind)
            try c.encode(panel, forKey: .panel)
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
