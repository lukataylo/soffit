# PRD — Ember Retro v1

**Status:** Draft · **Owner:** PM (you) · **Target release:** end of next quarter
**Engineering lead:** TBD · **Design lead:** TBD

## 1. One-liner

Ember is a lightweight retro tool for small-to-midsize engineering teams. It replaces the "shared Google Doc + stale Trello board" pattern with a single structured surface: each retro collects *notes*, *votes*, and *action items* that automatically flow into the team's issue tracker.

## 2. Why now

- Retros are consistently rated the highest-signal recurring meeting in internal surveys, but the lowest follow-through (only ~30% of identified action items land in a tracker within a week).
- Existing tools (Miro boards, Confluence macros, Parabol) either over-serve — expensive, feature-heavy — or under-serve — ephemeral, no integration story.
- The opportunity: a tool that makes it *easier to do the retro* than to skip it, and that makes the outcome *impossible to lose*.

## 3. Users and jobs

- **Engineering manager (primary).** Runs the retro, wants setup in under 60 seconds and outputs that don't need reformatting.
- **Team member (secondary).** Joins a retro, adds items, votes. Doesn't want to learn a new tool.
- **Stakeholder / skip-level (tertiary).** Reads the output asynchronously later. Wants a link, not a tool.

## 4. Scope for v1

### In scope
- Create a retro with a fixed three-column schema (`Went well`, `To improve`, `Action items`).
- Real-time item entry with optional anonymity.
- Dot-voting (three votes per person per column).
- One-click export to Markdown for pasting into docs.
- One-click create of linked tickets in the team's tracker (Azure DevOps first).
- Session state: `planned → live → voting → closed`.

### Out of scope (v1)
- Custom column templates.
- Slack/Teams integration (post to channel on close).
- Historical comparison across retros.
- Analytics dashboard.

## 5. Key user flows

See [`diagrams/user-flow.mmd`](../diagrams/user-flow.mmd) for the end-to-end flow and [`diagrams/state-machine.mmd`](../diagrams/state-machine.mmd) for the session lifecycle.

## 6. Non-functional requirements

- **Latency.** Item appears for all participants within 300ms of submit.
- **Capacity.** 50 concurrent participants per session.
- **Availability.** 99.5% monthly; retros are scheduled, so a daily maintenance window is acceptable.
- **Privacy.** Anonymous items must not be deanonymizable from server logs.

## 7. Success metrics

- **Activation:** % of created retros that reach `closed` state with ≥1 action item.
- **Follow-through:** % of exported action items that are still `in progress` or `done` 7 days later.
- **Adoption:** weekly active teams.

Targets at 90 days post-launch: activation ≥ 75%, follow-through ≥ 60%, 20+ weekly active teams.

## 8. Open questions

- Do we default anonymous on or off? (Hypothesis: off, with a one-click toggle at session start.)
- Is one week the right follow-through window, or should we tie it to sprint length per-team?
- Is Azure DevOps the right first integration, or GitHub Issues? (Probably ADO — see internal usage survey.)

## 9. Risks

- **Adoption risk:** teams already on Parabol won't switch without a clear diff. Mitigation — integration depth, not feature count.
- **Integration fragility:** ADO API quirks around work-item linking. Mitigation — ship with a fallback "copy-as-markdown" path and don't block release on the integration.
- **Anonymity leak:** we log every write. Mitigation — strip author ID at write time for anonymous items, not at read time.

## 10. Milestones

| Week | Milestone |
|------|-----------|
| 1–2 | Spec approved, design kickoff |
| 3–6 | Session CRUD, item entry, real-time sync |
| 7–8 | Voting + export |
| 9–10 | ADO integration |
| 11 | Private beta with 3 teams |
| 12 | GA |
