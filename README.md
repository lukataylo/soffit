# Soffit

A native macOS workspace for markdown power users. Tile any folder as a freeform canvas, edit markdown in place, drop in mermaid diagrams, web embeds, Claude chat, and an embedded terminal — all as draggable tabs inside IDE-style splittable panes.

Built for the post-Obsidian crowd: local-first, file-on-disk, no plugins, no cloud, no lock-in. Just markdown and panes.

This is v0.3. See `DECISIONS.md` for the non-obvious tradeoffs.

## Requirements

- macOS 14+ (Apple Silicon preferred)
- Xcode 15+ / Swift 5.9+

## Install

```bash
# One-time: fetch mermaid.min.js for offline diagram rendering
./scripts/vendor-mermaid.sh

# Build the .app bundle (icon + Info.plist + ad-hoc signing)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release
./scripts/build-app.sh release

# Launch
open build/Soffit.app
```

For development:

```bash
open Package.swift     # Modern Xcode treats this as a workspace
# then Product → Run
```

The first launch asks you to pick a workspace folder. The `examples/` directory is a ready-made seed workspace.

## What you can do

- **Pick any folder as a workspace** — Soffit treats it as a card grid by default. Each card is a live excerpt of the file.
- **Switch any folder to *Canvas* mode** — drop files anywhere, drag them around, add sticky notes, zoom and pan with trackpad. Your spatial layout persists per folder.
- **Click a card** to open the file as a tab in the focused pane. Double-click to open in edit/split mode.
- **Add a tab** via the `[+]` menu in any tab strip — pick from File, URL/diagram, or Terminal.
- **Drag a tab** to split or merge — compass overlay shows four split directions on the target pane, or drop on the tab strip to merge as a tab.
- **Split a pane** via `⌘\` (right) or `⌘⇧\` (down), or the pane's `[⋮]` menu.
- **Edit markdown** in three modes: *Preview* (real GFM rendering — tables, code blocks, lists, links all properly formatted), *Source* (raw monospace), *Split* (source + rendered side-by-side). Source highlighting is incremental so even very long PRDs stay responsive. Toolbar pill above the markdown pane has one-tap bold, italic, heading, list, quote, link, code, and a table picker — and scrolls horizontally on narrow panes.
- **Run `claude`** (or any CLI) inside the embedded terminal — `New Terminal` in the sidebar drops you in the workspace directory.
- **Drag the window** from the top 28pt strip. Double-click to zoom, honouring your system-wide title-bar preference.
- **Quit and relaunch.** Layout, tabs, markdown mode, canvas positions, and chat history all come back (terminals spawn fresh).

## Architecture

Four abstractions carry the weight:

1. **`LayoutTree`** (`Sources/Soffit/Layout/LayoutTree.swift`) — a recursive, `Codable` binary tree of splits and leaves. Each leaf is a `Pane` holding multiple tab panels with one active. Mutation flows through `addingTab`, `removingTab`, `splittingPane`, `settingActiveTab`, `settingRatio`, `closingPane`, `replacingPanel`. Pure value type; 15 unit tests in `Tests/SoffitTests/LayoutTreeTests.swift`.
2. **`Pane`** (`Sources/Soffit/Layout/Pane.swift`) — holds `tabs: [Panel]` and `activeTabID`. Closing the last tab removes the pane and promotes its sibling.
3. **`PanelProvider`** (`Sources/Soffit/Providers/PanelProvider.swift`) — a protocol registered by URI scheme. The shipping providers: `FolderProvider` (`folder://` grid + canvas), `FileProvider` (`file://`, markdown editor + preview), `WebProvider` / `MermaidProvider` (`https://`, `mermaid://`), and `TerminalProvider` (`terminal://`). A `ChatProvider` is registered for `chat://` URIs so any panels persisted before v0.3 still load, but the UI no longer surfaces a way to create new chat panels.
4. **`Panel`** (`Sources/Soffit/Layout/Panel.swift`) — the serialised tab: an ID, source URI, title, and opaque `state: Data?` the provider uses to persist mode, scroll, chat history, etc.

Splits render through `NSSplitViewRepresentable` wrapping a custom `InvisibleSplitView` so dividers paint nothing — the gradient shows through.

## Panel providers

- **Folder (`folder://`)** — two modes per folder: **Grid** (card grid, sortable by name/recent/kind) and **Canvas** (freeform spatial layout with sticky notes, drag-to-position, zoom/pan). Mode and item positions persist per folder. Breadcrumb at the top.
- **File (`file://`)** — markdown editor with three modes: Preview (true GFM render via MarkdownUI — tables, code blocks, lists, links), Source (raw mono with paragraph-scoped incremental highlighting), Split (source + rendered side-by-side). Floating toolbar pill above the pane for headings, bold, italic, code, lists, quote, link, table. Autosave debounced at 500ms; flush on tab close to prevent edit loss.
- **Web (`https://`)** — WKWebView. Figma URLs auto-rewrite to embed form; localhost passes through.
- **Mermaid (`mermaid://`)** — rewrites a workspace-relative `.mmd` path into a local HTML shim (`Resources/mermaid-shim.html`) that receives the diagram source via `postMessage`. Vendored `mermaid.min.js` — no network.
- **Terminal (`terminal://`)** — embedded `LocalProcessTerminalView` from SwiftTerm. Starts the user's login shell in the workspace directory. Drop into `claude` Code sessions or any CLI.

## Drag-to-split

- Grab a tab pill and drag it over any pane.
- Drop on the **tab strip** → tab is inserted in that pane.
- Drop on the **pane body** → a 4-way compass appears, releasing on an arrow splits the pane on that side with your tab. Direction is picked from the cursor quadrant (no "center" zone — tab merging is the tab strip's job).
- Drop on the **originating single-tab pane** → splits in place with an empty sibling pane; use its `[+]` to populate.

## Persistence

- `~/Library/Application Support/Soffit/layout.json` — the full pane tree (tabs + active IDs) plus workspace root, written debounced (300ms) on any tree change.
- Panel-specific state (markdown mode, canvas item positions) lives in each panel's `state: Data?` blob and round-trips through the same file. Canvas state writes are debounced 250ms to keep drags smooth.
- Markdown file content writes happen off the main thread.
- Recent files (`UserDefaults` `soffit.recentFiles.v1`) — last 20 opened files, MRU dedup, auto-prunes deleted entries.

## Known limitations

- No MCP, no tool use, no panel-to-panel data flow beyond the notification-bus shell.
- Markdown editor uses regex syntax highlighting (not tree-sitter); incremental scoping makes this fast even on PRD-sized files but extreme edge cases (massively nested fences) may need a manual mode-toggle to re-paint.
- Figma integration is embed-URL only; no Figma API.
- Single window, single workspace.
- `mermaid.min.js` is not checked into the repo; run `scripts/vendor-mermaid.sh` once.
- Terminal panes are session-bound (a relaunch spawns a fresh shell).
- The shipped .app bundle uses ad-hoc code signing — no notarisation. First-run on another Mac requires right-click → Open. The runtime fallback (programmatic dock icon at launch) still applies for SPM-direct execution.
- External edits to a markdown file while it's open in Soffit will be overwritten by the next debounced save (no file-mtime conflict detection yet).

## Testing

```bash
# Full Xcode is required (CommandLineTools does not ship XCTest on macOS).
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

36 tests cover:
- `LayoutTree` — split/close/tab insert/remove/ratio/state update/Codable round-trip
- `CanvasState` — defaults, codable, viewport preservation, debounced persistence, sticky note edit/color, registry reuse
- `MarkdownHighlighter` — full + incremental highlighting, paragraph scope expansion, code-fence fallback, large-document smoke
- `PanelLifecycle` — registry cleanup, replacePanel identity, tab/pane removal

UI layers (drag gestures, drop zones, animations) are not unit-tested.

## Repository layout

```
Package.swift                          SPM manifest — Soffit executable + tests
Sources/Soffit/
  App/                                 SoffitApp, AppServices, RootView, commands
  Layout/                              LayoutTree, Pane, LayoutStore, PaneView,
                                       NSSplitView representable, tab strip + pills,
                                       drop delegate, compass overlay
  Providers/
    Folder/                            Directory card grid, DocumentCard, breadcrumb
    File/                              Markdown editor (Preview/Source/Split),
                                       toolbar pill, table popover, highlighter
    Web/                               WKWebView, URL resolver (Figma / mermaid / localhost)
    Chat/                              ChatPanelView + ChatPanelModel + AnthropicClient (SSE)
    Terminal/                          SwiftTerm-backed local shell
  Workspace/                           Folder picker, sidebar, FSEvents watcher
  Persistence/                         KeychainStore, LayoutPersistence
  UI/                                  PanelTypePicker, OnboardingView, SoffitSurface,
                                       TitleBarDragRegion
  Resources/                           mermaid-shim.html, mermaid.min.js,
                                       AppIcon.icns, AppIcon.iconset/
Tests/SoffitTests/                     LayoutTree, CanvasState,
                                       MarkdownHighlighter, PanelLifecycle
examples/                              Ember retro: PRD, stories, diagrams
scripts/vendor-mermaid.sh              Vendor mermaid.js once
scripts/generate-icon.swift            Re-render the AppIcon programmatically
scripts/build-app.sh                   Wrap the SPM executable as Soffit.app
```
