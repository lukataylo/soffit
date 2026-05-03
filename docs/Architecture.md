# Architecture

Soffit is intentionally small. Four abstractions carry the weight; everything else is a plug-in around them.

## The four primitives

### `LayoutTree` — the immutable pane graph

`Sources/Soffit/Layout/LayoutTree.swift`

```swift
indirect enum LayoutTree: Hashable, Codable {
    case empty
    case leaf(Pane)
    case split(id: SplitID, orientation: Orientation, ratio: CGFloat,
               first: LayoutTree, second: LayoutTree)
}
```

A recursive enum with three cases. All mutations return a new tree (`addingTab`, `removingTab`, `splittingPane`, `closingPane`, `settingActiveTab`, `settingRatio`, `replacingPanel`, `updatingPanelState`).

Why a value-type enum and not a node graph?
- Free `Hashable` / `Equatable` synthesis (so the `removeDuplicates()` Combine debounce trivially deduplicates noisy publishes).
- Free `Codable` round-trip means persistence is `JSONEncoder().encode(tree)`.
- Pure value mutations are dead-easy to unit test.

### `Pane` — a tab strip

`Sources/Soffit/Layout/Pane.swift`

Holds `tabs: [Panel]` and an `activeTabID`. Closing the last tab causes the pane to become empty, which causes `removingTab` to drop the leaf, which causes the sibling subtree to promote up. This cascade is the only reason "close last tab" doesn't leave a UI dead-end.

### `Panel` — the serialised tab

`Sources/Soffit/Layout/Panel.swift`

```swift
struct Panel: Codable, Hashable, Identifiable {
    let id: PanelID
    var source: String   // URI: "file:///…", "folder:///…", "https://…", "mermaid:///…", "terminal:///…"
    var title: String
    var state: Data?     // opaque per-provider state blob
}
```

The provider for each panel is looked up by URI scheme. The `state: Data?` is a serialised, provider-defined blob — it round-trips through the layout snapshot. Used by markdown panels (mode), folder panels (canvas item positions), chat panels (message history).

### `PanelProvider` — the plugin protocol

`Sources/Soffit/Providers/PanelProvider.swift`

```swift
protocol PanelProvider {
    static var scheme: String { get }
    static var displayName: String { get }
    func makeView(for source: PanelSource, context: PanelContext) -> AnyView
}
```

Registered by URI scheme. Soffit ships providers for `folder://`, `file://`, `https://` / `http://`, `mermaid://`, `terminal://`, and `chat://` (legacy — kept so persisted layouts still load).

## Stores

### `LayoutStore` (`Layout/LayoutStore.swift`)

`@MainActor`, owns the `@Published` tree and `focusedPane`. All mutations from the UI flow through this object so `objectWillChange` fires once per user action. The 300ms debounce on `$tree` writes the layout snapshot to `~/Library/Application Support/Soffit/layout.json`.

### `WorkspaceStore` (`Workspace/WorkspaceStore.swift`)

Wraps a workspace root URL and a flat listing of its top-level entries. An `FSEventsWatcher` triggers `refresh()` on disk changes. The static helper `readDirectory(_:)` is `nonisolated` so providers can call it from background tasks.

### `RecentFilesStore` (`Workspace/RecentFilesStore.swift`)

UserDefaults-backed list of the last 20 opened files. MRU dedup, auto-prunes deleted files when the user expands the Recent section.

### Per-panel registries

Three singletons keyed on `PanelID`:

| Registry | Owns |
|---|---|
| `CanvasStateRegistry` | `CanvasStore` per folder panel — position/zoom/items/sticky notes |
| `MarkdownStateRegistry` | `MarkdownActiveState` per markdown panel — current mode, editor commands |
| `InitialStateHolder` | The on-load `Data?` blob so cold-started panels can restore their state |

These get cleaned up by `AppServices` when a panel disappears from the tree (it diffs `panelIDs` on every tree change).

## Rendering

### `LayoutHostView` → `LayoutTreeView` → `PaneView` / `SplitHost`

Recursive SwiftUI views matching the tree shape. `SplitHost` wraps `NSSplitViewRepresentable`, which holds two `NSHostingController` children to host the SwiftUI subtrees. Splits use a custom `InvisibleSplitView` (`drawDivider` is empty) so the gradient backdrop shows through the gutter.

### Why AppKit + SwiftUI hybrid?

Pure SwiftUI `HSplitView` / `VSplitView` are flaky around nested split-view dragging and geometry on macOS. AppKit's `NSSplitView` is rock-solid but only handles two arranged subviews per instance — perfect for a binary tree. So:
- Layout shell: `NSSplitView` (binary, nested, hand-rolled delegate).
- Pane content: SwiftUI throughout.

## Performance shape

Three patterns recur across the codebase:

1. **Read-on-demand → cached in `@State`**. Anywhere a SwiftUI view body would do disk IO, the IO moves into `Task.detached(priority: .userInitiated)` triggered from `onAppear` / `onChange`, with the result cached in `@State`. See `FilePreviewCard`, `DocumentCard`, `FileTreeView`.

2. **Debounced persistence**. Anywhere a per-frame mutation triggers a save, the save is gated through a Combine `debounce(for:scheduler:)` sink. See `LayoutStore` (300ms tree save), `CanvasStore` (250ms canvas state), `MarkdownPanelModel` (500ms file write).

3. **Discrete ops bypass the debounce**. The "immediate" path on `CanvasStore` (`add`, `remove`, color change, mode toggle) cancels any pending debounce and writes synchronously, then re-arms the sink. This keeps tests deterministic and gives the user the feeling that one-shot actions are durable immediately.

## Tests

`Tests/SoffitTests/`. Four suites, 36 tests:
- `LayoutTreeTests` — split/close/insert/remove/ratio/state/Codable.
- `CanvasStateTests` — defaults, codable, viewport preservation, sticky note edits, registry reuse.
- `MarkdownHighlighterTests` — full and incremental highlight, paragraph scope, code-fence fallback, large-document smoke.
- `PanelLifecycleTests` — registry cleanup, replacePanel identity, tab/pane removal, debounced canvas persistence convergence.

UI gestures (drag, drop zones, animation) are not unit-tested; live testing against `examples/` covers those.

## Key data flow

```
user action
   ↓
LayoutStore mutation (mainactor, sync)
   ↓
@Published tree fires objectWillChange
   ↓
SwiftUI re-renders the affected pane subtrees
   ↓
debounced sink picks up the new tree (300ms)
   ↓
JSON-encoded snapshot written atomically to disk
```

The debounce is the linchpin — it absorbs the burst of intermediate states a single user action produces (e.g., dragging a tab generates dozens of `objectWillChange` events; one disk write at the end captures the resting state).
