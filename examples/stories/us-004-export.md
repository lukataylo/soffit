# US-004 — Export and link actions

**Epic:** Ember Retro v1 · **Points:** 5 · **Owner:** TBD

## Story

**As an** engineering manager
**I want to** export the closed retro as Markdown and push each action item to Azure DevOps as a linked work item
**so that** the decisions the team made don't die in a tab I'll close tomorrow.

## Acceptance criteria

- [ ] When the session is `closed`, the session page shows a *Close out* panel with two buttons: `Copy Markdown` and `Push to ADO`.
- [ ] `Copy Markdown` places a structured Markdown digest on the clipboard: title, date, attendees, each column grouped and sorted by vote count, and an `## Action items` section at the bottom with checkboxes.
- [ ] `Push to ADO` opens a modal listing every `Action items` entry. For each, I can (a) edit the title, (b) pick an area path, (c) assign someone, (d) uncheck it to skip.
- [ ] Submitting the modal creates a work item per checked row, adds the Ember session URL as a link, and returns a list of created work item URLs.
- [ ] If the ADO push partially fails, the UI lists which rows failed and offers *Retry*.
- [ ] Both actions are idempotent by item: re-clicking `Push to ADO` won't create duplicate work items for the same retro action.

## Non-functional

- Export of a 100-item session completes in under 2 seconds.
- ADO push writes a `ember-action-id` tag on each work item to support idempotency.

## Notes

- Markdown format is the source of truth for the digest; the *Copy* path is just that format on the clipboard, and the *Post to Slack* path (v1.1) will be the same format piped through.
- The idempotency key is `session_id + action_item_id`, stored in the work item tag namespace. Don't use the work item title — titles are editable.

## Dependencies

- Needs the ADO service connection from infra. The shared `ado-service` account can do the write.
- Blocked on [US-003](us-003-vote.md) for the `votes` field in the export.
