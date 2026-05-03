import Combine
import Foundation
import SwiftUI

/// Loads user themes from `~/.soffit/themes/*.json`. Each theme is a small
/// dictionary of style overrides applied at the markdown rendered preview level.
///
/// MarkdownUI's theme model isn't trivially CSS-compatible, so themes are JSON
/// rather than CSS. Format:
/// ```
/// {
///   "name": "Solarized",
///   "background": "#fdf6e3",
///   "foreground": "#586e75",
///   "accent":     "#268bd2",
///   "headingColor": "#cb4b16",
///   "codeBackground": "#eee8d5"
/// }
/// ```
@MainActor
final class ThemesLoader: ObservableObject {
    @Published private(set) var available: [Theme] = []
    @Published var current: Theme = .default {
        didSet { UserDefaults.standard.set(current.name, forKey: "soffit.themeName") }
    }

    struct Theme: Hashable, Codable {
        var name: String
        var background: String
        var foreground: String
        var accent: String
        var headingColor: String
        var codeBackground: String

        static let `default` = Theme(name: "System",
                                     background: "",
                                     foreground: "",
                                     accent: "",
                                     headingColor: "",
                                     codeBackground: "")
    }

    static var themesDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".soffit/themes", isDirectory: true)
    }

    init() {
        try? FileManager.default.createDirectory(at: Self.themesDir, withIntermediateDirectories: true)
        load()
        if let saved = UserDefaults.standard.string(forKey: "soffit.themeName"),
           let theme = available.first(where: { $0.name == saved }) {
            current = theme
        }
    }

    func reload() { load() }

    private func load() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: Self.themesDir, includingPropertiesForKeys: nil) else {
            available = [.default]
            return
        }
        var loaded: [Theme] = [.default]
        for url in entries where url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url),
               let theme = try? JSONDecoder().decode(Theme.self, from: data) {
                loaded.append(theme)
            }
        }
        available = loaded
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        if s.count == 6 {
            r = Double((v >> 16) & 0xFF) / 255.0
            g = Double((v >> 8) & 0xFF) / 255.0
            b = Double(v & 0xFF) / 255.0
            a = 1.0
        } else {
            r = Double((v >> 24) & 0xFF) / 255.0
            g = Double((v >> 16) & 0xFF) / 255.0
            b = Double((v >> 8) & 0xFF) / 255.0
            a = Double(v & 0xFF) / 255.0
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
