import XCTest
@testable import Soffit

final class LayoutTreeTests: XCTestCase {
    // MARK: - Pane helpers

    func testPaneAddsAndRemovesTabs() {
        let a = Panel(source: "a", title: "")
        let b = Panel(source: "b", title: "")
        var pane = Pane(tabs: [a])
        XCTAssertEqual(pane.activeTabID, a.id)
        pane.addTab(b)
        XCTAssertEqual(pane.tabs.count, 2)
        XCTAssertEqual(pane.activeTabID, b.id)
        pane.removeTab(b.id)
        XCTAssertEqual(pane.tabs.map(\.id), [a.id])
        XCTAssertEqual(pane.activeTabID, a.id)
    }

    // MARK: - Tree insertion

    func testEmptyInsertBecomesLeaf() {
        let pane = Pane(tabs: [Panel(source: "s", title: "")])
        XCTAssertEqual(LayoutTree.empty.inserting(pane), .leaf(pane))
    }

    func testInsertOnNonEmptyCreatesSplit() {
        let paneA = Pane(tabs: [Panel(source: "a", title: "")])
        let paneB = Pane(tabs: [Panel(source: "b", title: "")])
        let tree = LayoutTree.leaf(paneA).inserting(paneB)
        if case .split(_, _, _, let first, let second) = tree {
            XCTAssertEqual(first, .leaf(paneA))
            XCTAssertEqual(second, .leaf(paneB))
        } else { XCTFail() }
    }

    // MARK: - Tab ops on tree

    func testAddingTabRoutesToNamedPane() {
        let a = Panel(source: "a", title: "")
        let b = Panel(source: "b", title: "")
        let pane = Pane(tabs: [a])
        let tree = LayoutTree.leaf(pane)
        let updated = tree.addingTab(b, toPane: pane.id)
        XCTAssertEqual(updated.pane(pane.id)?.tabs.map(\.id), [a.id, b.id])
        XCTAssertEqual(updated.pane(pane.id)?.activeTabID, b.id)
    }

    func testRemovingLastTabCollapsesPane() {
        let a = Panel(source: "a", title: "")
        let b = Panel(source: "b", title: "")
        let paneA = Pane(tabs: [a])
        let paneB = Pane(tabs: [b])
        let tree = LayoutTree.split(
            id: SplitID(), orientation: .horizontal, ratio: 0.5,
            first: .leaf(paneA), second: .leaf(paneB)
        )
        let collapsed = tree.removingTab(a.id)
        XCTAssertEqual(collapsed, .leaf(paneB))
    }

    func testRemovingOneTabKeepsPane() {
        let a = Panel(source: "a", title: "")
        let b = Panel(source: "b", title: "")
        let pane = Pane(tabs: [a, b])
        let tree = LayoutTree.leaf(pane)
        let updated = tree.removingTab(a.id)
        XCTAssertEqual(updated.pane(pane.id)?.tabs.map(\.id), [b.id])
    }

    // MARK: - Split ops

    func testSplittingPaneCreatesSiblings() {
        let a = Panel(source: "a", title: "")
        let b = Panel(source: "b", title: "")
        let paneA = Pane(tabs: [a])
        let newPane = Pane(tabs: [b])
        let tree = LayoutTree.leaf(paneA)
        let result = tree.splittingPane(paneA.id, direction: .horizontal, newPane: newPane)
        if case .split(_, let o, _, let first, let second) = result {
            XCTAssertEqual(o, .horizontal)
            XCTAssertEqual(first, .leaf(paneA))
            XCTAssertEqual(second, .leaf(newPane))
        } else { XCTFail() }
    }

    func testSplitWithInsertSideFirst() {
        let a = Panel(source: "a", title: "")
        let b = Panel(source: "b", title: "")
        let paneA = Pane(tabs: [a])
        let newPane = Pane(tabs: [b])
        let tree = LayoutTree.leaf(paneA)
        let result = tree.splittingPane(paneA.id, direction: .vertical, newPane: newPane, side: .first)
        if case .split(_, _, _, let first, let second) = result {
            XCTAssertEqual(first, .leaf(newPane))
            XCTAssertEqual(second, .leaf(paneA))
        } else { XCTFail() }
    }

    func testClosingPaneRemovesLeaf() {
        let paneA = Pane(tabs: [Panel(source: "a", title: "")])
        let paneB = Pane(tabs: [Panel(source: "b", title: "")])
        let tree = LayoutTree.split(id: SplitID(), orientation: .horizontal, ratio: 0.5,
                                    first: .leaf(paneA), second: .leaf(paneB))
        let closed = tree.closingPane(paneA.id)
        XCTAssertEqual(closed, .leaf(paneB))
    }

    // MARK: - Ratio

    func testSetRatioClampsAndUpdates() {
        let paneA = Pane(tabs: [Panel(source: "a", title: "")])
        let paneB = Pane(tabs: [Panel(source: "b", title: "")])
        let sid = SplitID()
        let tree = LayoutTree.split(id: sid, orientation: .horizontal, ratio: 0.5,
                                    first: .leaf(paneA), second: .leaf(paneB))
        let updated = tree.settingRatio(for: sid, to: 0.99)
        if case .split(_, _, let r, _, _) = updated {
            XCTAssertEqual(r, 0.95, accuracy: 0.001)
        } else { XCTFail() }
    }

    // MARK: - Panel state

    func testUpdatingPanelStateSetsData() {
        let a = Panel(source: "a", title: "")
        let pane = Pane(tabs: [a])
        let tree = LayoutTree.leaf(pane)
        let updated = tree.updatingPanelState(a.id, state: Data("hi".utf8))
        XCTAssertEqual(updated.panel(a.id)?.state, Data("hi".utf8))
    }

    func testReplacingPanelKeepsPaneIdentity() {
        let a = Panel(source: "a", title: "A")
        let b = Panel(id: a.id, source: "a2", title: "A2")
        let pane = Pane(tabs: [a])
        let tree = LayoutTree.leaf(pane)
        let updated = tree.replacingPanel(a.id, with: b)
        XCTAssertEqual(updated.pane(pane.id)?.tabs.first?.source, "a2")
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let a = Panel(source: "file:///a.md", title: "A", state: Data([1, 2, 3]))
        let b = Panel(source: "chat://claude", title: "B")
        let pane = Pane(tabs: [a, b], activeTabID: b.id)
        let other = Pane(tabs: [Panel(source: "mermaid:///x.mmd", title: "X")])
        let tree: LayoutTree = .split(id: SplitID(), orientation: .vertical, ratio: 0.4,
                                      first: .leaf(pane), second: .leaf(other))
        let data = try JSONEncoder().encode(tree)
        let decoded = try JSONDecoder().decode(LayoutTree.self, from: data)
        XCTAssertEqual(tree, decoded)
    }

    // MARK: - Traversal

    func testPaneIDsPreOrder() {
        let paneA = Pane(tabs: [Panel(source: "a", title: "")])
        let paneB = Pane(tabs: [Panel(source: "b", title: "")])
        let paneC = Pane(tabs: [Panel(source: "c", title: "")])
        let tree: LayoutTree = .split(id: SplitID(), orientation: .horizontal, ratio: 0.5,
                                      first: .leaf(paneA),
                                      second: .split(id: SplitID(), orientation: .vertical, ratio: 0.5,
                                                     first: .leaf(paneB), second: .leaf(paneC)))
        XCTAssertEqual(tree.paneIDs, [paneA.id, paneB.id, paneC.id])
    }

    func testPaneContainingFindsTab() {
        let a = Panel(source: "a", title: "")
        let b = Panel(source: "b", title: "")
        let paneA = Pane(tabs: [a])
        let paneB = Pane(tabs: [b])
        let tree = LayoutTree.split(id: SplitID(), orientation: .horizontal, ratio: 0.5,
                                    first: .leaf(paneA), second: .leaf(paneB))
        XCTAssertEqual(tree.paneContaining(a.id), paneA.id)
        XCTAssertEqual(tree.paneContaining(b.id), paneB.id)
    }
}
