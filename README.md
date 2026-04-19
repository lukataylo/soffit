# Soffit

A native macOS cockpit for product managers. Tile a markdown PRD, a mermaid diagram, a Figma frame, a Claude chat, and an embedded terminal in a single window — each as a first-class, draggable, resizable tab inside IDE-style panes.

Where your 27 open tabs finally reconcile their feelings.

This is a v0.2 MVP. See `DECISIONS.md` for the non-obvious tradeoffs.

## Requirements

- macOS 14+ (Apple Silicon preferred)
- Xcode 15+ / Swift 5.9+
- An Anthropic API key (only when you want the Claude chat panel)

## Build and run

Soffit ships as a Swift Package. Modern Xcode opens `Package.swift` directly as a workspace.

```bash
# Command line
./scripts/vendor-mermaid.sh        # one-time: fetch mermaid.min.js for offline rendering
swift build -c release
./.build/release/Soffit

# Xcode
open Package.swift
# then Product → Run
```

On first launch you're asked to pick a workspace folder. The `examples/` directory is a ready-made seed workspace for the fictional "Ember" retro tool: a PRD, four user stories, and three mermaid diagrams. The Anthropic API key is asked for only when needed — set it any time via **Soffit → Set Anthropic API Key…**.

## What you can do

- **Pick a workspace folder.** The root opens as a card grid of every file, each card showing a live excerpt.
- **Click a card** to open the file as a **tab** in the focused pane. Double-click to open in edit mode.
- **Drag a tab** to move it — compass overlay shows four split directions on the target pane, or drop on the tab strip to merge as a tab.
- **Split a pane** via `⌘\` (right) or `⌘⇧\` (down), or the pane's `[⋮]` menu.
- **Resize** any pane by dragging its divider. The invisible `NSSplitView` divider leaves breathing room through the gradient.
- **Edit markdown** directly in the preview — syntax markers (`**`, `#`, `` ` ``, `*`) render invisibly so you see formatted text while you type. Toolbar pill above the markdown pane gives one-tap bold, italic, heading, list, quote, link, code, and a table picker.
- **Run Claude Code** right in Soffit — `New Terminal` (⇧⌘T) opens an embedded xterm-compatible terminal (via SwiftTerm) rooted in the workspace directory.
- **Drag the window** from the top 28pt strip. Double-click that strip to zoom, honouring your system-wide title-bar preference.
- **Quit and relaunch.** Layout, tabs, markdown mode, and chat history come back exactly as you left them (terminals spawn fresh).

## Architecture

Four abstractions carry the weight:

1. **`LayoutTree`** (`Sources/Soffit/Layout/LayoutTree.swift`) — a recursive, `Codable` binary tree of splits and leaves. Each leaf is a `Pane` holding multiple tab panels with one active. Mutation flows through `addingTab`, `removingTab`, `splittingPane`, `settingActiveTab`, `settingRatio`, `closingPane`, `replacingPanel`. Pure value type; 15 unit tests in `Tests/SoffitTests/LayoutTreeTests.swift`.
2. **`Pane`** (`Sources/Soffit/Layout/Pane.swift`) — holds `tabs: [Panel]` and `activeTabID`. Closing the last tab removes the pane and promotes its sibling.
3. **`PanelProvider`** (`Sources/Soffit/Providers/PanelProvider.swift`) — a protocol registered by URI scheme. Six providers ship in v0.2: `FolderProvider` (`folder://` card grid), `FileProvider` (`file://`, markdown editor + preview), `WebProvider` / `MermaidProvider` (`https://`, `mermaid://`), `ChatProvider` (`chat://claude`), and `TerminalProvider` (`terminal://`).
4. **`Panel`** (`Sources/Soffit/Layout/Panel.swift`) — the serialised tab: an ID, source URI, title, and opaque `state: Data?` the provider uses to persist mode, scroll, chat history, etc.

Splits render through `NSSplitViewRepresentable` wrapping a custom `InvisibleSplitView` so dividers paint nothing — the gradient shows through.

## Panel providers

- **Folder (`folder://`)** — card grid for a directory; each card has a live excerpt. Double-click to open a file as a tab in the pane. Click a folder card to navigate in place. Breadcrumb at the top.
- **File (`file://`)** — markdown editor with three modes: Preview (WYSIWYG-ish, syntax markers hidden), Source (raw mono), Split (source + rendered). Floating toolbar pill above the pane for headings, bold, italic, code, lists, quote, link, table. Autosave on 500ms debounce.
- **Web (`https://`)** — WKWebView. Figma URLs auto-rewrite to embed form; localhost passes through.
- **Mermaid (`mermaid://`)** — rewrites a workspace-relative `.mmd` path into a local HTML shim (`Resources/mermaid-shim.html`) that receives the diagram source via `postMessage`. Vendored `mermaid.min.js` — no network.
- **Chat (`chat://claude`)** — streamed SSE against `/v1/messages`, default model `claude-opus-4-7`. API key read from Keychain.
- **Terminal (`terminal://`)** — embedded `LocalProcessTerminalView` from SwiftTerm. Starts the user's login shell in the workspace directory. Ready for `claude` Claude Code sessions.

## Drag-to-split

- Grab a tab pill and drag it over any pane.
- Drop on the **tab strip** → tab is inserted in that pane.
- Drop on the **pane body** → a 4-way compass appears, releasing on an arrow splits the pane on that side with your tab. Direction is picked from the cursor quadrant (no "center" zone — tab merging is the tab strip's job).
- Drop on the **originating single-tab pane** → splits in place with an empty sibling pane; use its `[+]` to populate.

## Persistence

- `~/Library/Application Support/Soffit/layout.json` — the full pane tree (tabs + active IDs) plus workspace root, written debounced (300ms) on any tree change.
- Panel-specific state (markdown mode, chat history) lives in each panel's `state: Data?` blob and round-trips through the same file.
- API key lives in macOS Keychain under `com.soffit.app` / `anthropic_api_key`.

## Known limitations

- No MCP, no tool use, no panel-to-panel data flow beyond the notification-bus shell.
- Chat has no workspace awareness — but the embedded terminal + Claude Code covers that gap.
- Markdown editor uses regex syntax highlighting (not tree-sitter); hidden-syntax rendering is WYSIWYG-ish, not a full rich editor.
- Figma integration is embed-URL only; no Figma API.
- Single window, single workspace.
- `mermaid.min.js` is not checked into the repo; run `scripts/vendor-mermaid.sh` once.
- Terminal panes are session-bound (a relaunch spawns a fresh shell).
- No app icon, no code signing, no notarisation — build from source.

## Testing

```bash
# Full Xcode is required (CommandLineTools does not ship XCTest on macOS).
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

15 tests cover `LayoutTree` (split / close / tab insert / tab remove / ratio / state update / Codable round-trip with multi-tab panes). UI layers are not unit-tested.

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
  Resources/                           mermaid-shim.html, mermaid.min.js
Tests/SoffitTests/                     LayoutTreeTests
examples/                              Ember retro: PRD, stories, diagrams
scripts/vendor-mermaid.sh              Vendor mermaid.js once
```
