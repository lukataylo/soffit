import AppKit
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            AppIconView()
                .frame(width: 96, height: 96)

            VStack(spacing: 4) {
                Text("Soffit")
                    .font(.system(size: 28, weight: .bold))
                Text(versionLine)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Text("A native macOS workspace for markdown power users.\nTile folders as canvases. Edit, preview, embed, multitask.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)

            HStack(spacing: 18) {
                Button("Repository") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/lukataylo/soffit")!)
                }
                Button("Privacy Policy") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/lukataylo/soffit/blob/main/PRIVACY.md")!)
                }
                Button("Report an Issue") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/lukataylo/soffit/issues/new")!)
                }
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
        }
        .padding(28)
        .frame(width: 360)
    }

    private var versionLine: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "dev"
        return "v\(v) · build \(b)"
    }
}

struct AppIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.62, blue: 0.42),
                        Color(red: 0.92, green: 0.36, blue: 0.48)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .shadow(color: .black.opacity(0.20), radius: 8, x: 0, y: 4)

            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))
        }
    }
}
