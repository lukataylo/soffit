import AppKit
import SwiftUI

/// Translucent window surface. `NSVisualEffectView` blurs whatever is behind the
/// window; a soft light-grey overlay tints everything so the panes stand out as
/// clear white cards.
struct SoffitSurface: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        // Just the visual-effect view, no tint. Preview.app, Notes, Mail and
        // friends all use the system .sidebar material straight — adding a
        // tint on top is what made Soffit look denser than its peers.
        WindowBlurBackground()
    }
}

struct WindowBlurBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover
        v.blendingMode = .behindWindow
        v.state = .followsWindowActiveState
        v.isEmphasized = false
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .hudWindow
        nsView.blendingMode = .behindWindow
        nsView.state = .followsWindowActiveState
    }
}
