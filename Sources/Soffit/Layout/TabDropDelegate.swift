import SwiftUI
import UniformTypeIdentifiers

/// Drop delegate for the pane's content area. Every position maps to one of four
/// split directions — center-merge is handled by a separate drop target on the tab strip.
struct TabDropDelegate: DropDelegate {
    let paneID: PaneID
    let session: WindowSession
    let paneSizeProvider: () -> CGSize
    let tabBarInset: CGFloat
    @Binding var isTargeted: Bool
    @Binding var dropDirection: DropDirection?

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.text])
    }

    func dropEntered(info: DropInfo) {
        updateState(info: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateState(info: info)
        return DropProposal(operation: isAboveTabBar(info.location) ? .forbidden : .move)
    }

    func dropExited(info: DropInfo) {
        reset()
    }

    func performDrop(info: DropInfo) -> Bool {
        guard !isAboveTabBar(info.location) else {
            reset()
            return false
        }
        guard let direction = DropDirection.from(point: info.location, in: paneSizeProvider()) else {
            reset()
            return false
        }
        guard let provider = info.itemProviders(for: [.text]).first else {
            reset()
            return false
        }
        let target = paneID
        provider.loadObject(ofClass: NSString.self) { obj, _ in
            guard let str = obj as? String, let uuid = UUID(uuidString: str) else { return }
            let panelID = PanelID(uuid)
            Task { @MainActor in
                session.layout.splitPaneByMoving(panelID, into: target, direction: direction)
            }
        }
        reset()
        return true
    }

    private func updateState(info: DropInfo) {
        if isAboveTabBar(info.location) {
            // Tab strip drop zone owns this area — don't show the compass here.
            isTargeted = false
            dropDirection = nil
        } else {
            isTargeted = true
            dropDirection = DropDirection.from(point: info.location, in: paneSizeProvider())
        }
    }

    private func isAboveTabBar(_ point: CGPoint) -> Bool {
        point.y < tabBarInset
    }

    private func reset() {
        isTargeted = false
        dropDirection = nil
    }
}
