import XCTest
@testable import Soffit

@MainActor
final class PanelLifecycleTests: XCTestCase {
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
        let original = Panel(source: "folder:///root", title: "root")
        let replacement = Panel(id: original.id, source: "folder:///root/sub", title: "sub")
        let pane = Pane(tabs: [original])
        let tree = LayoutTree.leaf(pane)
        let after = tree.replacingPanel(original.id, with: replacement)
        XCTAssertEqual(after.panel(original.id)?.source, "folder:///root/sub")
        XCTAssertNotNil(after.panel(original.id))
    }
}
