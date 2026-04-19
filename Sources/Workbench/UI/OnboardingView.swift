import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var services: AppServices
    @State private var key: String = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color(red: 0.85, green: 0.42, blue: 0.55).opacity(0.18))
                            .frame(width: 38, height: 38)
                        Image(systemName: "key.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(red: 0.85, green: 0.42, blue: 0.55))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Anthropic API key")
                            .font(.system(size: 18, weight: .bold))
                        Text("Stored in macOS Keychain. Never leaves this machine except in direct calls to the Anthropic API.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                }

                SecureField("sk-ant-…", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))

                HStack {
                    Button("Skip for now") {
                        services.needsAPIKey = false
                    }
                    .buttonStyle(.link)
                    Spacer()
                    Button("Save") {
                        services.saveAPIKey(key.trimmingCharacters(in: .whitespaces))
                        key = ""
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(26)
            .frame(width: 480)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 6)
            )
        }
    }
}
