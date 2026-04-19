# US-002 — Add retro items

**Epic:** Ember Retro v1 · **Points:** 5 · **Owner:** TBD

## Story

**As a** team member
**I want to** add items to the `Went well`, `To improve`, and `Action items` columns
**so that** the retro captures my input without me needing to shout over the meeting.

## Acceptance criteria

- [ ] Each column has a single-line input pinned at the top.
- [ ] Pressing ⏎ submits the item; ⇧⏎ inserts a newline for multi-line items.
- [ ] Items appear in my own view instantly (optimistic) and in other participants' views within 300ms.
- [ ] An *Anonymous* toggle next to the input reflects the session default and is remembered for the session.
- [ ] Each item shows `author` (or `Anonymous`) and a relative timestamp (`just now`, `2m`, …).
- [ ] I can edit or delete my own items; I cannot edit others'.
- [ ] Empty or whitespace-only items are rejected without error noise.

## Non-functional

- Concurrent entry by 50 participants must not miss items.
- Anonymous items must be un-deanonymizable from server logs (strip author at write, not read).

## Notes

- The 300ms target is end-to-end: keystroke → server → fan-out → render. Expect the server hop to eat most of that budget.
- Edit history is not shown in v1 — the last write wins.
