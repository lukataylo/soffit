import Foundation

enum MarkdownPanelMode: String, Codable, CaseIterable, Identifiable {
    case preview
    case edit
    case split
    case math

    var id: String { rawValue }

    var label: String {
        switch self {
        case .preview: return "Preview"
        case .edit: return "Source"
        case .split: return "Split"
        case .math: return "Math"
        }
    }

    var icon: String {
        switch self {
        case .preview: return "eye"
        case .edit: return "chevron.left.forwardslash.chevron.right"
        case .split: return "rectangle.split.2x1"
        case .math: return "function"
        }
    }
}

struct MarkdownPanelState: Codable {
    var mode: MarkdownPanelMode = .preview
}
