# Changelog

All notable changes to Soffit are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning follows
[Semver](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Pro/Free split. `SOFFIT_VARIANT=appstore` builds a sandboxed App Store
  variant; `SOFFIT_VARIANT=pro` builds an embedded-terminal Pro variant
  distributed via DMG.
- Embedded terminal pane (Pro only) via SwiftTerm.
- Editable mermaid diagrams. New `MermaidPanelView` with Source / Render /
  Split modes and 500 ms debounced autosave to the underlying `.mmd` file.
- Search icon in the top toolbar (`⌘P`).
- "New Markdown File" action in the folder grid header and sidebar with
  collision-safe naming (`Untitled.md`, `Untitled 2.md`, …).
- Typeable Preview mode — write rendered-style markdown without leaving
  Preview.
- GitHub Actions: `ci.yml` runs `swift build` + `swift test` on every push
  and PR; `release.yml` builds both DMGs on tag push and publishes a
  release with notes pulled from this changelog.
- Issue templates (bug report, feature request) and `CONTRIBUTING.md`.

### Changed
- Bumped surface translucency to `.sidebar` material.
- `build-app.sh` now produces a fully sealed code signature on macOS 14+.
  Uses `ditto --noextattr` for nested bundles and pipelines
  `xattr -c && codesign` so the kernel can't re-stamp `FinderInfo`
  between strip and sign.

### Fixed
- Sparkle's "Unable to Check For Updates" dialog when the public EdDSA
  key is unset — the menu item is now hidden until a real key is in
  `Info.plist`.

## [0.3.0] — 2026-04

### Added
- App Store readiness pass: sandbox + entitlements + security-scoped
  bookmarks, `PrivacyInfo.xcprivacy`, Sparkle 2.6 auto-update from
  GitHub Pages appcast, localisation scaffolding, two-screen onboarding
  flow, accessibility labels.
- iCloud Drive awareness: `CloudFile.materialise` waits for placeholder
  files to download before opening.
- Per-window state (`WindowSession`) so multi-window doesn't share panes.
- Folder canvases with sticky notes and file preview cards.
- Dark-mode-aware MarkdownUI theme (tables, code, blockquotes,
  headings).

### Changed
- Renamed Workbench → Soffit, full UX overhaul.
- Removed canvas mode in favour of multi-window tabs.
- Top-level surface uses `.sidebar` material; tighter gutters.

### Fixed
- Layout mutations now re-publish through `WindowSession` so
  `addTab` / `closeTab` correctly redraw.
- `setSelectedRange` out-of-bounds when external text shrinks under
  the cursor.

## [0.2.0] — 2026-03

### Added
- 17 of 19 planned power-user features: search palette, wiki-links,
  tags, outline panel, math (KaTeX), sketch, snippets, daily notes,
  git status, find/replace, and more.
- Workspace index with FSEvents-driven incremental updates.
- Markdown highlighter with full + incremental modes.

## [0.1.0] — 2026-02

### Added
- Initial Workbench v0.1 — a tiled macOS cockpit for power users.
- Pane / tab / panel primitives backed by `LayoutTree`.
- File, Folder, Web, Mermaid, Chat, Sketch, Terminal providers.
- SwiftPM executable target with bundled resources.

[Unreleased]: https://github.com/lukataylo/soffit/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/lukataylo/soffit/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/lukataylo/soffit/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/lukataylo/soffit/releases/tag/v0.1.0
