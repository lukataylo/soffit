# Quickstart

The 60-second tour.

## Install

Either:
- **Pre-built**: download `Soffit-<version>.dmg` from the [Releases page](https://github.com/lukataylo/soffit/releases), drag Soffit to Applications, right-click → **Open** the first time (the DMG is ad-hoc signed, not Apple-notarized).
- **From source**:
  ```bash
  git clone https://github.com/lukataylo/soffit.git
  cd soffit
  ./scripts/vendor-mermaid.sh                                            # one-time
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release
  ./scripts/build-app.sh release
  open build/Soffit.app
  ```

## First launch

1. Soffit asks you to pick a **workspace folder**. Pick any folder — it doesn't have to be empty, doesn't need a `.soffit/` dotfile, doesn't lock anything in. Soffit just reads + writes the markdown files you already have.
2. The folder opens as a **card grid** of every file inside, each card showing a live excerpt.

## Open a file

- **Single click** a card → opens as a tab in the focused pane, in **Preview** mode (rendered).
- **Double click** a card → opens in **Split** mode (source + rendered side-by-side).

## Tile your workspace

- Drag a tab onto another pane. A 4-way **compass** appears: drop on an arrow to split that pane on that side.
- Drop on the **tab strip** of a pane to merge it as a tab there.
- Use `⌘\` (split right) and `⌘⇧\` (split down) to split with the same content.

## Canvas mode

Switch any folder from **Grid** to **Canvas** in the header picker:

- Drag files anywhere on the canvas — they keep their position.
- Right-click empty space → **Add sticky note** (also via the floating `+` button).
- Trackpad pinch to zoom; two-finger drag to pan.
- Sticky note text and item positions persist per folder.

## Markdown editing

A markdown tab has three modes (toggle via the floating pill above the pane):

| Mode | What it shows |
|---|---|
| **Preview** | Real GFM render — tables, code blocks, lists, links all formatted properly |
| **Source** | Raw markdown, monospace, paragraph-scoped syntax highlighting |
| **Split** | Source on the left, rendered on the right |

Autosave fires on a 500ms debounce. Tab close flushes any pending edit.

## Embedded terminal

Sidebar → **New Terminal** drops you in a real shell rooted in your workspace. Run `claude`, `git`, `vim`, anything. Each terminal is its own pane, draggable + tileable like any other.
