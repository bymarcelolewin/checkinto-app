# Version Tasklist – v1.6.0-event-voting
This document outlines all the tasks to work on to deliver this particular version, grouped by phases.

| Status |      |
|--------|------|
| 🔴 | Not Started |
| 🟡 | In Progress |
| 🟢 | Completed |


## Phase 1: Author SQL Migration & Functions

All SQL files created in this phase. Nothing is executed against the live database yet. References features F120, F121, F122, F123, F124, F125, F136.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T01 | Author v1.6.0 migration SQL | Write `database/migrations/v1.6.0-event-voting.sql`. Single transaction. Creates 4 tables in order — `poll`, `poll_item`, `poll_winner_label`, `poll_vote` — with FKs, the `(poll_id, attendee_id)` composite PK on `poll_vote`, the `(poll_id, rank)` composite PK on `poll_winner_label`, CHECK on `poll.status` and `poll.top_n_winners`, `active boolean NOT NULL DEFAULT false` on `poll`. Adds indexes (`idx_poll_event_id`, `idx_poll_community_id`, `idx_poll_item_poll_id`, `idx_poll_vote_item_id`). Enables RLS on all four new tables with no anon policies. Grants: no anon grants on any new table; full grants to `authenticated` and `service_role`. Also installs both functions inline. | None | 🟢 Completed | AGENT |
| T02 | Author `submit_vote` function | Write `database/functions/submit-vote.sql`. `SECURITY DEFINER`. Validates poll exists + `active = true` + `status = 'open'` (`poll_unavailable` error if any fail); validates item belongs to poll (`invalid_item`); validates attendee row exists in `event_attendee` for the poll's event (`not_checked_in`). Upserts into `poll_vote` on `(poll_id, attendee_id)` so change-vote is just a re-call. Returns `{success: true, poll_item_id}` on success, `{success: false, error: <code>}` otherwise. `GRANT EXECUTE` to `anon` and `authenticated`. | T01 | 🟢 Completed | AGENT |
| T03 | Author `get_polls_for_event` function | Write `database/functions/get-polls-for-event.sql`. `SECURITY DEFINER`. Validates caller is checked into `p_event_id` (else returns `{polls: []}`). Returns JSON with one entry per `poll` where `event_id = p_event_id` AND `active = true`, ordered by `display_order, created_at`. Each entry includes: id, title, status, top_n_winners, show_vote_count, thanks_message, closed_message, no_votes_message, display_order, items (ordered by `display_order, name`), `my_vote_item_id`, `winner_labels` (map of `rank → label` from `poll_winner_label`), and `results` (null when open; for closed polls, items with `rank ≤ top_n_winners` using `RANK() OVER (ORDER BY COUNT(votes) DESC)`, each result row carrying `poll_item_id`, `name`, `vote_count`, `rank`, `is_my_vote`). `GRANT EXECUTE` to `anon` and `authenticated`. | T01 | 🟢 Completed | AGENT |
| T04 | Author v1.6.0 rollback migration | Write `database/migrations/v1.6.0-event-voting-rollback.sql`. Single transaction. Drops `submit_vote` and `get_polls_for_event` functions; drops `poll_vote`, `poll_winner_label`, `poll_item`, `poll` tables (in FK-safe order). | T01, T02, T03 | 🟢 Completed | AGENT |

## Phase 2: Apply Migration & Smoke Test in Supabase

USER runs SQL in the Supabase SQL editor and verifies behavior end-to-end at the database layer before any frontend work.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T05 | Apply v1.6.0 migration | Paste `v1.6.0-event-voting.sql`, then `submit-vote.sql`, then `get-polls-for-event.sql` into Supabase SQL editor and run in that order. Confirm success. | T01, T02, T03 | 🟢 Completed | USER |
| T06 | Verify schema, RLS, grants | Confirm via SQL: all 4 new tables exist with expected columns + constraints; RLS is enabled on all 4; `anon` has no grants on any new table; `anon` has EXECUTE on both functions. | T05 | 🟢 Completed | USER |
| T07 | Smoke test functions in SQL editor | Insert a draft poll (`active = false`) — confirm `get_polls_for_event` does NOT return it. Add `poll_item`s and a couple of `poll_winner_label` rows (e.g., rank 4 = "Honorable Mention"). Flip `active = true` — confirm it now appears. Call `submit_vote` as an attendee checked into the event — confirm row appears. Call again with a different item — confirm vote was changed (not duplicated). Call with non-checked-in attendee — confirm `not_checked_in`. Call against a `status = 'closed'` poll — confirm `poll_unavailable`. Flip `status = 'closed'` — confirm `get_polls_for_event` now returns `results` ordered by rank with correct labels merged. | T05 | 🟢 Completed | USER |

## Phase 3: Frontend Foundation

TypeScript types and service methods. No UI yet. References features F126, F127.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T08 | Add Poll types | In `src/lib/types.ts`, add interfaces: `Poll` (id, event_id, community_id, title, active, status, top_n_winners, show_vote_count, thanks_message, closed_message, no_votes_message, display_order, created_at, updated_at, items, my_vote_item_id, winner_labels, results), `PollItem` (id, poll_id, name, display_order), `PollWinnerLabel` (poll_id, rank, label), `PollResult` (poll_item_id, name, vote_count, rank, is_my_vote). | T07 | 🟢 Completed | AGENT |
| T09 | Add database service methods | In `src/lib/database.ts`, add `getPollsForEvent(eventId, attendeeId)` and `submitVote(pollId, pollItemId, attendeeId)` that wrap the two RPCs. Return typed payloads. | T08 | 🟢 Completed | AGENT |
| T10 | Type-check | Run `npm run check`. Confirm no new errors beyond the pre-existing tsconfig baseline. | T09 | 🟢 Completed | AGENT |

## Phase 4: Multi-Poll & History UX Prototype

Before building the multi-poll wrapper or the "Polls" history button, prototype the layout so the implementation is grounded in a real visual decision. References feature F134.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T11 | Run `:cody prototype` for multi-poll layout + Polls history button | USER runs `:cody prototype` to design: (a) how multiple concurrent polls render on the unified main screen (stacked, tabs, paginated, collapsed-by-default, etc.), (b) whether a persistent "Polls" button lives at the bottom of the app and what it opens (a separate route, a modal, an inline expansion), (c) where closed-poll results live once revealed (inline, history-only, both). Output: `docs/prototypes/polls-ui/` documenting the chosen pattern — **popup + inbox card**, no bottom-nav button, closed polls live in the inbox and open results in the popup. | T10 | 🟢 Completed | USER |
| T12 | Incorporate prototype outcomes into design + tasklist | AGENT updated `design.md` (Section 1 mental model and Section 2 frontend) to describe the popup + inbox model; added F138 (Polls Inbox Card), F139 (Poll Popup Modal), F140 (Auto-Popup on Load) to the feature backlog; marked F134 as completed and F132 as superseded by F139; restructured Phase 5 tasks around the two-component split. | T11 | 🟢 Completed | AGENT |

## Phase 5: UI Implementation

Build the popup + inbox model per the prototype outcomes. References features F128, F129, F130, F131, F133, F137, F138, F139, F140. (F132 is superseded by F139.)

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T13 | Author `PollsInbox.svelte` (F138) | The inbox card. Renders the `Polls` header + one row per poll returned by `get_polls_for_event`, ordered by `display_order, created_at`. Each row shows poll title, a state-based one-line subtitle ("4 options — tap to vote" / "Tap to view or change your vote" / "Tap to see the winners"), and a right-side pill (red **Vote** / green **Voted** / amber **Results**). Emits a `select` event with the poll id on tap. Styling via the existing CSS variable theme system. Reference: `docs/prototypes/polls-ui/` for visual + interaction. | T10, T12 | 🟢 Completed | AGENT |
| T14 | Author `PollPopup.svelte` (F139) | The modal container. Props: `{poll}`. Renders all per-poll states inside the modal body: (1) open + zero items → "Voting items coming soon" placeholder (F137); (2) open + no vote → ballot with radio list + `[Vote]` button (F128); (3) open + already voted → `thanks_message` + item list with prior pick highlighted + "Change your vote" link that re-renders ballot pre-selected (F129, F130); (4) closed + ranked results → labels from `winner_labels` (client-side ordinal defaults for unlabeled ranks), `" — Tie"` suffix on shared ranks, "your pick" badge driven by `is_my_vote`, optional vote counts gated by `show_vote_count` (F131); (5) closed + zero votes → `no_votes_message` (F133). Close affordances: top-right X button, click on dim overlay, Escape key. Emits a `voted` event after a successful submit. Reference: `docs/prototypes/polls-ui/`. | T10, T12 | 🟢 Completed | AGENT |
| T15 | Auto-popup-on-load logic (F140) | Built and shipped, then reversed post-deploy. The auto-popup felt intrusive in production; the red "Vote" inbox pill is enough of a call to action. `src/lib/utils/polls.ts` deleted; auto-popup invocation removed from `EventScreen.svelte`. The inbox + tap-to-open flow is the only entry point. | T13, T14 | 🚫 Removed (post-deploy) | AGENT |
| T16 | Wire into unified main screen | (a) **Plumb `attendee_id`**: extend `CheckInResponse` to include `attendee_id`, return it from `DatabaseService.checkInAttendee`, extend `ConfirmationState` and `storeConfirmationState` to persist it, pass it through `navigationActions.completeCheckin`. (b) **Render**: fetch polls via `getPollsForEvent` on the unified main screen, only when the attendee is checked in AND has `attendee_id` stored (stale email-only state from pre-v1.6.0 check-ins degrades gracefully — polls just don't render). Mount `PollsInbox` between the "You're checked in!" hero and the donation card; hide it entirely if the call returns `{polls: []}`. Manage popup state at the page level: listen to inbox `select` events to open the popup; listen to popup `voted` events to refresh inbox pills (refetch `getPollsForEvent`). Fire auto-popup-on-load (T15) once polls are loaded. No realtime polling. | T13, T14, T15 | 🟢 Completed | AGENT |
| T17 | End-to-end smoke test on dev | Verified in production at the live buildathon event. Inbox + tap-to-open flow worked; voting/change-vote/close-poll all functioned; persistence via attendee_id worked. Two adjustments shipped post-deploy: (a) auto-popup removed (felt intrusive — red pill is enough call to action), (b) `get_polls_for_event` filtered to `vote_count > 0` so items with zero votes don't show as "winners". | T16 | 🟢 Completed | USER |

## Phase 6: Documentation

References feature F135.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T18 | Update latest-schema.sql | Add `poll`, `poll_item`, `poll_winner_label`, `poll_vote` blocks with constraints, indexes, RLS, and grants. Update the header `Snapshot reflects state after …` line and add a section under "Data model notes" describing the voting model (per-event polls, function-only access, `active` for visibility vs `status` for voting state). | T17 | 🟢 Completed | AGENT |
| T19 | Update README.md | Bump the version badge from 1.5.0 to 1.6.0. Add an event voting feature section under "Key Features" (admin-defined polls, single-vote ballots, change-vote until close, ranked winners with custom labels). Update "How It Works" if needed to mention voting appears for checked-in attendees on the event screen. | T17 | 🟢 Completed | AGENT |
| T20 | Mark v1.6.0 complete in backlog | Update `docs/build/feature-backlog.md`: set v1.6.0 status to 🟢 Completed and all F120–F137 rows to 🟢 Completed (mark any prototype-deferred rows accordingly). | T18, T19 | 🟢 Completed | AGENT |

## Phase 7: Wrap-Up

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T21 | Write retrospective | Create `docs/build/v1.6.0-event-voting/retrospective.md` from template. | T20 | 🟢 Completed | AGENT |
| T22 | Update cody.json | Set `version` to `1.6.0` and `updatedAt` to today's date. | T20 | 🟢 Completed | AGENT |
| T23 | Update release-notes.md | Add v1.6.0 entry to `release-notes.md` at project root. | T20 | 🟢 Completed | AGENT |
| T24 | Commit to git | USER commits all changes with a descriptive message. | T23 | 🟢 Completed | USER |
