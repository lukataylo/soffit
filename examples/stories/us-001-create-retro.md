# US-001 — Create a retro

**Epic:** Ember Retro v1 · **Points:** 3 · **Owner:** TBD

## Story

**As an** engineering manager
**I want to** create a new retro session with a title and scheduled start time
**so that** my team can join it when the meeting starts without fumbling with setup.

## Acceptance criteria

- [ ] Given I'm signed in, when I click *New retro*, I see a form with `Title`, `Team`, `Starts at`, `Anonymous by default` (boolean).
- [ ] When I submit with all required fields, a session is created in `planned` state and I land on its page.
- [ ] The session page shows a shareable URL that can be opened without auth by team members.
- [ ] If I submit with an empty title, I see an inline error and the form does not submit.
- [ ] The `Starts at` field defaults to the next 15-minute slot (UTC-aware).

## Non-functional

- Creation round-trip ≤ 400ms on a warm API.
- Title accepts up to 120 characters; anything longer is rejected client-side.

## Notes

- The anonymity toggle here sets the *default* for items in this session; team members can still override per-item at entry time.
- Do **not** expose the session UUID in the shareable URL. Use a short slug.

## Out of scope

- Recurring retros (scheduled series).
- Calendar integration.
