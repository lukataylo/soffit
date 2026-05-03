import Foundation

/// Resilient replacement for SwiftPM's auto-generated `Bundle.module`.
///
/// SwiftPM's accessor looks for `Soffit_Soffit.bundle` at
/// `Bundle.main.bundleURL/Soffit_Soffit.bundle` (i.e. directly inside
/// `Soffit.app/`). That works for `swift run` but not for a properly laid-out
/// macOS `.app`, where resources live under `Contents/Resources/`. Hitting
/// `Bundle.module` on a deployed `.app` therefore fatalErrors.
///
/// `SoffitBundle.module` checks the macOS-conventional location first, then
/// falls back to the SPM/dev locations. If no candidate yields a real bundle
/// (e.g. on the very first launch from Xcode-via-derived-data) it returns a
/// synthesized Bundle pointing at the inner `Resources/` directory so
/// `url(forResource:withExtension:)` still resolves.
enum SoffitBundle {
    static let module: Bundle = resolve()

    private static func resolve() -> Bundle {
        let bundleName = "Soffit_Soffit.bundle"
        let candidates: [URL] = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(bundleName)"),
            Bundle(for: BundleFinder.self).resourceURL?.appendingPathComponent(bundleName),
            // Dev path — `swift run` from the source tree.
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent(bundleName)
        ].compactMap { $0 }

        for candidate in candidates {
            if let bundle = Bundle(url: candidate) {
                return bundle
            }
        }

        // The bundle directory exists but has no Info.plist (SwiftPM ships
        // shallow bundles without one). `Bundle(url:)` returns nil in that
        // case. Build a Bundle pointing at the inner `Resources/` directory
        // — that *does* satisfy Bundle's checks, and resource lookups via
        // url(forResource:) will resolve correctly.
        let nestedCandidates = candidates.map { $0.appendingPathComponent("Resources") }
        for candidate in nestedCandidates {
            if FileManager.default.fileExists(atPath: candidate.path),
               let bundle = Bundle(url: candidate) {
                return bundle
            }
        }

        // Final fallback: Bundle.main. Resource lookups against this won't
        // find SPM-bundled assets, but it keeps the app alive instead of
        // fatalError-ing.
        return Bundle.main
    }

    private final class BundleFinder {}
}
