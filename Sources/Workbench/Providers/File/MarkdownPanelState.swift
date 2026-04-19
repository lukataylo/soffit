import Foundation

enum MarkdownPanelMode: String, Codable, CaseIterable, Identifiable {
    case preview
    case edit
    case split

    var id: String { rawValue }

    var label: String {
        switch self {
        case .preview: return "Preview"
        case .edit: return "Source"
        case .split: return "Split"
        }
    }

    var icon: String {
        switch self {
        case .preview: return "eye"
        case .edit: return "chevron.left.forwardslash.chevron.right"
        case .split: return "rectangle.split.2x1"
        }
    }
}

struct MarkdownPanelState: Codable {
    var mode: MarkdownPanelMode = .preview
}
