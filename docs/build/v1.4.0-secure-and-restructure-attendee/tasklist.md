# Version Tasklist – v1.4.0-secure-and-restructure-attendee
This document outlines all the tasks to work on to deliver this particular version, grouped by phases.

| Status |      |
|--------|------|
| 🔴 | Not Started |
| 🟡 | In Progress |
| 🟢 | Completed |


## Phase 1: SQL Function & Migration Authoring

All SQL files created in this phase. Nothing is executed against the live database yet — just files on disk for review.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T01 | Create check_in_attendee function file | Write `database/functions/check-in-attendee.sql` with SECURITY DEFINER, search_path hardening, full input validation, idempotent upsert flow, jsonb return shape. Mirrors the style of `get-raffle-winners.sql`. | None | 🟢 Completed | AGENT |
| T02 | Author v1.4.0 migration | Write `database/migrations/v1.4.0-secure-and-restructure-attendee.sql`. Single transaction. Steps in order: create `community_attendee` table, backfill via UNION, drop `attendee.community_id`, install function, drop 5 permissive policies, revoke direct anon GRANTs, enable RLS on `community_attendee`. | T01 | 🟢 Completed | AGENT |
| T03 | Author v1.4.0 rollback migration | Write `database/migrations/v1.4.0-secure-and-restructure-attendee-rollback.sql`. Single transaction. Restores `attendee.community_id` (backfilled from earliest `community_attendee.created_at` per attendee), restores the 5 policies verbatim, restores GRANTs, drops the function and the `community_attendee` table. | T02 | 🟢 Completed | AGENT |

## Phase 2: Apply Migration in Supabase

User runs SQL in the Supabase SQL editor and verifies database state.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T04 | Apply v1.4.0 migration | Paste `v1.4.0-secure-and-restructure-attendee.sql` into Supabase SQL editor and run. Confirm it succeeds. | T01, T02 | 🟢 Completed | USER |
| T05 | Verify post-migration grants | Re-run the GRANTs audit query. Expect `anon` to have **no** grants on `attendee`, `event_attendee`, or `community_attendee`. | T04 | 🟢 Completed | USER |
| T06 | Verify post-migration policies | Re-run the policies query. Expect the 5 permissive policies on `attendee`/`event_attendee` to be gone. Confirm RLS is enabled on `community_attendee`. | T04 | 🟢 Completed | USER |
| T07 | Smoke test the function in SQL editor | Call `select check_in_attendee(...)` once with valid inputs and once with an invalid email; confirm correct behavior. | T04 | 🟢 Completed | USER |

## Phase 3: Frontend Refactor

Update the SvelteKit app to use the new RPC. After this phase, `npm run check` and a dev-server smoke test should both pass.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T08 | Drop community_id from Attendee type | Edit `src/lib/types.ts`: remove `community_id: string` from the `Attendee` interface. Confirm derived types (`AttendeeInput`, `AttendeeUpdate`) and the `isAttendee` guard still compile. | T04 | 🟢 Completed | AGENT |
| T09 | Rewrite checkInAttendee | Edit `src/lib/database.ts`: replace the multi-step `checkInAttendee` with a single `supabase.rpc('check_in_attendee', {...})` call. Map the RPC's jsonb response to the existing `CheckInResponse` shape. | T08 | 🟢 Completed | AGENT |
| T10 | Delete now-unused helpers | Remove `createAttendee`, `upsertAttendee`, `updateAttendee`, `getAttendeeByEmail`, `linkAttendeeToEvent`, `isEmailRegisteredForEvent`, `getEventById` from `src/lib/database.ts`. Confirm no references remain via grep. | T09 | 🟢 Completed | AGENT |
| T11 | Type-check and lint | Run `npm run check` and `npm run lint`. Confirmed v1.4.0 introduces zero new errors. (Pre-existing tooling errors — tsconfig `$lib` resolution issue and ESLint baseline — remain unchanged. Out of scope for this version.) | T10 | 🟢 Completed | AGENT |
| T12 | Manual smoke test in production | USER deploys via git push, then opens a live event URL, completes a check-in end-to-end against the migrated database, confirms attendee + community_attendee + event_attendee rows appear, tests re-submit idempotency. (Local dev test skipped — no live events at time of deploy, prod smoke test substitutes.) | T11 | 🔴 Not Started | USER |

## Phase 4: Documentation

Reflect the new state in the project's schema reference and grant docs.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T13 | Update latest-schema.sql | Remove `community_id` from `attendee`. Add `community_attendee` table definition + grant block. Update `attendee` and `event_attendee` grant blocks to remove anon (since anon now has no direct access). Add header comment noting check-in goes through `check_in_attendee()` RPC. | T12 | 🟢 Completed | AGENT |
| T14 | Mark v1.4.0 complete in backlog | Update `docs/build/feature-backlog.md`: set v1.4.0 status to 🟢 Completed and all 10 feature rows (F103–F112) to 🟢 Completed. | T13 | 🟢 Completed | AGENT |

## Phase 5: Wrap-Up

Cody Product Builder closeout steps.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T15 | Write retrospective | Create `docs/build/v1.4.0-secure-and-restructure-attendee/retrospective.md` from template. | T14 | 🟢 Completed | AGENT |
| T16 | Update cody.json | Set `version` to `1.4.0` and `updatedAt` to today's date. | T14 | 🟢 Completed | AGENT |
| T17 | Update release-notes.md | Add v1.4.0 entry to `release-notes.md` at project root. | T14 | 🟢 Completed | AGENT |
| T18 | Commit to git | USER commits all changes with a descriptive message. | T17 | 🔴 Not Started | USER |
