import XCTest
@testable import Workbench

final class LayoutTreeTests: XCTestCase {
    func testEmptyInsertBecomesLeaf() {
        let tree: LayoutTree = .empty
        let panel = Panel(source: "chat://claude", title: "C")
        let result = tree.inserting(panel)
        XCTAssertEqual(result, .leaf(panel))
    }

    func testSplitLeafByID() {
        let a = Panel(source: "file:///a.md", title: "A")
        let b = Panel(source: "file:///b.md", title: "B")
        let tree = LayoutTree.leaf(a)
        let result = tree.splitting(at: a.id, direction: .horizontal, newPanel: b)
        if case .split(_, let o, let r, let first, let second) = result {
            XCTAssertEqual(o, .horizontal)
            XCTAssertEqual(r, LayoutTree.defaultRatio)
            XCTAssertEqual(first, .leaf(a))
            XCTAssertEqual(second, .leaf(b))
        } else {
            XCTFail("Expected split")
        }
    }

    func testSplitWithInsertSideFirst() {
        let a = Panel(source: "a", title: "")
        let b = Panel(source: "b", title: "")
        let tree = LayoutTree.leaf(a)
        let result = tree.splitting(at: a.id, direction: .vertical, newPanel: b, insertOn: .first)
        if case .split(_, _, _, let first, let second) = result {
            XCTAssertEqual(first, .leaf(b))
            XCTAssertEqual(second, .leaf(a))
        } else { XCTFail() }
    }

    func testCloseLeafPromotesSibling() {
        let a = Panel(source: "a", title: "")
        let b = Panel(source: "b", title: "")
        let tree = LayoutTree.split(id: SplitID(), orientation: .horizontal, ratio: 0.5,
                                    first: .leaf(a), second: .leaf(b))
        let closed = tree.closing(a.id)
        XCTAssertEqual(closed, .leaf(b))
    }

    func testCloseNestedPreservesStructure() {
        let a = Panel(source: "a", title: "")
        let b = Panel(source: "b", title: "")
        let c = Panel(source: "c", title: "")
        let sid = SplitID()
        let inner: LayoutTree = .split(id: SplitID(), orientation: .vertical, ratio: 0.5,
                                        first: .leaf(b), second: .leaf(c))
        let tree: LayoutTree = .split(id: sid, orientation: .horizontal, ratio: 0.3,
                                       first: .leaf(a), second: inner)
        let closed = tree.closing(b.id)
        XCTAssertEqual(closed, .split(id: sid, orientation: .horizontal, ratio: 0.3,
                                       first: .leaf(a), second: .leaf(c)))
    }

    func testCloseAllReturnsEmpty() {
        let a = Panel(source: "a", title: "")
        let b = Panel(source: "b", title: "")
        let tree = LayoutTree.split(id: SplitID(), orientation: .horizontal, ratio: 0.5,
                                    first: .leaf(a), second: .leaf(b))
        XCTAssertEqual(tree.closing(a.id).closing(b.id), .empty)
    }

    func testSetRatioClampsAndUpdates() {
        let a = Panel(source: "a", title: "")
        let b = Panel(source: "b", title: "")
        let sid = SplitID()
        let tree = LayoutTree.split(id: sid, orientation: .horizontal, ratio: 0.5,
                                    first: .leaf(a), second: .leaf(b))
        let updated = tree.settingRatio(for: sid, to: 0.99)
        if case .split(_, _, let r, _, _) = updated {
            XCTAssertEqual(r, 0.95, accuracy: 0.001)
        } else { XCTFail() }
    }

    func testCodableRoundTrip() throws {
        let a = Panel(source: "file:///a.md", title: "A", state: Data([1,2,3]))
        let b = Panel(source: "chat://claude", title: "B")
        let tree: LayoutTree = .split(id: SplitID(), orientation: .vertical, ratio: 0.4,
                                       first: .leaf(a), second: .leaf(b))
        let data = try JSONEncoder().encode(tree)
        let decoded = try JSONDecoder().decode(LayoutTree.self, from: data)
        XCTAssertEqual(tree, decoded)
    }

    func testInsertOnNonEmptyCreatesSplit() {
        let a = Panel(source: "a", title: "")
        let b = Panel(source: "b", title: "")
        let tree = LayoutTree.leaf(a).inserting(b)
        if case .split(_, _, _, let first, let second) = tree {
            XCTAssertEqual(first, .leaf(a))
            XCTAssertEqual(second, .leaf(b))
        } else { XCTFail() }
    }

    func testUpdatingPanelStateSetsData() {
        let a = Panel(source: "a", title: "")
        let tree = LayoutTree.leaf(a)
        let updated = tree.updatingPanelState(a.id, state: Data("hi".utf8))
        XCTAssertEqual(updated.panel(a.id)?.state, Data("hi".utf8))
    }

    func testSplittingAtEdgeLeft() {
        let a = Panel(source: "a", title: "")
        let b = Panel(source: "b", title: "")
        let result = LayoutTree.leaf(a).splittingAtEdge(of: a.id, edge: .left, newPanel: b)
        if case .split(_, let o, _, let first, let second) = result {
            XCTAssertEqual(o, .horizontal)
            XCTAssertEqual(first, .leaf(b))
            XCTAssertEqual(second, .leaf(a))
        } else { XCTFail() }
    }

    func testPanelIDsPreOrder() {
        let a = Panel(source: "a", title: "")
        let b = Panel(source: "b", title: "")
        let c = Panel(source: "c", title: "")
        let tree: LayoutTree = .split(id: SplitID(), orientation: .horizontal, ratio: 0.5,
                                       first: .leaf(a),
                                       second: .split(id: SplitID(), orientation: .vertical, ratio: 0.5,
                                                      first: .leaf(b), second: .leaf(c)))
        XCTAssertEqual(tree.panelIDs, [a.id, b.id, c.id])
    }
}
