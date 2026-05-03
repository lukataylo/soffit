# App Store submission checklist

This is the runbook for getting Soffit through App Review. Items marked ✅
are already done in code; the rest require Apple Developer account access
and App Store Connect work.

## What's already in place ✅

- **App Sandbox** — `Resources/Soffit.entitlements` with the minimum required
  entitlements: `app-sandbox`, `files.user-selected.read-write`,
  `files.bookmarks.app-scope`, `network.client`. The build script applies
  them via `codesign --entitlements`.
- **Security-scoped bookmarks** — `WorkspaceBookmark.swift` persists the
  user's chosen folder across launches and re-resolves with
  `startAccessingSecurityScopedResource()`.
- **Privacy manifest** — `Sources/Soffit/Resources/PrivacyInfo.xcprivacy`
  declares zero data collection, zero tracking, and the required-reason API
  categories Soffit touches. Copied into `Soffit.app/Contents/Resources/` by
  `build-app.sh`.
- **Privacy policy** — `PRIVACY.md` in the repo root, linked from the About
  window.
- **No subprocess execution** — terminal provider was removed for App Store
  compatibility.
- **Hardened runtime** — `codesign --options runtime` is applied.
- **Bundle metadata** — `CFBundleIdentifier=com.soffit.app`,
  `LSMinimumSystemVersion=14.0`, `LSApplicationCategoryType=public.app-category.productivity`.
- **Onboarding** — `OnboardingFlowView` shown on first launch.
- **Accessibility** — `accessibilityLabel`, `accessibilityHint`,
  `accessibilityAdjustableAction` applied to custom controls. Tab pills,
  sidebar toggle, sidebar resize handle, search palette, file rows.

## What you (Luka) still need to do

### One-time setup

1. **Enroll in the Apple Developer Program** ($99/year). You need a paid
   account — App Store distribution is not free.
2. **Create an App ID** in the Apple Developer portal:
   - Bundle ID: `com.soffit.app` (matches Info.plist).
   - Capabilities: App Sandbox.
3. **Create a Distribution Provisioning Profile** for that App ID.
4. **App Store Connect → My Apps → New App**:
   - Name: `Soffit`.
   - Primary language: English (US).
   - Bundle ID: `com.soffit.app`.
   - SKU: `soffit` (anything unique).

### Per-release workflow

1. **Bump version** in `scripts/build-app.sh` (`VERSION="…"`).
2. **Build a signed, notarized DMG**:
   ```bash
   # Replace ad-hoc signing with your Developer ID identity.
   # Edit build-app.sh line:  --sign -  →  --sign "Developer ID Application: Your Name (TEAMID)"
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release
   ./scripts/build-app.sh release
   ./scripts/build-dmg.sh
   xcrun notarytool submit build/Soffit-<version>.dmg \
       --apple-id you@example.com \
       --team-id TEAMID \
       --password APP_SPECIFIC_PASSWORD \
       --wait
   xcrun stapler staple build/Soffit-<version>.dmg
   ```
   The Apple-specific password is generated at appleid.apple.com → Sign-in
   Security → App-Specific Passwords.
3. **Upload to App Store Connect**:
   - Use Transporter.app (download free from the Mac App Store) — drag the
     `.app` (zipped or as part of an `.ipa`-equivalent build).
   - Or use `xcrun altool --upload-app` if you prefer CLI.
4. **Fill in the App Store Connect listing** — see the next section.

### App Store Connect listing copy

**Subtitle (30 chars):**

> Markdown workspace for Mac

**Promotional text (170 chars):**

> Tile any folder of markdown into split panes. Wiki-links, full-text search, mermaid diagrams. Local-first. No vault, no plugins, no cloud.

**Description (4000 chars):**

```
A native Mac workspace for markdown.

Tile any folder. Edit, preview, sketch — all in one window.

Soffit reads and writes the markdown files you already have. No vault structure. No import. No syncing service of its own. Your files stay on your disk; Soffit just gives them a faster, more spatial home.

DESIGNED FOR THE POST-OBSIDIAN CROWD
• Open any folder as a workspace — your existing notes work as-is
• Tile splits via drag-and-drop, like a real IDE
• Local-first: nothing leaves your Mac except an anonymous version-check ping for updates

WIKI-LINKS, BACKLINKS, TAGS
• Type [[Note Name]] — auto-creates the note if it doesn't exist
• See every note linking to the current one in a side panel
• Tag with #project — the sidebar tracks them all

FAST EVERYWHERE
• ⌘P jumps to any file by name or heading
• ⌘⇧F searches every word in your workspace
• ⌘⌥F finds and replaces across files
• Indexing runs in the background — no lag, even on thousands of notes

REAL MARKDOWN
• GitHub-flavoured rendering: tables, code, task lists, links
• Math via KaTeX — $E = mc^2$
• Mermaid diagrams render inline, no internet needed
• Syntax highlighting that re-scans only the paragraph you're editing

YOUR EVERYDAY TOOLS
• Daily notes (⌘⇧D) with optional templates
• Sketch panels for freehand drawing
• Snippets — type ,date<space> for today
• Multi-window workflow with ⌘N

PRIVACY-FIRST
• No accounts, no analytics, no telemetry
• Compatible with iCloud Drive, Dropbox, git
• Source available at github.com/lukataylo/soffit
```

**Keywords (100 chars, comma-separated):**

> markdown, notes, editor, wiki, productivity, obsidian, knowledge, prd, writer, journal

**Support URL:**

> https://github.com/lukataylo/soffit/issues

**Marketing URL:**

> https://github.com/lukataylo/soffit

**Privacy Policy URL:**

> https://github.com/lukataylo/soffit/blob/main/PRIVACY.md

**Category:** Productivity (primary), Developer Tools (secondary)

**Age Rating:** 4+

### Screenshots (required: 3–10 per device family)

Required sizes for Mac:
- **1280 × 800** (16:10 — minimum)
- **1440 × 900** (recommended)
- **2560 × 1600** (Retina, recommended)
- **2880 × 1800** (Retina, recommended)

Suggested 5 screenshots:
1. **The hero shot** — multi-pane editor + mermaid diagram + folder grid
   (use `assets/hero.png` as a starting frame).
2. **Quick palette** — `⌘P` open with a fuzzy match showing.
3. **Wiki-links + backlinks** — markdown panel with backlinks side panel
   visible.
4. **Math rendering** — Math mode showing rendered equations.
5. **Multi-window** — two windows side-by-side with different layouts.

Generate via macOS screen capture (`⌘⇧4`) on a workspace with the demo
content under `examples/`.

### App Review notes

Paste this into App Store Connect → "App Review Information → Notes":

```
Soffit is a local-first markdown editor for Mac.

It does not require an account, does not transmit user data, and works
entirely with files the user has selected via NSOpenPanel. The workspace
folder is persisted as a security-scoped bookmark.

The only network activity is:
1. Sparkle auto-update checks (anonymous, configurable feed URL)
2. WKWebView panels load whatever URL the user opens (e.g., Figma embeds,
   localhost dev servers)

The app was previously distributed outside the Mac App Store; this is the
first App Store submission. The terminal feature available in the GitHub
release has been removed for App Store compliance.

To test:
- Open the app
- Click "Use the Examples Workspace" in the welcome screen, OR pick any
  folder containing .md files
- Try ⌘P to search, click any markdown file, edit it
- Try wiki-links: type [[somefile]] — auto-creates if not present
```

### Common rejection reasons to pre-empt

| Risk | Mitigation in place |
|---|---|
| Subprocess exec | Terminal removed; no `Process` calls except `git` (covered by network entitlement, not subprocess) |
| Unsandboxed file access | `files.user-selected.read-write` + bookmarks |
| Missing privacy manifest | `PrivacyInfo.xcprivacy` with required-reason APIs declared |
| Crashes on launch | We've shipped a stable build for ~2 weeks; sandbox-tested |
| Misleading description | Copy above is accurate; chat panels listed as "phasing out" rather than current |
| Excessive permissions | Only `network.client` (for WKWebView + Sparkle) |

### After submission

- App review typically takes 24–48 hours for a first submission.
- If rejected, the response will name the specific Guideline number. Address
  it, reply, resubmit. Most rejections are mechanical.
- If accepted, set the release manually rather than auto-release so you can
  push the corresponding GitHub release first and have everything ready.
