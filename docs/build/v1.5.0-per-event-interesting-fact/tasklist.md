# Version Tasklist – v1.5.0-per-event-interesting-fact
This document outlines all the tasks to work on to deliver this particular version, grouped by phases.

| Status |      |
|--------|------|
| 🔴 | Not Started |
| 🟡 | In Progress |
| 🟢 | Completed |


## Phase 1: SQL Function & Migration Authoring

All SQL files created in this phase. Nothing is executed against the live database yet.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T01 | Update canonical function file | Update `database/functions/check-in-attendee.sql`: attendee upsert no longer writes `interesting_fact`; event_attendee insert now writes it with `ON CONFLICT DO UPDATE`; use `xmax = 0` to preserve `already_checked_in` return semantics. Signature unchanged. | None | 🟢 Completed | AGENT |
| T02 | Author v1.5.0 migration | Write `database/migrations/v1.5.0-per-event-interesting-fact.sql`. Single transaction. Steps in order: add nullable column to event_attendee, backfill from attendee, defensive NULL check, set NOT NULL, drop attendee.interesting_fact, install updated function. | T01 | 🟢 Completed | AGENT |
| T03 | Author v1.5.0 rollback migration | Write `database/migrations/v1.5.0-per-event-interesting-fact-rollback.sql`. Single transaction. Restores attendee.interesting_fact (backfilled from event_attendee picking earliest), restores prior function body (writes fact to attendee, DO NOTHING on event_attendee), drops event_attendee.interesting_fact. | T02 | 🟢 Completed | AGENT |

## Phase 2: Apply Migration in Supabase

User runs SQL in the Supabase SQL editor and verifies database state.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T04 | Apply v1.5.0 migration | Paste `v1.5.0-per-event-interesting-fact.sql` into Supabase SQL editor and run. Confirm success. | T01, T02 | 🟢 Completed | USER |
| T05 | Verify schema changes | Confirm via SQL: `attendee` has no `interesting_fact` column, `event_attendee` has it as `NOT NULL`, every existing event_attendee row has a non-null value (237 rows, 0 nulls). | T04 | 🟢 Completed | USER |
| T06 | Smoke test the updated function in SQL editor | Call `check_in_attendee()` four times to exercise: new attendee + event, same email + same event with **different fact** (should update event_attendee.interesting_fact and return `already_checked_in: true`), same email + different event with different fact (two separate event_attendee rows with different facts), invalid email (rejected). All passed. | T04 | 🟢 Completed | USER |

## Phase 3: Frontend Type Updates

Update TypeScript types to match the new schema. No runtime behavior change.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T07 | Update types.ts | Drop `interesting_fact` from `Attendee` interface; remove its check from `isAttendee` type guard at line 257; add `interesting_fact: string` to `EventAttendee` interface; explicitly redeclare `AttendeeInput` so it keeps `interesting_fact` (no longer auto-derived from `Attendee` via Omit). | T04 | 🟢 Completed | AGENT |
| T08 | Type-check | Run `npm run check`. Confirm no new errors introduced beyond the pre-existing tsconfig baseline noted in v1.4.0 retrospective. | T07 | 🟢 Completed | AGENT |
| T09 | Manual smoke test in production | USER deploys via git push, then opens a live event URL, completes a check-in end-to-end. Verifies (a) check-in still succeeds with no UI change, (b) event_attendee row now has the interesting_fact value, (c) re-submitting with a different fact for the same event updates only that event's fact (not other events the person has attended). All passed. | T08 | 🟢 Completed | USER |

## Phase 4: Documentation

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T10 | Update latest-schema.sql | Move `interesting_fact` from `attendee` to `event_attendee` block; refresh header comment if needed. | T09 | 🟢 Completed | AGENT |
| T11 | Mark v1.5.0 complete in backlog | Update `docs/build/feature-backlog.md`: set v1.5.0 status to 🟢 Completed and all 7 feature rows (F113–F119) to 🟢 Completed. | T10 | 🟢 Completed | AGENT |

## Phase 5: Wrap-Up

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T12 | Write retrospective | Create `docs/build/v1.5.0-per-event-interesting-fact/retrospective.md` from template. | T11 | 🟢 Completed | AGENT |
| T13 | Update cody.json | Set `version` to `1.5.0` and `updatedAt` to today's date. | T11 | 🟢 Completed | AGENT |
| T14 | Update release-notes.md | Add v1.5.0 entry to `release-notes.md` at project root. | T11 | 🟢 Completed | AGENT |
| T15 | Commit to git | USER commits all changes with a descriptive message. | T14 | 🟢 Completed | USER |
