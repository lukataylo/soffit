import AppKit
import SwiftUI

struct NSSplitViewRepresentable<First: View, Second: View>: NSViewControllerRepresentable {
    let orientation: Orientation
    let ratio: CGFloat
    let onRatioChange: (CGFloat) -> Void
    let first: () -> First
    let second: () -> Second

    func makeNSViewController(context: Context) -> HostController {
        let controller = HostController()
        controller.coordinator = context.coordinator
        controller.configure(orientation: orientation,
                             ratio: ratio,
                             first: NSHostingController(rootView: AnyView(first())),
                             second: NSHostingController(rootView: AnyView(second())))
        return controller
    }

    func updateNSViewController(_ nsViewController: HostController, context: Context) {
        context.coordinator.onRatioChange = onRatioChange
        nsViewController.coordinator = context.coordinator
        nsViewController.update(orientation: orientation,
                                ratio: ratio,
                                first: AnyView(first()),
                                second: AnyView(second()))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onRatioChange: onRatioChange)
    }

    final class Coordinator: NSObject, NSSplitViewDelegate {
        var onRatioChange: (CGFloat) -> Void
        weak var splitView: NSSplitView?
        var isProgrammaticUpdate = false
        var lastReported: CGFloat = -1

        init(onRatioChange: @escaping (CGFloat) -> Void) {
            self.onRatioChange = onRatioChange
        }

        func splitViewDidResizeSubviews(_ notification: Notification) {
            guard !isProgrammaticUpdate, let split = splitView else { return }
            guard split.arrangedSubviews.count == 2 else { return }
            let sizeA = split.isVertical ? split.arrangedSubviews[0].frame.width : split.arrangedSubviews[0].frame.height
            let total = split.isVertical ? split.frame.width : split.frame.height
            guard total > 0 else { return }
            let ratio = sizeA / total
            guard abs(ratio - lastReported) > 0.002 else { return }
            lastReported = ratio
            onRatioChange(ratio)
        }

        func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool { false }
    }

    final class HostController: NSViewController {
        var coordinator: Coordinator?
        private let split = InvisibleSplitView()
        private var firstHost: NSHostingController<AnyView>?
        private var secondHost: NSHostingController<AnyView>?
        private var currentOrientation: Orientation = .horizontal
        private var pendingRatio: CGFloat = 0.5

        override func loadView() {
            split.dividerStyle = .thin
            split.autoresizingMask = [.width, .height]
            split.setValue(NSColor.clear, forKey: "dividerColor")
            view = split
        }

        func configure(orientation: Orientation, ratio: CGFloat,
                       first: NSHostingController<AnyView>, second: NSHostingController<AnyView>) {
            self.firstHost = first
            self.secondHost = second
            self.currentOrientation = orientation
            self.pendingRatio = ratio
            // isVertical must be set BEFORE adding arranged subviews so NSSplitView
            // lays them out in the right axis from the start.
            split.isVertical = (orientation == .horizontal)
            addChild(first)
            addChild(second)
            split.addArrangedSubview(first.view)
            split.addArrangedSubview(second.view)
            split.delegate = coordinator
            coordinator?.splitView = split
            DispatchQueue.main.async { [weak self] in self?.applyRatio(ratio) }
        }

        func update(orientation: Orientation, ratio: CGFloat, first: AnyView, second: AnyView) {
            firstHost?.rootView = first
            secondHost?.rootView = second
            if orientation != currentOrientation {
                currentOrientation = orientation
                split.isVertical = (orientation == .horizontal)
                pendingRatio = ratio
                DispatchQueue.main.async { [weak self] in self?.applyRatio(ratio) }
            } else if abs(ratio - pendingRatio) > 0.002 {
                pendingRatio = ratio
                applyRatio(ratio)
            }
        }

        private func applyRatio(_ ratio: CGFloat) {
            guard split.arrangedSubviews.count == 2 else { return }
            let total = split.isVertical ? split.frame.width : split.frame.height
            guard total > 0 else {
                DispatchQueue.main.async { [weak self] in self?.applyRatio(ratio) }
                return
            }
            coordinator?.isProgrammaticUpdate = true
            split.setPosition(total * ratio, ofDividerAt: 0)
            coordinator?.isProgrammaticUpdate = false
        }
    }
}

/// NSSplitView that paints no visible divider line; the gradient shows through the gap.
final class InvisibleSplitView: NSSplitView {
    override func drawDivider(in rect: NSRect) {
        // Intentionally empty — keep the divider hit-testable for drag, but invisible.
    }

    override var dividerColor: NSColor { .clear }
}
