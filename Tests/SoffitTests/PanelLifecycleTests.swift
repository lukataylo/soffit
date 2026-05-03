import XCTest
@testable import Soffit

@MainActor
final class PanelLifecycleTests: XCTestCase {
    func testRegistryCleanupRemovesStore() {
        let registry = CanvasStateRegistry.shared
        let id = PanelID()
        let store = registry.store(for: id, save: { _, _ in })
        XCTAssertTrue(registry.store(for: id, save: { _, _ in }) === store)
        registry.cleanup(id)
        let fresh = registry.store(for: id, save: { _, _ in })
        XCTAssertFalse(fresh === store, "cleanup should drop the prior store so a new one is created")
    }

    func testInitialStateHolderRoundtrip() {
        let id = PanelID()
        let payload = Data("hello".utf8)
        InitialStateHolder.shared.write(id, payload)
        XCTAssertEqual(InitialStateHolder.shared.read(id), payload)
        InitialStateHolder.shared.write(id, nil)
        XCTAssertNil(InitialStateHolder.shared.read(id))
    }

    func testMarkdownStateRegistryReusesAndCleansUp() {
        let registry = MarkdownStateRegistry.shared
        let id = PanelID()
        let a = registry.state(for: id)
        let b = registry.state(for: id)
        XCTAssertTrue(a === b)
        registry.cleanup(id)
        let c = registry.state(for: id)
        XCTAssertFalse(c === a)
    }

    func testClosingTabRemovesPanelFromTree() {
        let panelA = Panel(source: "file:///a.md", title: "A")
        let panelB = Panel(source: "file:///b.md", title: "B")
        let pane = Pane(tabs: [panelA, panelB], activeTabID: panelB.id)
        let tree = LayoutTree.leaf(pane)
        let after = tree.removingTab(panelA.id)
        XCTAssertNil(after.panel(panelA.id))
        XCTAssertNotNil(after.panel(panelB.id))
    }

    func testClosingPaneTakesAllTabsWithIt() {
        let a = Panel(source: "file:///a.md", title: "A")
        let b = Panel(source: "file:///b.md", title: "B")
        let paneA = Pane(tabs: [a, b], activeTabID: a.id)
        let paneB = Pane(tabs: [Panel(source: "folder:///x", title: "X")])
        let tree = LayoutTree.split(id: SplitID(),
                                    orientation: .horizontal,
                                    ratio: 0.5,
                                    first: .leaf(paneA),
                                    second: .leaf(paneB))
        let closed = tree.closingPane(paneA.id)
        XCTAssertNil(closed.panel(a.id))
        XCTAssertNil(closed.panel(b.id))
    }

    func testReplacingPanelPreservesPanelIdentity() {
        // Folder-grid breadcrumb navigation goes through replacePanel; the panel
        // ID must stay stable so the canvas/markdown state registries don't get
        // dropped underneath the user.
        let original = Panel(source: "folder:///root", title: "root")
        let replacement = Panel(id: original.id, source: "folder:///root/sub", title: "sub")
        let pane = Pane(tabs: [original])
        let tree = LayoutTree.leaf(pane)
        let after = tree.replacingPanel(original.id, with: replacement)
        XCTAssertEqual(after.panel(original.id)?.source, "folder:///root/sub")
        XCTAssertNotNil(after.panel(original.id))
    }
}

@MainActor
final class CanvasStorePersistenceTests: XCTestCase {
    func testDebouncedMoveStillRecordsLatestPositionOnImmediateOp() {
        // After several debounced moves, an immediate op (add/remove) should
        // flush the pending state — the saved blob must reflect the latest move.
        var saved: Data? = nil
        let store = CanvasStore(panelID: PanelID(), initial: CanvasState(),
                                save: { _, data in saved = data })
        store.addFile(at: "a.md", position: CGPoint(x: 0, y: 0))
        let id = store.state.items[0].id
        store.move(id, to: CGPoint(x: 50, y: 50))
        store.move(id, to: CGPoint(x: 200, y: 200))
        // Trigger immediate persistence via a discrete op.
        store.addStickyNote(at: CGPoint(x: 0, y: 0))
        XCTAssertNotNil(saved)
        let decoded = try? JSONDecoder().decode(CanvasState.self, from: saved!)
        XCTAssertEqual(decoded?.items.first?.position, CGPoint(x: 200, y: 200))
    }

    func testRapidStickyTextEditsConverge() {
        var saved: Data? = nil
        let store = CanvasStore(panelID: PanelID(), initial: CanvasState(),
                                save: { _, data in saved = data })
        store.addStickyNote(at: .zero, text: "init", color: .yellow)
        let id = store.state.items[0].id
        // Simulate a burst of keystrokes (each calls updateStickyText).
        for c in "lorem ipsum dolor" { store.updateStickyText(id, text: String(c)) }
        // Final state in memory should reflect last edit even though persistence
        // is debounced.
        if case .stickyNote(let text, _) = store.state.items[0].kind {
            XCTAssertEqual(text, "r")
        } else { XCTFail("expected sticky note") }
        // Force flush via discrete op and verify saved blob is consistent.
        store.updateStickyColor(id, color: .green)
        XCTAssertNotNil(saved)
    }
}
