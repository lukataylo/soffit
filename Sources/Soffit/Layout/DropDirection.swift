import CoreGraphics
import Foundation

enum DropDirection: String, Hashable {
    case above
    case below
    case left
    case right

    /// Pick a split direction based on cursor position in a pane. Always returns
    /// a directional result — there is no "center" zone; tab insertion is handled
    /// separately by dropping onto the tab strip itself.
    static func from(point: CGPoint, in size: CGSize) -> DropDirection? {
        guard size.width > 0, size.height > 0 else { return nil }
        let cx = size.width / 2
        let cy = size.height / 2
        let dx = point.x - cx
        let dy = point.y - cy
        if abs(dx) > abs(dy) {
            return dx < 0 ? .left : .right
        } else {
            return dy < 0 ? .above : .below
        }
    }
}
