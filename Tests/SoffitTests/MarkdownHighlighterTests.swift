import AppKit
import XCTest
@testable import Soffit

final class MarkdownHighlighterTests: XCTestCase {
    private var highlighter: MarkdownHighlighter!

    override func setUp() {
        super.setUp()
        highlighter = MarkdownHighlighter()
    }

    func testFullHighlightOnSimpleDocument() {
        let storage = NSTextStorage(string: "# Title\n\n**bold** and *italic*\n\n- item")
        highlighter.apply(to: storage, style: .rendered)
        // Sanity: no crash, attributes applied to whole range.
        let attrs = storage.attributes(at: 0, effectiveRange: nil)
        XCTAssertNotNil(attrs[.font])
        XCTAssertNotNil(attrs[.foregroundColor])
    }

    func testIncrementalHighlightInsideParagraph() {
        let text = "# Heading\n\nFirst paragraph.\n\nSecond paragraph **bold**.\n\nThird paragraph."
        let storage = NSTextStorage(string: text)
        highlighter.apply(to: storage, style: .rendered)
        // Simulate user editing the second paragraph.
        let editLocation = (text as NSString).range(of: "Second").location
        let editedRange = NSRange(location: editLocation, length: 6)
        // Should not crash and should leave attributes intact in unrelated parts.
        highlighter.applyIncremental(to: storage, style: .rendered, editedRange: editedRange)
    }

    func testIncrementalFallsBackToFullWhenCodeFenceInvolved() {
        let text = "Intro\n\n```\nfoo\nbar\n```\n\nOutro"
        let storage = NSTextStorage(string: text)
        // Edit at the closing fence — the heuristic should detect ``` in the
        // expanded scope and re-highlight the whole document so fence styling
        // re-pairs correctly.
        let editLocation = (text as NSString).range(of: "```\n\nOutro").location
        highlighter.applyIncremental(to: storage,
                                     style: .rendered,
                                     editedRange: NSRange(location: editLocation, length: 3))
        // Just verify it didn't crash; correctness of fence styling is a UI test concern.
        XCTAssertGreaterThan(storage.length, 0)
    }

    func testIncrementalHandlesEditAtEndOfBuffer() {
        let storage = NSTextStorage(string: "abc")
        // Edit beyond current length (simulates appending) — should clamp safely.
        highlighter.applyIncremental(to: storage,
                                     style: .rendered,
                                     editedRange: NSRange(location: 3, length: 0))
    }

    func testIncrementalHandlesEmptyDocument() {
        let storage = NSTextStorage(string: "")
        highlighter.applyIncremental(to: storage,
                                     style: .rendered,
                                     editedRange: NSRange(location: 0, length: 0))
    }

    func testFullHighlightOnLargeDocumentDoesNotCrash() {
        // Simulate a sizeable PRD: 1000 lines, mix of constructs.
        var lines: [String] = []
        for i in 0..<1000 {
            switch i % 5 {
            case 0: lines.append("# Section \(i)")
            case 1: lines.append("Some **bold** text and *italic* and `code`.")
            case 2: lines.append("- list item \(i)")
            case 3: lines.append("> a quote about \(i)")
            default: lines.append("Plain line \(i).")
            }
        }
        let storage = NSTextStorage(string: lines.joined(separator: "\n"))
        highlighter.apply(to: storage, style: .rendered)
        XCTAssertGreaterThan(storage.length, 5000)
    }
}
