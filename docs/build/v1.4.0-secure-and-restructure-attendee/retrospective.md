# Version Retrospective – v1.4.0-secure-and-restructure-attendee
This document reflects on what worked, what didn't, and how future versions can be improved.

## Version Summary

v1.4.0 was triggered by Supabase's announced policy change removing auto-grants on new public tables (May 30, 2026 for new projects, October 30, 2026 for existing). While auditing the project against that change, two unrelated but more pressing issues surfaced:

1. **Over-broad anon access.** Every public table had legacy `GRANT ALL` to `anon`, `authenticated`, `service_role`, and the `attendee` / `event_attendee` tables had `using = true` RLS policies. Anyone with the anon key (visible in the JS bundle) could read or modify the entire attendee table.

2. **Incorrect attendee/community data model.** `attendee.community_id` was a foreign key that nominally said "this attendee belongs to one community," but the code treated attendees as global-by-email and linked them to events across communities via `event_attendee`. The column was misleading and blocked planned future features (multi-community user views, per-community attendee lists).

The version addressed both in a single atomic migration:
- New `community_attendee` join table for true many-to-many, backfilled from existing data via a UNION of `attendee.community_id` and `event_attendee → event.community_id`.
- `attendee.community_id` dropped.
- New `check_in_attendee()` SECURITY DEFINER function as the only anon mutation path.
- Five permissive RLS policies dropped; direct anon GRANTs revoked on `attendee` and `event_attendee`.

Frontend changes were limited to `src/lib/database.ts` (rewrite `checkInAttendee` as a single RPC call, delete 7 now-unused helpers) and `src/lib/types.ts` (drop `community_id` from `Attendee`). The UI (`CheckinForm.svelte`, success page) needed no changes.

## What Went Well

- **Scope discovery surfaced real problems early.** The conversation started as "do I need to worry about a Supabase email," not a planned data-model refactor. Auditing the live grants and policies surfaced both the over-broad access and the misleading `attendee.community_id`. Combining the security tightening with the data-model fix into one v1.4.0 avoided a partial-progress interim state.
- **Atomic migration design.** Wrapping the entire migration in a single `BEGIN/COMMIT` block with the backfill before the `DROP COLUMN` removed the data-loss risk. If any step had failed in production, nothing would have changed.
- **Server-side validation moved from client to database.** Previously, `VALIDATION_RULES` in TypeScript was the only line of defense — and only against well-behaved browsers. The `check_in_attendee()` function mirrors the same rules in plpgsql, so a malicious client calling the RPC directly hits the same constraints.
- **Idempotent check-in by design.** `ON CONFLICT DO NOTHING` on the `event_attendee` insert handles re-submissions, double-clicks, and same-email-different-event flows without needing a pre-check query. The SQL smoke test confirmed `updated_at` advances on re-submit while no duplicate rows are created.
- **No live events at the time of deploy.** The decision to deploy without a local dev test was acceptable because there were no real users to impact. Production smoke test was used as the integration check.

## What Could Have Gone Better

- **The data-model problem should have been caught earlier in the project.** `attendee.community_id` has existed since v0.5.0 but was never reconciled with the actual M:N usage pattern. A schema review pass at any prior version would have surfaced it.
- **Local type-check / lint is broken project-wide.** `npm run check` reports 24 errors (mostly `$lib` module-resolution from a tsconfig.json that overrides SvelteKit's auto-generated paths), and `npm run lint` reports 751 errors. Neither tool is currently useful for catching regressions. v1.4.0 worked around this by reading errors per-file, but the tooling debt is real.
- **Local dev environment was unavailable for this version.** The user could not run the SvelteKit dev server locally during the build, forcing the prod smoke test to substitute for T12. This worked here because of the no-live-events constraint, but it's not a sustainable pattern.

## Lessons Learned

- **"Is this safe?" is a more productive question than "do I need to act on this email?"** Supabase's announcement was not actually urgent for this project (existing tables grandfathered, no new tables imminent). But asking "is my current state safe?" exposed a real security gap.
- **Audit GRANTs and RLS together, not separately.** Wide grants look alarming in isolation but are defanged by RLS in practice. Conversely, tight grants don't help if a policy has `using = true`. Both layers must be checked.
- **`SECURITY DEFINER` with `search_path = public, pg_temp` is the textbook pattern for anon-accessible mutation in Supabase.** Cleaner than trying to write RLS policies that scope to "rows belonging to a request whose identity we can't verify."
- **A backfill-then-drop migration must be in a single transaction.** Doing the backfill and column drop in separate statements (or scripts) creates a window where data could be lost on partial failure.

## Action Items

- **(Future patch)** Clean up the project's `tsconfig.json` to remove the `baseUrl`/`paths` that interfere with SvelteKit's `$lib` resolution. This will unblock `npm run check` and make future versions easier to verify.
- **(Future patch)** Rename the legacy `"Allow public read access to meetups"` policy on the `community` table — it's a leftover from before the v1.3.1 group→community rename and is now cosmetically wrong.
- **(Future v1.5.0 or later)** Build the authenticated user views the data model now supports: "show me all events/communities I've attended" and "show community owners all their attendees." Will require defining `authenticated`-role RLS policies that were intentionally left out of v1.4.0.
- **(Future patch)** Consider explicit GRANTs on `community_attendee` in the migration file (currently relies on Supabase's auto-grant for `authenticated`/`service_role`, which won't be there if applied post-Oct-30 to a fresh project).
- **Restore local dev environment.** The inability to run the dev server locally during this version pushed integration testing into production. Useful but not a pattern to repeat.
