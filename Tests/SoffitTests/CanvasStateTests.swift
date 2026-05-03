import XCTest
@testable import Soffit

@MainActor
final class CanvasStateTests: XCTestCase {
    func testCanvasStateDefaults() {
        let s = CanvasState.empty
        XCTAssertEqual(s.zoom, 1.0)
        XCTAssertEqual(s.pan, .zero)
        XCTAssertEqual(s.mode, .grid)
        XCTAssertTrue(s.items.isEmpty)
    }

    func testCodableRoundTripMixedItems() throws {
        var s = CanvasState()
        s.items = [
            CanvasItem(kind: .file(path: "prds/ember.md"),
                       position: CGPoint(x: 40, y: 80), size: CGSize(width: 320, height: 240)),
            CanvasItem(kind: .stickyNote(text: "Remember voting logic", color: .pink),
                       position: CGPoint(x: 400, y: 120), size: CGSize(width: 220, height: 160))
        ]
        s.zoom = 1.75
        s.pan = CGPoint(x: -80, y: -40)
        s.mode = .canvas

        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(CanvasState.self, from: data)
        XCTAssertEqual(s, decoded)
    }

    func testAddRemovePreservesViewport() throws {
        let panelID = PanelID()
        var saved: Data? = nil
        let store = CanvasStore(panelID: panelID, initial: CanvasState(),
                                save: { _, data in saved = data })
        store.setZoom(1.5)
        store.setPan(CGPoint(x: 100, y: 200))
        store.addFile(at: "a.md", position: CGPoint(x: 10, y: 10))
        store.addStickyNote(at: CGPoint(x: 50, y: 50), text: "hi", color: .blue)

        XCTAssertEqual(store.state.items.count, 2)
        XCTAssertEqual(store.state.zoom, 1.5)
        XCTAssertEqual(store.state.pan, CGPoint(x: 100, y: 200))

        let firstID = store.state.items[0].id
        store.remove(firstID)
        XCTAssertEqual(store.state.items.count, 1)
        XCTAssertEqual(store.state.zoom, 1.5)
        XCTAssertEqual(store.state.pan, CGPoint(x: 100, y: 200))

        XCTAssertNotNil(saved)
        let decoded = try JSONDecoder().decode(CanvasState.self, from: saved!)
        XCTAssertEqual(decoded.items.count, 1)
        XCTAssertEqual(decoded.zoom, 1.5)
    }

    func testUpdateStickyTextAndColor() {
        let store = CanvasStore(panelID: PanelID(), initial: CanvasState(), save: { _, _ in })
        store.addStickyNote(at: .zero, text: "a", color: .yellow)
        let id = store.state.items[0].id

        store.updateStickyText(id, text: "updated")
        store.updateStickyColor(id, color: .green)

        if case .stickyNote(let text, let color) = store.state.items[0].kind {
            XCTAssertEqual(text, "updated")
            XCTAssertEqual(color, .green)
        } else { XCTFail("expected sticky note") }
    }

    func testZoomClamped() {
        let store = CanvasStore(panelID: PanelID(), initial: CanvasState(), save: { _, _ in })
        store.setZoom(10)
        XCTAssertEqual(store.state.zoom, 3.0)
        store.setZoom(0.01)
        XCTAssertEqual(store.state.zoom, 0.25)
    }

    func testRegistryReturnsSameStorePerPanelID() {
        let registry = CanvasStateRegistry.shared
        let id = PanelID()
        let a = registry.store(for: id, save: { _, _ in })
        let b = registry.store(for: id, save: { _, _ in })
        XCTAssertTrue(a === b)
        registry.cleanup(id)
    }

    func testMoveUpdatesOnlyTargetItem() {
        let store = CanvasStore(panelID: PanelID(), initial: CanvasState(), save: { _, _ in })
        store.addFile(at: "a.md", position: CGPoint(x: 0, y: 0))
        store.addFile(at: "b.md", position: CGPoint(x: 100, y: 100))
        let idA = store.state.items[0].id
        let idB = store.state.items[1].id

        store.move(idA, to: CGPoint(x: 500, y: 500))
        XCTAssertEqual(store.state.items.first { $0.id == idA }?.position, CGPoint(x: 500, y: 500))
        XCTAssertEqual(store.state.items.first { $0.id == idB }?.position, CGPoint(x: 100, y: 100))
    }
}
