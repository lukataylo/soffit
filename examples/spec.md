# Ember — demo workspace

This is a seed workspace for **Ember**, a fictional retro-and-action-tracking tool for engineering teams. It exists to exercise Workbench end-to-end: a PRD, user stories, flow diagrams, a Figma placeholder, and a Claude chat panel all visible at once.

## What to look at

| File | What it is |
|------|------------|
| [`prds/ember-retro-v1.md`](prds/ember-retro-v1.md) | Full PRD for the v1 retro flow |
| [`stories/us-001-create-retro.md`](stories/us-001-create-retro.md) | User story: create a retro |
| [`stories/us-002-add-items.md`](stories/us-002-add-items.md) | User story: add retro items |
| [`stories/us-003-vote.md`](stories/us-003-vote.md) | User story: voting |
| [`stories/us-004-export.md`](stories/us-004-export.md) | User story: export to Markdown |
| [`diagrams/user-flow.mmd`](diagrams/user-flow.mmd) | End-to-end user flow |
| [`diagrams/architecture.mmd`](diagrams/architecture.mmd) | Service topology |
| [`diagrams/state-machine.mmd`](diagrams/state-machine.mmd) | Retro session lifecycle |
| [`flow.mmd`](flow.mmd) | Minimal example the success-criteria script uses |
| [`figma-url.txt`](figma-url.txt) | Placeholder for the Figma embed URL |

## Suggested layout

Open a Workbench with four panels tiled as:

- **Top-left** — `prds/ember-retro-v1.md` (editor + preview)
- **Top-right** — `diagrams/user-flow.mmd` (mermaid panel)
- **Bottom-left** — `stories/us-003-vote.md`
- **Bottom-right** — Claude chat

Then split again to drop in the Figma embed.
