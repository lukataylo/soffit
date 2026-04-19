# Soffit — implementation decisions

This file captures non-obvious tradeoffs made during v0.1. Obvious, brief-driven choices are not listed.

## 1. Swift Package instead of a hand-rolled .xcodeproj

The brief asked for an Xcode project/workspace, and "SPM only — no CocoaPods". Modern Xcode opens `Package.swift` directly and treats it as a workspace, so the repo ships a `Package.swift` with an `executable` target. Opening the file in Xcode produces a normal workspace experience with full dependency resolution, and the CLI path (`swift build`, `swift test`) is identical for CI. Hand-rolling a `.xcodeproj` would have added noise without giving anything back.

## 2. `NSSplitView` via an `NSViewControllerRepresentable`, not SwiftUI `HSplitView` / `VSplitView`

The brief calls for AppKit `NSSplitView` because nested SwiftUI splits are flaky around gutter dragging and geometry. `NSSplitViewRepresentable` (`Layout/NSSplitViewRepresentable.swift`) wraps a `NSSplitView` with two `NSHostingController` children, mirrors ratio changes back into `LayoutStore` through a delegate, and flips isVertical between horizontal/vertical orientations. The one subtlety is suppressing reentrant ratio updates while we apply a ratio programmatically (`isProgrammaticUpdate` flag) — without that, the SwiftUI-driven ratio and the split view's `didResizeSubviews` notifications fight each other.

## 3. `LayoutTree` is a plain recursive enum, not a protocol-based node graph

Keeping the tree as a single `indirect enum` with three cases (`empty`, `leaf`, `split`) made the mutation functions trivial to write as pure values, gives free `Hashable`/`Codable` synthesis (with a hand-written Codable because enums with associated values need it), and made the unit tests short and obvious. The cost is one extra Codable boilerplate block — small price.

## 4. Drag-to-split via edge "drop zones", not a true drag-and-drop session

A true `NSItemProvider` drag from one panel to another is the "real" macOS behaviour. For v0.1 we settled on 18pt-wide edge zones on each panel that respond to any drag gesture by opening the type picker, with the drop edge recorded. This is good enough to demonstrate the split, avoids building a drag pasteboard payload for something we immediately throw away, and the abstraction (`splittingAtEdge(of:edge:newPanel:)`) is ready to drive from a real drag source later.

## 5. Mermaid source injected via `postMessage`, not fetched by the shim

The shim initially tried to `fetch('file://…')` the `.mmd` file. That has two problems: `file://` fetches from a `file://` page are blocked under the WKWebView cross-origin rules we actually ship with, and the shim would need read access to the workspace root granted through `loadFileURL(_:allowingReadAccessTo:)`. Instead, Swift reads the `.mmd` from disk upfront, loads the shim, and on `didFinish` calls `webView.evaluateJavaScript` with a `window.postMessage({source: '…'}, '*')`. The shim is pure presentation — no network, no disk. Failure modes (missing file, invalid path) degrade to a small placeholder diagram so the app never shows a blank panel.

## 6. Chat history lives in the panel's opaque `state: Data?` blob

Alternatives were a sibling store keyed on panel ID or an actor per chat. Keeping it in the tree means it round-trips through `layout.json` for free, matches the brief's description of `PanelContext.savePanelState`, and the one seam needed — "cold-start this panel with its previous state" — is handled by `InitialStateHolder`, a tiny thread-safe dictionary seeded from the loaded tree at app start. A chat-focused store would have been more code and would have needed its own persistence file.

## 7. Markdown editor uses `NSTextView` + regex syntax highlighting

The brief explicitly allowed this for v0.1. The highlighter (`MarkdownHighlighter.swift`) runs on every `textDidChange` against the full `NSTextStorage`; on a 10k-line PRD this would be painful, but all our target files are PRD-sized (hundreds of lines) and the attributed-string rewrite is negligible. If perf becomes an issue later, the fix is incremental highlighting over the changed range rather than a tree-sitter swap.

## 8. Autosave on a 500ms debounce per panel

Per-panel debounce (not a global one) means two open markdown panels can be edited independently without one starving the other. `MarkdownPanelModel` owns its own `Combine` debounce and writes to disk atomically.

## 9. FSEvents watcher is a small `final class`, not a Swift actor

The brief suggested an actor. In practice the FSEventStream callback already runs off the main thread, and the only work we do in response is `workspace.refresh()`, which itself hops to `@MainActor`. Wrapping the FSEventStream in an actor added one more async hop for zero correctness benefit.

## 10. Keychain storage uses `kSecClassGenericPassword`

Readable only by processes running under the same user account, not synced to iCloud (no `kSecAttrSynchronizable` set), and wiped when the user reinstalls macOS. For a local-first PM tool that's the right default. If we later want per-profile keys, switch the `kSecAttrAccount` to a profile identifier.

## 11. No app icon, no Info.plist, no bundle identifier

Running an SPM executable on macOS bypasses the `.app` bundle machinery. That's fine for a source-built reviewer experience (the brief explicitly says no installer/notarisation), but it means no Dock icon beyond the generic terminal icon and no deep-link handling. When the project outgrows this, we'll need either a wrapper `.xcodeproj` or the modern `swiftpm`-generated bundle approach.

## 12. `claude-opus-4-7` as the default chat model

The brief names this model explicitly. If it is not available on the user's Anthropic account, the API returns a 400 and the chat panel surfaces the error inline — no silent fallback.

## 13. A dedicated `folder://` provider for the card grid

After a design review the empty state changed from "list of files in a sidebar" to "a card grid of every file in the current folder, with live preview excerpts". Rather than hard-code this into the layout host, it's a proper panel provider keyed on `folder://` so it respects the same split / resize / persistence rules as any other panel. Breadcrumb navigation replaces the panel's source URL (via `LayoutTree.replacingPanel`) so back / forward / in-place navigation works without new panel IDs.

## 14. Viewer-first markdown with persisted mode

Opening a markdown file one way (click) versus another (double-click) should feel like two different intents: "let me glance at this" versus "let me work on this". Single-click opens in `.preview`; double-click opens in `.split` (editor + rendered). The mode is stored in the panel's opaque `state: Data?` so the choice round-trips through `layout.json` across relaunches. The `Preview / Source / Split` toggle lives inside the panel, not in the top-level toolbar, because each panel's mode is independent.

## 15. `TapGesture(count:2).exclusively(before: .count(1))` for click discrimination

SwiftUI's naive `onTapGesture(count: 1)` + `onTapGesture(count: 2)` fires both on a double-click. The `.exclusively(before:)` composition lets us run the double-tap handler if and only if it recognises; the single-tap is the fallback. Not glamorous but it's the pattern that actually works.
