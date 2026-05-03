# Soffit Privacy Policy

*Last updated: 2026-05-03*

## Short version

Soffit is a local-first markdown editor. Your files stay on your Mac. Soffit doesn't have a server, doesn't track you, doesn't collect analytics, doesn't phone home for any reason except checking for app updates.

## Long version

### What Soffit reads

- **Markdown and other text files in the workspace folder you choose.** Soffit needs to read these to display, search, and edit them.
- **File modification dates and folder contents** for sorting, the recent-files list, and the workspace index.
- **Your macOS Keychain entry for `com.soffit.app`**, only if you previously stored an Anthropic API key there. (The chat panel feature is being phased out; existing chat panels still load.)

### What Soffit writes

- **Markdown files you edit** — written back to the same paths on disk.
- **`~/Library/Application Support/Soffit/layout.json`** — pane tree, tab list, canvas item positions. Local-only.
- **`~/Library/Containers/com.soffit.app/`** (sandboxed builds only) — Soffit's container directory.
- **`UserDefaults`** keys under `com.soffit.app` — recent files list, sidebar width, theme preference, spell-check toggle, sandbox bookmark.
- **`~/.soffit/snippets.json` and `~/.soffit/themes/*.json`** — your customisations, only when you create them.
- **Pasted images** to `<workspace>/attachments/` — only when you `⌘V` an image into a markdown file.
- **`<workspace>/daily/YYYY-MM-DD.md`** — only when you press `⌘⇧D`.

### What Soffit transmits over the network

- **Update checks** — Soffit periodically fetches `https://github.com/lukataylo/soffit/releases.atom` (or the configured Sparkle appcast URL) to see if a newer version exists. The request is anonymous and contains only a normal `User-Agent` header.
- **Web panels** — when you load a URL in a web panel (e.g., a Figma embed or your localhost dev server), Soffit's `WKWebView` makes the request directly. Those requests are subject to those sites' own privacy policies.
- **Mermaid and math rendering** — fully offline. The libraries are bundled.

Soffit does **not** transmit any other data. There is no analytics, no telemetry, no crash reporting (yet — when added, it will be opt-in via macOS's MetricKit).

### Third-party services

Soffit uses the following open-source libraries which run entirely on your device:

- [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) — markdown rendering
- [Sparkle](https://sparkle-project.org) — auto-update infrastructure
- [KaTeX](https://katex.org) — math rendering (vendored, no network)
- [marked.js](https://marked.js.org) — markdown rendering for the math panel (vendored)
- [mermaid](https://mermaid.js.org) — diagram rendering (vendored)

### Your rights

Soffit holds no data about you on any server. There is nothing for us to delete, export, or change on your behalf. Your data is on your disk; you control it directly.

### Contact

For questions: open an issue at [github.com/lukataylo/soffit](https://github.com/lukataylo/soffit/issues).
