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
        colorScheme == .dark
            ? Color(white: 0.12).opacity(0.55)
            : Color(white: 0.94).opacity(0.65)
    }
}

struct WindowBlurBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .underWindowBackground
        v.blendingMode = .behindWindow
        v.state = .active
        v.isEmphasized = false
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .underWindowBackground
        nsView.blendingMode = .behindWindow
        nsView.state = .active
    }
}
