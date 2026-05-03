import Combine
import CoreGraphics
import Foundation

// MARK: - Data model

enum FolderViewMode: String, Codable { case grid, canvas }

enum StickyColor: String, Codable, CaseIterable {
    case yellow, pink, blue, green

    var tint: (bg: Double, r: Double, g: Double, b: Double) {
        switch self {
        case .yellow: return (1.00, 1.00, 0.95, 0.70)
        case .pink:   return (1.00, 0.90, 0.92, 0.96)
        case .blue:   return (1.00, 0.85, 0.93, 1.00)
        case .green:  return (1.00, 0.88, 0.97, 0.88)
        }
    }
}

enum CanvasItemKind: Codable, Hashable {
    case file(path: String)
    case stickyNote(text: String, color: StickyColor)
}

struct CanvasItem: Codable, Hashable, Identifiable {
    let id: UUID
    var kind: CanvasItemKind
    var position: CGPoint
    var size: CGSize

    init(id: UUID = UUID(), kind: CanvasItemKind, position: CGPoint, size: CGSize) {
        self.id = id
        self.kind = kind
        self.position = position
        self.size = size
    }
}

struct CanvasState: Codable, Hashable {
    var items: [CanvasItem] = []
    var zoom: CGFloat = 1.0
    var pan: CGPoint = .zero
    var mode: FolderViewMode = .grid

    static let zoomRange: ClosedRange<CGFloat> = 0.25...3.0

    static let empty = CanvasState()
}

// MARK: - Per-pane store

@MainActor
final class CanvasStore: ObservableObject {
    @Published var state: CanvasState
    let panelID: PanelID
    private let save: (PanelID, Data?) -> Void
    private var saveDebounce: AnyCancellable?
    private let saveTrigger = PassthroughSubject<Void, Never>()

    init(panelID: PanelID, initial: CanvasState, save: @escaping (PanelID, Data?) -> Void) {
        self.panelID = panelID
        self.state = initial
        self.save = save
        saveDebounce = saveTrigger
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.flushPersist() }
    }

    // MARK: Mode

    func setMode(_ mode: FolderViewMode) {
        state.mode = mode
        persistImmediate()
    }

    // MARK: Items

    func add(_ item: CanvasItem) {
        state.items.append(item)
        persistImmediate()
    }

    func addFile(at path: String, position: CGPoint, size: CGSize = CGSize(width: 320, height: 260)) {
        add(CanvasItem(kind: .file(path: path), position: position, size: size))
    }

    func addStickyNote(at position: CGPoint, text: String = "", color: StickyColor = .yellow,
                       size: CGSize = CGSize(width: 220, height: 160)) {
        add(CanvasItem(kind: .stickyNote(text: text, color: color), position: position, size: size))
    }

    func remove(_ id: UUID) {
        state.items.removeAll { $0.id == id }
        persistImmediate()
    }

    func move(_ id: UUID, to position: CGPoint) {
        guard let idx = state.items.firstIndex(where: { $0.id == id }) else { return }
        state.items[idx].position = position
        persistDebounced()
    }

    func updateStickyText(_ id: UUID, text: String) {
        guard let idx = state.items.firstIndex(where: { $0.id == id }) else { return }
        if case .stickyNote(_, let color) = state.items[idx].kind {
            state.items[idx].kind = .stickyNote(text: text, color: color)
            persistDebounced()
        }
    }

    func updateStickyColor(_ id: UUID, color: StickyColor) {
        guard let idx = state.items.firstIndex(where: { $0.id == id }) else { return }
        if case .stickyNote(let text, _) = state.items[idx].kind {
            state.items[idx].kind = .stickyNote(text: text, color: color)
            persistImmediate()
        }
    }

    // MARK: Viewport

    func setZoom(_ zoom: CGFloat) {
        state.zoom = zoom.clamped(to: CanvasState.zoomRange)
        persistDebounced()
    }

    func setPan(_ pan: CGPoint) {
        state.pan = pan
        persistDebounced()
    }

    // MARK: Persistence

    private func persistImmediate() {
        saveDebounce?.cancel()
        flushPersist()
        // Re-arm the debounce sink for subsequent edits.
        saveDebounce = saveTrigger
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.flushPersist() }
    }

    private func persistDebounced() {
        saveTrigger.send()
    }

    private func flushPersist() {
        let data = try? JSONEncoder().encode(state)
        save(panelID, data)
    }
}

@MainActor
final class CanvasStateRegistry {
    static let shared = CanvasStateRegistry()
    private var map: [PanelID: CanvasStore] = [:]

    func store(for panelID: PanelID, save: @escaping (PanelID, Data?) -> Void) -> CanvasStore {
        if let existing = map[panelID] { return existing }
        let initial: CanvasState = {
            if let data = InitialStateHolder.shared.read(panelID),
               let decoded = try? JSONDecoder().decode(CanvasState.self, from: data) {
                return decoded
            }
            return .empty
        }()
        let store = CanvasStore(panelID: panelID, initial: initial, save: save)
        map[panelID] = store
        return store
    }

    func cleanup(_ panelID: PanelID) {
        map.removeValue(forKey: panelID)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
