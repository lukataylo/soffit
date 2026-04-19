# US-003 — Vote on items

**Epic:** Ember Retro v1 · **Points:** 3 · **Owner:** TBD

## Story

**As a** team member
**I want to** place dot-votes on the items I think are most important
**so that** the team can prioritise what to discuss without a shouting match.

## Acceptance criteria

- [ ] Voting is only active while the session is in `voting` state; the manager moves the session into voting via a button.
- [ ] I have exactly 3 votes per column (9 total).
- [ ] Clicking the vote button on an item increments my vote count on it; clicking again decrements.
- [ ] I cannot spend more than 3 votes in a single column — the button disables when I'm out.
- [ ] I can see my own vote distribution live in a sidebar (`Went well 2/3 · To improve 3/3 · Actions 1/3`).
- [ ] I cannot see *others'* votes until the session moves to `closed`.
- [ ] Total vote counts per item are visible to everyone throughout.

## Non-functional

- Vote updates fan out to all participants within 300ms.
- Vote state is durable across reload.

## Notes

- "3 votes per column" is deliberate: it prevents strategic stacking while still rewarding strong conviction.
- When the session closes, the per-person breakdown becomes visible. This is load-bearing for the post-retro discussion but was debated — some teams prefer full anonymity forever. Revisit if activation metrics suffer.

## Open question

- Should the voting button be a click or a long-press? Click risks miss-taps; long-press adds friction. Prototype both with the Friday test group.
