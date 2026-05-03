# Soffit — implementation decisions

This file captures non-obvious tradeoffs made during development. Obvious, brief-driven choices are not listed.

## v0.3 additions

### v0.3.1 Incremental markdown highlighting via `NSTextStorageDelegate`

Initial implementation re-scanned the entire `NSTextStorage` with seven regexes on every keystroke. For PRD-sized files (1k–10k lines) this caused noticeable input lag. v0.3 keeps the same regex set but scopes re-scan to ~5 lines around the editor's `editedRange`, falling back to a full re-scan only when the scope contains a code-fence marker (where partial-scope styling would mis-pair). The `MarkdownHighlighter.applyIncremental(to:style:editedRange:)` API is independent of the editor so the same logic could later drive a tree-sitter swap.

### v0.3.2 Canvas state persistence: split immediate vs. debounced

Canvas mode lets you drag files and sticky notes around, type into notes, pan/zoom. Initially every mutation called `JSONEncoder.encode(state)` + the host save callback, meaning a single drag tick wrote the whole state ~60 times per second. Split into:
- *Immediate* (`add`, `remove`, sticky-color change, mode toggle) — discrete user actions; persistence latency would be felt as "did my click register?"
- *Debounced 250ms* (`move`, `setPan`, `setZoom`, sticky-text edit) — high-frequency mutations where in-flight in-memory state is what matters; only the resting state needs to hit disk.

Tests force-flush by following a debounced burst with a discrete op, which calls `persistImmediate` and cancels+re-arms the debounce sink.

### v0.3.3 Panel-state registries get an explicit cleanup hook

`CanvasStateRegistry`, `MarkdownStateRegistry`, and `InitialStateHolder` are global singletons keyed on `PanelID`. Without cleanup, every closed pane leaks its store. v0.3 watches `layout.$tree` and on each emission diffs the previous-vs-current `panelIDs` set; ids that disappeared get removed from all three registries. This sits in `AppServices.start()` so it's owned by the same actor as the layout itself, no new synchronisation needed.

### v0.3.4 Folder cards and file tree do disk I/O off the main thread

Three on-render disk reads were caught and moved to `Task.detached(priority: .userInitiated)` sinks:
- `FilePreviewCard` markdown/text/image content (cached in `@State`, re-loaded on URL change).
- `DocumentCard.loadPreview` (markdown/mermaid/plain excerpt).
- `FileTreeView` expanded subdirectory listings (cached per-URL, invalidated on FSEvents).

This required marking `WorkspaceStore.readDirectory(_:)` as `nonisolated` since the helper does pure file I/O with no actor-isolated state.

### v0.3.5 .app bundling without a wrapper Xcode project

The original brief said "no installer/notarisation"; the SPM executable ran fine but had no Dock icon and no proper bundle. v0.3 adds a `scripts/build-app.sh` post-build step that:
1. Copies `.build/release/Soffit` into `build/Soffit.app/Contents/MacOS/`.
2. Copies the SPM `Soffit_Soffit.bundle` into `Resources/` so `Bundle.module` keeps finding `mermaid-shim.html`.
3. Generates an `Info.plist` with `LSMinimumSystemVersion=14.0`, `NSPrincipalClass=NSApplication`, version metadata.
4. Ad-hoc signs the app (`codesign --sign -`) so first-run quarantine is less aggressive.

Pre-built distribution still requires an Apple Developer cert + notarisation, which is intentionally out of scope.

### v0.3.6 App icon is generated, not authored

`scripts/generate-icon.swift` renders the icon programmatically — gradient squircle with the 2x2 grid mark — at all 10 macOS-required sizes, then `iconutil` compiles to `.icns`. This means the icon is reproducible from source: no Sketch/Figma asset checked in, and the gradient/grid can be tweaked by editing the Swift script. Trade-off: the result is technically correct but lacks the hand-tuned details a designer-authored icon would have. Good enough for v0.3; revisit when a designer is engaged.

## v0.1 / v0.2 baseline (kept for context)

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

## 11. Dock icon rendered programmatically; no Info.plist, no bundle identifier

Running an SPM executable on macOS bypasses the `.app` bundle machinery. We could either ship a wrapper `.xcodeproj` with an `.icns` resource or render the icon at runtime. v0.2 takes the runtime path: `AppIcon.install()` (`Sources/Soffit/UI/AppIcon.swift`) draws the brand mark — Soffit-orange rounded rectangle with a 2x2 pane grid — into a 512pt `NSImage` on `applicationDidFinishLaunching` and assigns it to `NSApp.applicationIconImage`. No image asset to manage, the same code path drives any future @1x/@2x rendering, and the icon stays in sync with the in-app brand colour. Code signing/notarisation still need a wrapper bundle later.

## 12. `claude-opus-4-7` as the default chat model

The brief names this model explicitly. If it is not available on the user's Anthropic account, the API returns a 400 and the chat panel surfaces the error inline — no silent fallback.

## 13. A dedicated `folder://` provider for the card grid

After a design review the empty state changed from "list of files in a sidebar" to "a card grid of every file in the current folder, with live preview excerpts". Rather than hard-code this into the layout host, it's a proper panel provider keyed on `folder://` so it respects the same split / resize / persistence rules as any other panel. Breadcrumb navigation replaces the panel's source URL (via `LayoutTree.replacingPanel`) so back / forward / in-place navigation works without new panel IDs.

## 14. Viewer-first markdown with persisted mode

Opening a markdown file one way (click) versus another (double-click) should feel like two different intents: "let me glance at this" versus "let me work on this". Single-click opens in `.preview`; double-click opens in `.split` (editor + rendered). The mode is stored in the panel's opaque `state: Data?` so the choice round-trips through `layout.json` across relaunches. The `Preview / Source / Split` toggle lives inside the panel, not in the top-level toolbar, because each panel's mode is independent.

## 15. `TapGesture(count:2).exclusively(before: .count(1))` for click discrimination

SwiftUI's naive `onTapGesture(count: 1)` + `onTapGesture(count: 2)` fires both on a double-click. The `.exclusively(before:)` composition lets us run the double-tap handler if and only if it recognises; the single-tap is the fallback. Not glamorous but it's the pattern that actually works.
