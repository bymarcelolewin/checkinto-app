# Version Design Document : v1.4.0-secure-and-restructure-attendee
Technical implementation and design guide for the upcoming version.

## 1. Features Summary
_Overview of features included in this version._

This version addresses two related problems surfaced by Supabase's announced policy change (auto-grants removed on new public tables — May 30, 2026 for new projects, October 30, 2026 for existing ones):

1. **Over-broad anon access.** The live database has the legacy Supabase default of `GRANT ALL` to `anon`, `authenticated`, and `service_role` on every public table, with permissive RLS policies (`using = true`) on `attendee` (SELECT, INSERT, UPDATE) and `event_attendee` (SELECT, INSERT). Anyone with the anon key (which ships in the JS bundle) can read or modify the entire attendee table.

2. **Wrong attendee/community relationship.** `attendee.community_id` is a foreign key that records the *first* community an attendee interacted with, but the actual many-to-many relationship lives implicitly in `event_attendee → event.community_id`. The column is misleading and blocks future features like "show me all my events across communities" and "show community owners all their attendees."

The v1.4.0 changes:

- **Function-based check-in.** A single `check_in_attendee()` SECURITY DEFINER function becomes the only path for anonymous mutation. Input is validated server-side; the function upserts the attendee, links the community via the new join table, and inserts the event link idempotently.
- **`community_attendee` join table** for true many-to-many between attendees and communities, backfilled from existing data, with `attendee.community_id` dropped.
- **Lock down direct anon access** to `attendee` and `event_attendee`. Drop the 5 permissive RLS policies, revoke direct table GRANTs.

| Feature | ID |
|---|---|
| community_attendee join table | F103 |
| Backfill community_attendee | F104 |
| Drop attendee.community_id | F105 |
| check_in_attendee RPC | F106 |
| Drop permissive policies | F107 |
| Revoke anon direct access | F108 |
| RLS on community_attendee | F109 |
| Rollback migration | F110 |
| Update database.ts | F111 |
| Update latest-schema.sql | F112 |

## 2. Technical Architecture Overview
_High-level technical structure that supports all features in this version._

**Database (Supabase Postgres)**
- New table: `public.community_attendee (attendee_id uuid, community_id uuid, created_at timestamptz, PK (attendee_id, community_id))` with FKs to `attendee.id` and `community.id` and `ON DELETE CASCADE` on both sides.
- Modified table: `public.attendee` — drop `community_id` column. Email remains `UNIQUE` (one global identity per email).
- New function: `public.check_in_attendee(p_email text, p_first_name text, p_last_name text, p_interesting_fact text, p_event_id uuid) RETURNS jsonb` with `SECURITY DEFINER`, `SET search_path = public, pg_temp`, owner = `postgres`.
- Existing function `public.get_raffle_winners(uuid)` — unchanged.

**Access control (post-v1.4.0 state)**

| Role | attendee | event_attendee | community_attendee | event/community/talent/venue |
|---|---|---|---|---|
| anon | (no direct grant) | (no direct grant) | (no direct grant) | SELECT via RLS |
| authenticated | full (future) | full (future) | full (future) | full (future) |
| service_role | full | full | full | full |

Anon's only DB paths become: direct `SELECT` on the four read-only tables (`event`, `community`, `talent`, `venue`), `EXECUTE` on `check_in_attendee()`, and `EXECUTE` on `get_raffle_winners()`.

**Frontend (SvelteKit + supabase-js)**
- `src/lib/database.ts` — `checkInAttendee()` rewritten to a single `supabase.rpc('check_in_attendee', {...})` call. Helpers no longer used by anything are deleted: `createAttendee`, `upsertAttendee`, `updateAttendee`, `getAttendeeByEmail`, `linkAttendeeToEvent`, `isEmailRegisteredForEvent`, `getEventById`.
- `src/lib/screens/CheckinForm.svelte` — no UI behavior change. The `isExistingAttendee` flag returned from the RPC becomes `already_checked_in` semantically (was this person already linked to *this event*) and continues to drive only the existing console.log branching.

## 3. Implementation Notes
_Shared technical considerations across all features in this version._

**Migration order is load-bearing.** The migration runs as a single transaction. The order inside the transaction is:

1. Create `community_attendee` table.
2. Backfill `community_attendee` from `attendee.community_id` UNIONed with `event_attendee → event.community_id` (`ON CONFLICT DO NOTHING`).
3. Drop `attendee.community_id` column.
4. Create `check_in_attendee` function and grant `EXECUTE` to `anon`.
5. Drop the 5 permissive RLS policies on `attendee` and `event_attendee`.
6. Revoke direct table GRANTs from `anon` on `attendee` and `event_attendee`.
7. Enable RLS on `community_attendee` with no anon policies.

If any step fails the entire transaction rolls back — no data loss.

**Idempotent check-in.** The RPC's behavior on each call:

```
INSERT INTO attendee (email, first_name, last_name, interesting_fact)
VALUES (p_email, p_first_name, p_last_name, p_interesting_fact)
ON CONFLICT (email) DO UPDATE SET
  first_name = EXCLUDED.first_name,
  last_name = EXCLUDED.last_name,
  interesting_fact = EXCLUDED.interesting_fact,
  updated_at = now()
RETURNING id INTO v_attendee_id;

INSERT INTO community_attendee (attendee_id, community_id)
VALUES (v_attendee_id, v_community_id)
ON CONFLICT DO NOTHING;

INSERT INTO event_attendee (event_id, attendee_id)
VALUES (p_event_id, v_attendee_id)
ON CONFLICT DO NOTHING
RETURNING true INTO v_newly_linked;
-- v_newly_linked is NULL if conflict occurred
```

The function derives `v_community_id` from `event.community_id` (lookup by `p_event_id` with `active = true` filter). If the event is inactive or missing, the function raises an exception and the transaction rolls back.

**Server-side validation.** The function enforces, before any writes:
- `p_email`: NOT NULL, trim length 1–254, matches `^[^\s@]+@[^\s@]+\.[^\s@]+$`
- `p_first_name`, `p_last_name`: NOT NULL, trim length 1–50 each
- `p_interesting_fact`: NOT NULL, trim length 1–255
- `p_event_id`: NOT NULL, exists in `event` with `active = true`

On validation failure, raise an exception with a clear message (the client surfaces `error` in the returned jsonb).

**Function return shape:**
```json
{
  "success": true,
  "already_checked_in": false,
  "attendee_id": "uuid"
}
```
or on failure:
```json
{
  "success": false,
  "error": "human-readable message"
}
```

**Search path hardening.** `SET search_path = public, pg_temp` on the function prevents search-path injection attacks (Postgres best practice for SECURITY DEFINER).

## 4. Other Technical Considerations
_Shared any other technical information that might be relevant to building this version._

**No live events affected.** User confirmed there are no live events at the time of this migration, making this a safe window to deploy a breaking change to RLS policies and table structure.

**No frontend UI changes.** The check-in form, success page, and raffle UI all remain visually and behaviorally identical. The only observable change to end users is that submissions are slightly faster (one round-trip RPC instead of 5 sequential queries).

**Backwards compatibility surface.**
- The `Attendee` TypeScript type in `src/lib/types.ts` currently includes `community_id`. After v1.4.0 the column is gone, so the type must be updated. The `AttendeeInput` type used by the form is unchanged.
- Any external scripts or dashboard queries that reference `attendee.community_id` will break. The `database/admin/raffle-admin-script.sql` should be audited for references during the build.

**Rollback.** A companion `*-rollback.sql` script reverses every step. The backfill direction on rollback picks the *earliest* `community_attendee.created_at` per attendee as the restored `community_id` value, providing deterministic but lossy reversal (information about multi-community attendees collapses back to one community).

**Out of scope for v1.4.0:**
- Per-community attendee profiles (different display name per community).
- Authenticated user views ("my events across communities").
- Community owner admin views ("all attendees in my community").
- Rate limiting / CAPTCHA on the RPC (backlog item B004 covers that).

## 5. Open Questions
_Unresolved technical or product questions affecting this version._

None remaining for v1.4.0. The three items previously listed have been resolved:

1. **`database/admin/raffle-admin-script.sql`** — audited. Does not reference `attendee.community_id`. The only `attendee` columns it touches are `first_name`, `last_name`, `email`, and `id`, all of which are unaffected by this migration. No changes needed. (Section 7 of that script references a `meetup` table name that is stale from before the v1.3.1 rename to `community`; that is a pre-existing issue unrelated to v1.4.0.)

2. **`Attendee` TypeScript type** — confirmed `src/lib/types.ts:92` declares `community_id: string` on the `Attendee` interface. F111 covers the removal: drop the field from `Attendee`, which propagates correctly to derived types (`AttendeeInput`, `AttendeeUpdate`) via `Omit`. The `isAttendee` type guard does not check `community_id` and needs no change.

3. **RLS policies for `authenticated` role** — explicitly out of scope (see Section 4). Listed here only as a future-state pointer; no decision required now.
