import AppKit
import SwiftUI

/// Translucent window surface. `NSVisualEffectView` blurs whatever is behind the
/// window; a soft light-grey overlay tints everything so the panes stand out as
/// clear white cards.
struct SoffitSurface: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            WindowBlurBackground()
            tintOverlay
        }
    }

    private var tintOverlay: some View {
        // Light tint, low opacity so the wallpaper blur shows through but cards
        // still pop. Dark mode keeps a touch more weight so cards don't lose contrast.
        colorScheme == .dark
            ? Color(white: 0.10).opacity(0.30)
            : Color(white: 0.96).opacity(0.25)
    }
}

struct WindowBlurBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .headerView
        v.blendingMode = .behindWindow
        v.state = .followsWindowActiveState
        v.isEmphasized = false
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .headerView
        nsView.blendingMode = .behindWindow
        nsView.state = .followsWindowActiveState
    }
}
