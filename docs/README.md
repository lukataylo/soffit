# Soffit docs

Versioned documentation that travels with the code. The same content is suitable for the GitHub wiki — see the note at the bottom.

## Pages

- **[Quickstart](Quickstart.md)** — install, first launch, basic workflows.
- **[Canvas mode](Canvas-mode.md)** — the freeform spatial folder mode.
- **[Keyboard shortcuts](Keyboard-shortcuts.md)** — everything bindable.
- **[Architecture](Architecture.md)** — for contributors. The four primitives, stores, rendering, perf shape.

## Mirroring to the GitHub wiki

GitHub's wiki is a separate git repo (`soffit.wiki.git`) that doesn't exist until the first page is created via the web UI. To mirror this folder to the wiki:

1. Visit https://github.com/lukataylo/soffit/wiki and click **Create the first page** (any content — it'll get overwritten).
2. Then locally:
   ```bash
   git clone https://github.com/lukataylo/soffit.wiki.git
   cd soffit.wiki
   cp ../soffit/docs/*.md .
   git add . && git commit -m "Sync docs from main repo" && git push
   ```

Or just rely on the in-repo `docs/` folder — GitHub renders these as plain markdown when you browse, and they stay in sync with the code via PRs.
