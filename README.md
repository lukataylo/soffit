# Workbench

A native macOS cockpit for product managers. Tile a markdown PRD, a mermaid diagram, a Figma frame, and a Claude chat panel in a single window — each resizable, each first-class, each exactly where your attention can reach it.

Where your 27 open tabs finally reconcile their feelings.

This is a v0.1 MVP. See `DECISIONS.md` for the non-obvious tradeoffs.

## Requirements

- macOS 14+ (Apple Silicon preferred)
- Xcode 15+ / Swift 5.9+
- An Anthropic API key (only required for the chat panel)

## Build and run

Workbench ships as a Swift Package. Modern Xcode opens `Package.swift` directly as a workspace.

```bash
# Command line
./scripts/vendor-mermaid.sh        # one-time: fetch mermaid.min.js for offline rendering
swift build -c release
./.build/release/Workbench

# Xcode
open Package.swift
# then Product → Run
```

On first launch you're asked for an Anthropic API key (stored in macOS Keychain) and a workspace folder. The `examples/` directory is a ready-made seed workspace for the fictional "Ember" retro tool: a PRD, four user stories, and three mermaid diagrams.

## What you can do

- **Pick a workspace folder.** The root opens as a card grid of every file in that folder, titled with a markdown heading where one exists and previewed inline.
- **Click a card or sidebar file** to open it in a **preview panel** next to the grid.
- **Double-click** to open the same file in **edit mode** (markdown gets editor + rendered preview in a split; mermaid gets the rendered chart).
- **Drag a panel's edge** into another panel to add a new split in that direction; pick the new panel's type from the picker (markdown, web, mermaid, chat).
- **Resize** by dragging any gutter. **Close** by clicking the × in the panel header.
- **Quit and relaunch.** Layout, markdown mode, and chat history come back exactly as you left them.

## Architecture

Three abstractions carry the weight:

1. **`LayoutTree`** (`Sources/Workbench/Layout/LayoutTree.swift`) — a recursive, `Codable` binary tree of splits and leaves. All mutation goes through `inserting`, `splitting(at:direction:newPanel:)`, `closing(_:)`, `settingRatio(for:to:)`, `replacingPanel(_:with:)`. Pure value type; 12 unit tests in `Tests/WorkbenchTests/LayoutTreeTests.swift`.
2. **`PanelProvider`** (`Sources/Workbench/Providers/PanelProvider.swift`) — a protocol registered by URI scheme. Five providers ship in v0.1: `FolderProvider` (`folder://` card grid), `FileProvider` (`file://`, markdown editor + preview), `WebProvider` / `MermaidProvider` (`https://`, `mermaid://`), and `ChatProvider` (`chat://claude`).
3. **`Panel`** (`Sources/Workbench/Layout/Panel.swift`) — the serialised leaf: an ID, a source URI, and an opaque `state: Data?` the provider uses to persist scroll position, chat history, or the markdown editor's mode.

The tree renders through `LayoutTreeView`, which wraps each split in an `NSSplitView` via `NSSplitViewRepresentable` for reliable nested drag-to-resize.

## Panel providers

- **Folder (`folder://`)** — card grid for a directory; each card shows a live markdown excerpt, mermaid source, or folder preview. Click a card to open for preview; double-click to open in edit mode. Click a folder card to navigate in place. Breadcrumb header jumps up the tree.
- **File (`file://`)** — markdown editor with a `Preview / Source / Split` pill toggle. Non-markdown files fall back to a read-only source view. Autosave on a 500ms debounce.
- **Web (`https://`)** — WKWebView. Figma URLs auto-rewrite to embed form; localhost passes through.
- **Mermaid (`mermaid://`)** — rewrites a workspace-relative `.mmd` path into a local HTML shim (`Resources/mermaid-shim.html`) that receives the diagram source via `postMessage`. Vendored `mermaid.min.js` — no network.
- **Chat (`chat://claude`)** — streamed SSE against `/v1/messages`, default model `claude-opus-4-7`. API key read from Keychain.

## Persistence

- `~/Library/Application Support/Workbench/layout.json` — the full tree plus workspace root, written debounced (300ms) on any tree change.
- Panel-specific state (chat history, markdown editor mode) lives in each panel's `state: Data?` blob and round-trips through the same file.
- API key lives in macOS Keychain under `com.workbench.app` / `anthropic_api_key`.

## Known limitations (v0.1)

- No MCP, no tool use, no panel-to-panel data flow beyond the notification bus shell.
- Chat has no workspace awareness — responses are generic.
- Markdown editor uses regex syntax highlighting (not tree-sitter).
- Figma integration is embed-URL only; no Figma API.
- Single window, single workspace.
- `mermaid.min.js` is not checked into the repo; run `scripts/vendor-mermaid.sh` once.
- No app icon, no code signing, no notarisation — build from source.

## Testing

```bash
# Full Xcode is required (CommandLineTools does not ship XCTest on macOS).
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

12 tests cover `LayoutTree` (split / close / setRatio / replace / Codable round-trip). UI layers are not unit-tested.

## Repository layout

```
Package.swift                          SPM manifest — executable + tests
Sources/Workbench/
  App/                                 WorkbenchApp, AppServices, RootView, commands
  Layout/                              LayoutTree, LayoutStore, NSSplitView representable, headers
  Providers/
    Folder/                            Directory card grid, DocumentCard, breadcrumb
    File/                              Markdown editor + preview, mode toggle, syntax highlighter
    Web/                               WKWebView, URL resolver (Figma / mermaid / localhost)
    Chat/                              ChatPanelView + ChatPanelModel + AnthropicClient (SSE)
  Workspace/                           Workspace folder picker, file tree, FSEvents watcher
  Persistence/                         KeychainStore, LayoutPersistence
  UI/                                  PanelTypePicker, OnboardingView, WorkbenchSurface background
  Resources/                           mermaid-shim.html, mermaid.min.js
Tests/WorkbenchTests/                  LayoutTreeTests
examples/                              Seed workspace: Ember retro PRD, stories, diagrams
scripts/vendor-mermaid.sh              Vendor mermaid.js once
```
