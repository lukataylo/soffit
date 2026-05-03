import Foundation
#if SOFFIT_PRO
import Sparkle
#endif

/// Sparkle auto-update wrapper (Pro variant only). The App Store build
/// gets updates via the Mac App Store and must not bundle Sparkle —
/// Apple disallows third-party update mechanisms in MAS apps, and
/// Sparkle's library validation requirements aren't compatible with the
/// App Sandbox anyway. Under `!SOFFIT_PRO` this class is a stub so menu
/// commands compile but never surface a Check-for-Updates item.
@MainActor
final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()

    let isConfigured: Bool

    #if SOFFIT_PRO
    let updater: SPUStandardUpdaterController?

    private init() {
        // Only spin up Sparkle when the bundle has a real public key. The
        // template Info.plist ships with a placeholder; surfacing a broken
        // "updater failed to start" alert when running ad-hoc dev builds is
        // worse than silently disabling the feature.
        let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        let configured = (publicKey?.isEmpty == false)
            && publicKey != "REPLACE_WITH_KEYGEN_OUTPUT"

        if configured {
            self.updater = SPUStandardUpdaterController(startingUpdater: true,
                                                       updaterDelegate: nil,
                                                       userDriverDelegate: nil)
            self.isConfigured = true
        } else {
            self.updater = nil
            self.isConfigured = false
        }
    }

    func checkForUpdates() {
        updater?.checkForUpdates(nil)
    }

    var canCheckForUpdates: Bool {
        updater?.updater.canCheckForUpdates ?? false
    }
    #else
    private init() {
        self.isConfigured = false
    }

    func checkForUpdates() {}

    var canCheckForUpdates: Bool { false }
    #endif
}
