# Canvas mode

Every folder in Soffit has a freeform Canvas alongside the default card grid. Switch modes via the picker in the folder header (`Grid` / `Canvas`).

Canvas mode is the marquee feature: it lets you treat a folder as a spatial workspace — drop files anywhere, drag them around, scatter sticky notes, zoom in on a cluster. Your layout persists per folder, not globally.

## What you can put on a canvas

| Item | Source |
|---|---|
| **File card** | Drag from sidebar, drop on canvas. Or right-click a grid card → **Add to Canvas**. Or drag a file from Finder onto the canvas. |
| **Sticky note** | Floating `+` button on the canvas. Type freely. Pick from four colours (yellow, pink, blue, green). |

## Movement + viewport

| Gesture | Effect |
|---|---|
| Drag a card / sticky | Move it (debounced position save — feels frictionless) |
| Trackpad pinch | Zoom canvas (0.25× to 3.0×) |
| Two-finger drag empty space | Pan the canvas |
| Click a file card | Open it as a tab in the focused pane |
| Right-click an item | Delete |

Zoom and pan are persisted per folder, so reopening the same folder restores its viewport.

## How it persists

Canvas state lives in the panel's `state: Data?` blob (see [Architecture](Architecture.md)), which round-trips through `~/Library/Application Support/Soffit/layout.json`. Per-item:

- `position: CGPoint` — top-left in canvas space (independent of zoom)
- `size: CGSize` — defaults: file card 320×260, sticky 220×160
- `kind: file(path)` or `kind: stickyNote(text, color)`

For files: paths are stored relative to the workspace root when possible, absolute as a fallback. So if you rename your workspace folder but keep the structure, canvas positions still resolve.

## Performance notes

- Drag and pan/zoom mutate the in-memory state synchronously, so the visual response is at SwiftUI's frame rate.
- The actual JSON encode + disk write is debounced 250ms — a single drag of an item causes one write at rest, not 60+ writes per second.
- File card previews load **once**, async, then cache in the view's `@State`. Panning a canvas with 30 cards triggers zero file reads.

## Tips

- Spatial memory beats hierarchy for some kinds of work. Use Canvas mode for project hubs, retrospective walls, ideation surfaces, anywhere "where" matters.
- Keep one folder = one workspace. Canvas state is per-folder, so duplicating a folder duplicates the layout too (but not vice versa — the canvas blob is in `layout.json`, not the folder itself).
- Sticky notes are not files — they live only in the canvas blob. If you want a permanent note, make a `.md` file and drop it on the canvas instead.
