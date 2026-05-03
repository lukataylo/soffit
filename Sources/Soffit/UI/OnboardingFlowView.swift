import AppKit
import SwiftUI

/// Two-screen onboarding for first-launch. Pro audience — terse copy, one
/// real action per screen.
///
/// Shown when `UserDefaults` key `soffit.onboardingComplete` isn't true. Sets
/// it on completion, so subsequent launches skip directly to the workspace
/// picker (or the persisted workspace if there is one).
struct OnboardingFlowView: View {
    @EnvironmentObject var services: AppServices
    let onFinish: () -> Void

    @State private var step: Step = .welcome

    enum Step { case welcome, workspace }

    var body: some View {
        ZStack {
            SoffitSurface().ignoresSafeArea()
            switch step {
            case .welcome:    welcome
            case .workspace:  workspacePick
            }
        }
        .frame(minWidth: 560, minHeight: 420)
        .background(OnboardingWindowSizer())
    }

    // MARK: - Welcome

    private var welcome: some View {
        VStack(spacing: 24) {
            Spacer()
            AppIconView()
                .frame(width: 96, height: 96)

            VStack(spacing: 8) {
                Text("Welcome to Soffit.")
                    .font(.system(size: 32, weight: .bold))
                Text("A native Mac workspace for markdown.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                bullet("Tile any folder. Edit. Preview. Sketch.")
                bullet("Wiki-links, tags, full-text search across every note.")
                bullet("Local files. Local index. Nothing leaves your Mac.")
            }
            .padding(.top, 4)

            Spacer()

            Button {
                step = .workspace
            } label: {
                Text("Continue")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 160, height: 32)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 40)
        }
        .padding(28)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 13))
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(.primary)
            Spacer()
        }
        .frame(width: 360)
    }

    // MARK: - Workspace pick

    private var workspacePick: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "folder.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.35))

            VStack(spacing: 8) {
                Text("Pick your workspace.")
                    .font(.system(size: 26, weight: .bold))
                Text("Any folder of markdown will do. Soffit reads and writes the files you already have — no vault structure, no import.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .frame(maxWidth: 460)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    pickWorkspace()
                } label: {
                    Label("Choose Folder…", systemImage: "folder.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 200, height: 32)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

                Button("Use the Examples Workspace") {
                    if let examples = bundledExamplesURL() {
                        services.openWorkspace(at: examples)
                        complete()
                    }
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, 40)
        }
        .padding(28)
    }

    // MARK: - Helpers

    private func pickWorkspace() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Workspace"
        if panel.runModal() == .OK, let url = panel.url {
            services.openWorkspace(at: url)
            complete()
        }
    }

    private func bundledExamplesURL() -> URL? {
        // Best-effort: if running from the source tree, the examples folder
        // sits alongside Sources/. Sandboxed App Store builds won't have it.
        let candidates = [
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("examples"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("examples")
        ]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: "soffit.onboardingComplete")
        onFinish()
    }
}

extension UserDefaults {
    var hasCompletedOnboarding: Bool {
        bool(forKey: "soffit.onboardingComplete")
    }
}

/// Shrinks the host window to a compact onboarding size on first appearance,
/// then re-centres it. The workspace UI uses `.defaultSize(1180×760)`; that
/// initial size feels oversized for a two-screen welcome flow.
private struct OnboardingWindowSizer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { resize(v) }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private func resize(_ view: NSView) {
        guard let win = view.window else {
            // Window not yet attached; retry next runloop tick.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { resize(view) }
            return
        }
        let target = NSSize(width: 640, height: 480)
        if win.frame.size.width > target.width + 20 || win.frame.size.height > target.height + 20 {
            var frame = win.frame
            frame.size = target
            win.setFrame(frame, display: true, animate: false)
            win.center()
        }
    }
}
