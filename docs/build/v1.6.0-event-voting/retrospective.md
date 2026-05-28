# Version Retrospective – v1.6.0-event-voting

This document reflects on what worked, what didn't, and how future versions can be improved.

## Version Summary

v1.6.0 added per-event polls that checked-in attendees can vote on, with a popup + inbox card UX. Four new tables (`poll`, `poll_item`, `poll_winner_label`, `poll_vote`), two new SECURITY DEFINER functions (`submit_vote`, `get_polls_for_event`), two new Svelte components (`PollsInbox`, `PollPopup`), and the plumbing to persist `attendee_id` in localStorage so the polls feature could identify the voter. Shipped live at the iBuildWithAI Buildathon #1 — 5 hackathon entrants, an inbox row with a red "Vote" pill surfaced after check-in, attendees tapped to vote in a modal, admin closed the poll, ranked results revealed in everyone's popup.

## What Went Well

- **Schema design held up under live use.** The `active` (visibility) / `status` (open|closed) split paid off — being able to drop placeholder items into a hidden poll the night before, then flip `active=true` at showtime, made the day-of operation a single SQL statement. Same for revealing results: one `status='closed'` flip.
- **Function-only access model.** Routing every read through `get_polls_for_event` and every write through `submit_vote` meant we never had to think about RLS policies for the voting flow — anon literally cannot touch the four new tables directly. The composite PK on `poll_vote` made change-vote work for free as an `ON CONFLICT DO UPDATE`.
- **Prototype before code paid for itself.** The `:cody prototype` round (`docs/prototypes/polls-ui/`) replaced an "everything inline, maybe with a Polls bottom-nav button" model with the simpler popup + inbox pattern. Saved real implementation time that would have been spent on layout variants nobody ended up wanting.
- **One-step-at-a-time smoke testing in Supabase.** Running T07 as 9 numbered steps with explicit expected outcomes per step caught nothing dramatic but gave high confidence before any frontend code shipped. Worth the extra back-and-forth.
- **Production smoke test on the live event surfaced two real refinements** (auto-popup felt intrusive; zero-vote items shouldn't appear as "winners"). Both were fixed in under five minutes and pushed to production without disrupting attendees.

## What Could Have Gone Better

- **Misread the existing persistence model.** Section 2 of the original design.md asserted that `attendee_id` was already in localStorage from v0.6.0. It wasn't — only `attendeeEmail` was persisted (the raffle system identifies users by email). The gap was caught during T16 implementation and patched (extended `CheckInResponse`, `ConfirmationState`, `storeConfirmationState`, `completeCheckin`), but it was a sloppy planning error. A 30-second read of `src/lib/utils/storage.ts` during design would have caught it.
- **Auto-popup-on-load (F140) was built and then ripped out post-deploy.** The prototype's "Like" list specifically called out auto-popup as a win, but seeing it in production made it feel intrusive — the red "Vote" pill is enough call-to-action. The lesson: prototype confidence doesn't survive contact with a real first-load experience on a real device. Worth ~30 minutes of build + ~10 of teardown, but a real waste in retrospect.
- **`get_polls_for_event` shipped with a wrong-results bug.** Items with zero votes were being included in the ranked results (showing up as "Third Place Winner — Tie" with no votes), because the filter was only `WHERE r.rank <= top_n_winners`. A one-line fix (`AND r.vote_count > 0`), but it slipped past the SQL smoke test in T07 because the test data only had one vote per item — there were no zero-vote items in the smoke test to flush out the bug. Better smoke-test design would have included a zero-vote item.
- **Text enum for `poll.status` instead of a boolean.** I added forward extensibility (room for future `'paused'`, `'archived'`, etc.) for states the user never asked for. The parallel `active` field is a boolean, so the mix is inconsistent. The CHECK constraint protects against typos, but a boolean would have been simpler and more honest. Flagged for a v1.6.1 cleanup patch.

## Lessons Learned

- **Read the code before writing the design.** Frontend assumptions about what's stored in localStorage are cheap to verify and expensive to get wrong. A 60-second `grep` of `storage.ts` would have caught the `attendee_id` gap before I committed to a wrong sentence in the design doc.
- **Prototype outcomes are necessary but not sufficient.** Prototypes test layout and feel; they don't test what a real attendee experiences when they first land on a page in a real event. Reserve the right to reverse a prototype decision after production exposure — and budget for the possibility.
- **Pick the simplest type that captures the meaning.** Two states → boolean. Three states → enum. Don't enum for hypothetical futures.
- **Smoke tests should include "empty" / "zero" cases on purpose.** The 9-step T07 covered the happy paths and several error paths thoroughly, but didn't include a "poll closes with mixed voted + zero-vote items" case. The bug only manifested in production.
- **The popup + inbox pattern was the right shape for this product.** No bottom-nav button, no tabs, no accordion — just an inbox row that opens a modal. Worth remembering as a default for "list of small interactive items per event."

## Action Items

- **(v1.6.1 patch)** Convert `poll.status` from `text + CHECK` to `voting_open boolean DEFAULT true`. Update `submit_vote`, `get_polls_for_event`, the `Poll` TS type, and the day-of cheat sheet. ~30 minutes.
- **(v1.6.1 patch — optional)** Add a `clear_vote(p_poll_id, p_attendee_id)` SECURITY DEFINER function and a "Clear your vote" link in the popup, for the rare opt-out case. Discussed pre-event but deferred to avoid last-minute backend changes.
- **(Future patch)** Resolve the pre-existing `$lib/*` tsconfig resolution issue — `npm run check` is still useless for catching regressions across versions. Carried over from v1.4.0 and v1.5.0 action items; should genuinely happen in a dedicated cleanup release.
- **(Future patch)** Rename the legacy `"Allow public read access to meetups"` policy on the `community` table. Still on the followup list from v1.4.0/v1.5.0.
- **(Future v1.7.0+)** Build an admin UI for poll creation/management so non-SQL users (or someone other than the project owner) can run polls. v1.6.0 hard-codes "admin = the person with Supabase access".
- **(Future)** Real-time poll updates. v1.6.0 fetches on mount + after-vote only; updates while a user is on the page require a refresh. Reusing the raffle's 5-second polling pattern (or a Supabase realtime channel) would close that gap if it becomes a real need.
- **(Process)** For future versions, include explicit "empty / zero / edge-case" rows in smoke-test step lists. The zero-vote results bug would have been caught.
