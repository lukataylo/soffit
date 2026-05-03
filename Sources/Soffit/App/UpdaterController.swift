import Foundation
import Sparkle

/// Sparkle auto-update wrapper. The appcast lives at the URL declared in
/// Info.plist (`SUFeedURL`) — we host it on GitHub Pages so it always points
/// at the latest release DMG. Each DMG is signed with the EdDSA private key
/// and verified against the matching public key embedded in Info.plist
/// (`SUPublicEDKey`).
///
/// Setup, one-time:
///   1. `./scripts/sparkle-keygen.sh` to generate the key pair.
///   2. Copy the public key into Info.plist's SUPublicEDKey.
///   3. Host appcast.xml at the SUFeedURL (e.g., GitHub Pages).
///   4. Sign each DMG release with `sign_update <dmg>` and put the signature
///      into the appcast entry's sparkle:edSignature attribute.
@MainActor
final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()

    let updater: SPUStandardUpdaterController

    private init() {
        // `startingUpdater: true` enables Sparkle's automatic background checks
        // on the schedule the user has selected (default daily).
        updater = SPUStandardUpdaterController(startingUpdater: true,
                                               updaterDelegate: nil,
                                               userDriverDelegate: nil)
    }

    /// Manual "Check for Updates…" entry point.
    func checkForUpdates() {
        updater.checkForUpdates(nil)
    }

    var canCheckForUpdates: Bool {
        updater.updater.canCheckForUpdates
    }
}
