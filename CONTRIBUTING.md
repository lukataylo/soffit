# Contributing to Soffit

Thanks for considering a contribution. Soffit is intentionally small and opinionated; that shapes what kind of changes are welcome.

## What we welcome

- **Bug fixes.** Especially with a failing test that proves the bug.
- **Performance improvements** with a measurement.
- **Accessibility improvements.** VoiceOver labels, keyboard nav, dynamic type — anything that makes Soffit usable by more people.
- **Documentation** in the wiki or in-code comments.
- **New panel providers** that fit Soffit's "tile any kind of pane" model. See [Providers](https://github.com/lukataylo/soffit/wiki/Providers) for the protocol.

## What we'll politely decline

- **New top-level features that don't fit the markdown-power-user thesis.** Soffit is not Notion. We won't add databases, kanban boards, or block-based editing.
- **Cross-platform ports.** Soffit is macOS-native by design. The AppKit/SwiftUI hybrid layout, NSSplitView, NSTextView, and FSEvents wiring don't survive a Linux/Windows port.
- **Plugin runtime.** The `PanelProvider` protocol is the plugin model; runtime plugin loading is not on the roadmap.
- **Heavy dependencies.** Anything that would more than double the compiled binary size, or that pulls in Electron-equivalent runtimes, is a no.

## Workflow

1. **Open an issue first** for non-trivial changes. We'd rather discuss the design than reject a finished PR.
2. **Fork → branch → PR.** Branch names like `fix/short-description` or `feat/short-description`.
3. **One commit per PR is preferred.** Squash before merge if you have intermediate commits.
4. **Tests must pass.** `swift test` from the repo root. CI runs this on every PR.
5. **Match existing style.** No `swift-format` config currently; just match what's around the code you're editing.
6. **Keep the diff focused.** A bug fix doesn't need surrounding cleanup; a new feature doesn't need a refactor.

## Setup

Requires macOS 14+, Xcode 15+, full Xcode (not just Command Line Tools — XCTest doesn't ship with CLT).

```bash
git clone https://github.com/lukataylo/soffit.git
cd soffit
./scripts/vendor-mermaid.sh
./scripts/vendor-katex.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

To test the .app bundle:

```bash
./scripts/build-app.sh release        # App Store variant (default, sandboxed)
SOFFIT_VARIANT=pro ./scripts/build-app.sh release   # Pro variant (with terminal)
open build/Soffit.app
```

## Architecture

See [the Architecture wiki page](https://github.com/lukataylo/soffit/wiki/Architecture). The four primitives (`LayoutTree`, `Pane`, `Panel`, `PanelProvider`) carry the weight; everything else plugs in around them.

## Tests

Tests live in `Tests/SoffitTests/`. Four suites today:

- `LayoutTreeTests` — the pane tree mutation algebra
- `MarkdownHighlighterTests` — full + incremental highlighting
- `PanelLifecycleTests` — registry cleanup, replacePanel identity

**UI is not currently unit-tested.** Live testing against `examples/` covers gestures, animations, and drop targets.

## Commit messages

Imperative mood, present tense, short summary on the first line, blank line, optional body explaining the *why*.

```
Fix wikilink autocomplete on aliased targets

The regex was greedy on the alias separator, which meant typing
"[[Note|long alias" would never trigger the picker. Tightening to
[^|] in the alias group fixes it without breaking the bare case.
```

Avoid noise like "WIP", "fix typo", "address review". Squash before merging.

## License

By contributing, you agree your contribution is licensed under the [MIT License](LICENSE).

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). Be excellent to each other.
