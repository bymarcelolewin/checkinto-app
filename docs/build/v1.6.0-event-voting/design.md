# Version Design Document : v1.6.0-event-voting
Technical implementation and design guide for the upcoming version.

## 1. Features Summary
_Overview of features included in this version._

Add a per-event voting feature so checked-in attendees can vote on admin-defined items (e.g., hackathon projects) and, after the admin closes the poll, see the ranked winners on the same screen.

**Mental model**
- A **poll** belongs to both an **event** and a **community** (the event's community). The community link is a direct FK on `poll` — same pattern `event`, `talent`, and `venue` already use — so that future community-admin scoping (RLS by community ownership) is a cheap, additive change. v1.6.0 ships with a single global admin (the project owner) operating directly in Supabase; no auth-based community-admin enforcement is wired up yet.
- An **event** can have **zero or more polls**. Each poll has a custom title (the question), a status (`open` / `closed`), and per-poll display/copy settings.
- A poll carries an **`active`** flag (default `false`) — the admin builds the poll + items in Supabase with `active = false` (invisible to attendees), then flips it to `true` when ready to publish. Setting it back to `false` retires the poll from view. `active` and `status` are independent axes: `active = true / status = 'open'` shows the ballot; `active = true / status = 'closed'` shows the results; `active = false` hides the poll entirely regardless of `status`. (The `event.active` precedent uses default `true` because events are created already-ready; polls are created as drafts, hence the inverted default.)
- **Visibility is enforced server-side.** The `poll`, `poll_item`, and `poll_vote` tables are all locked to function-only anon access. Every read goes through `get_polls_for_event`, which (a) requires the caller to be checked into the requested event and (b) only returns polls where `event_id = $1` and `active = true`. There is no path by which a checked-in attendee can read polls for an event/community they aren't part of, or read inactive polls.
- A poll has **items** — free-text names the admin enters in Supabase (e.g., "John's Project").
- A poll has optional **winner labels** — per-rank custom text in a separate `poll_winner_label` table. Admin can set `1 → "First Place"`, `4 → "Honorable Mention"`, `5 → "Honorable Mention"`, etc. Multiple ranks may share a label. Any rank without a row falls back to a client-rendered default (`"1st Place"`, `"2nd Place"`, …, `"Nth Place"`). If the admin creates no labels, every rank uses the default. Labels are scoped to the poll because every poll may want different labeling.
- A **checked-in attendee** can cast **one vote** per poll. They may change their vote at any time while the poll is open. Voting is not anonymous internally (it's tied to `attendee_id` for enforcement and "your-vote" display), but no UI surfaces who voted for what.
- When the admin flips the status to `closed`, the ballot is replaced by a ranked results view. Top-N is configurable per poll; ties use **competition ranking** (two-way tie for 2nd → both show "2nd Place — Tie", next rank is 4th).
- All poll administration (creating polls/items, opening, closing) happens directly in Supabase. No admin UI ships in v1.6.0.
- **Attendee UI = popup + inbox card** (decided by `docs/prototypes/polls-ui/`).
  - A **polls inbox card** sits on the unified main screen between the "You're checked in!" hero and the donation card. It renders one row per visible poll (active = true). Each row shows the poll title plus a right-side **pill**: red **"Vote"** for un-voted open polls, green **"Voted"** for already-voted open polls, amber **"Results"** for closed polls.
  - Tapping any inbox row opens a **modal popup** for that poll. Inside the popup the attendee either casts/changes their vote (open polls) or views the ranked results (closed polls). The popup is closed via the top-right X, the dim overlay, or the Escape key.
  - On page load, if there is at least one open poll the attendee hasn't voted on AND that poll's id isn't in the per-event localStorage "seen" list, the popup auto-opens with that poll and adds it to "seen". This surfaces the action without forcing the attendee to discover the inbox. The "seen" list is purely a UX nudge — the inbox row is always the canonical entry point.
- No "Polls" bottom-nav button. The inbox card IS the polls list; closed polls stay in the inbox until the admin sets `active = false`. No cross-event history view in v1.6.0.

**Features included**

| Feature | ID |
|---|---|
| Poll Schema | F120 |
| One-Vote-Per-Attendee Constraint | F121 |
| submit_vote RPC | F122 |
| Poll Results Query | F123 |
| RLS & Grants | F124 |
| Rollback Migration | F125 |
| TypeScript Interfaces | F126 |
| Database Service Methods | F127 |
| Inline Ballot UI | F128 |
| Post-Vote Thank-You State | F129 |
| Change-Vote Capability | F130 |
| Closed-Poll Results Display | F131 |
| Voting-Closed State for Non-Voters | F132 |
| No-Votes-Recorded State | F133 |
| Multi-Poll & History UX Prototype | F134 |
| Update latest-schema.sql | F135 |
| Poll Winner Labels | F136 |
| Empty-Poll Placeholder ("voting items coming soon") | F137 |
| Polls Inbox Card | F138 |
| Poll Popup Modal | F139 |
| Auto-Popup on Load | F140 |

## 2. Technical Architecture Overview
_High-level technical structure that supports all features in this version._

### Database (Supabase Postgres)

Three new tables, two new functions, all following the post-v1.4.0 access model (anon reads only the metadata they need; writes go through `SECURITY DEFINER` functions).

#### New tables

**`public.poll`** — one row per poll attached to an event. `community_id` is denormalized from `event.community_id` (must be kept consistent on insert) so community-scoped admin queries and future RLS don't have to JOIN through `event`.

```sql
CREATE TABLE public.poll (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL,
  community_id uuid NOT NULL,
  title text NOT NULL,
  active boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  top_n_winners integer NOT NULL DEFAULT 3 CHECK (top_n_winners > 0),
  show_vote_count boolean NOT NULL DEFAULT false,
  thanks_message text NOT NULL DEFAULT 'Thanks for voting. Stay tuned for the winners.',
  closed_message text NOT NULL DEFAULT 'Voting has closed.',
  no_votes_message text NOT NULL DEFAULT 'No votes were recorded for this poll.',
  display_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT poll_pkey PRIMARY KEY (id),
  CONSTRAINT fk_poll_event FOREIGN KEY (event_id) REFERENCES public.event(id) ON DELETE CASCADE,
  CONSTRAINT fk_poll_community FOREIGN KEY (community_id) REFERENCES public.community(id)
);
CREATE INDEX idx_poll_event_id ON public.poll(event_id);
CREATE INDEX idx_poll_community_id ON public.poll(community_id);

-- RLS on (defense in depth) — anon has no direct access. All reads go through get_polls_for_event() RPC.
ALTER TABLE public.poll ENABLE ROW LEVEL SECURITY;
-- No grants for anon.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.poll TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.poll TO service_role;
```

**`public.poll_item`** — the choices on a poll's ballot.

```sql
CREATE TABLE public.poll_item (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  poll_id uuid NOT NULL,
  name text NOT NULL,
  display_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT poll_item_pkey PRIMARY KEY (id),
  CONSTRAINT fk_poll_item_poll FOREIGN KEY (poll_id) REFERENCES public.poll(id) ON DELETE CASCADE
);
CREATE INDEX idx_poll_item_poll_id ON public.poll_item(poll_id);

-- RLS on (defense in depth) — anon has no direct access. Reads go through get_polls_for_event() RPC.
ALTER TABLE public.poll_item ENABLE ROW LEVEL SECURITY;
-- No grants for anon.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.poll_item TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.poll_item TO service_role;
```

**`public.poll_winner_label`** — optional per-rank labels for a poll's results view. Function-only access.

```sql
CREATE TABLE public.poll_winner_label (
  poll_id uuid NOT NULL,
  rank integer NOT NULL CHECK (rank > 0),
  label text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT poll_winner_label_pkey PRIMARY KEY (poll_id, rank),
  CONSTRAINT fk_poll_winner_label_poll FOREIGN KEY (poll_id) REFERENCES public.poll(id) ON DELETE CASCADE
);

-- RLS on (defense in depth) — anon has no direct access. Reads go through get_polls_for_event() RPC.
ALTER TABLE public.poll_winner_label ENABLE ROW LEVEL SECURITY;
-- No grants for anon.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.poll_winner_label TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.poll_winner_label TO service_role;
```

Composite PK `(poll_id, rank)` guarantees at most one label per rank per poll, but multiple ranks may share the same `label` text (e.g., ranks 4 and 5 both labeled "Honorable Mention"). Zero rows for a poll means "use defaults everywhere."

**`public.poll_vote`** — one row per (poll, attendee). Function-only access — anon has no direct grants.

```sql
CREATE TABLE public.poll_vote (
  poll_id uuid NOT NULL,
  attendee_id uuid NOT NULL,
  poll_item_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT poll_vote_pkey PRIMARY KEY (poll_id, attendee_id),
  CONSTRAINT fk_poll_vote_poll FOREIGN KEY (poll_id) REFERENCES public.poll(id) ON DELETE CASCADE,
  CONSTRAINT fk_poll_vote_attendee FOREIGN KEY (attendee_id) REFERENCES public.attendee(id),
  CONSTRAINT fk_poll_vote_item FOREIGN KEY (poll_item_id) REFERENCES public.poll_item(id) ON DELETE CASCADE
);
CREATE INDEX idx_poll_vote_item_id ON public.poll_vote(poll_item_id);

-- RLS on (defense in depth) but no anon policies. Writes via submit_vote() RPC; reads via get_polls_for_event() RPC.
ALTER TABLE public.poll_vote ENABLE ROW LEVEL SECURITY;
-- No grants for anon.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.poll_vote TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.poll_vote TO service_role;
```

The composite PK `(poll_id, attendee_id)` is the single-vote-per-attendee enforcement. The secondary index on `poll_item_id` keeps the results query (which counts votes per item) cheap.

#### New functions

**`public.submit_vote(p_poll_id uuid, p_poll_item_id uuid, p_attendee_id uuid) returns jsonb`** — `SECURITY DEFINER`.

Validation:
1. Poll exists, `active = true`, and `status = 'open'` → else return `{success: false, error: 'poll_unavailable'}` (one error covers inactive, missing, and closed — clients shouldn't need to differentiate, and lumping them prevents leaking which case applies).
2. Poll item exists and belongs to that poll → else `{success: false, error: 'invalid_item'}`.
3. Attendee is checked into the poll's event (row exists in `event_attendee` for `(event_id, p_attendee_id)`) → else `{success: false, error: 'not_checked_in'}`.

Action:
```sql
INSERT INTO poll_vote (poll_id, attendee_id, poll_item_id)
VALUES (p_poll_id, p_attendee_id, p_poll_item_id)
ON CONFLICT (poll_id, attendee_id) DO UPDATE
    SET poll_item_id = EXCLUDED.poll_item_id,
        updated_at  = now();
```

Returns: `{success: true, poll_item_id: <uuid>}`.

Grants: `EXECUTE` to `anon`, `authenticated`. (Mirrors `check_in_attendee`.)

**`public.get_polls_for_event(p_event_id uuid, p_attendee_id uuid) returns jsonb`** — `SECURITY DEFINER`.

Returns the full payload needed to render the voting UI for an event in one round trip. Visibility rules enforced inside the function:
1. Caller must be checked into `p_event_id` (row in `event_attendee` for `(p_event_id, p_attendee_id)`). If not, returns `{polls: []}` — graceful degradation; the UI shouldn't be calling this for non-checked-in users.
2. Only polls with `event_id = p_event_id` AND `active = true` are returned. Inactive polls and polls from other events/communities are invisible to the function's output. Closed polls remain visible (so attendees see the winners) — `active` controls visibility, `status` controls whether voting is open.

Shape:
```json
{
  "polls": [
    {
      "id": "...",
      "title": "Vote for your favorite project",
      "status": "open" | "closed",
      "top_n_winners": 3,
      "show_vote_count": false,
      "thanks_message": "...",
      "closed_message": "...",
      "no_votes_message": "...",
      "display_order": 0,
      "items": [
        {"id": "...", "name": "John's Project", "display_order": 0},
        ...
      ],
      "my_vote_item_id": "..." | null,
      "winner_labels": {"1": "First Place", "4": "Honorable Mention", ...},
      "results": [
        {"poll_item_id": "...", "name": "John's Project", "vote_count": 12, "rank": 1, "is_my_vote": false},
        ...
      ] | null
    }
  ]
}
```

- **`my_vote_item_id`** is populated for both open and closed polls (so the closed-poll view can highlight what the attendee chose).
- **`is_my_vote`** on each result item is the same signal denormalized — frontend uses it to render a "your pick" badge next to the item the attendee voted for. Always present on closed-poll results, always `false` when the attendee didn't vote.
- **`winner_labels`** is the per-rank label map for the poll (empty object if the admin defined none). Frontend keys by rank when rendering; falls back to client-side defaults (`"1st Place"`, `"2nd Place"`, …) for ranks not in the map. Ties append `" — Tie"` to whichever label resolves.
- **`results`** is `null` when `status = 'open'`. When `status = 'closed'`, `results` includes only items with `rank <= top_n_winners`, where rank is computed by `RANK() OVER (ORDER BY COUNT(vote) DESC)` — i.e., competition ranking. If a tie crosses the cutoff (e.g., top_n = 3, votes are [10, 8, 8, 8, 5] → ranks 1, 2, 2, 2, 5), all tied items at the cutoff are included.
- **Empty-item polls are still returned.** If `active = true` but the poll has zero items, `items` is `[]` and `results` is `null`. The frontend renders the "voting items coming soon" placeholder in that case (F137). Same applies during the brief window between admin creating a poll's items and flipping `active = true` — we don't generally encounter this since admin keeps polls inactive while drafting.

Grants: `EXECUTE` to `anon`, `authenticated`.

### Frontend (SvelteKit + supabase-js)

- `src/lib/types.ts` — add `Poll`, `PollItem`, `PollResult` interfaces; extend whatever event-page state shape the unified main screen uses to carry polls.
- `src/lib/database.ts` — add `getPollsForEvent(eventId, attendeeId)` and `submitVote(pollId, itemId, attendeeId)` methods that wrap the two RPCs.
- **Two new components**, plus glue on the main screen:
  - **`PollsInbox.svelte`** (F138) — the inbox card. Renders the `Polls` header + one `inbox-row` per poll returned by `get_polls_for_event`. Each row shows poll title, a one-line subtitle ("4 options — tap to vote" / "Tap to view or change your vote" / "Tap to see the winners"), and a right-side pill (red "Vote" / green "Voted" / amber "Results"). Tap → emits an event with the poll id so the page can open the popup.
  - **`PollPopup.svelte`** (F139) — the modal container. Receives a `poll` prop and renders the right state inside its card body. Closes via top-right X, click on dim overlay, or Escape key. Emits a `voted` event after a successful submit so the page can refresh the inbox state. Per-state content:
    1. **Open + zero items** → "Voting items coming soon" placeholder (F137).
    2. **Open + no vote yet** → ballot (radio list + Vote button).
    3. **Open + already voted** → `thanks_message` + a list of items with the prior pick highlighted + "Change your vote" link that re-renders the ballot pre-selected.
    4. **Closed + ranked results** → ranked winners with labels resolved from `winner_labels` (client-side ordinal fallback), "Nth Place — Tie" suffix on shared ranks, "your pick" badge driven by `is_my_vote`, optional vote counts gated by `show_vote_count`.
    5. **Closed + zero votes** → `no_votes_message`.
    6. **Closed + attendee never voted** → same as state 4/5; no separate `closed_message` intermediate state needed in the popup-based model (the popup IS the deliberate click-through from the inbox).
- **Auto-popup-on-load (F140) — built then reversed in production.** Originally the popup auto-opened on mount for the first un-voted open poll (with a localStorage "seen" list to avoid re-prompting after dismissal). Production testing showed it felt intrusive on check-in — the red "Vote" pill on the inbox row already communicates the action clearly. Removed: `src/lib/utils/polls.ts` was deleted and the invocation was stripped from `EventScreen.svelte`. The inbox + tap-to-open is now the only entry point to the popup.
- **Persistence and the attendee_id plumbing gap.** Votes ride on the existing identity model — `get_polls_for_event` returns `my_vote_item_id` per poll keyed by `attendee_id`, and survival across refresh / browser close is automatic given the right identifier in localStorage. However, the existing v0.6.0 `ConfirmationState` only persists `attendeeEmail` (the raffle system identifies users by email, not id), so v1.6.0 must extend it to also persist `attendee_id`. The `check_in_attendee` RPC already returns `attendee_id` in its JSON output — we just need to plumb it through the existing TS wrapper (`CheckInResponse`), the navigation store call (`completeCheckin`), and `storeConfirmationState`. For attendees with stale state (email persisted from a pre-v1.6.0 check-in, no `attendee_id`), polls simply do not render; re-checking-in restores them.
- **"Clear check-in" does NOT delete votes.** Clearing is a local reset (wipe localStorage). DB rows on `poll_vote` stay, tied to the attendee's email. Re-checking-in with the same email returns the same `attendee_id` and votes reappear in the inbox. This matches how raffle wins and the per-event fact already behave.
- Polls list refresh: there is no real-time requirement. A fetch on mount plus a refresh after a successful vote (to flip the pill from "Vote" → "Voted") is enough for v1.6.0. We deliberately do not piggyback on the raffle polling loop here.

## 3. Implementation Notes
_Shared technical considerations across all features in this version._

**Migration order.** Single transaction is fine since none of these tables exist yet — there's no backfill risk like v1.4.0/v1.5.0 had.

```
1. CREATE TABLE poll                  (+ RLS enable)
2. CREATE TABLE poll_item             (+ RLS enable)
3. CREATE TABLE poll_winner_label     (+ RLS enable)
4. CREATE TABLE poll_vote             (+ RLS enable)
5. CREATE INDEXes
6. GRANTs (authenticated + service_role; no anon)
7. CREATE FUNCTION submit_vote
8. CREATE FUNCTION get_polls_for_event
9. GRANT EXECUTE on both functions (anon + authenticated)
```

**Ranking SQL — the core of `get_polls_for_event` results.**

```sql
WITH ranked AS (
  SELECT
    pi.id            AS poll_item_id,
    pi.name,
    pi.display_order,
    COUNT(pv.attendee_id) AS vote_count,
    RANK() OVER (ORDER BY COUNT(pv.attendee_id) DESC) AS rank,
    BOOL_OR(pv.attendee_id = $3) AS is_my_vote  -- $3 = p_attendee_id
  FROM poll_item pi
  LEFT JOIN poll_vote pv ON pv.poll_item_id = pi.id
  WHERE pi.poll_id = $1
  GROUP BY pi.id, pi.name, pi.display_order
)
SELECT poll_item_id, name, vote_count, rank, COALESCE(is_my_vote, false) AS is_my_vote
FROM ranked
WHERE rank <= $2  -- top_n_winners
ORDER BY rank ASC, display_order ASC, name ASC;
```

`LEFT JOIN` so items with zero votes still appear in the ranking pool. `RANK()` gives competition ranking (`1, 2, 2, 4`) which matches our tie spec. Filtering `rank <= top_n` after computing rank means tied items at the cutoff are all included, which is the right behavior — "show top 3" with a 3-way tie for 2nd shows four items (1st, 2nd-Tie, 2nd-Tie, 2nd-Tie) rather than arbitrarily cutting one off. `BOOL_OR(pv.attendee_id = $3)` collapses the LEFT JOIN's multiple rows-per-item back into a single boolean per item indicating whether the calling attendee voted for it — this is the source of the `is_my_vote` field driving the "your pick" badge.

The label map is fetched separately (`SELECT rank, label FROM poll_winner_label WHERE poll_id = $1`) and merged into the JSON output as `winner_labels`. Labels live on the poll, not the result row, so the frontend can render the same label for tied items at the same rank without the function having to think about ties.

**Why function-only on `poll_vote`.** Letting anon `SELECT` the raw `poll_vote` table would let any visitor read the full who-voted-for-what list — a privacy regression. Routing all reads through `get_polls_for_event`, which returns only aggregate `results` plus the caller's own `my_vote_item_id`, keeps individual votes server-side.

**Attendee identity on the frontend.** The unified main screen already knows the checked-in `attendee_id` (returned by `check_in_attendee` after v1.4.0, persisted to `localStorage` per v0.6.0). Pass it straight into both RPCs. No new identity work required.

**Concurrency.** The `ON CONFLICT DO UPDATE` upsert in `submit_vote` is safe under concurrent re-votes from the same attendee — the row-level lock serializes them, and last-write-wins matches the user-visible "I changed my mind" intent.

**`community_id` consistency.** Since the column is denormalized from `event.community_id`, the admin INSERT path needs to set it correctly. To keep this from drifting, the easiest discipline is a tiny helper or a documented convention ("always insert with `SELECT community_id FROM event WHERE id = …`"); a composite FK enforcing `(event_id, community_id)` against `event(id, community_id)` is also an option but would require a `UNIQUE (id, community_id)` on `event` first, which is extra schema churn for a single-admin workflow. v1.6.0 documents the convention and relies on it. If/when community-admin RLS lands, we can revisit and add the composite constraint then.

**No realtime / no polling.** Closed-poll results are static once the admin flips the flag. We accept that an attendee viewing the page when the flag flips will continue seeing the ballot until they refresh. That's an acceptable v1.6.0 behavior; a `:cody prototype` may later surface a need for live results, in which case we'd reuse the raffle's 5-second polling pattern.

## 4. Other Technical Considerations
_Shared any other technical information that might be relevant to building this version._

**Trust model.** `submit_vote` validates that `p_attendee_id` corresponds to someone in `event_attendee` for the poll's event — but it does not cryptographically prove the caller _is_ that attendee. A user who knows another attendee's `attendee_id` could vote on their behalf. This matches the existing trust model the raffle already operates under (the attendee_id sits in `localStorage` and is passed by the client). Hardening this would require a real auth identity for attendees, which is out of scope.

**Out of scope for v1.6.0:**
- Admin UI for creating/managing polls and items. All admin actions happen in Supabase Studio or via SQL.
- The persistent "Polls" bottom-nav button and the history view it opens — both go to prototype first.
- Multiple-open-poll layout (stacked vs paginated vs tabs) — prototype first.
- Realtime results updates while a poll is open or just after close.
- Vote-down / abstain / "I have no opinion" states.
- Per-item images, descriptions, or links — items are name-only.
- Export of vote data.
- Analytics on participation rate.

**Forward compatibility:** the `poll` row carries enough configuration (per-poll messages, top-N, vote-count toggle, display order) that we shouldn't need a schema change for the prototype-driven UI work. If multi-select polls are introduced later, the cleanest path is a `max_votes integer NOT NULL DEFAULT 1` column on `poll` plus relaxing the PK on `poll_vote` to `(poll_id, attendee_id, poll_item_id)`. We won't do this now, but the schema is shaped so the change is additive.

**Community-admin RLS later.** The `community_id` column on `poll` exists specifically so that when authenticated community-owner accounts ship, an RLS policy of the form `community_id IN (SELECT community_id FROM community_owner WHERE user_id = auth.uid())` can be dropped in without restructuring the table or rewriting any JOINs. v1.6.0 does not add such a policy — there is no `community_owner` table yet — but the schema is shaped so it's a one-policy addition rather than a migration.

**Smoke testing.** A `smoketest+*` poll on a prod event before the hackathon is recommended — create one poll with 2-3 items, vote from a phone, change the vote, then close from Supabase Studio and confirm the results view renders.

## 5. Open Questions
_Unresolved technical or product questions affecting this version._

All previously open product questions have been resolved before code authoring:

1. **"Your pick" highlight on closed-poll results** — yes. `is_my_vote` denormalized onto each result item; frontend renders a small badge on the matching row (F131).
2. **Empty poll on open status** — show a "voting items coming soon" placeholder. The function still returns the poll (with `items: []`); the frontend renders the placeholder (F137).
3. **Closing message for non-voters** — click-through button, not transient. `closed_message` shows with a "See results" button; tap to advance to results (F132).
4. **Polls-history scope** — current event only when the future "Polls" history view ships. No cross-event/cross-community history view planned. The `get_polls_for_event` shape (scoped to one event) is already correct for this.

No remaining open questions at the design level.
