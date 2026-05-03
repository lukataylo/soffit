import SwiftUI

struct PanelTypePicker: View {
    let onChoose: (String, String) -> Void
    let onCancel: () -> Void

    @State private var kind: Kind = .web
    @State private var url: String = ""
    @State private var title: String = ""

    enum Kind: String, CaseIterable, Identifiable {
        case web, mermaid
        var id: String { rawValue }
        var label: String {
            switch self {
            case .web: return "Web (URL / Figma / localhost)"
            case .mermaid: return "Mermaid diagram"
            }
        }
        var placeholder: String {
            switch self {
            case .web: return "https://www.figma.com/... or http://localhost:3000"
            case .mermaid: return "path/to/diagram.mmd (relative to workspace)"
            }
        }
        var needsURL: Bool { true }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Panel")
                .font(.title3.bold())

            Picker("Type", selection: $kind) {
                ForEach(Kind.allCases) { k in Text(k.label).tag(k) }
            }
            .pickerStyle(.radioGroup)

            if kind.needsURL {
                TextField(kind.placeholder, text: $url)
                    .textFieldStyle(.roundedBorder)
            }
            TextField("Title (optional)", text: $title)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(kind.needsURL && url.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 460)
    }

    private func submit() {
        let source: String
        let defaultTitle: String
        switch kind {
        case .web:
            var s = url.trimmingCharacters(in: .whitespaces)
            if !s.contains("://") { s = "https://" + s }
            source = s
            defaultTitle = URL(string: s)?.host ?? "Web"
        case .mermaid:
            let path = url.trimmingCharacters(in: .whitespaces)
            let clean = path.hasPrefix("/") ? path : "/" + path
            source = "mermaid://\(clean)"
            defaultTitle = (path as NSString).lastPathComponent
        }
        let finalTitle = title.isEmpty ? defaultTitle : title
        onChoose(source, finalTitle)
    }
}
