# Version Design Document : v1.5.0-per-event-interesting-fact
Technical implementation and design guide for the upcoming version.

## 1. Features Summary
_Overview of features included in this version._

This version corrects a data model mismatch surfaced in v1.4.0 testing.

**The problem:** `interesting_fact` lives on the `attendee` row. Since `attendee` is a global identity (one row per email after v1.4.0), the fact is shared across every event the person attends. When the same person checks in to Event A with fact "X" and later Event B with fact "Y", the column gets overwritten — Event A retroactively now also shows fact "Y". This is wrong: an interesting fact is contextual to a specific gathering ("just got back from Japan," "shipped a feature today"), not an identity attribute.

**The fix:** move `interesting_fact` to the `event_attendee` join table, where each check-in records its own fact. Same person at different events can share different things. Same person re-submitting to the same event can fix a typo on their fact (preserved behavior from v1.4.0).

| Feature | ID |
|---|---|
| Add interesting_fact column to event_attendee | F113 |
| Backfill event_attendee.interesting_fact | F114 |
| Drop attendee.interesting_fact | F115 |
| Update check_in_attendee RPC | F116 |
| Rollback migration | F117 |
| Update TypeScript types | F118 |
| Update latest-schema.sql | F119 |

## 2. Technical Architecture Overview
_High-level technical structure that supports all features in this version._

**Database (Supabase Postgres)**
- Modified table: `public.event_attendee` — add `interesting_fact text NOT NULL`. Stored per (event_id, attendee_id) row.
- Modified table: `public.attendee` — drop `interesting_fact` column. Becomes pure identity: `id`, `email`, `first_name`, `last_name`, `created_at`, `updated_at`.
- Modified function: `public.check_in_attendee(text, text, text, text, uuid)` — signature unchanged; internally writes the fact to `event_attendee` instead of `attendee`. `ON CONFLICT DO UPDATE` on `event_attendee` so re-submits update the stored fact.

**Function return shape — unchanged.**
The `{success, already_checked_in, attendee_id}` jsonb output is preserved. The `already_checked_in` semantics shift slightly: it now means "this (event, attendee) pair already existed before this call" — but since the `ON CONFLICT DO UPDATE` always touches the row, we need the `xmax = 0` trick to detect whether the row was newly inserted vs. updated. This keeps the existing frontend's `isExistingAttendee` flag accurate.

**Access control — unchanged from v1.4.0.**
Anon still has zero direct access to `attendee` or `event_attendee`. Function still runs as `SECURITY DEFINER`. No new grants needed.

**Frontend (SvelteKit + supabase-js)**
- `src/lib/types.ts` — drop `interesting_fact: string` from the `Attendee` interface; remove its check from the `isAttendee` type guard; add `interesting_fact: string` to the `EventAttendee` interface.
- `src/lib/database.ts` — no changes (still passes `p_interesting_fact` to the RPC; the RPC handles routing).
- `src/lib/screens/CheckinForm.svelte` — no changes (still collects `interestingFact` from the form and passes it through).
- `src/lib/validation.ts` and `src/lib/database.ts:217-220` (duplicated `validateCheckInForm`) — no changes (still validate the form input field; the field name didn't change).

## 3. Implementation Notes
_Shared technical considerations across all features in this version._

**Migration order is load-bearing.** Single transaction:

1. `ALTER TABLE event_attendee ADD COLUMN interesting_fact text` (nullable initially).
2. Backfill: `UPDATE event_attendee ea SET interesting_fact = a.interesting_fact FROM attendee a WHERE ea.attendee_id = a.id`.
3. Defensive check: verify no `event_attendee` rows remain with NULL `interesting_fact`. If any do (orphaned join rows), raise an exception to roll back rather than silently lose data.
4. `ALTER TABLE event_attendee ALTER COLUMN interesting_fact SET NOT NULL`.
5. `ALTER TABLE attendee DROP COLUMN interesting_fact`.
6. `CREATE OR REPLACE FUNCTION check_in_attendee(...)` with updated body.

**Backfill is not lossy.** Today there is exactly one `interesting_fact` per attendee. Every `event_attendee` row for that person displays the same value (it's the only one that exists). Copying that single value into every `event_attendee` row preserves the current state exactly. Per-event differentiation begins with the first new check-in after v1.5.0 ships.

**Updated function body — key change:**

```
-- attendee upsert no longer writes interesting_fact
INSERT INTO attendee (email, first_name, last_name)
VALUES (v_email, v_first_name, v_last_name)
ON CONFLICT (email) DO UPDATE
    SET first_name = EXCLUDED.first_name,
        last_name  = EXCLUDED.last_name,
        updated_at = now()
RETURNING id INTO v_attendee_id;

-- event_attendee insert now writes interesting_fact, with DO UPDATE for re-submits
WITH upserted AS (
    INSERT INTO event_attendee (event_id, attendee_id, interesting_fact)
    VALUES (p_event_id, v_attendee_id, v_interesting_fact)
    ON CONFLICT (event_id, attendee_id) DO UPDATE
        SET interesting_fact = EXCLUDED.interesting_fact
    RETURNING (xmax = 0) AS was_inserted
)
SELECT was_inserted INTO v_was_inserted FROM upserted;
```

The `xmax = 0` trick: in Postgres, `xmax` is 0 on a freshly inserted row and non-zero on a row that was updated (the value is the transaction ID that locked it). This is the canonical way to distinguish "did the INSERT win" vs "did the DO UPDATE fire" from inside the same statement.

**No change to function signature, grants, or anon access.** The frontend's RPC call is byte-identical. The migration only touches schema + function body.

## 4. Other Technical Considerations
_Shared any other technical information that might be relevant to building this version._

**Behavioral change visible to end users:** none in v1.5.0 itself. The form, the success page, and the raffle UI all behave identically.

**Behavioral change visible to the database (and future features):**
- Re-submitting a check-in for the same event with a different fact now updates that event's fact (current behavior on v1.4.0: it updated the global `attendee.interesting_fact`, which silently rewrote every prior event's display).
- Each event_attendee row has its own permanent record of what was shared at that gathering.

**Smoke-test impact.** The existing v1.4.0 prod smoke-test data (`smoketest+*@example.com` rows) will be backfilled along with everything else. If those rows are still in production at migration time, they'll get a sensible interesting_fact value carried over from their attendee row. No special cleanup needed first.

**Backwards compatibility:**
- The `Attendee` TypeScript type loses `interesting_fact`. The `isAttendee` guard's check on that field must be removed in the same PR or the guard will always return false for v1.5.0 data.
- `AttendeeInput`, derived via `Omit<Attendee, 'id' | 'created_at' | 'updated_at'>`, automatically loses `interesting_fact` too. Callers passing it (just `CheckinForm.svelte:43`) will get a TypeScript error if `interesting_fact` is included in the literal. But: the form passes the data straight to `checkInAttendee()`, whose parameter type is `AttendeeInput`. We need to decide whether to keep `interesting_fact` in `AttendeeInput` (because the RPC still takes it as input) or remove it (because it's no longer stored on the attendee row).

**Decision on `AttendeeInput`:** keep `interesting_fact` in it. Despite the field no longer being persisted on the attendee row, the form still collects it and the RPC still accepts it. Renaming `AttendeeInput` to something more accurate (e.g., `CheckInPayload`) would be cosmetic churn. Either define a new explicit input type for the RPC, or keep `AttendeeInput` as-is. v1.5.0 will take the second path to minimize the diff: re-add `interesting_fact` to `AttendeeInput` directly (it stops being auto-derived from `Attendee`).

**Out of scope for v1.5.0:**
- Consolidating the duplicated `validateCheckInForm` between `src/lib/validation.ts` and `src/lib/database.ts`. Real but unrelated cosmetic debt.
- Renaming `AttendeeInput` → `CheckInPayload` for accuracy.
- Surfacing per-event facts in any UI (raffle display, admin views, etc.).
- Renaming the stale `"Allow public read access to meetups"` policy on `community` (still on the followup list from v1.4.0).

## 5. Open Questions
_Unresolved technical or product questions affecting this version._

None. All items previously open have been resolved before code authoring:

1. **Frontend impact** — audited. Only `types.ts` needs structural changes. `database.ts`, `validation.ts`, `CheckinForm.svelte` are untouched.
2. **`AttendeeInput` shape** — decided to keep `interesting_fact` on it explicitly (no longer derived from `Attendee` via `Omit`). Smallest diff path.
3. **Function return shape** — preserved exactly. `already_checked_in` semantics maintained via `xmax = 0`.
