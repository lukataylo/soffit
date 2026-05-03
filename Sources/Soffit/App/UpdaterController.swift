import Foundation
import Sparkle

/// Sparkle auto-update wrapper. The appcast lives at the URL declared in
/// Info.plist (`SUFeedURL`); each DMG is signed with the EdDSA private key
/// and verified against the matching public key in `SUPublicEDKey`.
///
/// Setup, one-time:
///   1. `./scripts/sparkle-keygen.sh` to generate the key pair.
///   2. Pass the public key via SU_PUBLIC_ED_KEY env var to build-app.sh.
///   3. Host appcast.xml at the SUFeedURL (e.g., GitHub Pages).
///   4. Sign each DMG release with `sign_update` and inject the signature
///      into the appcast entry.
@MainActor
final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()

    let updater: SPUStandardUpdaterController?
    let isConfigured: Bool

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
}
